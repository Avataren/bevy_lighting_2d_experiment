use bevy::prelude::*;
pub struct Light2DPlugin;

impl Plugin for Light2DPlugin {
    fn build(&self, app: &mut App) {
        app.add_systems(Startup, setup);
    }
}

fn setup(mut commands: Commands) {}
