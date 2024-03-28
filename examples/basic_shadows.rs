use bevy::{prelude::*, window::WindowResolution};
use iyes_perf_ui::{PerfUiCompleteBundle, PerfUiPlugin};
use lighting::{light2d_plugin::SDFComputePlugin, postprocess_plugin::PostProcessPlugin};
// mod plugins;
// use plugins::{
//     init_game_plugin::InitGamePlugin, light2d::light2d_plugin::SDFComputePlugin,
//     light2d::postprocess_plugin::PostProcessPlugin,
// };

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
            .add_systems(Startup, setup);
    }
}

fn setup(mut commands: Commands) {
    commands.spawn(PerfUiCompleteBundle::default());
}
