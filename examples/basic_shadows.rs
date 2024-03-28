use bevy::{prelude::*, sprite::{MaterialMesh2dBundle, Mesh2dHandle}, window::WindowResolution};
use iyes_perf_ui::{PerfUiCompleteBundle, PerfUiPlugin};
use lighting::{light2d_plugin::{Occluder, SDFComputePlugin, SDFVisualizer}, postprocess_plugin::PostProcessPlugin};
// mod plugins;
// use plugins::{
//     init_game_plugin::InitGamePlugin, light2d::light2d_plugin::SDFComputePlugin,
//     light2d::postprocess_plugin::PostProcessPlugin,
// };

const TEST_OCCLUDERS: usize = 24;

fn main() {
    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                canvas: Some("#game-canvas".to_string()),
                title: "Light2D".to_string(),
                resizable: true,
                resolution: WindowResolution::new(1920., 1080.),
                prevent_default_event_handling: false,
                present_mode: bevy::window::PresentMode::AutoNoVsync,
                ..default()
            }),
            ..default()
        }))
        .insert_resource(Msaa::Off)
        .add_plugins((InitGamePlugin, SDFComputePlugin, PostProcessPlugin))
        .run();
}

pub struct InitGamePlugin;

impl Plugin for InitGamePlugin {
    fn build(&self, app: &mut App) {
        //app.insert_resource(ClearColor(Color::rgb(0.1, 0.21, 0.36)))
        app
            //.add_plugins(bevy::diagnostic::SystemInformationDiagnosticsPlugin)
            .add_plugins(bevy::diagnostic::FrameTimeDiagnosticsPlugin)
            .add_plugins(bevy::diagnostic::EntityCountDiagnosticsPlugin)
            .add_plugins(PerfUiPlugin)
            .add_systems(Startup, setup)
            .add_systems(Update, animate_sprites);
    }
}

fn setup(
    mut commands: Commands,
    asset_server: ResMut<AssetServer>,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
) {
    commands.spawn(PerfUiCompleteBundle::default());

    commands
        .spawn(SpriteBundle {
            sprite: Sprite {
                custom_size: Some(Vec2::new(1920 as f32, 1080 as f32)),
                ..default()
            },
            //texture: image.clone(),
            texture: asset_server.load("floor.png"),
            ..default()
        })
        .insert(SDFVisualizer);

    let shapes = [
        Mesh2dHandle(meshes.add(Rectangle::new(50.0, 50.0))),
        Mesh2dHandle(meshes.add(Circle { radius: 25.0 })),
    ];

    for i in 0..TEST_OCCLUDERS {
        let color = Color::hsl(360. * i as f32 / TEST_OCCLUDERS as f32, 0.95, 0.7);
        commands
            .spawn(MaterialMesh2dBundle {
                mesh: shapes[i % 2].clone(),
                material: materials.add(color),
                transform: Transform::from_xyz(
                    (i as f32) * 50.0,
                    0.0,
                    (i as f32) / TEST_OCCLUDERS as f32 + 0.1,
                ),
                ..default()
            })
            .insert(Occluder {
                position: Vec4::new(0.0, 0.0, 0.0, 0.0),
                data: Vec4::new(50.0, 50.0, (i % 2) as f32, 25.0 * 1.5),
            });
    }
}

fn animate_sprites(
    time: Res<Time>,
    //mut query: Query<&mut Transform, (With<Sprite>, Without<SDFVisualizer>)>,
    mut query: Query<&mut Transform, With<Occluder>>,
) {
    let mut i = 0.0;
    for mut transform in &mut query.iter_mut() {
        //transform.rotate(Quat::from_rotation_z(time.delta_seconds()));
        let mut x = ((time.elapsed_seconds() + i) * 0.5).sin() * 400.0;
        let mut y = ((time.elapsed_seconds() + i) * 0.5).cos() * 300.0;

        x += ((time.elapsed_seconds() * 1.5 + i * 0.5) * 0.5).cos() * 3.0;
        y += ((time.elapsed_seconds() * 1.75 + i * 0.25) * 0.5).sin() * 200.0;

        x += ((time.elapsed_seconds() * 2.5 + i * 1.5) * 0.5).cos() * 200.0;
        y += ((time.elapsed_seconds() * 2.75 + i * 1.25) * 0.5).sin() * 100.0;

        i += 1.0;
        transform.translation = Vec3::new(x, y, i * 0.1 + 0.1);
    }
}
