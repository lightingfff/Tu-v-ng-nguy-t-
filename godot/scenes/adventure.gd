extends Node2D

const PAINTING = preload("res://assets/song-nguyet.webp")
const LANDSCAPE_SHADER = preload("res://shaders/landscape.gdshader")

const WORLD_SIZE = Vector2(2560, 853)
const ROUTE = [
	Vector2(110, 622), Vector2(510, 624), Vector2(946, 623),
	Vector2(1010, 598), Vector2(1105, 554), Vector2(1228, 518),
	Vector2(1320, 506), Vector2(1430, 518), Vector2(1535, 550),
	Vector2(1625, 598), Vector2(1715, 621), Vector2(2445, 622)
]
const SPAWN_X = 170.0
const KEEPER_X = 420.0
const SHRINE_X = 2250.0
const SHARDS = [780.0, 1356.0, 1874.0]
const SPEED = 238.0
const LEFT_BOUND = 110.0
const RIGHT_BOUND = 2445.0

enum Stage { MEET, COLLECT, RETURN, COMPLETE }
const OBJECTIVES = {
	Stage.MEET: "Gặp Người giữ đền ở quán trà.",
	Stage.COLLECT: "Đi về phía đông và thu thập nguyệt thạch.",
	Stage.RETURN: "Mang đủ ba mảnh tới đền cuối đường.",
	Stage.COMPLETE: "Ấn Nguyệt đã sáng trở lại."
}

@onready var painting: Sprite2D = $Painting
@onready var traveler = $Traveler
@onready var keeper = $Keeper
@onready var camera: Camera2D = $Camera
@onready var effects = $WorldEffects
@onready var hud = $Overlay/HUD

var near_reeds: Array[Sprite2D] = []
var reed_anchors: Array[Vector2] = []
var landscape := ShaderMaterial.new()
var stage := Stage.MEET
var recovered: Array[bool] = [false, false, false]
var actor_x := SPAWN_X
var destination := SPAWN_X
var using_destination := false
var travel_direction := 1.0
var elapsed := 0.0

func _ready() -> void:
	painting.texture = PAINTING
	landscape.shader = LANDSCAPE_SHADER
	painting.material = landscape
	landscape.set_shader_parameter("material_atlas", preload("res://assets/river-material.png"))
	_place_reeds()
	keeper.position = Vector2(KEEPER_X, route_y(KEEPER_X))
	keeper.face = -1.0
	traveler.position = Vector2(actor_x, route_y(actor_x))
	effects.guide = keeper.position
	effects.altar = Vector2(SHRINE_X, route_y(SHRINE_X))
	for shard in SHARDS:
		effects.shard_points.append(Vector2(shard, route_y(shard)))
	hud.action_requested.connect(_interact)
	_update_hud()
	_frame_camera(1.0)

func _physics_process(delta: float) -> void:
	var left := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var right := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var steer := float(right) - float(left)
	var next_x := actor_x
	if not is_zero_approx(steer):
		using_destination = false
		next_x += steer * SPEED * delta
	elif using_destination:
		next_x = move_toward(actor_x, destination, SPEED * delta)
		if is_equal_approx(next_x, destination):
			using_destination = false
	next_x = clampf(next_x, LEFT_BOUND, RIGHT_BOUND)
	var moving := not is_equal_approx(actor_x, next_x)
	if moving:
		travel_direction = signf(next_x - actor_x)
	actor_x = next_x
	traveler.set_motion(Vector2(actor_x, route_y(actor_x)), travel_direction, moving, delta)
	effects.traveler = traveler.position
	effects.moving = moving
	effects.facing = travel_direction
	_collect_shards()
	_update_context()

func _process(delta: float) -> void:
	elapsed += delta
	landscape.set_shader_parameter("elapsed", elapsed)
	landscape.set_shader_parameter("restored", float(stage == Stage.COMPLETE))
	effects.elapsed = elapsed
	effects.queue_redraw()
	_frame_camera(1.0 - exp(-6.0 * delta))
	var pan := camera.position.x - WORLD_SIZE.x * 0.5
	landscape.set_shader_parameter("pan", pan / WORLD_SIZE.x)
	for i in near_reeds.size():
		var reed := near_reeds[i]
		reed.position.x = reed_anchors[i].x - pan * 0.23
		reed.skew = sin(elapsed * 1.22 + i * 1.74) * 0.043 + sin(elapsed * 2.3 + i) * 0.011

