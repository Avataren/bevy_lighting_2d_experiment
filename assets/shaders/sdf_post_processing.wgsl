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
    var shadow_intensity = 1.0;

    var sdf_sample = textureSample(sdf_texture, texture_sampler, p).r * 0.5;
    var is_neg = sdf_sample < 0.0;

    for (var i = 0; i < max_steps; i = i + 1) {
        let step_size = sdf_sample;//max(sdf_sample, 0.001);
        let next_p = p + light_dir * step_size;
        let next_total_distance = total_distance + length(next_p - p);

        let continue_raymarch = f32(next_total_distance < max_ray_len); // Convert boolean to f32
        if continue_raymarch > 0.0 {
            p = mix(p, next_p, continue_raymarch);
            total_distance = mix(total_distance, next_total_distance, continue_raymarch);
            sdf_sample += 0.006;
            let step_obstruction = max(0.0, 1.0 - sdf_sample * 2.0 / light_radius);
            shadow_intensity *= mix(1.0, (1.0 - step_obstruction * 0.5), continue_raymarch); // Update shadow intensity conditionally
        }
        // Sample texture only when necessary, not possible on wasm target
        if (continue_raymarch > 0.0) {
            sdf_sample = textureSample(sdf_texture, texture_sampler, p).r * 0.25;
        }
    }
    let adjusted_pixel_pos = vec2(pixel_pos.x, pixel_pos.y / aspect);
    let adjusted_light_pos = vec2(light_pos.x, light_pos.y / aspect);
    let d = length(adjusted_light_pos - adjusted_pixel_pos);
    let attenuation = 24.0 / (1.0 + 20.0 * d + 2500.0 * d * d);
    return select(max(0.0, shadow_intensity * attenuation), 0.5, is_neg);
}

@fragment
fn fragment(in: FullscreenVertexOutput) -> @location(0) vec4<f32> {
    var lights: array<Light, 4> = array<Light,4>(
        Light(vec2<f32>(0.25, 0.25), vec3<f32>(1.0, 0.25, 0.25), 1.0, 0.15),
        Light(vec2<f32>(0.75, 0.65), vec3<f32>(0.2, 0.37, 0.8), 1.0, 0.15),
        Light(vec2<f32>(0.4, 0.75), vec3<f32>(0.4, 0.7, 0.25), 1.0, 0.15),
        Light(vec2<f32>(0.8, 0.2), vec3<f32>(0.8, 0.8, 0.8), 1.0, 0.15)
    );

    let ambient = 0.02;
    let textureSize = textureDimensions(screen_texture);
    let aspect = f32(textureSize.x) / f32(textureSize.y);
    var color = vec3<f32>(0.0, 0.0, 0.0);

    for (var i = 0; i < 4; i = i + 1) {
        let light_contribution = raymarch_light(lights[i].position, in.uv, 32, 0.025, aspect);
        color += lights[i].color * light_contribution;
    }

    let unlit = textureSample(screen_texture, texture_sampler, in.uv);
    return vec4<f32>(
        unlit.r * (color.r + ambient),
        unlit.g * (color.g + ambient),
        unlit.b * (color.b + ambient),
        1.0
    );
}
