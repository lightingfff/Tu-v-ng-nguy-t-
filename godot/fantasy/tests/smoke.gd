extends SceneTree

var world: Node3D
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: " + message)
		failed = true

func _ticks(count: int) -> void:
	for i in count:
		await physics_frame

func _key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _press(code: Key) -> void:
	_key(code)
	await _ticks(2)
	_key(code, false)

func _move_to(axis: int, goal: float, max_steps: int = 540) -> void:
	var location: float = world.party.active.global_position[axis]
	var code := KEY_D if goal >= location else KEY_A
	if axis == 2:
		code = KEY_S if goal >= location else KEY_W
	_key(code)
	for i in max_steps:
		await physics_frame
		location = world.party.active.global_position[axis]
		if absf(location - goal) < 0.21:
			break
	_key(code, false)
	await _ticks(4)
	_check(absf(world.party.active.global_position[axis] - goal) < 0.38, "Walkway reachable at %.1f. Actual position: %s" % [goal, world.party.active.global_position])

func _run() -> void:
	world = load("res://fantasy/scenes/adventure_slice.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await _ticks(10)
	_check(world.party.members.size() == 3, "Party has three members")
	var actors: Array[CombatActor] = world.party.members
	for actor in actors:
		_check(actor._portrait.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Nearest on every sprite")
	await _press(KEY_C)
	_check(is_equal_approx(world.camera.size, 15.6), "Wide zoom")
	await _press(KEY_C)
	_check(is_equal_approx(world.camera.size, 11.7), "Close zoom")
	await _press(KEY_B)
	_check(not world.guild_rig._halos[0].visible and world.guild_rig._rays[0].visible, "Glow can be disabled independently")
	await _press(KEY_R)
	_check(not world.guild_rig._rays[0].visible, "Sunray can be disabled independently")
	await _press(KEY_B)
	await _press(KEY_R)
	_check(world.forest_rig._halos[0].visible and world.forest_rig._rays[0].visible, "Both rigs share A/B switches")
	await _press(KEY_F1)
	_check(world.hud.debug.visible and world.hud.debug_rows.get_child_count() == 13, "Debug panel exposes controls")
	await _press(KEY_F1)

	await _press(KEY_E)
	_check(world.quest == world.Quest.OFFERED, "Contract requires proximity")
	await _move_to(0, -21.9)
	await _move_to(2, -1.6)
	await _press(KEY_E)
	_check(world.quest == world.Quest.DEPART, "Contract accepted from the board")
	await _move_to(2, 2.2)
	await _move_to(0, 16.9)
	_check(world.quest == world.Quest.HUNT, "Walked through the unlocked gate to the forest")
	await _press(KEY_E)
	_check(world.quest != world.Quest.COMPLETE, "Chest stays locked while the enemy lives")

	await _move_to(0, 20.0)
	var sword: CombatActor = world.party.active
	var enemy: CombatActor = world.enemy

	# Place both combatants on the open fighting floor to reproduce overlap and timing.
	world.party.place(Vector3(25.6, .05, -1.25))
	enemy.global_position = Vector3(27.44, .05, -1.25)
	world._enemy_wait = 15
	await _ticks(8)
	var original_armor := enemy.armor
	await _press(KEY_J)
	await _press(KEY_2)
	_check(world.party.active == sword, "Swap rejected in windup")
	await _ticks(25)
	_check(enemy.armor == original_armor - sword.data.armor_damage, "One hit across overlapping physics ticks")
	await _ticks(12)
	var original_hp: int = world.party.active.hp
	_check(world.party.active.dodge(Vector3.BACK), "Dodge available from ready")
	world.party.active.take_hit(15, 0)
	_check(world.party.active.hp == original_hp, "Dodge ignores damage")
	await _ticks(16)
	world.party.place(Vector3(25.75, .05, -1.25))
	actors[2].global_position = Vector3(26.0, .05, -.65)
	enemy.global_position = Vector3(27.45, .05, -1.25)
	await _ticks(6)
	await _press(KEY_F)
	_check(world.party.assist != null, "Guardian assist starts")
	_check(not world.party.request_assist(enemy), "Second assist during cooldown rejected")
	await _ticks(31)
	_check(enemy.armor == 0, "Guardian support breaks armor")
	_check(world.party.active == sword, "Assist keeps the controlled actor")
	await _press(KEY_2)
	_check(world.party.index == 1, "Swapped to mage")
	for i in 4:
		if enemy.state == CombatActor.State.DOWN:
			break
		await _press(KEY_J)
		await _ticks(53)
	_check(world.quest == world.Quest.LOOT, "Mage projectile defeated the golem")
	world.party.place(world.chest.global_position + Vector3(0, .05, -1.15))
	await _ticks(5)
	await _press(KEY_E)
	_check(world.quest == world.Quest.COMPLETE, "Side-route chest opens and completes the contract")
	if not failed:
		print("PASS · Glow and Sunray A/B, zoom, gate, attack, dodge, hit dedup, assist, mage, chest")
	quit(1 if failed else 0)
