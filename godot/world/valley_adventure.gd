extends Node3D

const TRAVELER = preload("res://world/traveler.gd")
const GRASS_SHADER = preload("res://world/materials/grass.gdshader")
const NPC_TEXTURE = preload("res://assets/lu-khach.webp")

const SPAWN := Vector3(-30, 0.5, 4.0)
const KEEPER := Vector3(-23.8, 0.06, -0.8)
const SHRINE := Vector3(35.0, 0.07, -0.85)
const SHARDS := [Vector3(-10.6, 0.1, -10.7), Vector3(21.2, 0.11, -13.95), Vector3(44.15, 0.1, 15.15)]
const VIEW_OFFSET := Vector3(3.8, 17.4, 25.5)

enum Stage { MEET, SEARCH, RETURN, COMPLETE }

@onready var terrain: MeshInstance3D = $Valley/Banks
@onready var bridge: Node3D = $Valley/Crossing/ArchBridge
@onready var camera: Camera3D = $Camera
@onready var player: CharacterBody3D = $Traveler
@onready var hud = $Overlay/HUD

var stage := Stage.MEET
var picked: Array[bool] = [false, false, false]
var gems: Array[Node3D] = []
var objective_beacon: Node3D
var shrine_light: OmniLight3D
var route: Array[Vector3] = []
var blocked_for := 0.0
var previous_position := SPAWN
var camera_target := SPAWN
var elapsed := 0.0
var tap_position := Vector2.ZERO
var place := ""
var navigator := RayCast3D.new()

func _ready() -> void:
	_add_mesh_collider(terrain, terrain.mesh.create_trimesh_shape(), 1)
	var deck := _first_mesh(bridge)
	if deck != null:
		_add_mesh_collider(deck, deck.mesh.create_trimesh_shape(), 1)
	_add_limits()
	_add_architecture_collision()
	_add_lights()
	_sow_grass()
	_add_keeper()
	_create_objectives()
	add_child(navigator)
	navigator.collision_mask = 1
	navigator.enabled = false
	hud.action_requested.connect(_interact)
	_sync_quest()
	_follow_camera(1.0)

func _physics_process(delta: float) -> void:
	var x := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var z := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var nudge := Vector3(x, 0, z).normalized()
	if nudge != Vector3.ZERO:
		route.clear()
		blocked_for = 0
	elif not route.is_empty():
		var remaining: Vector3 = route.front() - player.position
		remaining.y = 0
		if remaining.length_squared() < .18:
			route.pop_front()
			blocked_for = 0
		else:
			nudge = remaining.normalized()
			blocked_for = blocked_for + delta if previous_position.distance_squared_to(player.position) < .00015 else 0.0
			if blocked_for > .32:
				route.clear()
				blocked_for = 0.0
				nudge = Vector3.ZERO
	player.steering = nudge
	previous_position = player.position
	if player.position.y < -2.0:
		player.position = SPAWN
		player.velocity = Vector3.ZERO
		route.clear()
	_collect()
	_update_context()

func _process(delta: float) -> void:
	elapsed += delta
	_follow_camera(1.0 - exp(-delta * 5.2))
	for i in gems.size():
		if gems[i].visible:
			gems[i].rotation.y = elapsed * .95 + i
			gems[i].position.y = SHARDS[i].y + 1.18 + sin(elapsed * 2.9 + i) * .18
	objective_beacon.position.y = 2.4 + sin(elapsed * 2.6) * .13

