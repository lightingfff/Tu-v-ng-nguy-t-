class_name AdventureLightRig
extends Node3D

const GLOW = preload("res://fantasy/lighting/local_glow.gdshader")
const SUNRAY = preload("res://fantasy/lighting/sunray.gdshader")

@export var glow_enabled := true
@export var sunray_enabled := true
@export_range(0.0, 1.0) var intensity := 0.33
@export_range(0.0, 1.0) var threshold := 0.48
@export var tint := Color("#ffbc65")
@export_range(0.5, 5.0) var falloff := 2.1
@export_range(0.0, 0.6) var ray_intensity := 0.15
@export var ray_tint := Color("#ffdfaa")
@export_range(12.0, 80.0) var ray_angle := 45.0
@export_range(0.3, 5.0) var width := 2.15
@export_range(1.0, 14.0) var length := 6.5
@export_range(0.0, 2.5) var drift_speed := 0.26

var _halos: Array[MeshInstance3D] = []
var _rays: Array[MeshInstance3D] = []
var _apertures: Array[Vector3] = []
var _spill: SpotLight3D
var _camera_forward := Vector3(0.07, 0.61, 0.79).normalized()

func _ready() -> void:
	for marker in $Emitters.get_children():
		var halo := _quad(GLOW, Vector2.ONE * float(marker.get_meta("size", 1.55)))
		halo.position = marker.position + _camera_forward * 0.12
		halo.basis = Basis.looking_at(-_camera_forward)
		halo.material_override.set_shader_parameter(&"source_energy", float(marker.get_meta("energy", 0.88)))
		_halos.append(halo)
	for marker in $Apertures.get_children():
		_apertures.append(marker.position)
		_rays.append(_quad(SUNRAY, Vector2.ONE))
	_spill = SpotLight3D.new()
	_spill.spot_angle = 27.0
	_spill.spot_attenuation = 0.8
	add_child(_spill)
	apply_settings()

func _quad(shader: Shader, size: Vector2) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var plate := QuadMesh.new()
	plate.size = size
	var material := ShaderMaterial.new()
	material.shader = shader
	node.mesh = plate
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func apply_settings() -> void:
	for halo in _halos:
		halo.visible = glow_enabled
		var material := halo.material_override as ShaderMaterial
		material.set_shader_parameter(&"intensity", intensity)
		material.set_shader_parameter(&"threshold", threshold)
		material.set_shader_parameter(&"tint", tint)
		material.set_shader_parameter(&"falloff", falloff)
	for i in _rays.size():
		var ray := _rays[i]
		ray.visible = sunray_enabled
		var angle := deg_to_rad(ray_angle)
		var direction := Vector3(cos(angle), -sin(angle), 0.34).normalized()
		var y := -direction
		var x := direction.cross(_camera_forward).normalized()
		var effective := minf(length, (_apertures[i].y - 0.36) / -direction.y)
		ray.basis = Basis(x, y, x.cross(y))
		ray.position = _apertures[i] + direction * effective * 0.5
		if i == 0:
			_spill.position = _apertures[0] + direction * .18
			_spill.look_at(_spill.global_position + global_basis * direction)
			_spill.light_color = ray_tint
			_spill.light_energy = ray_intensity * 8.0
			_spill.spot_range = effective + 2.2
			_spill.visible = sunray_enabled and ray_intensity > 0.0
		ray.mesh.size = Vector2(width * (1.0 - i * 0.22), effective)
		var material := ray.material_override as ShaderMaterial
		material.set_shader_parameter(&"intensity", ray_intensity * (1.0 - i * 0.21))
		material.set_shader_parameter(&"tint", ray_tint)
		material.set_shader_parameter(&"falloff", falloff * 0.69)
		material.set_shader_parameter(&"drift_speed", drift_speed)
