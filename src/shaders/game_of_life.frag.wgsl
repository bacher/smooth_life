struct Uniforms {
    aspect_ratio: f32,
    frag_step: vec2<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var image: texture_2d<f32>;
@group(0) @binding(2) var image_sampler: sampler;

@fragment fn main(
    @location(0) uv: vec2<f32>,
) -> @location(0) vec4<f32> {
    // let step_x = dpdx(uv.x);
    // let step_y = dpdy(uv.y);
    // let step_x = uniforms.frag_step.x;
    // let step_y = uniforms.frag_step.y;

    let texture_size = textureDimensions(image, 0);

    let x = u32(uv.x * f32(texture_size.x));
    let y = u32(uv.y * f32(texture_size.y));

    // let cell = textureSample(image, image_sampler, uv).r;
    let cell = textureLoad(image, vec2(x, y), 0).r;

    let neighbours =
        // textureSample(image, image_sampler, uv + vec2(-step_x, -step_y)).r +
        textureLoad(image, vec2(x - 1, y - 1), 0).r +
        textureLoad(image, vec2(x,     y - 1), 0).r +
        textureLoad(image, vec2(x + 1, y - 1), 0).r +
        textureLoad(image, vec2(x - 1, y    ), 0).r +
        textureLoad(image, vec2(x + 1, y    ), 0).r +
        textureLoad(image, vec2(x - 1, y + 1), 0).r +
        textureLoad(image, vec2(x,     y + 1), 0).r +
        textureLoad(image, vec2(x + 1, y + 1), 0).r;

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