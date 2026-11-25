class_name PartyController
extends Node3D

signal feedback(message: String)
signal armor_broken(role: int)
signal all_down

const GUARDED := 2
var members: Array[CombatActor] = []
var index := 0
var assist_cooldown := 0.0
var assist: CombatActor
var _assist_target: CombatActor
var _assist_timer := 0.0
var _assist_started := false
var active: CombatActor:
	get:
		return members[index]

func add_member(actor: CombatActor) -> void:
	var role := members.size()
	add_child(actor)
	members.append(actor)
	actor.set_vulnerable(role == index)
	actor.defeated.connect(_on_defeat.bind(role))
	actor.struck.connect(_on_strike.bind(role))

func place(at: Vector3) -> void:
	for i in members.size():
		var actor := members[i]
		actor.global_position = at + (Vector3(-1.3 * (i + 1), 0, 0.75) if i != index else Vector3.ZERO)
		actor.velocity = Vector3.ZERO
		actor.steering = Vector3.ZERO

func swap_to(role: int) -> bool:
	if role < 0 or role >= members.size() or role == index:
		return false
	var next := members[role]
	if not active.can_swap() or next == assist or next.state == CombatActor.State.DOWN:
		feedback.emit("Đổi vai khi đã qua nhịp ra đòn hoặc né.")
		return false
	_swap(role)
	return true

func _swap(role: int) -> void:
	var old := active
	var next := members[role]
	var foot := old.global_position
	var direction := old.facing
	old.set_vulnerable(false)
	old.cancel_recovery()
	old.global_position = next.global_position
	old.steering = Vector3.ZERO
	old.velocity = Vector3.ZERO
	index = role
	next.global_position = foot
	next.facing = direction
	next.velocity = Vector3.ZERO
	next.set_vulnerable(true)

func request_assist(target: CombatActor) -> bool:
	if target == null or target.state == CombatActor.State.DOWN or assist_cooldown > 0.0 or assist:
		return false
	var chosen := GUARDED if index != GUARDED else 1
	var helper := members[chosen]
	if helper.state != CombatActor.State.READY or active.global_position.distance_to(target.global_position) > 7.0:
		feedback.emit("Tiến gần quái để gọi hỗ trợ.")
		return false
	assist = helper
	_assist_target = target
	_assist_timer = 1.7
	_assist_started = false
	assist_cooldown = 3.4
	feedback.emit("%s vào hỗ trợ!" % helper.data.title)
	return true

func update_party(delta: float, fighting: bool) -> void:
	assist_cooldown = maxf(0.0, assist_cooldown - delta)
	if assist:
		_update_assist(delta)
	for i in members.size():
		var actor := members[i]
		if i == index or actor == assist or actor.state == CombatActor.State.DOWN:
			continue
		var sign_z := -1.0 if i % 2 == 0 else 1.0
		var retreat := 2.6 if fighting else 1.65
		var offset := -active.facing * retreat + Vector3(0, 0, sign_z * 0.9)
		var toward := active.global_position + offset - actor.global_position
		toward.y = 0
		actor.steering = toward.limit_length() if toward.length_squared() > 0.16 else Vector3.ZERO

func _update_assist(delta: float) -> void:
	_assist_timer -= delta
	if _assist_started:
		if assist.state == CombatActor.State.READY:
			assist = null
		return
	if _assist_timer <= 0.0 or _assist_target.state == CombatActor.State.DOWN:
		assist.steering = Vector3.ZERO
		assist = null
		return
	var direction := _assist_target.global_position - assist.global_position
	direction.y = 0.0
	var reach := 1.85 if assist.data.projectile_speed == 0 else 4.0
	if direction.length() > reach:
		assist.steering = direction.normalized()
	else:
		assist.steering = Vector3.ZERO
		_assist_started = assist.begin_attack(direction, true)

func _on_strike(_target: CombatActor, broken: bool, role: int) -> void:
	if broken:
		armor_broken.emit(role)

func _on_defeat(role: int) -> void:
	if role != index:
		return
	for i in members.size():
		if members[i].state == CombatActor.State.READY or members[i].state == CombatActor.State.RECOVERY:
			if members[i] == assist:
				assist = null
			_swap(i)
			return
	all_down.emit()

func reset_at(at: Vector3) -> void:
	assist = null
	assist_cooldown = 0.0
	index = 0
	for i in members.size():
		members[i].reset_actor()
		members[i].set_vulnerable(i == index)
	place(at)
