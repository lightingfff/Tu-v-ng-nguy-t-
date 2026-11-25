extends Node2D

const CELL = 3.0
const TRAVELER = preload("res://assets/lu-khach.webp")
const TRAVELER_SCALE = 0.79
const RUN_CYCLE = preload("res://assets/lu-khach-run.webp")
const FRAME_SIZE = Vector2(96, 152)
const PALETTE = {
	"x": Color("#192033"), "o": Color("#272942"), "n": Color("#303c59"),
	"h": Color("#536887"), "k": Color("#ab736e"), "f": Color("#efd2ad"),
	"l": Color("#fff2ce"), "c": Color("#b3c5c7"), "w": Color("#e3e6d3"),
	"t": Color("#577082"), "r": Color("#bb5e46"), "p": Color("#ec9b61"),
	"g": Color("#e9bd74"), "m": Color("#efe4a8")
}
const UPPER_PIXELS = [
	"           xxxxx",
	"        xxxooonxx",
	"      xxxonhhhnnxx",
	"    xxoohhnonhnnxx",
	"    xonnoonhhnnnnnx",
	"     xoonnnnnnnnxox",
	"    xononnnnnxnnxx",
	"    xonnnnnnxxnx",
	"     xoonnnxfkx",
	"      xonnnxfklx",
	"       xonnxfloxx",
	"       xonnxkflfx",
	"        xonxkfkkx",
	"         xoxkfxx",
	"       xxxkffxx",
	"      xotxrpx",
	"     xottrxprxx",
	"    xottcxrpcrxx",
	"   xottctrrcwcrx",
	"   xotctctrrwcwx",
	"   xotctctrrwcwxx",
	"   xoctcwtcrgmcwx",
	"   xtctcwccrrwrx",
	"  xotctcccxggrxx",
	"  xogcccccxxxfx",
	"   xtrcccx   xx",
	"    xtrcx",
	"     xxx"
]

@export var is_keeper := false

var torso: ImageTexture
var phase := 0.0
var breath := 0.0
var running := false
var face := 1.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not is_keeper:
		return
	var image := Image.create_empty(22, UPPER_PIXELS.size(), false, Image.FORMAT_RGBA8)
	for y in UPPER_PIXELS.size():
		for x in UPPER_PIXELS[y].length():
			var code: String = UPPER_PIXELS[y][x]
			if PALETTE.has(code):
				var color: Color = PALETTE[code]
				if is_keeper:
					if code == "r" or code == "p":
						color = Color("#5b9d97") if code == "r" else Color("#a8c7a3")
					elif code == "t":
						color = Color("#6c736c")
					elif code == "n":
						color = Color("#785e57")
				image.set_pixel(x, y, color)
	torso = ImageTexture.create_from_image(image)
	scale = Vector2.ONE * 0.96

func set_motion(point: Vector2, direction: float, moving: bool, delta: float) -> void:
	breath += delta
	position = point
	face = direction
	running = moving
	if running:
		phase = fposmod(phase + delta * 12.4, TAU)
	else:
		phase = 0.0
	queue_redraw()

func _draw() -> void:
	_draw_shadow()
	if not is_keeper:
		_draw_traveler()
		return
	if torso == null:
		return
	var bounce := roundf(absf(sin(phase)) * 4.0) if running else 0.0
	draw_set_transform(Vector2(0, -bounce), 0.0, Vector2(face, 1.0))
	_draw_leg(phase + PI, Color("#2b314b"), Color("#242839"))
	_draw_leg(phase, Color("#53637a"), Color("#322d3e"))

	var hem_pull := roundf((1.0 + sin(phase * 2.1)) * 4.0) if running else 0.0
	var coat := PackedVector2Array([Vector2(-21, -47), Vector2(-9, -35),
		Vector2(-23 - hem_pull, -20), Vector2(-29 - hem_pull, -29)])
	draw_colored_polygon(coat, Color("#293950"))
	draw_texture_rect(torso, Rect2(Vector2(-30, -torso.get_height() * CELL - 16),
		Vector2(torso.get_size()) * CELL), false)
	draw_set_transform(Vector2.ZERO)
	if is_keeper:
		var staff := Color("#594344")
		draw_rect(Rect2(-27, -83, 4, 83), staff)
		draw_rect(Rect2(-25, -83, 2, 68), Color("#a78762"))
		draw_rect(Rect2(-30, -86, 9, 9), Color("#e2b96d"))

func _draw_traveler() -> void:
	var tex: Texture2D = RUN_CYCLE if running else TRAVELER
	var cell: Vector2 = FRAME_SIZE if running else TRAVELER.get_size()
	var index := floori(phase / TAU * 6.0) if running else 0
	var source := Rect2(Vector2(index * cell.x, 0), cell)
	var size_px := cell * TRAVELER_SCALE
	var inhale := 0.0 if running else 0.8 * sin(breath * 2.1)
	var sprite := Rect2(-size_px.x * 0.5, -size_px.y - inhale, size_px.x, size_px.y + inhale)

	# Project the same animated silhouette away from the low sun, anchored at the boots.
	var cast := Transform2D(Vector2(face * 0.89, 0), Vector2(-0.47, -0.105), Vector2(1, 0))
	draw_set_transform_matrix(cast)
	draw_texture_rect_region(tex, sprite, source, Color(0.14, 0.19, 0.30, 0.29))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1))
	var canopy := maxf(1.0 - smoothstep(300.0, 740.0, position.x), smoothstep(2030.0, 2410.0, position.x))
	var shade := canopy * (0.52 + sin(position.x * 0.026 + breath * 0.62) * 0.28)
	var lit := Color(1.0, 0.985, 0.94).lerp(Color(0.82, 0.88, 0.98), shade)
	draw_texture_rect_region(tex, sprite, source, lit)

func _draw_shadow() -> void:
	draw_set_transform(Vector2(10, 2), 0.05, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 30.0, Color("#11192b28"), true, -1.0, true)
	draw_circle(Vector2(-6, -1), 23.0, Color("#11192b44"), true, -1.0, true)
	draw_circle(Vector2(-10, -1), 15.0, Color("#11182954"), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)

func _draw_leg(angle: float, fabric: Color, boot: Color) -> void:
	var stride := sin(angle) * 17.0 if running else (-6.0 if angle > 1.0 else 7.0)
	var lift := maxf(0.0, cos(angle)) * 13.0 if running else 0.0
	var knee := Vector2(roundf(stride * 0.62), -17 - roundf(lift * 0.5))
	var heel := Vector2(roundf(stride), -5 - roundf(lift))
	draw_line(Vector2(4 if angle > 1.0 else -2, -39), knee, Color("#171d31"), 13.0)
	draw_line(knee, heel, Color("#171d31"), 11.0)
	draw_line(Vector2(4 if angle > 1.0 else -2, -37), knee, fabric, 8.0)
	draw_line(knee, heel, fabric, 6.0)
	draw_rect(Rect2(heel + Vector2(-5, -4), Vector2(13, 9)), boot)
	draw_rect(Rect2(heel + Vector2(-5, 3), Vector2(15, 3)), Color("#191d2d"))