func _follow_camera(blend: float) -> void:
	var focus := player.position + Vector3(player.steering.x * 2.5, -.1, -.7)
	camera_target = camera_target.lerp(focus, blend)
	camera.position = camera_target + VIEW_OFFSET
	camera.look_at(camera_target + Vector3(0, 1.3, 0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			_interact()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_C:
			camera.size = 22.5 if camera.size < 20.0 else 17.4
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_position = event.position
		_select_ground.call_deferred()

func _select_ground() -> void:
	var start := camera.project_ray_origin(tap_position)
	var direction := camera.project_ray_normal(tap_position)
	navigator.position = start
	navigator.target_position = direction * 110.0
	navigator.force_raycast_update()
	if not navigator.is_colliding():
		return
	var target := navigator.get_collision_point()
	route.clear()
	blocked_for = 0
	if absf(player.position.x) > 7.6 and (absf(target.x) < 7.6 or target.x * player.position.x < 0):
		var approach := signf(player.position.x)
		route.append(Vector3(approach * 8.1, 0, 4))
		if absf(target.x) > 7.6:
			route.append(Vector3(-approach * 8.1, 0, 4))
	route.append(target)

func _horizontal_range(point: Vector3) -> float:
	return Vector2(player.position.x - point.x, player.position.z - point.z).length()

func _collect() -> void:
	if stage != Stage.SEARCH:
		return
	for i in SHARDS.size():
		if not picked[i] and _horizontal_range(SHARDS[i]) < 1.28:
			picked[i] = true
			gems[i].hide()
			hud.announce("Đã tìm thấy một mảnh nguyệt thạch.")
			_sync_quest()
	if picked.count(true) == SHARDS.size():
		stage = Stage.RETURN
		_sync_quest()

func _update_context() -> void:
	var action := ""
	if stage == Stage.MEET and _horizontal_range(KEEPER) < 2.3:
		action = "Nói chuyện"
	elif stage == Stage.RETURN and _horizontal_range(SHRINE) < 2.6:
		action = "Thắp Ấn Nguyệt"
	hud.set_action(action)
	var x := player.position.x
	var z := player.position.z
	var region := "Xóm Bến Sương"
	if absf(x) < 7.6:
		region = "Cầu Gió"
	elif x > 30 and z > 8:
		region = "Rừng Lồng Đèn"
	elif x > 28 and z < 8:
		region = "Miếu Trăng Nổi"
	elif x > 7.6:
		region = "Đồi Thông"
	elif x > -16 and z < -6:
		region = "Bến Lau"
	if region != place:
		place = region
		hud.location.text = place

func _interact() -> void:
	if stage == Stage.MEET and _horizontal_range(KEEPER) < 2.3:
		stage = Stage.SEARCH
		hud.announce("Người giữ đền: Tìm ở Bến Lau, Đồi Thông và Rừng Lồng Đèn.")
	elif stage == Stage.RETURN and _horizontal_range(SHRINE) < 2.6:
		stage = Stage.COMPLETE
		shrine_light.light_energy = 4.0
		hud.announce("Ấn Nguyệt đã sáng trở lại. Bạn nhận 100 kinh nghiệm.")
	_sync_quest()
	_update_context()

func _sync_quest() -> void:
	var text := [
		"Gặp Người giữ đền trước quán trà.",
		"Tìm ở Bến Lau, Đồi Thông và Rừng Lồng Đèn.",
		"Đem nguyệt thạch tới Miếu Trăng Nổi.",
		"Ấn Nguyệt đã sáng trở lại.",
	][stage] as String
	hud.update_quest(text, picked.count(true), stage == Stage.COMPLETE)
	for i in gems.size():
		gems[i].visible = stage == Stage.SEARCH and not picked[i]
	objective_beacon.visible = stage == Stage.MEET or stage == Stage.RETURN
	var marker := SHRINE if stage == Stage.RETURN else KEEPER
	objective_beacon.position = marker + Vector3(0, 2.4, 0)

func _first_mesh(parent: Node3D) -> MeshInstance3D:
	for child in parent.get_children():
		if child is MeshInstance3D:
			return child
		if child is Node3D:
			var nested := _first_mesh(child)
			if nested != null:
				return nested
	return null

func _add_mesh_collider(parent: Node3D, shape: Shape3D, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var hitbox := CollisionShape3D.new()
	hitbox.shape = shape
	parent.add_child(body)
	body.add_child(hitbox)

func _box_collider(parent: Node3D, center: Vector3, size: Vector3, layer := 2) -> void:
	var anchor := Node3D.new()
	anchor.position = center
	parent.add_child(anchor)
	var shape := BoxShape3D.new()
	shape.size = size
	_add_mesh_collider(anchor, shape, layer)

func _add_limits() -> void:
	for side in [-1, 1]:
		_box_collider(self, Vector3(55.35 * side, 3.0, 0), Vector3(.5, 10, 65))
		_box_collider(self, Vector3(0, 3.0, 31.6 * side), Vector3(112, 10, .5))
	for x in [-6.37, 6.37]:
		_box_collider(self, Vector3(x, 2.3, -15.0), Vector3(.29, 7, 34.3))
		_box_collider(self, Vector3(x, 2.3, 19.28), Vector3(.29, 7, 26.5))

func _add_architecture_collision() -> void:
	for path in ["Village/TeaHouse", "Village/WestCottage", "Village/UpperCottage",
			"ShrineAndForest/CrescentShrine", "ShrineAndForest/WaysideShelter"]:
		var building := get_node("Valley/" + path) as Node3D
		var shr: bool = path.ends_with("CrescentShrine")
		var w := 6.4 if shr else 7.4
		_box_collider(building, Vector3(0, 1.5, -.14), Vector3(w + .1, 3.0, 4.4))
	for tree in $Valley/Groves.get_children():
		_box_collider(tree, Vector3(.06, .79, 0), Vector3(.67, 1.58, .67))
	for lantern in $Valley/Crossing.get_children():
		if lantern != bridge:
			_box_collider(lantern, Vector3(0, .38, 0), Vector3(.65, .76, .65))
	for boulder in $Valley/Boulders.get_children():
		_box_collider(boulder, Vector3(.06, .30, 0), Vector3(1.14, .62, .95))
	var gate: Node3D = $Valley/ShrineAndForest/GateToTheGrove
	for side in [-1, 1]:
		_box_collider(gate, Vector3(side * 2.16, 0.9, 0), Vector3(.86, 1.8, .82))
	for item in $Valley/Gardens.get_children():
		if item.name.begins_with("WoodFence"):
			_box_collider(item, Vector3(0, .57, 0), Vector3(3.95, 1.14, .27))
	var ramp_mesh := BoxMesh.new()
	ramp_mesh.size = Vector3(4, .12, 2.8)
	for limit in [-1, 1]:
		var ramp := Node3D.new()
		ramp.position = Vector3(limit * 7.19, .071, 4.0)
		ramp.rotation.z = -limit * .11
		add_child(ramp)
		_add_mesh_collider(ramp, ramp_mesh.create_trimesh_shape(), 1)

func _add_lights() -> void:
	for node in $Valley/Crossing.get_children():
		if node == bridge:
			continue
		_place_light(node.position + Vector3(0, 1.9, 0), 1.52, 4.6, Color("#ffbc76"))
	_place_light(Vector3(-24.0, 2.1, -2.25), 2.5, 6.3, Color("#ffb978"))
	_place_light(Vector3(12.0, 1.4, 4.0), .9, 5.9, Color("#9ad9de"))
	shrine_light = _place_light(Vector3(35,2.1,-1.4), 2.2, 7.4, Color("#ffc780"))

func _place_light(at: Vector3, energy: float, reach: float, tint: Color) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.45
	add_child(light)
	return light

func _add_keeper() -> void:
	var keeper := Sprite3D.new()
	keeper.texture = NPC_TEXTURE
	keeper.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	keeper.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	keeper.shaded = false
	keeper.pixel_size = .0097
	keeper.centered = false
	keeper.offset.x = -NPC_TEXTURE.get_width() * .5
	keeper.modulate = Color("#efd4a5")
	keeper.flip_h = true
	keeper.position = KEEPER
	add_child(keeper)

func _create_objectives() -> void:
	for point in SHARDS:
		var node := _make_gem(Color("#77f0d7"), .28)
		node.position = point
		gems.append(node)
		node.hide()
	objective_beacon = _make_gem(Color("#ffd28a"), .18)

func _make_gem(tint: Color, radius: float) -> MeshInstance3D:
	var gem := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 3.0
	shape.radial_segments = 4
	shape.rings = 2
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = .5
	material.roughness = .27
	gem.mesh = shape
	gem.material_override = material
	add_child(gem)
	return gem

func _sow_grass() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 5:
		var angle := blade * 2.39996
		var turn := Vector3(cos(angle), 0, sin(angle))
		var foot := turn * .12
		var tangent := Vector3(-turn.z, 0, turn.x) * .038
		surface.add_vertex(foot - tangent)
		surface.add_vertex(foot + tangent)
		surface.add_vertex(foot + turn * .36 + Vector3.UP * (.53 + (blade % 3) * .15))
	surface.generate_normals()
	var blade_mesh := surface.commit()
	var mat := ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	blade_mesh.surface_set_material(0, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 65371
	var transforms: Array[Transform3D] = []
	var shades: Array[Color] = []
	for i in 1560:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (rng.randf_range(6.38, 9.6) if i < 490 else rng.randf_range(8.1, 53.8))
		var z := rng.randf_range(-28.0, 27.0)
		if absf(z - 4) < 2.25 or (x < 0 and absf(z + 1.5) < 4.6 and absf(x + 24.0) < 6.8):
			continue
		if _near_branch(Vector2(x,z)):
			continue
		var clump := rng.randf_range(.45, 1.23) * (1.25 if i < 490 else 1.0)
		var base := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * clump)
		var coast := exp(-maxf(0.0,absf(x)-6.0)*2.6)*-.37
		var hill := maxf(0.0,(absf(z)-18.5)/10.0)*(.9+.43*sin(x*.22))
		var y := .036 + coast + sin(x*.31)*cos(z*.46)*.027 + hill
		transforms.append(Transform3D(base, Vector3(x,y,z)))
		var hue := rng.randf_range(.19, .26)
		shades.append(Color.from_hsv(hue, rng.randf_range(.40,.67), rng.randf_range(.32,.55)))
	var grass := MultiMesh.new()
	grass.transform_format = MultiMesh.TRANSFORM_3D
	grass.use_colors = true
	grass.mesh = blade_mesh
	grass.instance_count = transforms.size()
	for i in transforms.size():
		grass.set_instance_transform(i, transforms[i])
		grass.set_instance_color(i, shades[i])
	var clumps := MultiMeshInstance3D.new()
	clumps.name = "RiverGrass"
	clumps.multimesh = grass
	clumps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clumps)

func _near_branch(p: Vector2) -> bool:
	for segment in [
		[Vector2(-19, 4), Vector2(-9, -13)], [Vector2(16, 4), Vector2(21, -16)],
		[Vector2(32, 4), Vector2(32, -6)], [Vector2(29, 4), Vector2(46, 15)],
	]:
		if Geometry2D.get_closest_point_to_segment(p, segment[0], segment[1]).distance_to(p) < 1.65:
			return true
	return false
