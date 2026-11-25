extends Node3D

enum Quest { OFFERED, DEPART, HUNT, LOOT, COMPLETE }

const SWORDSMAN = preload("res://fantasy/combat/swordsman.tres")
const MAGE = preload("res://fantasy/combat/mage.tres")
const GUARDIAN = preload("res://fantasy/combat/guardian.tres")
const GOLEM = preload("res://fantasy/combat/golem.tres")
const IMPACT = preload("res://fantasy/assets/impact.png")

@onready var guild := $Guild
@onready var forest := $Forest
@onready var gate := $Gate
@onready var party: PartyController = $Party
@onready var camera: Camera3D = $Camera
@onready var hud = $HUD
@onready var guild_rig: AdventureLightRig = $Guild/LightRig
@onready var forest_rig: AdventureLightRig = $Forest/LightRig
@onready var board: Marker3D = $Guild/Contract
@onready var threshold: Marker3D = $Gate/Threshold
@onready var chest: Marker3D = $Forest/Chest
@onready var spawn: Marker3D = $Guild/Spawn
@onready var nest: Marker3D = $Forest/Golem

var enemy: CombatActor
var quest := Quest.OFFERED
var glow := true
var sunray := true
var _rig: AdventureLightRig
var _focus := Vector3.ZERO
var _enemy_wait := 0.0
var _danger: MeshInstance3D
var _vfx_ring := TorusMesh.new()
var _vfx_materials := {}
var _focus_initial := true

func _ready() -> void:
	for member in [SWORDSMAN, MAGE, GUARDIAN]:
		party.add_member(_actor(member))
	enemy = _actor(GOLEM)
	enemy.opponent = true
	add_child(enemy)
	enemy.global_position = nest.global_position
	enemy.defeated.connect(_enemy_down)
	enemy.set_vulnerable(false)
	party.feedback.connect(hud.notify)
	party.armor_broken.connect(_on_break)
	party.all_down.connect(_restart.call_deferred)
	party.place(spawn.global_position)
	_vfx_ring.inner_radius = 0.48
	_vfx_ring.outer_radius = 0.60
	_vfx_ring.rings = 18
	_vfx_ring.ring_segments = 8
	_danger = _ring(Color("#f28b61"), 0.9)
	_danger.hide()
	hud.interact.connect(interact)
	hud.visual_toggle.connect(set_visual)
	_update_context()

func _actor(data: AdventurerData) -> CombatActor:
	var actor := CombatActor.new()
	actor.data = data
	actor.cast_effect.connect(_spark)
	return actor

func _physics_process(delta: float) -> void:
	var move_x := float(_pressed(KEY_D, KEY_RIGHT)) - float(_pressed(KEY_A, KEY_LEFT))
	var move_z := float(_pressed(KEY_S, KEY_DOWN)) - float(_pressed(KEY_W, KEY_UP))
	party.active.steering = Vector3(move_x, 0, move_z).normalized()
	var player := party.active
	if player.global_position.y < -3:
		_restart.call_deferred()
	if quest == Quest.DEPART and player.global_position.x > threshold.global_position.x:
		quest = Quest.HUNT
		enemy.set_vulnerable(true)
		hud.notify("F gọi Hộ vệ phá giáp. Bấm 2 để đổi sang Pháp sư.")
	var fighting := quest == Quest.HUNT and _near(enemy.global_position, 8.0)
	party.update_party(delta, fighting)
	_think(delta, fighting)
	_update_context()

func _pressed(key: Key, alternate: Key) -> bool:
	return Input.is_physical_key_pressed(key) or Input.is_physical_key_pressed(alternate)

func _process(delta: float) -> void:
	var lead_z := -3.15 if party.active.global_position.x < -10.5 else -1.4
	var target := party.active.global_position + Vector3(1.45, 0.75, lead_z)
	_focus = target if _focus_initial else _focus.lerp(target, 1 - exp(-delta * 6.5))
	_focus_initial = false
	camera.position = _focus + Vector3(0.9, 11.9, 16.7)
	camera.look_at(_focus)
	var windup := quest == Quest.HUNT and enemy.state == CombatActor.State.WINDUP
	_danger.visible = windup
	if windup:
		_danger.global_position = enemy.global_position + enemy.facing * 1.22 + Vector3.UP * 0.045

func _think(delta: float, fighting: bool) -> void:
	enemy.steering = Vector3.ZERO
	_enemy_wait = maxf(0.0, _enemy_wait - delta)
	if not fighting or enemy.state != CombatActor.State.READY:
		return
	var toward := party.active.global_position - enemy.global_position
	toward.y = 0.0
	if toward.length() > 1.89:
		enemy.steering = toward.normalized()
	elif _enemy_wait <= 0.0:
		enemy.begin_attack(toward)
		_enemy_wait = 1.45

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_E: interact()
		KEY_J: attack()
		KEY_SPACE: party.active.dodge(party.active.steering)
		KEY_1: party.swap_to(0)
		KEY_2: party.swap_to(1)
		KEY_3: party.swap_to(2)
		KEY_F: assist()
		KEY_C: camera.size = 15.6 if camera.size < 14.0 else 11.7
		KEY_B: set_visual(&"glow", not glow)
		KEY_R: set_visual(&"sunray", not sunray)
		KEY_F1: hud.show_debug(_rig)

