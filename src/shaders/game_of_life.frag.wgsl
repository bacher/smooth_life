const step = 0.0016666666666666668;

@group(0) @binding(1) var image: texture_2d<f32>;
@group(0) @binding(2) var image_sampler: sampler;
@fragment fn main(
    @location(0) uv: vec2<f32>,
) -> @location(0) vec4<f32> {
    // return vec4(1.0, 0.0, 0.0, 1.0);
    // return textureSample(image, image_sampler, uv) + 0.002;
    let cell = textureSample(image, image_sampler, uv).r;
    let neighbours =
        textureSample(image, image_sampler, uv + vec2(-step, -step)).r +
        textureSample(image, image_sampler, uv + vec2( 0,    -step)).r +
        textureSample(image, image_sampler, uv + vec2( step, -step)).r +
        textureSample(image, image_sampler, uv + vec2(-step,  0   )).r +
        textureSample(image, image_sampler, uv + vec2( step,  0   )).r +
        textureSample(image, image_sampler, uv + vec2(-step,  step)).r +
        textureSample(image, image_sampler, uv + vec2( 0,     step)).r +
        textureSample(image, image_sampler, uv + vec2( step,  step)).r;

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