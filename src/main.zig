const std = @import("std");
const math = std.math;
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;

// WGSL Simple shader
// zig fmt: off
const wgsl_simple_vs =
    \\  struct Uniforms {
    \\      aspect_ratio: f32,
    \\      mip_level: f32,
    \\  }
    \\  @group(0) @binding(0) var<uniform> uniforms: Uniforms;
    \\
    \\  struct VertexOut {
    \\      @builtin(position) position_clip: vec4<f32>,
    \\      @location(0) uv: vec2<f32>,
    \\  }
    \\  @vertex fn main(
    \\      @location(0) position: vec2<f32>,
    \\      @location(1) uv: vec2<f32>,
    \\  ) -> VertexOut {
    \\      let p = vec2(position.x / uniforms.aspect_ratio, position.y);
    \\      var output: VertexOut;
    \\      output.position_clip = vec4(p, 0.0, 1.0);
    \\      output.uv = uv;
    \\      return output;
    \\  }
;
const wgsl_simple_fs =
    \\  @fragment fn main(
    \\      @location(0) uv: vec2<f32>,
    \\  ) -> @location(0) vec4<f32> {
    \\      return vec4(1.0, 0.0, 0.0, 1.0);
    \\  }
;
// zig fmt: on

// zig fmt: off
const wgsl_common =
\\  struct Uniforms {
\\      aspect_ratio: f32,
\\      mip_level: f32,
\\  }
\\  @group(0) @binding(0) var<uniform> uniforms: Uniforms;
;
const wgsl_vs = wgsl_common ++
    \\  struct VertexOut {
    \\      @builtin(position) position_clip: vec4<f32>,
    \\      @location(0) uv: vec2<f32>,
    \\  }
    \\  @vertex fn main(
    \\      @location(0) position: vec2<f32>,
    \\      @location(1) uv: vec2<f32>,
    \\  ) -> VertexOut {
    \\      let p = vec2(position.x / uniforms.aspect_ratio, position.y);
    \\      var output: VertexOut;
    \\      output.position_clip = vec4(p, 0.0, 1.0);
    \\      output.uv = uv;
    \\      return output;
    \\  }
;
const wgsl_fs = wgsl_common ++
    \\  @group(0) @binding(1) var image: texture_2d<f32>;
    \\  @group(0) @binding(2) var image_sampler: sampler;
    \\  @fragment fn main(
    \\      @location(0) uv: vec2<f32>,
    \\  ) -> @location(0) vec4<f32> {
    \\      return textureSampleLevel(image, image_sampler, uv, uniforms.mip_level);
    \\  }
;
// zig fmt: on

const Vertex = extern struct {
    position: [2]f32,
    uv: [2]f32,
};

const Uniforms = extern struct {
    aspect_ratio: f32,
    mip_level: f32,
};

const DemoState = struct {
    gctx: *zgpu.GraphicsContext,

    simple_pipeline: zgpu.RenderPipelineHandle = .{},
    simple_bind_group: zgpu.BindGroupHandle,

    pipeline: zgpu.RenderPipelineHandle = .{},
    bind_group: zgpu.BindGroupHandle,

    vertex_buffer: zgpu.BufferHandle,
    index_buffer: zgpu.BufferHandle,

    texture: zgpu.TextureHandle,
    texture_view: zgpu.TextureViewHandle,
    sampler: zgpu.SamplerHandle,

    mip_level: i32 = 0,
};

