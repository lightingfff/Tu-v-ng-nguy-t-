extends Node2D

const PETAL_COLORS = [
	Color("#e89bbb"), Color("#dc7eac"), Color("#f1aec8"), Color("#b670a8")
]
const GRASS_COLORS = [Color("#3c625b"), Color("#60775e"), Color("#5c735c")]
const GRASS_ROOTS = [
	Vector2(271, 946), Vector2(316, 969), Vector2(348, 988),
	Vector2(349, 599), Vector2(366, 608), Vector2(396, 579),
	Vector2(943, 942), Vector2(1011, 981), Vector2(1253, 914),
	Vector2(1362, 791), Vector2(1452, 753)
]
const BUTTERFLY_PERCHES = [Vector2(456, 528), Vector2(522, 494), Vector2(1018, 502)]

var elapsed := 0.0

func _draw() -> void:
	_draw_birds()
	_draw_grasses()
	_draw_butterflies()
	_draw_petals()

func _draw_birds() -> void:
	for bird in range(4):
		var x := 940.0 - fposmod(elapsed * 19.0 + 41.0 * bird, 670.0)
		var y := 118.0 + sin(elapsed * 0.67 + bird) * 16.0 + bird * 8.0
		var wings := 2.1 * sin(elapsed * (7.9 + 0.2 * bird) + bird)
		var shape := PackedVector2Array([
			Vector2(x - 6, y - wings), Vector2(x - 2, y - 1),
			Vector2(x, y + 1), Vector2(x + 2, y - 1), Vector2(x + 6, y - wings)
		])
		draw_polyline(shape, Color("#101a37"), 1.4, true)

func _draw_grasses() -> void:
	for index in GRASS_ROOTS.size():
		var root: Vector2 = GRASS_ROOTS[index]
		for blade in range(5):
			var local_root := root + Vector2(4.4 * blade, sin(index + blade) * 4.0)
			var height := 7.0 + fposmod(5.1 * (index + blade), 9.0)
			var flex := sin(elapsed * 1.83 - root.x * 0.014 + blade * 0.32) * 3.2
			var lean := (blade - 2) * 2.5 + flex
			var middle := local_root + Vector2(lean * 0.35, -height * 0.5)
			var tip := local_root + Vector2(lean, -height)
			draw_polyline(
				PackedVector2Array([local_root, middle, tip]),
				GRASS_COLORS[(index + blade) % GRASS_COLORS.size()], 1.45, true
			)

func _draw_butterflies() -> void:
	for index in BUTTERFLY_PERCHES.size():
		var perch: Vector2 = BUTTERFLY_PERCHES[index]
		var phase := elapsed + index * 1.68
		var x := perch.x + sin(phase * 1.2) * 39.0 + sin(phase * 3.4) * 5.0
		var y := perch.y + cos(phase * 1.71) * 19.0 + sin(phase * 3.7) * 3.0
		var beat := 1.5 + absf(sin(phase * 14.0)) * 3.3
		var point := Vector2(round(x), round(y))
		draw_rect(Rect2(point + Vector2(-beat, -4), Vector2(beat, 5)), Color("#e3ab8b"))
		draw_rect(Rect2(point + Vector2(1, -3), Vector2(beat, 4)), Color("#f2ccab"))
		draw_rect(Rect2(point + Vector2(-1, 0), Vector2(2, 3)), Color("#48374f"))

func _draw_petals() -> void:
	for index in range(42):
		var lifespan := 9.0 + fposmod(index * 1.61, 10.0)
		var age := fposmod(elapsed + 1.79 * index, lifespan)
		var origin := Vector2(16.0 + fposmod(index * 71.31, 260.0), fposmod(index * 117.21, 580.0))
		var drift := Vector2(
			age * (24.0 + fposmod(index * 11.17, 31.0)) + sin(age + index) * 15.0,
			age * (18.0 + fposmod(index * 19.31, 13.0)) + cos(age * 1.4 + index) * 10.0
		)
		var opacity := smoothstep(0.0, 1.0, age) * (1.0 - smoothstep(lifespan - 2.0, lifespan, age))
		var width := 2.0 + absf(sin(age * (1.7 + fposmod(index, 4.0) * 0.32))) * 3.0
		var paint: Color = PETAL_COLORS[index % PETAL_COLORS.size()]
		paint.a = opacity * (0.48 + fposmod(index * 0.53, 0.40))
		var point := (origin + drift).round()
		draw_rect(Rect2(point, Vector2(round(width), 2.0)), paint)
		draw_rect(Rect2(point + Vector2(1, -1), Vector2(2, 2)), paint)
