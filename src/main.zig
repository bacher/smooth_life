const std = @import("std");
const math = std.math;
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;

const TEXTURE_WIDTH = 600;
const TEXTURE_HEIGHT = 600;

const frag_step: [2]f32 = .{
    1.0 / @as(f32, @floatFromInt(TEXTURE_WIDTH)),
    1.0 / @as(f32, @floatFromInt(TEXTURE_HEIGHT)),
};

const wgsl_simple_vs = @embedFile("shaders/game_of_life.vert.wgsl");
const wgsl_simple_fs = @embedFile("shaders/game_of_life.frag.wgsl");

const wgsl_vs = @embedFile("shaders/output.vert.wgsl");
const wgsl_fs = @embedFile("shaders/output.frag.wgsl");

const Vertex = extern struct {
    position: [2]f32,
    uv: [2]f32,
};

const Uniforms = extern struct {
    aspect_ratio: f32,
    // "frag_step" in the shader definition defined as vec2<f32>, which have aligment 8 bytes.
    // @sizeOf([2]f32) == 8
    frag_step: [2]f32 align(@sizeOf([2]f32)),
};

const DemoState = struct {
    gctx: *zgpu.GraphicsContext,

    simple_pipeline: zgpu.RenderPipelineHandle = .{},
    pipeline: zgpu.RenderPipelineHandle = .{},

    vertex_buffer: zgpu.BufferHandle,
    index_buffer: zgpu.BufferHandle,

    textures: [2]struct {
        bind_group: zgpu.BindGroupHandle,
        texture: zgpu.TextureHandle,
        texture_view: zgpu.TextureViewHandle,
    },

    sampler: zgpu.SamplerHandle,

    current_frame: u32 = 0,
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

    const bind_group_layout = gctx.createBindGroupLayout(&.{
        zgpu.bufferEntry(0, .{ .vertex = true, .fragment = true }, .uniform, true, 0),
        zgpu.textureEntry(1, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.samplerEntry(2, .{ .fragment = true }, .filtering),
    });
    defer gctx.releaseResource(bind_group_layout);

    // Create a vertex buffer.
    const vertex_data = [_]Vertex{
        .{ .position = [2]f32{ -1.0, 1.0 }, .uv = [2]f32{ 0.0, 0.0 } },
        .{ .position = [2]f32{ 1.0, 1.0 }, .uv = [2]f32{ 1.0, 0.0 } },
        .{ .position = [2]f32{ 1.0, -1.0 }, .uv = [2]f32{ 1.0, 1.0 } },
        .{ .position = [2]f32{ -1.0, -1.0 }, .uv = [2]f32{ 0.0, 1.0 } },
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

    const texture_1 = createDataTexture(gctx);
    const texture_view_1 = gctx.createTextureView(texture_1, .{});

    const texture_2 = createDataTexture(gctx);
    const texture_view_2 = gctx.createTextureView(texture_2, .{});

    const data = try generateStartingTextureData(allocator);
    defer allocator.free(data);

    gctx.queue.writeTexture(
        .{ .texture = gctx.lookupResource(texture_2).? },
        .{
            .bytes_per_row = TEXTURE_WIDTH * 4,
            .rows_per_image = TEXTURE_HEIGHT,
        },
        .{ .width = TEXTURE_WIDTH, .height = TEXTURE_HEIGHT },
        u8,
        data,
    );

    const sampler = gctx.createSampler(.{});

    const bind_group_1 = gctx.createBindGroup(bind_group_layout, &.{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = 256 },
        .{ .binding = 1, .texture_view_handle = texture_view_1 },
        .{ .binding = 2, .sampler_handle = sampler },
    });

    const bind_group_2 = gctx.createBindGroup(bind_group_layout, &.{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = 256 },
        .{ .binding = 1, .texture_view_handle = texture_view_2 },
        .{ .binding = 2, .sampler_handle = sampler },
    });

    const demo = try allocator.create(DemoState);
    demo.* = .{
        .gctx = gctx,
        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,
        .textures = .{
            .{
                .bind_group = bind_group_1,
                .texture = texture_1,
                .texture_view = texture_view_1,
            },
            .{
                .bind_group = bind_group_2,
                .texture = texture_2,
                .texture_view = texture_view_2,
            },
        },
        .sampler = sampler,
    };

    // (Async) Create a render pipeline.
    {
        const pipeline_layout = gctx.createPipelineLayout(&.{
            bind_group_layout,
        });
        defer gctx.releaseResource(pipeline_layout);

        const texture_color_targets = [_]wgpu.ColorTargetState{.{
            .format = .rgba8_unorm,
        }};
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

        // Create a texture render pipeline.
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
                    .target_count = texture_color_targets.len,
                    .targets = &texture_color_targets,
                },
            };

            gctx.createRenderPipelineAsync(
                allocator,
                pipeline_layout,
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

        pass: {
            const vb_info = gctx.lookupResourceInfo(demo.vertex_buffer) orelse break :pass;
            const ib_info = gctx.lookupResourceInfo(demo.index_buffer) orelse break :pass;
            const simple_pipeline = gctx.lookupResource(demo.simple_pipeline) orelse break :pass;
            const pipeline = gctx.lookupResource(demo.pipeline) orelse break :pass;

            const current_texture_info = demo.textures[demo.current_frame % 2];
            const previous_texture_info = demo.textures[1 - demo.current_frame % 2];

            const current_texture_view = gctx.lookupResource(current_texture_info.texture_view) orelse break :pass;
            const current_bind_group = gctx.lookupResource(current_texture_info.bind_group) orelse break :pass;

            const previous_bind_group = gctx.lookupResource(previous_texture_info.bind_group) orelse break :pass;

            // Game of life render pass
            {
                const color_attachments = [_]wgpu.RenderPassColorAttachment{.{
                    .view = current_texture_view,
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
                    .frag_step = frag_step,
                };

                pass.setBindGroup(0, previous_bind_group, &.{mem.offset});

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
                    .frag_step = frag_step,
                };

                pass.setBindGroup(0, current_bind_group, &.{mem.offset});

                pass.drawIndexed(6, 1, 0, 0, 0);
            }
        }

        break :commands encoder.finish(null);
    };
    defer commands.release();

    gctx.submit(&.{commands});
    _ = gctx.present();

    demo.current_frame += 1;
}

