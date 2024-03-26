#import bevy_core_pipeline::fullscreen_vertex_shader::FullscreenVertexOutput
#import bevy_light2d::sdf_utils::{sdf_circle}

@group(0) @binding(0) var screen_texture: texture_2d<f32>;
@group(0) @binding(1) var texture_sampler: sampler;
struct PostProcessSettings {
    intensity: f32,
#ifdef SIXTEEN_BYTE_ALIGNMENT
    // WebGL2 structs must be 16 byte aligned.
    _webgl2_padding: vec3<f32>
#endif
}
@group(0) @binding(2) var<uniform> settings: PostProcessSettings;
@group(0) @binding(3) var sdf_texture: texture_2d<f32>;

struct Light {
    position: vec2<f32>,
    color: vec3<f32>,
    intensity: f32,
    radius: f32,
};


fn raymarch_light(light_pos: vec2<f32>, pixel_pos: vec2<f32>, max_steps: i32, light_radius: f32, aspect: f32) -> f32 {
    let light_dir = normalize(light_pos - pixel_pos);
    let max_ray_len = length(light_pos - pixel_pos);
    var p = pixel_pos;
    var total_distance = 0.0;
    var max_obstruction = 0.0;

    var is_neg = textureSample(sdf_texture, texture_sampler, p).r < 0.0;

    for (var i = 0; i < max_steps; i = i + 1) {
        let sdf_sample = textureSample(sdf_texture, texture_sampler, p).r * 0.25;

        let next_p = p + light_dir * max(sdf_sample, 0.001);
        let next_total_distance = total_distance + length(next_p - p);

        let should_update =  (next_total_distance < max_ray_len);
        if should_update {
            p = next_p;
            total_distance = next_total_distance;

            let obstruction = (1.0 - (sdf_sample+0.002) * 6.0 / light_radius);
            max_obstruction = max(max_obstruction, obstruction);
        }
    }

    let adjusted_pixel_pos = vec2(pixel_pos.x, pixel_pos.y / aspect);
    let adjusted_light_pos = vec2(light_pos.x, light_pos.y / aspect);

    let d = length(adjusted_light_pos - adjusted_pixel_pos);
    let attenuation = 32.0 / (1.0 + 20.0 * d + 2500.0 * d * d);

    return select(max(0.0, (1.0 - max_obstruction) * attenuation), 0.5, is_neg);
}


@fragment
fn fragment(in: FullscreenVertexOutput) -> @location(0) vec4<f32> {

    var lights: array<Light, 4> = array<Light,4>(
        Light(vec2<f32>(0.25, 0.25), vec3<f32>(1.0, 0.25, 0.25), 1.0, 0.05),
        Light(vec2<f32>(0.75, 0.65), vec3<f32>(0.2, 0.37, 0.8), 1.0, 0.05),
        Light(vec2<f32>(0.4, 0.75), vec3<f32>(0.4, 0.7, 0.25), 1.0, 0.05),
        Light(vec2<f32>(0.8, 0.2), vec3<f32>(0.8, 0.8, 0.8), 1.0, 0.05)
    );

    let offset_strength = settings.intensity;
    let unlit = textureSample(screen_texture, texture_sampler, in.uv);
    // let spos = in.uv - vec2<f32>(0.5, 0.5) * 2.0;
    //let sdf_value = textureSample(sdf_texture, texture_sampler, in.uv).r;
    let ambient = 0.02;
    let aspect = f32(1920.0) / f32(1080.0);
    var color = vec3<f32>(0.0, 0.0, 0.0);

    //let base_col = select(0.0, 0.5, sdf_value < 0.0);//     // The fragment is inside an object, consider it fully lit
    //color = vec3<f32>(base_col, base_col, base_col); // Add full light color for each light
    //let multiplier = select(0.0, 1.0, sdf_value > 0.0);
    for (var i = 0; i < 4; i = i + 1) {
        let light_contribution = raymarch_light(lights[i].position, in.uv, 32, 0.025, aspect);
        color += lights[i].color * light_contribution;// * multiplier;
    }
    return vec4<f32>(
        unlit.r * (color.r + ambient),
        unlit.g * (color.g + ambient),
        unlit.b * (color.b + ambient),
        1.0
    );

    // var col = select(vec4<f32>(0.99, 0.6, 0.06, 1.0), vec4<f32>(0.15, 0.35, 1.0, 0.9), sdf_value > 0.0);

    // col *= 1.0 - exp(-8.0 * abs(sdf_value));
    // col *= 0.8 + 0.2 * cos(256.0 * abs(sdf_value));
    // col = mix(col, vec4<f32>(1.0), 1.0 - smoothstep(0.0, 0.0015, abs(sdf_value)));
    // col.a = 1.0;

    // return col;
}
