extends Node3D

enum Place { GUILD, GATE, FOREST }
@export var place := Place.GUILD

const STONE = preload("res://world/textures/slate.png")
const WOOD = preload("res://world/textures/cedar.png")
const BARK = preload("res://world/textures/timber.png")
const GRASS = preload("res://world/textures/grass.png")
const MOSS = preload("res://world/textures/river_rock.png")

var _stone: StandardMaterial3D
var _wood: StandardMaterial3D
var _bark: StandardMaterial3D
var _brick: StandardMaterial3D
var _iron: StandardMaterial3D
var _gold: StandardMaterial3D
var _amber: StandardMaterial3D
var _blue: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var chest_lid: MeshInstance3D
var portcullis: Node3D

func _ready() -> void:
	_rng.seed = 95 + place
	_stone = _material(Color("#a2aebc"), STONE, Vector3(3, 2, 1))
	_wood = _material(Color("#af7c61"), WOOD, Vector3(2, 2, 1))
	_bark = _material(Color("#786361"), BARK)
	_brick = _material(Color("#687d93"), STONE)
	_iron = _material(Color("#344356"))
	_gold = _material(Color("#c58c4d"))
	_amber = _material(Color("#ffd288"))
	_blue = _material(Color("#6ddccf"))
	_amber.emission_enabled = true
	_amber.emission = Color("#ffac51")
	_amber.emission_energy_multiplier = 0.66
	_blue.emission_enabled = true
	_blue.emission = Color("#41cbc3")
	_blue.emission_energy_multiplier = 0.48
	match place:
		Place.GUILD:
			_guild()
		Place.GATE:
			_gate()
		Place.FOREST:
			_forest()

