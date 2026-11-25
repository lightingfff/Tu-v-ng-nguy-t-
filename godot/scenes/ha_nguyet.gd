extends Node2D

const PAINTING = preload("res://assets/ha-nguyet.webp")
const DISTANCE_MAP = preload("res://assets/ha-nguyet-depth.webp")
const WATER_MAP = preload("res://assets/ha-nguyet-water.webp")
const VILLAGE_SHADER = preload("res://shaders/village.gdshader")

const SCENE_SIZE = Vector2(1536, 1024)
const CAMERA_CENTERS = [Vector2(768, 512), Vector2(734, 578), Vector2(1104, 470)]
const CAMERA_ZOOMS = [0.79, 1.00, 1.30]
const FOCUS_DISTANCES = [0.43, 0.49, 0.59]

@onready var painting: Sprite2D = $Painting
@onready var camera: Camera2D = $Camera
@onready var wind = $Wind
@onready var interface: CanvasLayer = $Interface

var atmosphere := ShaderMaterial.new()
var view_index := 0
var elapsed := 0.0
var focus_distance := FOCUS_DISTANCES[0]
var stopped := false
var depth_enabled := true
var light_enabled := true

func _ready() -> void:
	painting.texture = PAINTING
	atmosphere.shader = VILLAGE_SHADER
	atmosphere.set_shader_parameter("painting", PAINTING)
	# A separate low-pass plate keeps depth blur consistent on Compatibility renderers.
	var low_pass := PAINTING.get_image()
	low_pass.resize(256, 171, Image.INTERPOLATE_LANCZOS)
	atmosphere.set_shader_parameter("defocused_painting", ImageTexture.create_from_image(low_pass))
	atmosphere.set_shader_parameter("distance_map", DISTANCE_MAP)
	atmosphere.set_shader_parameter("water_map", WATER_MAP)
	painting.material = atmosphere

func _process(delta: float) -> void:
	if not stopped:
		elapsed += delta
		wind.elapsed = elapsed
		wind.queue_redraw()

	var blend := 1.0 - exp(-3.1 * delta)
	var next_zoom := lerpf(camera.zoom.x, CAMERA_ZOOMS[view_index], blend)
	var drift := Vector2(sin(elapsed * 0.31), cos(elapsed * 0.25)) * 2.6
	var target: Vector2 = CAMERA_CENTERS[view_index] + drift
	var next_center := camera.position.lerp(target, blend)
	if next_center.distance_squared_to(target) < 0.0016:
		next_center = target
	# Constrain the camera to the painting at every intermediate zoom.
	var half_visible := get_viewport_rect().size / (2.0 * next_zoom)
	camera.position = next_center.clamp(half_visible, SCENE_SIZE - half_visible)
	camera.zoom = Vector2.ONE * next_zoom

	focus_distance = lerpf(focus_distance, FOCUS_DISTANCES[view_index], blend)
	atmosphere.set_shader_parameter("camera_offset", (camera.position - SCENE_SIZE / 2.0) / SCENE_SIZE)
	atmosphere.set_shader_parameter("focus", focus_distance)
	atmosphere.set_shader_parameter("elapsed", elapsed)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1:
			view_index = 0
		KEY_2:
			view_index = 1
		KEY_3:
			view_index = 2
		KEY_SPACE:
			stopped = not stopped
		KEY_H:
			interface.visible = not interface.visible
		KEY_D:
			depth_enabled = not depth_enabled
			atmosphere.set_shader_parameter("depth_enabled", float(depth_enabled))
		KEY_L:
			light_enabled = not light_enabled
			atmosphere.set_shader_parameter("atmosphere_enabled", float(light_enabled))
		KEY_F11:
			var mode := DisplayServer.window_get_mode()
			var fullscreen := DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_WINDOWED if mode == fullscreen else fullscreen
			)
