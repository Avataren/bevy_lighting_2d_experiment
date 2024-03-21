@group(0) @binding(0) var texture: texture_storage_2d<rgba8unorm, read_write>;

fn sdf_round_rect(p: vec2<f32>, size: vec2<f32>, r: f32 ) -> f32
{
   return sdf_rect(p, size) - r;
}


fn sdf_rect(p: vec2<f32>, size: vec2<f32>) -> f32 {
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
    let textureSize = textureDimensions(texture);
    // Convert the textureSize to a vec2<f32> for calculations
    let textureSizeF32 = vec2<f32>(f32(textureSize.x), f32(textureSize.y));
    // Normalize the invocation_id to get UV coordinates in the range [0.0, 1.0]
    let uv = vec2<f32>(f32(invocation_id.x), f32(invocation_id.y)) / textureSizeF32;
    
    let center = vec2<f32>(0.5, 0.5);
    var d = sdf_rect(uv - center, vec2<f32>(0.1, 0.1 * 16.0/9.0));
    d = min( d, sdf_round_rect(uv - center -  vec2<f32>(0.3, 0.2) , vec2<f32>(0.05, 0.05 * 16.0/9.0), 0.01));
    d = min( d, sdf_rect(uv - center +  vec2<f32>(0.3, 0.2) , vec2<f32>(0.1, 0.05 * 16.0/9.0)));
    
    var col: vec4<f32>;
    col = select(vec4<f32>(0.95,0.6,0.1, 1.0), vec4<f32>(0.45,0.55,1.0, 1.0), d>0.0);

	col *= 1.0 - exp(-8.0*abs(d));
	col *= 0.8 + 0.2*cos(1024.0*abs(d));
	col = mix( col, vec4<f32>(1.0), 1.0-smoothstep(0.0,0.0015,abs(d)) );

    textureStore(texture, vec2<i32>(invocation_id.xy), col);
}
