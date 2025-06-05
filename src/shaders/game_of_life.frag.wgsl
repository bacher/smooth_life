struct Uniforms {
    aspect_ratio: f32,
    frag_step: vec2<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var image: texture_2d<f32>;
@group(0) @binding(2) var image_sampler: sampler;

@fragment fn main(
    @builtin(position) frag_coord: vec4f,
    @location(0) uv: vec2<f32>,
) -> @location(0) vec4<f32> {
    // let step_x = dpdx(uv.x);
    // let step_y = dpdy(uv.y);
    // let step_x = uniforms.frag_step.x;
    // let step_y = uniforms.frag_step.y;

    let texture_size = textureDimensions(image, 0);
    let texture_size_i32 = vec2(i32(texture_size.x), i32(texture_size.y));

    // let center_x = i32(uv.x * f32(texture_size.x));
    // let center_y = i32(uv.y * f32(texture_size.y));
    let center_x = i32(frag_coord.x);
    let center_y = i32(frag_coord.y);

    let center_cell_value = textureLoad(image, vec2(center_x, center_y), 0).r;

    var outer_sum: f32 = 0.0;
    var outer_count: u32 = 0;
    var inner_sum: f32 = 0.0;
    var inner_count: u32 = 0;

    for (var y = -12; y <= 12; y += 1) {
        for (var x = -12; x <= 12; x += 1) {
            let cell_x = modulo(center_x + x, texture_size_i32.x);
            let cell_y = modulo(center_y + y, texture_size_i32.y);

            let cell_value = textureLoad(image, vec2(cell_x, cell_y), 0).r;

            let x_float = f32(x);
            let y_float = f32(y);
            let distance_2: f32 = x_float * x_float + y_float * y_float;

            if (x == 0 && y == 0) {
                continue;
            } else if (distance_2 <= 16.0) {
                inner_sum += cell_value;
                inner_count += 1;
            } else if (distance_2 <= 144.0) {
                outer_sum += cell_value;
                outer_count += 1;
            }
        }
    }

    let inner = inner_sum / f32(inner_count);
    let outer = outer_sum / f32(outer_count);

    var change = -0.25;
    if (
        (inner < 0.5 && outer >= 0.25 && outer < 0.33) ||
        (inner >= 0.5 && outer >= 0.35 && outer < 0.51)
    ) {
        change = 0.25;
    }

    return vec4(
        center_cell_value + change,
        0.0,
        0.0,
        1.0,
    );
}

fn modulo(a: i32, b: i32) -> i32 {
    if (a < 0) {
        return a + b;
    }
    if (a > b) {
        return a - b;
    }
    return a;
}