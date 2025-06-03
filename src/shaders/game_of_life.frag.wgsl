struct Uniforms {
    aspect_ratio: f32,
    frag_step: vec2<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var image: texture_2d<f32>;
@group(0) @binding(2) var image_sampler: sampler;

const step = 0.0016666666666666668;

@fragment fn main(
    @location(0) uv: vec2<f32>,
) -> @location(0) vec4<f32> {
    // return vec4(1.0, 0.0, 0.0, 1.0);
    // return textureSample(image, image_sampler, uv) + 0.002;

    let step_x = uniforms.frag_step.x;
    let step_y = uniforms.frag_step.y;

    let cell = textureSample(image, image_sampler, uv).r;
    let neighbours =
        textureSample(image, image_sampler, uv + vec2(-step_x, -step_y)).r +
        textureSample(image, image_sampler, uv + vec2( 0,      -step_y)).r +
        textureSample(image, image_sampler, uv + vec2( step_x, -step_y)).r +
        textureSample(image, image_sampler, uv + vec2(-step_x,  0     )).r +
        textureSample(image, image_sampler, uv + vec2( step_x,  0     )).r +
        textureSample(image, image_sampler, uv + vec2(-step_x,  step_y)).r +
        textureSample(image, image_sampler, uv + vec2( 0,       step_y)).r +
        textureSample(image, image_sampler, uv + vec2( step_x,  step_y)).r;

    return vec4(
        select(
            0.0,
            1.0,
            (cell == 0.0 && neighbours == 3.0) ||
            (cell == 1.0 && neighbours >= 2.0 && neighbours <= 3.0)
            ),
        0.0,
        0.0,
        1.0,
    );
}