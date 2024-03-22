use bevy::prelude::*;
pub struct InitGamePlugin;

impl Plugin for InitGamePlugin {
    fn build(&self, app: &mut App) {
        //app.insert_resource(ClearColor(Color::rgb(0.1, 0.21, 0.36)))
        app.add_systems(Startup, setup);
    }
}

fn setup(mut commands: Commands) {}