pub fn main() !void {
    try zglfw.init();
    defer zglfw.terminate();

    zglfw.windowHint(.client_api, .no_api);

    const window = try zglfw.Window.create(TEXTURE_WIDTH, TEXTURE_HEIGHT, "Smooth Life", null);
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

fn createDataTexture(gctx: *zgpu.GraphicsContext) zgpu.TextureHandle {
    return gctx.createTexture(.{
        .usage = .{
            .texture_binding = true,
            .copy_dst = true,
            .render_attachment = true,
        },
        .size = .{
            .width = TEXTURE_WIDTH,
            .height = TEXTURE_HEIGHT,
            .depth_or_array_layers = 1,
        },
        .format = .rgba8_unorm,
        // Attachment can't have mip levels
        // .mip_level_count = math.log2_int(u32, 600) + 1,
    });
}

fn generateStartingTextureData(allocator: std.mem.Allocator) ![]u8 {
    const data = try allocator.alloc([4]u8, TEXTURE_WIDTH * TEXTURE_HEIGHT);

    var y: usize = 0;
    while (y < TEXTURE_HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < TEXTURE_WIDTH) : (x += 1) {
            const intensivity: f32 = if (x >= 200 and x < 400 and y >= 250 and y < 350) 1.0 else 0.0;

            data[(y * TEXTURE_WIDTH + x)] = .{
                @intFromFloat(intensivity * 255.0 + 0.5),
                0,
                0,
                255,
            };
        }
    }

    return std.mem.sliceAsBytes(data);
}
