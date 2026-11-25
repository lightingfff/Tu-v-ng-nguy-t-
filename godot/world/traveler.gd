extends CharacterBody3D

const STAND = preload("res://assets/lu-khach.webp")
const RUN = preload("res://assets/lu-khach-run.webp")
const WALK_SPEED := 6.5

@onready var portrait: Sprite3D = $Portrait
var steering := Vector3.ZERO
var foot_distance := 0.0

func _physics_process(delta: float) -> void:
	var old := global_position
	var wanted := steering * WALK_SPEED
	var acceleration := 36.0 if steering.length_squared() > 0.01 else 47.0
	velocity.x = move_toward(velocity.x, wanted.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, wanted.z, acceleration * delta)
	velocity.y = -0.6 if is_on_floor() else maxf(-19.0, velocity.y - 24.0 * delta)
	move_and_slide()
	_update_pose(old.distance_to(global_position), delta)

func _update_pose(travel: float, delta: float) -> void:
	var moving := travel > delta * 0.46 and Vector2(velocity.x, velocity.z).length_squared() > 0.15
	if moving:
		foot_distance = fposmod(foot_distance + travel, 2.85)
		if portrait.texture != RUN:
			portrait.texture = RUN
			portrait.hframes = 6
		portrait.frame = floori(foot_distance / 2.85 * 6.0)
		if absf(velocity.x) > 0.25:
			portrait.flip_h = velocity.x < 0.0
	else:
		portrait.frame = 0
		portrait.hframes = 1
		portrait.texture = STAND
		foot_distance = 0.0