fn create(allocator: std.mem.Allocator, window: *zglfw.Window) !*DemoState {
    const gctx = try zgpu.GraphicsContext.create(
        allocator,
        .{
            .window = window,
            .fn_getTime = @ptrCast(&zglfw.getTime),
            .fn_getFramebufferSize = @ptrCast(&zglfw.Window.getFramebufferSize),
            .fn_getWin32Window = @ptrCast(&zglfw.getWin32Window),
            .fn_getX11Display = @ptrCast(&zglfw.getX11Display),
            .fn_getX11Window = @ptrCast(&zglfw.getX11Window),
            .fn_getWaylandDisplay = @ptrCast(&zglfw.getWaylandDisplay),
            .fn_getWaylandSurface = @ptrCast(&zglfw.getWaylandWindow),
            .fn_getCocoaWindow = @ptrCast(&zglfw.getCocoaWindow),
        },
        .{},
    );
    errdefer gctx.destroy(allocator);

    // var arena_state = std.heap.ArenaAllocator.init(allocator);
    // defer arena_state.deinit();
    // const arena = arena_state.allocator();

    const simple_bind_group_layout = gctx.createBindGroupLayout(&.{
        zgpu.bufferEntry(0, .{ .vertex = true, .fragment = true }, .uniform, true, 0),
    });
    defer gctx.releaseResource(simple_bind_group_layout);

    const bind_group_layout = gctx.createBindGroupLayout(&.{
        zgpu.bufferEntry(0, .{ .vertex = true, .fragment = true }, .uniform, true, 0),
        zgpu.textureEntry(1, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.samplerEntry(2, .{ .fragment = true }, .filtering),
    });
    defer gctx.releaseResource(bind_group_layout);

    // Create a vertex buffer.
    const vertex_data = [_]Vertex{
        .{ .position = [2]f32{ -0.9, 0.9 }, .uv = [2]f32{ 0.0, 0.0 } },
        .{ .position = [2]f32{ 0.9, 0.9 }, .uv = [2]f32{ 1.0, 0.0 } },
        .{ .position = [2]f32{ 0.9, -0.9 }, .uv = [2]f32{ 1.0, 1.0 } },
        .{ .position = [2]f32{ -0.9, -0.9 }, .uv = [2]f32{ 0.0, 1.0 } },
    };
    const vertex_buffer = gctx.createBuffer(.{
        .usage = .{ .copy_dst = true, .vertex = true },
        .size = vertex_data.len * @sizeOf(Vertex),
    });
    gctx.queue.writeBuffer(gctx.lookupResource(vertex_buffer).?, 0, Vertex, vertex_data[0..]);

    // Create an index buffer.
    const index_data = [_]u16{ 0, 1, 3, 1, 2, 3 };
    const index_buffer = gctx.createBuffer(.{
        .usage = .{ .copy_dst = true, .index = true },
        .size = index_data.len * @sizeOf(u16),
    });
    gctx.queue.writeBuffer(gctx.lookupResource(index_buffer).?, 0, u16, index_data[0..]);

    // Create a texture.
    const texture = gctx.createTexture(.{
        .usage = .{
            .texture_binding = true,
            .copy_dst = true,
            .render_attachment = true,
        },
        .size = .{
            .width = 600,
            .height = 600,
            .depth_or_array_layers = 1,
        },
        .format = .bgra8_unorm,
        // Attachment can't have mip levels
        // .mip_level_count = math.log2_int(u32, 600) + 1,
    });
    const texture_view = gctx.createTextureView(texture, .{});

    // gctx.queue.writeTexture(
    //     .{ .texture = gctx.lookupResource(texture).? },
    //     .{
    //         .bytes_per_row = image.bytes_per_row,
    //         .rows_per_image = image.height,
    //     },
    //     .{ .width = image.width, .height = image.height },
    //     u8,
    //     image.data,
    // );

    // Create a sampler.
    const sampler = gctx.createSampler(.{});

    const simple_bind_group = gctx.createBindGroup(simple_bind_group_layout, &.{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = 256 },
    });

    const bind_group = gctx.createBindGroup(bind_group_layout, &.{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = 256 },
        .{ .binding = 1, .texture_view_handle = texture_view },
        .{ .binding = 2, .sampler_handle = sampler },
    });

    const demo = try allocator.create(DemoState);
    demo.* = .{
        .gctx = gctx,
        .simple_bind_group = simple_bind_group,
        .bind_group = bind_group,
        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,
        .texture = texture,
        .texture_view = texture_view,
        .sampler = sampler,
    };

    // Generate mipmaps on the GPU.
    // const commands = commands: {
    //     const encoder = gctx.device.createCommandEncoder(null);
    //     defer encoder.release();
    //
    //     gctx.generateMipmaps(arena, encoder, demo.texture);
    //
    //     break :commands encoder.finish(null);
    // };
    // defer commands.release();
    // gctx.submit(&.{commands});

    // (Async) Create a render pipeline.
    {
        // simple
        const simple_pipeline_layout = gctx.createPipelineLayout(&.{
            simple_bind_group_layout,
        });
        defer gctx.releaseResource(simple_pipeline_layout);

        // regular
        const pipeline_layout = gctx.createPipelineLayout(&.{
            bind_group_layout,
        });
        defer gctx.releaseResource(pipeline_layout);

        const color_targets = [_]wgpu.ColorTargetState{.{
            .format = zgpu.GraphicsContext.swapchain_format,
        }};

        const vertex_attributes = [_]wgpu.VertexAttribute{
            .{ .format = .float32x2, .offset = 0, .shader_location = 0 },
            .{ .format = .float32x2, .offset = @offsetOf(Vertex, "uv"), .shader_location = 1 },
        };
        const vertex_buffers = [_]wgpu.VertexBufferLayout{.{
            .array_stride = @sizeOf(Vertex),
            .attribute_count = vertex_attributes.len,
            .attributes = &vertex_attributes,
        }};

        // Create a simple render pipeline.
        {
            const vs_module = zgpu.createWgslShaderModule(gctx.device, wgsl_simple_vs, "vs");
            defer vs_module.release();

            const fs_module = zgpu.createWgslShaderModule(gctx.device, wgsl_simple_fs, "fs");
            defer fs_module.release();

            const pipeline_descriptor = wgpu.RenderPipelineDescriptor{
                .vertex = .{
                    .module = vs_module,
                    .entry_point = "main",
                    .buffer_count = vertex_buffers.len,
                    .buffers = &vertex_buffers,
                },
                .primitive = .{
                    .front_face = .cw,
                    .cull_mode = .back,
                    .topology = .triangle_list,
                },
                .fragment = &.{
                    .module = fs_module,
                    .entry_point = "main",
                    .target_count = color_targets.len,
                    .targets = &color_targets,
                },
            };

            gctx.createRenderPipelineAsync(
                allocator,
                simple_pipeline_layout,
                pipeline_descriptor,
                &demo.simple_pipeline,
            );
        }

        // Create a final render pipeline.
        {
            const vs_module = zgpu.createWgslShaderModule(gctx.device, wgsl_vs, "vs");
            defer vs_module.release();

            const fs_module = zgpu.createWgslShaderModule(gctx.device, wgsl_fs, "fs");
            defer fs_module.release();

            const pipeline_descriptor = wgpu.RenderPipelineDescriptor{
                .vertex = .{
                    .module = vs_module,
                    .entry_point = "main",
                    .buffer_count = vertex_buffers.len,
                    .buffers = &vertex_buffers,
                },
                .primitive = .{
                    .front_face = .cw,
                    .cull_mode = .back,
                    .topology = .triangle_list,
                },
                .fragment = &.{
                    .module = fs_module,
                    .entry_point = "main",
                    .target_count = color_targets.len,
                    .targets = &color_targets,
                },
            };

            gctx.createRenderPipelineAsync(
                allocator,
                pipeline_layout,
                pipeline_descriptor,
                &demo.pipeline,
            );
        }
    }

    return demo;
}

