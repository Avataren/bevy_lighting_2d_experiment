@group(0) @binding(0) var texture: texture_storage_2d<rgba8unorm, read_write>;

fn sdf_rectangle(point: vec2<f32>, size: vec2<f32>, center: vec2<f32>) -> f32 {
    let p = point - center;
    let d = abs(p) - size;
    let max_d: vec2<f32> = max(d, vec2<f32>(0.0, 0.0));
    return length(max_d) + min(max(d.x, d.y), 0.0);
}

@compute @workgroup_size(8, 8, 1)
fn init(@builtin(global_invocation_id) invocation_id: vec3<u32>, @builtin(num_workgroups) num_workgroups: vec3<u32>) {
    let location = vec2<i32>(i32(invocation_id.x), i32(invocation_id.y));

    let color = vec4<f32>(0.1, 0.2, 0.3, 1.0);

    textureStore(texture, location, color);
}

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    // Normalize the invocation_id to get UV coordinates in the range [0.0, 1.0]
    let uv = vec2<f32>(f32(invocation_id.x), f32(invocation_id.y)) / vec2<f32>(1920.0, 1080.0);
    let sdf = sdf_rectangle(uv, vec2<f32>(0.1, 0.1), vec2<f32>(0.5, 0.5));
    
    var color: vec4<f32>;
    if (sdf < 0.0) {
        color = vec4<f32>(-sdf, 0.0, 0.0, 1.0);
    } else {
        color = vec4<f32>(0.0, sdf, sdf, 1.0);
    }
    textureStore(texture, vec2<i32>(invocation_id.xy), color);
}
