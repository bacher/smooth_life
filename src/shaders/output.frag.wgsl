struct Uniforms {
    aspect_ratio: f32,
    mip_level: f32,
}
@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var image: texture_2d<f32>;
@group(0) @binding(2) var image_sampler: sampler;

@fragment fn main(
    @location(0) uv: vec2<f32>,
) -> @location(0) vec4<f32> {
    return textureSample(image, image_sampler, uv).rrra;
}