fn destroy(allocator: std.mem.Allocator, demo: *DemoState) void {
    demo.gctx.destroy(allocator);
    allocator.destroy(demo);
}

fn draw(demo: *DemoState) void {
    const gctx = demo.gctx;
    const fb_width = gctx.swapchain_descriptor.width;
    const fb_height = gctx.swapchain_descriptor.height;

    const back_buffer_view = gctx.swapchain.getCurrentTextureView();
    defer back_buffer_view.release();

    const commands = commands: {
        const encoder = gctx.device.createCommandEncoder(null);
        defer encoder.release();

        // Main pass.
        pass: {
            const vb_info = gctx.lookupResourceInfo(demo.vertex_buffer) orelse break :pass;
            const ib_info = gctx.lookupResourceInfo(demo.index_buffer) orelse break :pass;
            const simple_pipeline = gctx.lookupResource(demo.simple_pipeline) orelse break :pass;
            const pipeline = gctx.lookupResource(demo.pipeline) orelse break :pass;
            const simple_bind_group = gctx.lookupResource(demo.simple_bind_group) orelse break :pass;
            const bind_group = gctx.lookupResource(demo.bind_group) orelse break :pass;
            const texture_view = gctx.lookupResource(demo.texture_view) orelse break :pass;

            // Simple render pass
            {
                const color_attachments = [_]wgpu.RenderPassColorAttachment{.{
                    .view = texture_view,
                    .load_op = .clear,
                    .store_op = .store,
                }};
                const render_pass_info = wgpu.RenderPassDescriptor{
                    .color_attachment_count = color_attachments.len,
                    .color_attachments = &color_attachments,
                };
                const pass = encoder.beginRenderPass(render_pass_info);
                defer {
                    pass.end();
                    pass.release();
                }

                pass.setVertexBuffer(0, vb_info.gpuobj.?, 0, vb_info.size);
                pass.setIndexBuffer(ib_info.gpuobj.?, .uint16, 0, ib_info.size);

                pass.setPipeline(simple_pipeline);

                const mem = gctx.uniformsAllocate(Uniforms, 1);
                mem.slice[0] = .{
                    .aspect_ratio = @as(f32, @floatFromInt(fb_width)) / @as(f32, @floatFromInt(fb_height)),
                    .mip_level = @as(f32, @floatFromInt(demo.mip_level)),
                };

                pass.setBindGroup(0, simple_bind_group, &.{mem.offset});

                pass.drawIndexed(6, 1, 0, 0, 0);
            }

            // Final render pass
            {
                const color_attachments = [_]wgpu.RenderPassColorAttachment{.{
                    .view = back_buffer_view,
                    .load_op = .clear,
                    .store_op = .store,
                }};
                const render_pass_info = wgpu.RenderPassDescriptor{
                    .color_attachment_count = color_attachments.len,
                    .color_attachments = &color_attachments,
                };

                const pass = encoder.beginRenderPass(render_pass_info);
                defer {
                    pass.end();
                    pass.release();
                }

                pass.setVertexBuffer(0, vb_info.gpuobj.?, 0, vb_info.size);
                pass.setIndexBuffer(ib_info.gpuobj.?, .uint16, 0, ib_info.size);

                pass.setPipeline(pipeline);

                const mem = gctx.uniformsAllocate(Uniforms, 1);
                mem.slice[0] = .{
                    .aspect_ratio = @as(f32, @floatFromInt(fb_width)) / @as(f32, @floatFromInt(fb_height)),
                    .mip_level = @as(f32, @floatFromInt(demo.mip_level)),
                };

                pass.setBindGroup(0, bind_group, &.{mem.offset});

                pass.drawIndexed(6, 1, 0, 0, 0);
            }
        }

        break :commands encoder.finish(null);
    };
    defer commands.release();

    gctx.submit(&.{commands});
    _ = gctx.present();
}

pub fn main() !void {
    try zglfw.init();
    defer zglfw.terminate();

    zglfw.windowHint(.client_api, .no_api);

    const window = try zglfw.Window.create(600, 600, "Smooth Life", null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const demo = try create(allocator, window);
    defer destroy(allocator, demo);

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();
        draw(demo);
    }
}