func attack() -> void:
	var aim := party.active.facing
	if quest == Quest.HUNT and _near(enemy.global_position, 7.7):
		aim = enemy.global_position - party.active.global_position
	party.active.begin_attack(aim)

func assist() -> void:
	if quest != Quest.HUNT or not party.request_assist(enemy):
		hud.notify("Hỗ trợ cần mục tiêu trong tầm và kỹ năng đã hồi.")

func set_visual(kind: StringName, on: bool) -> void:
	match kind:
		&"glow": glow = on
		&"sunray": sunray = on
	for rig in [guild_rig, forest_rig]:
		rig.glow_enabled = glow
		rig.sunray_enabled = sunray
		rig.apply_settings()
	hud.inspect_rig(_rig)

func _near(at: Vector3, reach: float) -> bool:
	return party.active.global_position.distance_to(at) < reach

func _context() -> String:
	if quest == Quest.OFFERED and _near(board.global_position, 2.0):
		return "Nhận hợp đồng"
	if quest == Quest.LOOT and _near(chest.global_position, 2.05):
		return "Mở rương"
	return ""

func interact() -> void:
	var current := _context()
	if current == "Nhận hợp đồng":
		quest = Quest.DEPART
		gate.open_gate()
		hud.notify("Đã nhận hợp đồng Thạch Vệ. Ra cổng phía đông.")
	elif current == "Mở rương":
		quest = Quest.COMPLETE
		forest.chest_lid.rotation.x = -0.85
		forest.chest_lid.position += Vector3(0, .20, -.20)
		_spark(chest.global_position + Vector3.UP * .85, Color("#ffc561"), 1.35)
		hud.notify("Nhận La Bàn Lam Tinh. Hoàn thành hợp đồng!")
	_update_context()

func _update_context() -> void:
	var x := party.active.global_position.x
	var zone := "Hội quán La Bàn Gãy"
	if x > threshold.global_position.x:
		zone = "Rừng Lam Diệp"
	elif x > gate.global_position.x - 7.6:
		zone = "Thành Vách Gió"
	hud.chapter.text = zone
	var rig := forest_rig if x > threshold.global_position.x else guild_rig
	if rig != _rig:
		_rig = rig
		hud.inspect_rig(rig)
	var objectives := [
		"Đến bảng hợp đồng trong sảnh.",
		"Ra cổng phía đông tới Rừng Lam Diệp.",
		"Phá giáp và hạ Thạch Vệ.",
		"Theo nhánh phía đông nam để mở rương.",
		"Hợp đồng hoàn thành · La Bàn Lam Tinh"
	]
	hud.objective.text = objectives[quest]
	hud.set_interaction(_context())
	hud.encounter.visible = quest == Quest.HUNT and _near(enemy.global_position, 11.0)
	hud.armor.max_value = enemy.data.armor
	hud.armor.value = enemy.armor
	hud.enemy_hp.max_value = enemy.data.health
	hud.enemy_hp.value = enemy.hp
	var row := PackedStringArray()
	for i in party.members.size():
		var mark := "▸ " if i == party.index else ""
		row.append("%s%d %s   %d HP" % [mark, i + 1, party.members[i].data.title, party.members[i].hp])
	row.append("Hỗ trợ  %.1fs" % party.assist_cooldown if party.assist_cooldown > 0 else "Hỗ trợ sẵn sàng")
	var copy := "     /     ".join(row)
	if hud.roster.text != copy:
		hud.roster.text = copy

func _on_break(role: int) -> void:
	hud.notify("%s đã phá giáp! Đổi sang Pháp sư để nối đòn." % party.members[role].data.title)

func _enemy_down() -> void:
	quest = Quest.LOOT
	hud.notify("Đã hạ Thạch Vệ. Tìm rương ở nhánh đông nam.")

func _restart() -> void:
	party.reset_at(spawn.global_position)
	_focus_initial = true
	if quest == Quest.HUNT:
		quest = Quest.DEPART
		enemy.reset_actor()
		enemy.global_position = nest.global_position
		enemy.set_vulnerable(false)
		hud.notify("Đã về hội quán. Hợp đồng vẫn còn hiệu lực.")

func _ring(tint: Color, size: float) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	mark.mesh = _vfx_ring
	if not _vfx_materials.has(tint):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = tint
		_vfx_materials[tint] = material
	mark.material_override = _vfx_materials[tint]
	mark.scale = Vector3.ONE * size
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mark)
	return mark

func _spark(at: Vector3, tint: Color, size: float) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = IMPACT
	sprite.hframes = 4
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.pixel_size = size / 32.0
	sprite.modulate = tint
	add_child(sprite)
	sprite.global_position = at
	if glow:
		var halo := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * size * 1.8
		halo.mesh = quad
		halo.basis = camera.global_basis
		var material := ShaderMaterial.new()
		material.shader = AdventureLightRig.GLOW
		material.set_shader_parameter(&"tint", tint)
		material.set_shader_parameter(&"intensity", _rig.intensity * 0.82)
		material.set_shader_parameter(&"threshold", _rig.threshold)
		material.set_shader_parameter(&"falloff", _rig.falloff)
		halo.material_override = material
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.add_child(halo)
		halo.position = camera.global_basis.z * 0.06
	var animation := create_tween()
	animation.tween_property(sprite, "frame", 3, 0.16)
	animation.tween_callback(sprite.queue_free)
