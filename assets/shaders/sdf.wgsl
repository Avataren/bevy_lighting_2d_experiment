#define_import_path bevy_light2d::raymarch
#import bevy_light2d::sdf_utils::{world_to_sdf_uv, screen_to_ndc, sdf_circle}

struct Occluder {
    position: vec4<f32>,
    data: vec4<f32>,
};

@group(0) @binding(0) var texture: texture_storage_2d<r32float, write>;
@group(0) @binding(1) var<uniform> time: f32;
@group(0) @binding(2) var<uniform> num_occ: u32;
@group(0) @binding(3) var<uniform> occluders: array<Occluder, 256>;
@group(0) @binding(4) var<uniform> proj_matrix: mat4x4<f32>;



fn sdf_round_rect(p: vec2<f32>, size: vec2<f32>, r: f32 ) -> f32
{
   return sdf_rect(p, size) - r;
}

fn sdf_rect(p: vec2<f32>, size: vec2<f32>) -> f32 {
    let d = abs(p) - size;
    let max_d: vec2<f32> = max(d, vec2<f32>(0.0, 0.0));
    return length(max_d) + min(max(d.x, d.y), 0.0);
}

fn sdf_world(p: vec2<f32>, aspect: f32) -> f32 {
    var d = 1000.0;
    for (var i = 0u; i < num_occ; i = i + 1u) {
        let occ = occluders[i];
        let occ_pos = occ.position.xy; // Directly use pre-transformed position
        let occ_size = occ.data.xy; // Directly use pre-transformed size
        let occ_type = occ.data.z; // Type of the occluder (e.g., rectangle, circle)
        let occ_r = occ.data.w; // Additional data, like radius for circles

        let occ_p = p - occ_pos; // Position relative to the occluder

        // Perform SDF calculations based on occluder type
        if (occ_type == 0.0) {
            d = min(d, sdf_rect(occ_p, occ_size));
        } else if (occ_type == 1.0) {
            d = min(d, sdf_circle(occ_p, occ_r, aspect));
        } else if (occ_type == 2.0) {
            d = min(d, sdf_round_rect(occ_p, occ_size, occ_r));
        }        
    }
    return d;
}

@compute @workgroup_size(8, 8, 1)
fn init(@builtin(global_invocation_id) invocation_id: vec3<u32>, @builtin(num_workgroups) num_workgroups: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));

    let color = vec4<f32>(0.0, 0.0, 0.0, 1.0);

    textureStore(texture, location, color);
}

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let textureSize = textureDimensions(texture);
    let textureSizeF32 = vec2<f32>(f32(textureSize.x), f32(textureSize.y));
    let texture_posF32 = vec2<f32>(f32(invocation_id.x), f32(invocation_id.y));
    let aspect = f32(textureSize.x) / f32(textureSize.y);
    let ndc_pos = screen_to_ndc(texture_posF32,textureSizeF32);
    let aspect_corrected_ndc = vec2<f32>(ndc_pos.x, ndc_pos.y * aspect);

    let d = sdf_world(ndc_pos, aspect);

    textureStore(texture, vec2<i32>(invocation_id.xy), vec4<f32>(d,0,0,0));
}
