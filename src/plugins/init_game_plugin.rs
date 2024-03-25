use bevy::prelude::*;

pub struct InitGamePlugin;

impl Plugin for InitGamePlugin {
    fn build(&self, app: &mut App) {
        //app.insert_resource(ClearColor(Color::rgb(0.1, 0.21, 0.36)))
        app
        //.add_plugins(bevy::diagnostic::FrameTimeDiagnosticsPlugin)
        //.add_plugins(bevy::diagnostic::EntityCountDiagnosticsPlugin)
        //.add_plugins(bevy::diagnostic::SystemInformationDiagnosticsPlugin)
        //.add_plugins(PerfUiPlugin)
        .add_systems(Startup, setup);
    }
}

fn setup(_commands: Commands) {
    //commands.spawn(PerfUiCompleteBundle::default());
}
