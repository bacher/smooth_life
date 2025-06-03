struct Uniforms {
    aspect_ratio: f32,
    frag_step: vec2<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;

struct VertexOut {
    @builtin(position) position_clip: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

@vertex fn main(
    @location(0) position: vec2<f32>,
    @location(1) uv: vec2<f32>,
) -> VertexOut {
    let p = vec2(position.x / uniforms.aspect_ratio, position.y);
    var output: VertexOut;
    output.position_clip = vec4(p, 0.0, 1.0);
    output.uv = uv;
    return output;
}