extends Node2D

const ATLAS_SIZE = Vector2i(26, 30)
const DRAW_SCALE = 3.0
const CLOTH = {
	"x": Color("#151d35"), "n": Color("#222b46"), "h": Color("#303954"),
	"l": Color("#4d617b"), "m": Color("#8397a9"), "p": Color("#a26761"),
	"s": Color("#e1ab87"), "k": Color("#f5ca97"), "c": Color("#234855"),
	"t": Color("#2c6471"), "v": Color("#478e8b"), "a": Color("#82beb1"),
	"d": Color("#594d55"), "g": Color("#be894d"), "b": Color("#eecc85"),
}
const PIXELS = [
	"          xxxxxxx",
	"        xhnnnnnnlx",
	"       xhnnnllhnnlx",
	"      xmhhhnnhlnnnlx",
	"      xlhhnnhlhnnnlx",
	"     xmhhhnnllhnnnnx",
	"     xlhhnnnhhnnxxnx",
	"    xmhhxhxxnnxxppnx",
	"    xlhhspspxxpspsnx",
	"    xlnnssxsxxsxssnx",
	"    xlnxskssssssksnx",
	"     xhnpskksskkpnx",
	"     xhnnpssksspnxx",
	"      xnnnppsppnxx",
	"      xhnnxxppxxx",
	"     xvnxdbggxdtx",
	"     xattbbgggttcvx",
	"    xacttvbbgtcttvvx",
	"   xacccttvbtctttcavx",
	"   xccctttvbgtcctttvx",
	"   xccctttbbgtcttttvx",
	"   xccctvbggbgtctttcx",
	"    xpctxbgbbggxtcpsx",
	"     xxctvbbgtctcxx",
	"     xaccccgtctttcx",
	"    xaccctttcttttcx",
	"    xcccccttcttvtx",
	"    xxxxxxtccccxxx",
	"        xnnxxnnx",
	"        xxdxxdxx",
]
var texture: ImageTexture

func _ready() -> void:
	var pixels := Image.create_empty(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in PIXELS.size():
		for x in PIXELS[y].length():
			var code: String = PIXELS[y][x]
			if CLOTH.has(code):
				pixels.set_pixel(x, y, CLOTH[code])
	# Texture filtering stays nearest through camera moves to preserve the drawn pixels.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = ImageTexture.create_from_image(pixels)

func _draw() -> void:
	draw_set_transform(Vector2(12.0, 12.0), 0.55, Vector2(1.16, 0.25))
	draw_circle(Vector2.ZERO, 27.0, Color(0.035, 0.046, 0.082, 0.11), true, -1.0, true)
	draw_circle(Vector2.ZERO, 19.0, Color(0.027, 0.031, 0.061, 0.15), true, -1.0, true)
	draw_set_transform(Vector2(6.0, -0.4), -0.10, Vector2(1.0, 0.24))
	draw_circle(Vector2.ZERO, 26.0, Color(0.023, 0.037, 0.079, 0.15), true, -1.0, true)
	draw_circle(Vector2.ZERO, 20.0, Color(0.022, 0.030, 0.056, 0.26), true, -1.0, true)
	draw_circle(Vector2.ZERO, 13.0, Color(0.025, 0.028, 0.044, 0.33), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	if texture != null:
		var size_px := Vector2(ATLAS_SIZE) * DRAW_SCALE
		draw_texture_rect(texture, Rect2(Vector2(-size_px.x * 0.46, -size_px.y), size_px), false)
