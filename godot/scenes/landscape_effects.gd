extends Node2D

const GRASS_ROOTS = [
	Vector2(767, 586), Vector2(842, 590), Vector2(895, 583), Vector2(933, 573),
	Vector2(1762, 591), Vector2(1826, 586), Vector2(1880, 590), Vector2(1942, 579),
	Vector2(210, 793), Vector2(251, 819), Vector2(1893, 820), Vector2(2399, 795)
]
const OCHRE = Color("#eac272")
const MINT = Color("#b1fbf0")
const LEAF_COLORS = [Color("#eac086"), Color("#d78b54"), Color("#9e7041"), Color("#8a9e62")]

var guide := Vector2.ZERO
var altar := Vector2.ZERO
var shard_points: Array[Vector2] = []
var recovered: Array[bool] = []
var stage := 0
var elapsed := 0.0
var footprint := Vector2.ZERO
var footprint_time := -10.0
var traveler := Vector2.ZERO
var moving := false
var facing := 1.0
var dust: Array[Vector3] = []
var last_dust_at := 0.0

func _process(_delta: float) -> void:
	if moving and elapsed - last_dust_at > 0.12:
		dust.append(Vector3(traveler.x - facing * 17.0, traveler.y, elapsed))
		last_dust_at = elapsed
	while not dust.is_empty() and elapsed - dust.front().z > 0.44:
		dust.pop_front()

func _draw() -> void:
	_draw_birds()
	_draw_wind()
	_draw_dust()
	_draw_target()
	if stage == 0:
		_draw_waypoint(guide - Vector2(0, 122), OCHRE)
		var label := "Người giữ đền"
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var position := guide - Vector2(width * 0.5, 141)
		draw_string_outline(font, position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("#302634"))
		draw_string(font, position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, OCHRE)
	elif stage == 1:
		for i in shard_points.size():
			if not recovered[i]:
				_draw_crystal(shard_points[i], i)
	elif stage == 2:
		_draw_waypoint(altar - Vector2(0, 78), OCHRE)
	elif stage == 3:
		_draw_shrine()

func _draw_birds() -> void:
	for i in 4:
		var x := 1410.0 - fposmod(elapsed * 41.0 + i * 60.0, 1010.0)
		var y := 144.0 + i * 19.0 + sin(elapsed * 1.22 + i) * 10.0
		var flap := sin(elapsed * (7.5 + i * 0.4) + i) * 5.5
		var p := Vector2(x, y)
		var points := PackedVector2Array([p + Vector2(-10, flap), p + Vector2(-4, -3),
			p + Vector2(0, 1), p + Vector2(4, -3), p + Vector2(10, flap)])
		draw_polyline(points, Color("#253c53d4"), 2.3, true)

func _draw_wind() -> void:
	for i in GRASS_ROOTS.size():
		var root: Vector2 = GRASS_ROOTS[i]
		for j in 5:
			var foot := root + Vector2(j * 4.0, sin(i + j) * 3.0)
			var lean := sin(elapsed * 2.1 - root.x * 0.015 + j * 0.42) * 5.5
			var height := 16.0 + fposmod((i + j) * 4.7, 20.0)
			var points := PackedVector2Array([foot, foot + Vector2(lean * 0.38, -height * 0.5),
				foot + Vector2(lean + (j - 2) * 5.0, -height)])
			draw_polyline(points, Color("#7a933a9e") if j % 2 == 0 else Color("#d8b45f84"), 1.7, true)

	for i in 48:
		var cycle := 9.0 + fposmod(i * 1.89, 10.0)
		var age := fposmod(elapsed + i * 2.17, cycle)
		var x := fposmod(i * 87.19, 2550.0) + age * (21.0 + fposmod(i * 3.9, 18.0))
		var y := 95.0 + fposmod(i * 39.1, 237.0) + age * 20.0 + sin(age * 2.4 + i) * 17.0
		var point := Vector2(roundf(x), roundf(y))
		var width := 1.0 + absf(sin(age * 3.7 + i)) * 5.0
		var fade := smoothstep(0.0, 1.2, age) * (1.0 - smoothstep(cycle - 2.0, cycle, age))
		var paint: Color = LEAF_COLORS[i % LEAF_COLORS.size()]
		paint.a = fade * 0.78
		draw_rect(Rect2(point, Vector2(width, 2.0)), paint)
		draw_rect(Rect2(point + Vector2(width * 0.32, -1), Vector2(2.6, 2.0)), paint)

func _draw_dust() -> void:
	for particle in dust:
		var age := elapsed - particle.z
		var p := Vector2(particle.x + age * 28.0, particle.y - age * 25.0)
		var alpha := maxf(0.0, 0.41 - age) * 0.76
		draw_circle(p, 2.4 + age * 7.0, Color(0.96, 0.80, 0.58, alpha))
		draw_circle(p + Vector2(-9, -1), 1.6 + age * 5.0, Color(0.97, 0.83, 0.62, alpha * 0.66))

func _draw_target() -> void:
	var age := elapsed - footprint_time
	if age > 0.70:
		return
	draw_set_transform(footprint, 0.0, Vector2(1.0, 0.29))
	draw_arc(Vector2.ZERO, 10.0 + age * 25.0, 0.0, TAU, 20,
		Color(0.97, 0.93, 0.67, 0.88 - age), 1.8, true)
	draw_set_transform(Vector2.ZERO)

func _draw_crystal(base: Vector2, index: int) -> void:
	var core := base - Vector2(0, 42.0 + sin(elapsed * 2.7 + index) * 6.1)
	for i in 4:
		draw_circle(core, 11.0 + i * 5.7, Color(0.34, 0.90, 0.85, 0.054), true, -1.0, true)
	_draw_diamond(core, 14.0, MINT)
	_draw_diamond(core + Vector2(1, -2), 8.0, Color("#459eaf"))
	draw_circle(core - Vector2(3, 6), 2.7, Color("#e7ffec"), true, -1.0, true)

func _draw_waypoint(point: Vector2, color: Color) -> void:
	var core := point - Vector2(0, sin(elapsed * 3.3) * 5.0)
	draw_circle(core, 19.0, Color(0.23, 0.14, 0.13, 0.68), true, -1.0, true)
	_draw_diamond(core, 11.0, color)

func _draw_diamond(point: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([point - Vector2(0, radius), point + Vector2(radius * 0.65, 0),
		point + Vector2(0, radius), point - Vector2(radius * 0.65, 0)])
	draw_colored_polygon(points, color)

func _draw_shrine() -> void:
	var center := Vector2(2220, 355)
	for i in 21:
		var age := fposmod(elapsed * 40.0 + i * 25.0, 165.0) / 165.0
		var p := center + Vector2(sin(elapsed * 0.77 + i) * (19.0 + age * 49.0), -age * 143.0)
		var alpha := (1.0 - age) * smoothstep(0.0, 0.18, age)
		draw_circle(p, 1.3 + alpha * 2.0, Color(1.0, 0.83, 0.42, alpha), true, -1.0, true)
