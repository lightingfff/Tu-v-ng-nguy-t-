class_name CombatActor
extends CharacterBody3D

signal struck(target: CombatActor, armor_broken: bool)
signal defeated
signal cast_effect(location: Vector3, tint: Color, scale_hint: float)

enum State { READY, WINDUP, ACTIVE, RECOVERY, DODGE, HURT, DOWN }
const PLAYER_HURT := 4
const ENEMY_HURT := 8

var data: AdventurerData
var opponent := false
var state := State.READY
var hp := 0
var armor := 0
var steering := Vector3.ZERO
var facing := Vector3.RIGHT
var vulnerable := false
var _invulnerable := false
var _clock := 0.0
var _stride := 0.0
var _hit := {}
var _assist_strike := false
var _distance := 0.0
var _attack_origin := Vector3.ZERO
var _hurtbox: Area3D
var _hitbox: Area3D
var _shape: CollisionShape3D
var _portrait: Sprite3D
var _animation: AnimationPlayer
var _mark: MeshInstance3D

func _ready() -> void:
	hp = data.health
	armor = data.armor
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.46
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.32
	add_child(_collider(capsule, Vector3.UP * 0.68))

	_hurtbox = Area3D.new()
	_hurtbox.collision_layer = ENEMY_HURT if opponent else PLAYER_HURT
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	add_child(_hurtbox)
	_hurtbox.add_child(_collider(capsule, Vector3.UP * 0.68))

	_hitbox = Area3D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = PLAYER_HURT if opponent else ENEMY_HURT
	_hitbox.monitoring = false
	_hitbox.monitorable = false
	add_child(_hitbox)
	_hitbox.top_level = true
	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.39 if data.projectile_speed > 0 else 0.88
	_shape.shape = sphere
	_hitbox.add_child(_shape)

	_portrait = Sprite3D.new()
	_portrait.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_portrait.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_portrait.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_portrait.centered = false
	_portrait.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_portrait)
	_set_pose(false)

	var shadow := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.43 if opponent else 0.30
	disk.bottom_radius = disk.top_radius
	disk.height = 0.012
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0.055, 0.07, 0.12, 0.60)
	disk.material = shadow_mat
	shadow.mesh = disk
	shadow.position.y = 0.026
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

	_mark = MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.17
	orb.height = 0.34
	orb.radial_segments = 8
	orb.rings = 4
	var orb_mat := StandardMaterial3D.new()
	orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb_mat.albedo_color = data.tint
	orb.material = orb_mat
	_mark.mesh = orb
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hitbox.add_child(_mark)
	_mark.hide()
	_setup_attack_track()

func _collider(shape: Shape3D, at: Vector3) -> CollisionShape3D:
	var body := CollisionShape3D.new()
	body.shape = shape
	body.position = at
	return body

func _setup_attack_track() -> void:
	_animation = AnimationPlayer.new()
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animation.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	add_child(_animation)
	var clip := Animation.new()
	clip.length = data.windup + data.active_time + data.recovery
	var track := clip.add_track(Animation.TYPE_METHOD)
	clip.track_set_path(track, NodePath("."))
	clip.track_insert_key(track, data.windup, {"method": &"_open_attack", "args": []})
	clip.track_insert_key(track, data.windup + data.active_time, {"method": &"_close_attack", "args": []})
	clip.track_insert_key(track, clip.length - 0.001, {"method": &"_finish_attack", "args": []})
	var library := AnimationLibrary.new()
	library.add_animation(&"strike", clip)
	var evasion := Animation.new()
	evasion.length = 0.23
	var window := evasion.add_track(Animation.TYPE_METHOD)
	evasion.track_set_path(window, NodePath("."))
	evasion.track_insert_key(window, 0.0, {"method": &"_open_dodge", "args": []})
	evasion.track_insert_key(window, 0.229, {"method": &"_close_dodge", "args": []})
	library.add_animation(&"evade", evasion)
	_animation.add_animation_library(&"", library)

func set_vulnerable(value: bool) -> void:
	vulnerable = value
	_sync_hurtbox()

func _sync_hurtbox() -> void:
	_hurtbox.set_deferred("monitorable", is_damageable())

func can_swap() -> bool:
	return state == State.READY or state == State.RECOVERY

func begin_attack(direction: Vector3, assist := false) -> bool:
	if state != State.READY:
		return false
	_face(direction)
	_assist_strike = assist
	_hit.clear()
	_distance = 0
	state = State.WINDUP
	_animation.play(&"strike")
	_animation.advance(0.0)
	return true

func _open_attack() -> void:
	state = State.ACTIVE
	_hitbox.set_deferred("monitoring", true)
	_attack_origin = global_position + Vector3.UP * 0.82
	_hitbox.global_position = _attack_origin + facing * (0.52 if data.projectile_speed > 0 else data.reach * 0.57)
	_mark.visible = data.projectile_speed > 0

func _close_attack() -> void:
	state = State.RECOVERY
	_hitbox.set_deferred("monitoring", false)
	_mark.hide()

func _finish_attack() -> void:
	state = State.READY

func cancel_recovery() -> void:
	if can_swap():
		_animation.stop()
		state = State.READY

func dodge(direction: Vector3) -> bool:
	if not can_swap():
		return false
	cancel_recovery()
	_face(direction)
	state = State.DODGE
	_open_dodge()
	_animation.play(&"evade")
	_animation.advance(0.0)
	return true

