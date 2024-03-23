use bevy::{
    prelude::*,
    render::{
        //extract_component::ComponentUniforms,
        extract_resource::{ExtractResource, ExtractResourcePlugin},
        render_asset::{RenderAssetUsages, RenderAssets},
        render_graph::{self, RenderGraph, RenderLabel},
        render_resource::*,
        renderer::{RenderContext, RenderDevice},
        Render,
        RenderApp,
        RenderSet,
    },
};
use std::borrow::Cow;

const SIZE: (u32, u32) = (1920, 1080);
const WORKGROUP_SIZE: u32 = 8;

fn setup(mut commands: Commands, mut images: ResMut<Assets<Image>>) {
    let mut image = Image::new_fill(
        Extent3d {
            width: SIZE.0,
            height: SIZE.1,
            depth_or_array_layers: 1,
        },
        TextureDimension::D2,
        &[0, 0, 0, 255],
        TextureFormat::Rgba8Unorm,
        RenderAssetUsages::RENDER_WORLD,
    );
    image.texture_descriptor.usage =
        TextureUsages::COPY_DST | TextureUsages::STORAGE_BINDING | TextureUsages::TEXTURE_BINDING;
    let image = images.add(image);

    //commands.spawn(CameraData::default());

    commands.spawn(SpriteBundle {
        sprite: Sprite {
            custom_size: Some(Vec2::new(SIZE.0 as f32, SIZE.1 as f32)),
            ..default()
        },
        texture: image.clone(),
        ..default()
    });

    //commands.spawn(Camera2dBundle::default());

    commands.insert_resource(SDFImage {
        texture: image,
        view_matrix: Mat4::IDENTITY,
        proj_matrix: Mat4::IDENTITY,
        time: 0.0,
    });
}

fn update_time(time: Res<Time>, mut sdf_image: ResMut<SDFImage>) {
    sdf_image.time = time.elapsed_seconds();
}

pub struct SDFComputePlugin;

#[derive(Debug, Hash, PartialEq, Eq, Clone, RenderLabel)]
struct SDFNodeLabel;

impl Plugin for SDFComputePlugin {
    fn build(&self, app: &mut App) {
        // Extract the resources from the main world into the render world
        // for operation on by the compute shader and display on the sprite.
        app.add_plugins(ExtractResourcePlugin::<SDFImage>::default())
            // .add_plugins((
            //     ExtractComponentPlugin::<CameraData>::default(),
            //     UniformComponentPlugin::<CameraData>::default()
            // ))
            .add_systems(Startup, setup)
            .add_systems(Update, (update_camera_data, update_time));
        let render_app = app.sub_app_mut(RenderApp);
        render_app.add_systems(
            Render,
            prepare_bind_group.in_set(RenderSet::PrepareBindGroups),
        );

        let mut render_graph = render_app.world.resource_mut::<RenderGraph>();
        render_graph.add_node(SDFNodeLabel, SDFNode::default());
        render_graph.add_node_edge(SDFNodeLabel, bevy::render::graph::CameraDriverLabel);
    }

    fn finish(&self, app: &mut App) {
        let render_app = app.sub_app_mut(RenderApp);
        render_app.init_resource::<SDFPipeline>();
    }
}

fn update_camera_data(cam_q: Query<(&Camera, &Transform)>, mut cam_data: ResMut<SDFImage>) {
    for (cam, transform) in cam_q.iter() {
        //let mut cam_data = cam_data;
        cam_data.view_matrix = transform.compute_matrix().inverse();
        cam_data.proj_matrix = cam.projection_matrix();
    }
}

//#[derive(Component, Clone, Copy, ExtractComponent, ShaderType)]
// struct CameraData {
//     view_matrix: Mat4,
//     proj_matrix: Mat4,
// }

#[derive(Resource, Clone, Deref, ExtractResource, AsBindGroup)]
struct SDFImage {
    #[deref]
    #[storage_texture(0, image_format = Rgba8Unorm, access = ReadWrite)]
    texture: Handle<Image>,
    #[uniform(1)]
    view_matrix: Mat4,
    #[uniform(2)]
    proj_matrix: Mat4,
    #[uniform(3)]
    time: f32,
    #[cfg(feature = "webgl2")]
    _webgl2_padding: Vec3,
}

// impl Default for CameraData {
//     fn default() -> Self {
//         Self {
//             view_matrix: Mat4::IDENTITY,
//             proj_matrix: Mat4::IDENTITY,
//         }
//     }
// }

#[derive(Resource)]
struct SDFImageBindGroup(BindGroup);

