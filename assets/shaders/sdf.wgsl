struct Occluder {
    position: vec4<f32>,
    data: vec4<f32>,
};

@group(0) @binding(0) var texture: texture_storage_2d<r16float, read_write>;
@group(0) @binding(1) var<uniform> time: f32;
@group(0) @binding(2) var<uniform> num_occ: u32;
@group(0) @binding(3) var<uniform> occluders: array<Occluder, 255>;
@group(0) @binding(4) var<uniform> view_proj_matrix: mat4x4<f32>;

fn sdf_circle(p: vec2<f32>, r: f32) -> f32
{
    return length(p) - r;
}

fn sdf_round_rect(p: vec2<f32>, size: vec2<f32>, r: f32 ) -> f32
{
   return sdf_rect(p, size) - r;
}


fn sdf_rect(p: vec2<f32>, size: vec2<f32>) -> f32 {
    let d = abs(p) - size;
    let max_d: vec2<f32> = max(d, vec2<f32>(0.0, 0.0));
    return length(max_d) + min(max(d.x, d.y), 0.0);
}

fn sdf_world(p: vec2<f32>) -> f32
{
    var d = 1000.0;
    for (var i = 0u; i < num_occ; i = i + 1u)
    {
        let occ = occluders[i];
        let occ_pos = occ.position.xy;
        let occ_size = occ.data.xy;
        let occ_type = occ.data.z;
        let occ_r = occ.data.w;
        let occ_p = p - occ_pos;
        if (occ_type == 0.0)
        {
            d = min(d, sdf_rect(occ_p, occ_size));
        }
        else if (occ_type == 1.0)
        {
            d = min(d, sdf_circle(occ_p, occ_r));
        }
        else if (occ_type == 2.0)
        {
            d = min(d, sdf_round_rect(occ_p, occ_size, occ_r));
        }        
    }
    //var d = sdf_circle(p, 0.5);
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
    // Normalize the invocation_id to get UV coordinates in the range [0.0, 1.0]
    let textureSize = textureDimensions(texture);
    // Convert the textureSize to a vec2<f32> for calculations
    let textureSizeF32 = vec2<f32>(f32(textureSize.x), f32(textureSize.y));
    // Normalize the invocation_id to get UV coordinates in the range [0.0, 1.0]

    //let ndc = (vec2<f32>(f32(invocation_id.x), f32(invocation_id.y)) / textureSizeF32) * 2.0 - vec2<f32>(1.0, 1.0);
    // var uv = ndc * 0.5 + 0.5;
    // uv.y = 1.0 - uv.y; // Invert Y-axis

    let aspect = f32(textureSize.y) / f32(textureSize.x);
    var uv = (vec2<f32>(f32(invocation_id.x), f32(invocation_id.y)) / textureSizeF32 - vec2<f32>(0.5, 0.5)) * 2.0;
    uv.y = -uv.y; // Flip Y-axis to match texture coordinates

    //uv.x/=aspect;
    // var uv = (vec2<f32>(f32(invocation_id.x), f32(invocation_id.y) ) / textureSizeF32 - vec2<f32>(0.5, 0.5)) * vec2<f32>(-aspect, 1.0); ;

    //let ts = sin(time) * 0.1;
    //let tc = cos(time) * 0.3;

    // let center = vec2<f32>(0.0, 0.0);
    // var d = sdf_rect(uv - center, vec2<f32>(0.35 - ts+tc, 0.15+ts-tc*0.25));
    // d = min( d, sdf_round_rect(uv  -  vec2<f32>(0.3, 0.2) , vec2<f32>(0.05, 0.05 ), 0.01));
    // d = min( d, sdf_rect(uv +  vec2<f32>(0.3 + tc, 0.2 + ts) , vec2<f32>(0.1, 0.05 )));
    // d = min( d, sdf_circle(uv +  vec2<f32>(0.2 + tc*ts*5.0, 0.4-ts*ts*4.0) , 0.05));
   
    let d = sdf_world(uv);

    // var col: vec4<f32>;
    // col = select(vec4<f32>(0.99,0.6,0.06, 1.0), vec4<f32>(0.15,0.35,1.0, 0.9), d>0.0);

	// col *= 1.0 - exp(-6.0*abs(d));
	// col *= 0.8 + 0.2*cos(512.0*abs(d));
	// col = mix( col, vec4<f32>(1.0), 1.0-smoothstep(0.0,0.0015,abs(d)) );
    // col.a = 1.0;
    textureStore(texture, vec2<i32>(invocation_id.xy), vec4<f32>(d,0,0,0));
}