func _frame_camera(blend: float) -> void:
	var view := get_viewport_rect().size
	var scale_factor := maxf(1.0, maxf(view.x / WORLD_SIZE.x, view.y / WORLD_SIZE.y))
	camera.zoom = Vector2.ONE * scale_factor
	var half_view := view / (2.0 * scale_factor)
	var desired_x := actor_x + travel_direction * 144.0
	var desired_y := 463.0 + (route_y(actor_x) - ROUTE[0].y) * 0.30
	var desired := Vector2(desired_x, desired_y).clamp(half_view, WORLD_SIZE - half_view)
	camera.position = camera.position.lerp(desired, blend).clamp(half_view, WORLD_SIZE - half_view)

func route_y(x: float) -> float:
	for i in range(1, ROUTE.size()):
		var from: Vector2 = ROUTE[i - 1]
		var to: Vector2 = ROUTE[i]
		if x <= to.x:
			return lerpf(from.y, to.y, inverse_lerp(from.x, to.x, x))
	return ROUTE.back().y

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			_interact()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var selected: Vector2 = get_canvas_transform().affine_inverse() * event.position
		destination = clampf(selected.x, LEFT_BOUND, RIGHT_BOUND)
		using_destination = true
		effects.footprint = Vector2(destination, route_y(destination))
		effects.footprint_time = elapsed

func _collect_shards() -> void:
	if stage != Stage.COLLECT:
		return
	for i in SHARDS.size():
		if not recovered[i] and absf(actor_x - SHARDS[i]) < 42.0:
			recovered[i] = true
			hud.announce("Nhặt được một mảnh nguyệt thạch.")
			_update_hud()
	if recovered.count(true) == SHARDS.size():
		stage = Stage.RETURN
		_update_hud()
		hud.announce("Đã đủ ba mảnh. Hãy tới đền ở cuối đường.")

func _update_context() -> void:
	var label := ""
	if stage == Stage.MEET and absf(actor_x - KEEPER_X) < 134.0:
		label = "Nói chuyện"
	elif stage == Stage.RETURN and absf(actor_x - SHRINE_X) < 142.0:
		label = "Thắp Ấn Nguyệt"
	hud.set_action(label)

func _interact() -> void:
	if stage == Stage.MEET and absf(actor_x - KEEPER_X) < 134.0:
		stage = Stage.COLLECT
		hud.announce("Người giữ đền: Mang ba mảnh nguyệt thạch tới đền bên kia sông.")
		_update_hud()
	elif stage == Stage.RETURN and absf(actor_x - SHRINE_X) < 142.0:
		stage = Stage.COMPLETE
		hud.announce("Bạn đã thắp lại Ấn Nguyệt. +100 kinh nghiệm.")
		_update_hud()
	_update_context()

func _update_hud() -> void:
	hud.update_quest(OBJECTIVES[stage], recovered.count(true), stage == Stage.COMPLETE)
	effects.stage = stage
	effects.recovered = recovered

# These reeds occupy a nearer camera plane than the walking surface.
func _place_reeds() -> void:
	var reed_art: Texture2D = preload("res://assets/lau.webp")
	for clump in [Vector3(130, 881, 0.74), Vector3(1100, 880, 0.56), Vector3(2365, 886, 0.81)]:
		var reed := Sprite2D.new()
		reed.texture = reed_art
		reed.centered = false
		reed.offset = Vector2(-reed_art.get_width() * 0.5, -reed_art.get_height())
		reed.scale = Vector2.ONE * clump.z
		reed.position = Vector2(clump.x, clump.y)
		reed.z_index = 4
		reed.modulate = Color(0.76, 0.82, 0.84)
		add_child(reed)
		near_reeds.append(reed)
		reed_anchors.append(reed.position)
