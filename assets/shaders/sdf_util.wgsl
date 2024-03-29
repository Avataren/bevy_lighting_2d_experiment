#define_import_path bevy_light2d::sdf_utils

fn world_to_sdf_uv(world_pos: vec2<f32>, view_proj: mat4x4<f32>, inv_sdf_scale: vec2<f32>) -> vec2<f32> {
    let ndc = (view_proj * vec4<f32>(world_pos, 0.0, 1.0)).xy;
    let ndc_sdf = ndc * inv_sdf_scale;
    let uv = (ndc_sdf + 1.0) * 0.5;
    let y = 1.0 - uv.y;
    return vec2<f32>(uv.x, y);
}

fn screen_to_ndc(
    screen_pos:     vec2<f32>,
    screen_size:     vec2<f32> ) -> vec2<f32> {
    let screen_pose_f32 = vec2<f32>(0.0, screen_size.y)
                        + vec2<f32>(screen_pos.x, -screen_pos.y);
    return (screen_pose_f32 / screen_size) * 2.0 - 1.0;
}

fn visualize_sdf(sdf_value:f32) -> vec4<f32>
{
    var col = select(vec4<f32>(0.99, 0.6, 0.06, 1.0), vec4<f32>(0.15, 0.35, 1.0, 0.9), sdf_value > 0.0);

    col *= 1.0 - exp(-8.0 * abs(sdf_value));
    col *= 0.8 + 0.2 * cos(256.0 * abs(sdf_value));
    col = mix(col, vec4<f32>(1.0), 1.0 - smoothstep(0.0, 0.0015, abs(sdf_value)));
    col.a = 1.0;

    return col;    
}

fn sdf_circle(p: vec2<f32>, r: f32, aspect: f32) -> f32
{
    let adjusted_p = vec2(p.x, p.y / aspect);
    return length(adjusted_p) - r;    
}