func _open_dodge() -> void:
	_invulnerable = true
	_sync_hurtbox()

func _close_dodge() -> void:
	_invulnerable = false
	state = State.READY
	_sync_hurtbox()

func _face(direction: Vector3) -> void:
	direction.y = 0
	if direction.length_squared() > 0.01:
		facing = direction.normalized()

func reset_actor() -> void:
	_stop_action()
	_invulnerable = false
	hp = data.health
	armor = data.armor
	state = State.READY
	velocity = Vector3.ZERO
	steering = Vector3.ZERO
	_portrait.show()

func _physics_process(delta: float) -> void:
	if state == State.DOWN:
		return
	var before := global_position
	var motion := Vector3.ZERO
	match state:
		State.READY:
			motion = steering.limit_length() * data.speed
			_face(steering)
		State.DODGE:
			motion = facing * 12.3
		State.HURT:
			motion = -facing * 2.5
		State.ACTIVE:
			if data.projectile_speed == 0 and not opponent:
				motion = facing * (6.0 if _assist_strike else 2.0)
	velocity.x = motion.x
	velocity.z = motion.z
	velocity.y = -0.55 if is_on_floor() else maxf(-18.0, velocity.y - 24.0 * delta)
	move_and_slide()
	if _animation.is_playing():
		_animation.advance(delta)
	if state == State.ACTIVE:
		_scan_strike(delta)
	if state == State.HURT:
		_clock -= delta
		if _clock <= 0.0:
			state = State.READY
	_update_pose(before.distance_to(global_position), delta)

func _scan_strike(delta: float) -> void:
	if data.projectile_speed > 0:
		_distance += data.projectile_speed * delta
		var point := _attack_origin + facing * (_distance + 0.52)
		if _blocked(_hitbox.global_position, point):
			_close_attack()
			return
		_hitbox.global_position = point
	else:
		_hitbox.global_position = global_position + facing * data.reach * 0.57 + Vector3.UP * 0.82
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape.shape
	query.transform = _hitbox.global_transform
	query.collision_mask = _hitbox.collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_3d().direct_space_state.intersect_shape(query):
		var target := (hit.collider as Area3D).get_parent() as CombatActor
		if target == null or _hit.has(target.get_instance_id()) or not target.is_damageable():
			continue
		if _blocked(global_position + Vector3.UP * 0.82, target.global_position + Vector3.UP * 0.8):
			continue
		_hit[target.get_instance_id()] = true
		if target.take_hit(data.damage, data.armor_damage):
			struck.emit(target, true)
		else:
			struck.emit(target, false)
		cast_effect.emit(target.global_position + Vector3.UP, data.tint, 0.85)
		if data.projectile_speed > 0:
			_close_attack()
			break

func _blocked(from: Vector3, to: Vector3) -> bool:
	var check := PhysicsRayQueryParameters3D.create(from, to, 1)
	return not get_world_3d().direct_space_state.intersect_ray(check).is_empty()

func is_damageable() -> bool:
	return vulnerable and not _invulnerable and state != State.DOWN

func take_hit(damage: int, armor_damage: int) -> bool:
	if not is_damageable():
		return false
	var previous_armor := armor
	armor = maxi(armor - armor_damage, 0)
	hp = maxi(hp - (maxi(1, floori(damage * 0.2)) if armor > 0 else damage), 0)
	var broken := previous_armor > 0 and armor == 0
	if hp == 0:
		_stop_action()
		state = State.DOWN
		set_vulnerable(false)
		_portrait.hide()
		defeated.emit()
	elif armor == 0:
		_stop_action()
		state = State.HURT
		_clock = 0.42 if broken else 0.16
	return broken

func _stop_action() -> void:
	_animation.stop()
	_hitbox.set_deferred("monitoring", false)
	_mark.hide()

func _update_pose(travel: float, delta: float) -> void:
	var running := state == State.READY and steering.length_squared() > 0.02 and travel > delta * 0.6
	_set_pose(running)
	if running:
		_stride = fposmod(_stride + travel, 2.8)
		_portrait.frame = floori(_stride / 2.8 * _portrait.hframes)
	_portrait.flip_h = facing.x < -0.06
	var step_bias := sin(_stride / 2.8 * TAU) if running and data.run_atlas == null else 0.0
	_portrait.scale = Vector3(1.08, 0.91, 1.0) if state == State.HURT else Vector3(1.0, 1.0 + .018 * step_bias, 1.0)
	var lean := 0.028 * step_bias
	if state == State.WINDUP:
		lean = 0.14
	elif state == State.ACTIVE and data.projectile_speed == 0:
		lean = -0.18
	_portrait.rotation.z = lean * signf(facing.x)

func _set_pose(running: bool) -> void:
	var sheet := data.run_atlas if running and data.run_atlas else data.portrait
	if _portrait.texture == sheet:
		return
	_portrait.frame = 0
	_portrait.hframes = 1
	_portrait.texture = sheet
	_portrait.hframes = 6 if sheet == data.run_atlas else 1
	_portrait.pixel_size = data.height / float(sheet.get_height())
	_portrait.offset.x = -sheet.get_width() / float(_portrait.hframes) * 0.5