fn prepare_bind_group(
    mut commands: Commands,
    pipeline: Res<SDFPipeline>,
    gpu_images: Res<RenderAssets<Image>>,
    sdf_image: Res<SDFImage>,
    render_device: Res<RenderDevice>,
    _world: &World,
) {
    let view = gpu_images.get(&sdf_image.texture).unwrap();

    // Convert Mat4 matrices and f32 time into byte slices
    let view_matrix_bytes = bytemuck::bytes_of(&sdf_image.view_matrix);
    let proj_matrix_bytes = bytemuck::bytes_of(&sdf_image.proj_matrix);
    let time_bytes = bytemuck::bytes_of(&sdf_image.time);

    // Create buffers for view matrix, proj matrix, and time
    let view_matrix_buffer = render_device.create_buffer_with_data(&BufferInitDescriptor {
        label: Some("view matrix buffer"),
        contents: view_matrix_bytes,
        usage: BufferUsages::UNIFORM | BufferUsages::COPY_DST,
    });

    let proj_matrix_buffer = render_device.create_buffer_with_data(&BufferInitDescriptor {
        label: Some("proj matrix buffer"),
        contents: proj_matrix_bytes,
        usage: BufferUsages::UNIFORM | BufferUsages::COPY_DST,
    });

    let time_buffer = render_device.create_buffer_with_data(&BufferInitDescriptor {
        label: Some("time buffer"),
        contents: time_bytes,
        usage: BufferUsages::UNIFORM | BufferUsages::COPY_DST,
    });
    let bind_group = render_device.create_bind_group(
        None, // Label for debugging
        &pipeline.texture_bind_group_layout, // The layout this bind group is based on
        &[ // Array of entries
            BindGroupEntry {
                binding: 0,
                resource: BindingResource::TextureView(&view.texture_view), // Texture view as a resource
            },
            BindGroupEntry {
                binding: 1,
                resource: BindingResource::Buffer(BufferBinding { // Buffer binding for the view matrix
                    buffer: &view_matrix_buffer,
                    offset: 0,
                    size: None, // Use the full size of the buffer
                }),
            },
            BindGroupEntry {
                binding: 2,
                resource: BindingResource::Buffer(BufferBinding { // Buffer binding for the projection matrix
                    buffer: &proj_matrix_buffer,
                    offset: 0,
                    size: None,
                }),
            },
            BindGroupEntry {
                binding: 3,
                resource: BindingResource::Buffer(BufferBinding { // Buffer binding for the time value
                    buffer: &time_buffer,
                    offset: 0,
                    size: None,
                }),
            },
        ],
    );
    
    commands.insert_resource(SDFImageBindGroup(bind_group));
}

#[derive(Resource)]
struct SDFPipeline {
    texture_bind_group_layout: BindGroupLayout,
    init_pipeline: CachedComputePipelineId,
    update_pipeline: CachedComputePipelineId,
}

impl FromWorld for SDFPipeline {
    fn from_world(world: &mut World) -> Self {
        let render_device = world.resource::<RenderDevice>();
        let texture_bind_group_layout = SDFImage::bind_group_layout(render_device);
        //let cam_data_layout = CameraData::bind_group_layout(render_device);
        let shader = world.resource::<AssetServer>().load("shaders/sdf.wgsl");
        let pipeline_cache = world.resource::<PipelineCache>();
        let init_pipeline = pipeline_cache.queue_compute_pipeline(ComputePipelineDescriptor {
            label: None,
            layout: vec![texture_bind_group_layout.clone()],
            push_constant_ranges: Vec::new(),
            shader: shader.clone(),
            shader_defs: vec![],
            entry_point: Cow::from("init"),
        });
        let update_pipeline = pipeline_cache.queue_compute_pipeline(ComputePipelineDescriptor {
            label: None,
            layout: vec![texture_bind_group_layout.clone()],
            push_constant_ranges: Vec::new(),
            shader,
            shader_defs: vec![],
            entry_point: Cow::from("main"),
        });

        SDFPipeline {
            texture_bind_group_layout,
            init_pipeline,
            update_pipeline,
        }
    }
}

enum SDFState {
    Loading,
    Init,
    Update,
}

struct SDFNode {
    state: SDFState,
}

impl Default for SDFNode {
    fn default() -> Self {
        Self {
            state: SDFState::Loading,
        }
    }
}

impl render_graph::Node for SDFNode {
    fn update(&mut self, world: &mut World) {
        let pipeline = world.resource::<SDFPipeline>();
        let pipeline_cache = world.resource::<PipelineCache>();

        // if the corresponding pipeline has loaded, transition to the next stage
        match self.state {
            SDFState::Loading => {
                if let CachedPipelineState::Ok(_) =
                    pipeline_cache.get_compute_pipeline_state(pipeline.init_pipeline)
                {
                    self.state = SDFState::Init;
                }
            }
            SDFState::Init => {
                if let CachedPipelineState::Ok(_) =
                    pipeline_cache.get_compute_pipeline_state(pipeline.update_pipeline)
                {
                    self.state = SDFState::Update;
                }
            }
            SDFState::Update => {}
        }
    }

    fn run(
        &self,
        _graph: &mut render_graph::RenderGraphContext,
        render_context: &mut RenderContext,
        world: &World,
    ) -> Result<(), render_graph::NodeRunError> {
        let texture_bind_group = &world.resource::<SDFImageBindGroup>().0;
        let pipeline_cache = world.resource::<PipelineCache>();
        let pipeline = world.resource::<SDFPipeline>();

        let mut pass = render_context
            .command_encoder()
            .begin_compute_pass(&ComputePassDescriptor::default());

        pass.set_bind_group(0, texture_bind_group, &[]);

        // select the pipeline based on the current state
        match self.state {
            SDFState::Loading => {}
            SDFState::Init => {
                let init_pipeline = pipeline_cache
                    .get_compute_pipeline(pipeline.init_pipeline)
                    .unwrap();
                pass.set_pipeline(init_pipeline);
                pass.dispatch_workgroups(SIZE.0 / WORKGROUP_SIZE, SIZE.1 / WORKGROUP_SIZE, 1);
            }
            SDFState::Update => {
                let update_pipeline = pipeline_cache
                    .get_compute_pipeline(pipeline.update_pipeline)
                    .unwrap();
                pass.set_pipeline(update_pipeline);
                pass.dispatch_workgroups(SIZE.0 / WORKGROUP_SIZE, SIZE.1 / WORKGROUP_SIZE, 1);
            }
        }

        Ok(())
    }
}
