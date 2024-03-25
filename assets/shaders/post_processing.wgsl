#import bevy_core_pipeline::fullscreen_vertex_shader::FullscreenVertexOutput

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

fn raymarch_light(light_pos: vec2<f32>, pixel_pos: vec2<f32>, max_steps: i32, max_distance: f32, light_radius: f32) -> f32 {
    let light_dir = normalize(light_pos - pixel_pos);
    let max_ray_len = length(light_pos - pixel_pos);
    var p = pixel_pos;
    var total_distance = 0.0;
    var max_obstruction = 0.0;

    for (var i = 0; i < max_steps; i = i + 1) {
        // Pre-sample texture
        let sdf_sample = textureSample(sdf_texture, texture_sampler, p).r * 0.5;

        // Calculate next position and distance without updating them immediately
        let next_p = p + light_dir * max(sdf_sample, 0.001);
        let next_total_distance = total_distance + length(next_p - p);

        // Use a uniform condition to decide whether to update
        let should_update = (next_total_distance <= max_distance) && (length(next_p - light_pos) >= light_radius);
        if (total_distance > max_ray_len) {
            break; // Stop if the ray exceeds the max distance
        }
        // Conditionally update ray marching variables based on the uniform condition
        if (should_update) {
            p = next_p;
            total_distance = next_total_distance;

            if (sdf_sample < 0.0025) {
                let obstruction = 1.0 - sdf_sample * 16.0 / light_radius;
                //let obstruction = clamp(1.0 - sdf_sample * 48.0 / light_radius, 0.0, 1.0); 
                max_obstruction = max(max_obstruction, obstruction);
            }
        }
    }

    let d = length(light_pos - pixel_pos);
    let attenuation = 8.0 / (1.0 + 20.0 * d + 2500.0 * d * d);
    return max(0.0, (1.0 - max_obstruction) * attenuation);
}




// fn raymarch_light(light_pos: vec2<f32>, pixel_pos: vec2<f32>, max_steps: i32, max_distance: f32, light_radius: f32) -> f32 {
//     let light_dir = normalize(light_pos - pixel_pos);
//     var p = pixel_pos;
//     var total_distance = 0.0;
//     var max_obstruction = 0.0; // Tracks the maximum obstruction value
//     let constant_attenuation = 8.0; // You can adjust this constant
//     let linear_attenuation = 20.0; // Adjust linear attenuation factor
//     let quadratic_attenuation = 2500.0; // Adjust quadratic attenuation factor
    
//     for (var i = 0; i < max_steps; i = i + 1) {
//         let sdf = textureSample(sdf_texture, texture_sampler, p).r * 0.05; // Sample the SDF at the current point
//         // Check for an occluder
//         if (sdf < 0.01) { // Adjust the threshold based on your SDF
//             let obstruction = 1.0 - sdf*48.0 / light_radius; // Calculate the obstruction based on SDF and light radius
//             max_obstruction = max(max_obstruction, obstruction); // Keep the maximum obstruction value
//         }

//         // Advance the ray
//         p += light_dir * max(sdf, 0.0005); // Use a small minimum step to avoid getting stuck in zero SDF regions
//         total_distance += length(p - pixel_pos);

//         if (total_distance > max_distance) {
//             break; // Stop if the ray exceeds the max distance
//         }
//         // Break if we've reached close to the light source
//         if (length(p - light_pos) < light_radius) {
//             break;
//         }
//     }

//     // Calculate the attenuation based on the distance to the light source
//     let d = length(light_pos - pixel_pos);
//     let attenuation = constant_attenuation / (1.0 + linear_attenuation * d + quadratic_attenuation * d * d);

//     // Apply attenuation to the light intensity reduced by the maximum obstruction
//     return max(0.0, (1.0 - max_obstruction) * attenuation);
// }

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
    let spos = in.uv - vec2<f32>(0.5, 0.5) * 2.0;
    let sdf_value = textureSample(sdf_texture, texture_sampler, in.uv).r;
    let ambient = 0.01;

    var color = vec3<f32>(0.0, 0.0, 0.0);

    //if (sdf_value < 0.0) { // Check if the fragment is inside an object based on SDF
    let base_col = select (0.0, 0.5, sdf_value < 0.0);//     // The fragment is inside an object, consider it fully lit
    color = vec3<f32>(base_col,base_col,base_col); // Add full light color for each light
    // } else {
        // The fragment is outside, compute lighting normally
    let multiplier = select (0.0,1.0, sdf_value > 0.0);
    for (var i = 0; i < 4; i = i + 1) {
        let light_contribution = raymarch_light(lights[i].position, in.uv, 16, 32.0, 0.025);
        color += lights[i].color * light_contribution * multiplier;
    }
    // }
    return vec4<f32>(
        unlit.r * (color.r + ambient),
        unlit.g * (color.g + ambient),
        unlit.b * (color.b + ambient),
        1.0
    );
}