func _material(color: Color, texture: Texture2D = null, tile := Vector3.ONE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = texture
	material.uv1_scale = tile
	material.roughness = 0.84
	return material

func _mesh(form: Mesh, at: Vector3, material: Material, label := "") -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	if not label.is_empty():
		mesh.name = label
	mesh.mesh = form
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	return mesh

func _box(at: Vector3, size: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var form := BoxMesh.new()
	form.size = size
	var mesh := _mesh(form, at, material)
	if solid:
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		var bounds := CollisionShape3D.new()
		bounds.shape = shape
		mesh.add_child(body)
		body.add_child(bounds)
	return mesh

func _rock(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var form := SphereMesh.new()
	form.height = 1.0
	form.radius = 0.5
	form.radial_segments = 7
	form.rings = 4
	var stone := _mesh(form, at, material)
	stone.scale = size
	stone.rotation.y = _rng.randf_range(-PI, PI)
	return stone

func _lamp(at: Vector3, energy: float) -> void:
	_box(at, Vector3(0.19, 0.38, 0.18), _amber)
	_box(at + Vector3.UP * 0.23, Vector3(0.34, 0.08, 0.32), _iron)
	_box(at - Vector3.UP * 0.23, Vector3(0.28, 0.08, 0.27), _gold)
	if energy > 0:
		var light := OmniLight3D.new()
		light.position = at + Vector3(0, -0.3, 0.45)
		light.light_color = Color("#ffab5b")
		light.light_energy = energy
		light.omni_range = 4.8
		add_child(light)

func _wall(at: Vector3, size: Vector3) -> void:
	_box(at, size, _brick, true)
	_box(at + Vector3(0, size.y * 0.37, size.z * 0.49),
		Vector3(size.x, 0.14, 0.22), _stone)

func _guild() -> void:
	var floor := _material(Color("#bd8b73"), WOOD, Vector3(9, 6, 1))
	_box(Vector3(0, -0.23, 0), Vector3(25, 0.46, 15), floor, true)
	var carpet := _material(Color("#673b52"), WOOD, Vector3(1, 4, 1))
	_box(Vector3(0.5, 0.018, 1.4), Vector3(2.6, 0.026, 10.0), carpet)
	for x in [-0.84, 1.84]:
		_box(Vector3(x, 0.036, 1.4), Vector3(0.07, 0.02, 9.92), _gold)
	_wall(Vector3(-9.02, 2.6, -6.7), Vector3(6.95, 5.2, 0.55))
	_wall(Vector3(5.52, 2.6, -6.7), Vector3(13.95, 5.2, 0.55))
	_wall(Vector3(-3.5, 0.82, -6.7), Vector3(4.1, 1.64, 0.55))
	_wall(Vector3(-3.5, 5.03, -6.7), Vector3(4.1, 0.36, 0.55))
	_wall(Vector3(-10.7, 2.05, -2.4), Vector3(0.53, 4.1, 9.1))
	_box(Vector3(0, 0.29, 7.37), Vector3(25, 0.58, 0.38), _brick, true)
	_box(Vector3(12.2, 1.0, -3.52), Vector3(0.6, 2.0, 7.8), _brick, true)
	_box(Vector3(12.2, 1.0, 5.72), Vector3(0.6, 2.0, 3.25), _brick, true)

	var glass := _material(Color("#8fa9bc"))
	glass.emission_enabled = true
	glass.emission = Color("#a0c4ce")
	glass.emission_energy_multiplier = 0.40
	_box(Vector3(-3.5, 3.25, -6.79), Vector3(3.87, 3.24, 0.10), glass)
	for x in [-5.48, -4.53, -3.55, -2.56, -1.56]:
		_box(Vector3(x, 3.21, -6.49), Vector3(0.115, 3.25, 0.22), _iron)
	for y in [1.65, 2.66, 3.75, 4.76]:
		_box(Vector3(-3.5, y, -6.49), Vector3(4.09, 0.12, 0.23), _iron)
	for x in [-9.25, -5.84, -1.3, 5.8, 10.3]:
		_box(Vector3(x, 2.3, -6.19), Vector3(0.43, 4.6, 0.44), _wood)
		_box(Vector3(x, 0.33, -6.14), Vector3(0.64, 0.65, 0.59), _stone)
	_box(Vector3(3.8, 3.8, -5.92), Vector3(8.5, 0.25, 1.3), _wood)
	for x in [0.65, 2.4, 4.2, 6.1, 7.8]:
		_box(Vector3(x, 4.15, -5.29), Vector3(0.13, 0.65, 0.14), _iron)
	_box(Vector3(4.1, 4.41, -5.30), Vector3(7.9, 0.11, 0.13), _gold)
	for at in [Vector3(-7.35, 2.65, -5.81), Vector3(2.6, 2.65, -5.81), Vector3(8.9, 2.65, -5.81)]:
		_lamp(at, 1.15)
	_box(Vector3(-1.75, 1.62, -3.93), Vector3(2.4, 1.38, 0.18), _wood, true)
	_box(Vector3(-1.75, 2.34, -3.92), Vector3(2.55, 0.13, 0.24), _gold)
	var parchment := _material(Color("#e4c6a0"))
	for i in 6:
		var at := Vector3(-2.55 + (i % 3) * 0.78, 1.39 + (i / 3) * 0.48, -3.82)
		_box(at, Vector3(0.51, 0.4, 0.035), parchment).rotation.z = _rng.randf_range(-0.13, 0.13)
	for x in [-7.8, 6.75]:
		var table_z := 0.95 if x < 0 else -1.25
		_box(Vector3(x, 0.73, table_z), Vector3(3.1, 0.16, 1.6), _wood, true)
		for l in [-1.26, 1.26]:
			_box(Vector3(x + l, 0.36, table_z), Vector3(0.18, 0.73, 1.24), _wood)
		for side in [-1.0, 1.0]:
			_box(Vector3(x, 0.36, table_z + side * 1.19), Vector3(2.4, 0.18, 0.42), _wood, true)
		for i in 4:
			_box(Vector3(x - 0.9 + 0.56 * i, 0.92, table_z + .12), Vector3(0.10, 0.27, 0.12), _gold)
	for i in 4:
		_box(Vector3(7.1 + (i % 2) * .82, 0.28 + (i / 2) * 0.54, -4.45),
			Vector3(.78, .56, .68), _wood, true)
	var banner := _material(Color("#76508a"))
	for x in [-8.3, 9.4]:
		_box(Vector3(x, 3.46, -6.03), Vector3(1.05, 1.7, 0.09), banner)
		_box(Vector3(x, 4.32, -6.01), Vector3(1.3, 0.1, 0.15), _gold)
		_box(Vector3(x, 3.5, -5.97), Vector3(0.32, 0.32, 0.047), _gold).rotation.z = PI / 4

func _gate() -> void:
	_box(Vector3(0, -0.25, 0), Vector3(17.2, 0.5, 11.6), _stone, true)
	for side in [-1.0, 1.0]:
		_wall(Vector3(2, 1.9, side * 4.6), Vector3(1.8, 3.8, 2.7))
		_box(Vector3(2, 4.08, side * 4.6), Vector3(2.05, 0.56, 2.95), _stone)
		for offset in [-0.92, 0, 0.92]:
			_box(Vector3(2, 4.64, side * 4.6 + offset), Vector3(1.91, 0.62, .39), _brick)
		for i in 4:
			_box(Vector3(-4.87 + i * 0.78, 0.11 * (i + 1), side * 4.68),
				Vector3(.84, .22 * (i + 1), 1.75), _brick)
		_lamp(Vector3(1.07, 2.2, side * 2.99), 0.7)
	_box(Vector3(2, 3.85, 0), Vector3(1.61, 0.97, 6.8), _brick)
	_box(Vector3(2, 4.28, 0), Vector3(1.83, 0.17, 6.9), _stone)
	_box(Vector3(-4.8, 0.30, -5.6), Vector3(13, 0.6, 0.32), _brick, true)
	_box(Vector3(-4.8, 0.30, 5.6), Vector3(13, 0.6, 0.32), _brick, true)

	portcullis = Node3D.new()
	portcullis.name = "Portcullis"
	add_child(portcullis)
	for i in 13:
		_box(Vector3(1.82, 1.62, (i - 6) * 0.45), Vector3(.16, 3.24, .14), _iron).reparent(portcullis)
	for y in [0.78, 2.42]:
		_box(Vector3(1.82, y, 0), Vector3(.17, .14, 5.64), _iron).reparent(portcullis)

func open_gate() -> void:
	$Barrier/CollisionShape3D.set_deferred("disabled", true)
	var rising := create_tween()
	rising.tween_property(portcullis, "position:y", 3.34, .49)
	rising.tween_callback(portcullis.hide)

func _forest() -> void:
	var earth := _material(Color("#627c78"), MOSS, Vector3(13, 10, 1))
	var grass := _material(Color("#446f69"), GRASS, Vector3(6, 4, 1))
	var gravel := _material(Color("#9ca4b4"), STONE, Vector3(5, 2.2, 1))
	_box(Vector3(4, -0.49, -1.0), Vector3(50, 0.45, 36), earth)
	_box(Vector3(3.5, -0.25, 0), Vector3(34, 0.50, 24), earth, true)
	_box(Vector3(0.2, 0.014, 0.5), Vector3(21, 0.02, 4.3), gravel)
	_box(Vector3(6.2, 0.018, -4.0), Vector3(13.2, 0.02, 8.8), gravel)
	_box(Vector3(13.1, 0.023, 5.65), Vector3(5.0, 0.03, 8.1), gravel).rotation.y = -0.34
	var shades: Array[StandardMaterial3D] = [
		_material(Color("#2e5c59"), GRASS), _material(Color("#386d61"), GRASS),
		_material(Color("#568d70"), GRASS)]
	var trees: Array[Vector2] = [
		Vector2(-10,-4.8),Vector2(-7,-8),Vector2(-3.3,-6.4),Vector2(0,-9),
		Vector2(5,-10),Vector2(10.5,-8.6),Vector2(16,-7),Vector2(19,-3),
		Vector2(-10,6.2),Vector2(-5.3,9.3),Vector2(-0.3,8.6),Vector2(3.8,10.1),
		Vector2(7.0,7.8),Vector2(12.4,10.7),Vector2(18.3,9.55),Vector2(19.5,2.9),
		Vector2(-12.5,-9.4),Vector2(18.6,-10.5),Vector2(11.8,-12)]
	for p in trees:
		_tree(Vector3(p.x, 0, p.y), _rng.randf_range(0.70, 1.29), shades)
	for i in 28:
		var x := _rng.randf_range(-11.4, 19.6)
		var z := (-1.0 if i % 2 == 0 else 1.0) * _rng.randf_range(7.7, 11.8)
		_rock(Vector3(x, 0.17, z), Vector3(_rng.randf_range(.45, 1.4), .65, .84), _brick)
		if i % 2 == 0:
			_box(Vector3(x, 0.025, z - 0.18), Vector3(1.35, 0.04, 1.8), grass)
	for p in [Vector3(-8, 0, -2.4), Vector3(1.8, 0, 3.4), Vector3(11.4, 0, 5.0)]:
		_crystal_cluster(p)
	for p in [Vector3(-3, 0, -3.45), Vector3(3.9, 0, -8.6), Vector3(15.7, 0, 8.75)]:
		_mushroom_patch(p)
	for x in [1.8, 11.9]:
		_box(Vector3(x, 1.07, -7.45), Vector3(0.82, 2.14, .84), _brick, true)
		_box(Vector3(x, 2.14, -7.45), Vector3(1.08, 0.22, 1.07), _stone)
		_box(Vector3(x, 1.35, -7.0), Vector3(.19, .53, 0.045), _blue).rotation.z = PI * .25
	var chest := Vector3(14.2, 0.0, 7.8)
	_box(chest + Vector3.UP * .27, Vector3(1.1, 0.54, .63), _wood, true)
	chest_lid = _box(chest + Vector3.UP * .57, Vector3(1.18, .18, .70), _iron)
	_box(chest + Vector3(0, .44, .35), Vector3(.20, .25, .10), _gold)
	for x in [-.44, .44]:
		_box(chest + Vector3(x, .33, .335), Vector3(.10, .6, .09), _gold)
	for z in [-11.86, 11.86]:
		_box(Vector3(3.5, 2.4, z), Vector3(34.2, 4.8, 0.3), _brick, true).hide()
	_box(Vector3(20.35, 2.4, 0), Vector3(.3, 4.8, 24), _brick, true).hide()
	for z in [-9.0, 9.0]:
		_box(Vector3(-13.45, 2.4, z), Vector3(.3, 4.8, 6.2), _brick, true).hide()

func _tree(at: Vector3, size: float, shades: Array[StandardMaterial3D]) -> void:
	var trunk := CylinderMesh.new()
	trunk.radial_segments = 7
	trunk.rings = 1
	trunk.height = 4.4 * size
	trunk.bottom_radius = 0.5 * size
	trunk.top_radius = .24 * size
	_mesh(trunk, at + Vector3.UP * trunk.height * 0.5, _bark).rotation.z = _rng.randf_range(-0.12, 0.12)
	_box(at + Vector3.UP, Vector3(.75, 2.0, .75) * size, _bark, true).hide()
	for i in 4:
		var a := i * 1.62
		var offset := Vector3(cos(a) * 0.93, 3.65 + _rng.randf_range(-0.35, 1.0), sin(a) * 0.9) * size
		_rock(at + offset, Vector3(2.85, 1.65, 2.45) * size, shades[i % shades.size()])

func _crystal_cluster(at: Vector3) -> void:
	for i in 3:
		var core := PrismMesh.new()
		core.size = Vector3(.32, 1.23 - i * .22, .32)
		var p := _mesh(core, at + Vector3((i - 1) * .34, core.size.y * .44, i * .12), _blue)
		p.rotation_degrees = Vector3(0, i * 36.0, (i - 1) * 17.0)
	_rock(at + Vector3.UP * .10, Vector3(1.52, .56, 1.1), _brick)

func _mushroom_patch(at: Vector3) -> void:
	for i in 5:
		var size := _rng.randf_range(.19, .39)
		var a := i * 2.39996
		var p := at + Vector3(cos(a) * .58, 0, sin(a) * .61)
		_box(p + Vector3.UP * size * .65, Vector3(.10, size, .10), _stone)
		_rock(p + Vector3.UP * size * 1.21, Vector3(size * 1.6, size * .52, size * 1.42), _blue)
