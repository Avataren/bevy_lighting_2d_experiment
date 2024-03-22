use bevy::{prelude::*, window::WindowResolution};
mod plugins;
use plugins::{
    init_game_plugin::InitGamePlugin, light2d::light2d_plugin::SDFComputePlugin,
    light2d::postprocess_plugin::PostProcessPlugin,
};

fn main() {
    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                canvas: Some("#game-canvas".to_string()),
                title: "Light2D".to_string(),
                resizable: false,
                //mode: WindowMode::BorderlessFullscreen,
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
