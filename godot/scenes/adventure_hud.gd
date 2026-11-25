extends Control

signal action_requested

var objective: Label
var inventory: Label
var notice: Label
var action_button: Button
var banner_timer: Timer
var hint: Label

func _ready() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 26.0
	top.offset_right = -26.0
	top.offset_top = 22.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var brand := VBoxContainer.new()
	top.add_child(brand)
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_theme_constant_override("separation", 1)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_child(_label("TINH VỰC · VỌNG NGUYỆT", 15, Color("#ffe4b3")))
	brand.add_child(_label("Bờ Sông Nguyệt", 32, Color("#fff0d8")))

	var quest := PanelContainer.new()
	top.add_child(quest)
	quest.add_theme_stylebox_override("panel", _box(Color("#111c31ed"), Color("#9a7d53b0"), 9))
	quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var quest_content := VBoxContainer.new()
	quest.add_child(quest_content)
	quest_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_content.add_child(_label("ÁNH SÁNG TRỞ VỀ", 14, Color("#efbd77")))
	objective = _label("", 19, Color("#faf5eb"))
	quest_content.add_child(objective)
	inventory = _label("", 15, Color("#c9edea"))
	quest_content.add_child(inventory)

	hint = _label("A/D · ←/→  hoặc chạm để đi     ·     E  tương tác", 16, Color("#f6ead1"))
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -45.0
	hint.offset_bottom = -16.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if OS.has_feature("mobile"):
		hint.text = "Chạm vào đường để đi"

	notice = _label("", 20, Color("#fff1ce"))
	add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	notice.offset_left = 34.0
	notice.offset_right = -34.0
	notice.offset_top = -159.0
	notice.offset_bottom = -115.0
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.hide()

	action_button = Button.new()
	add_child(action_button)
	action_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_button.offset_left = -152.0
	action_button.offset_right = 152.0
	action_button.offset_top = -109.0
	action_button.offset_bottom = -54.0
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action_button.add_theme_font_size_override("font_size", 21)
	action_button.add_theme_color_override("font_color", Color("#fff0cb"))
	action_button.add_theme_stylebox_override("normal", _box(Color("#23263bea"), Color("#e9bd7b"), 10))
	action_button.add_theme_stylebox_override("hover", _box(Color("#3c3a4cf4"), Color("#fce0a5"), 10))
	action_button.add_theme_stylebox_override("pressed", _box(Color("#6f4d3ef9"), Color("#fce0a5"), 10))
	action_button.pressed.connect(func() -> void: action_requested.emit())
	action_button.hide()

	banner_timer = Timer.new()
	add_child(banner_timer)
	banner_timer.one_shot = true
	banner_timer.timeout.connect(notice.hide)

func update_quest(details: String, collected: int, completed: bool) -> void:
	objective.text = details
	inventory.text = "Hoàn thành · +100 KN" if completed else "Nguyệt thạch  %d / 3" % collected

func set_action(details: String) -> void:
	action_button.visible = not details.is_empty()
	if action_button.visible:
		action_button.text = details if OS.has_feature("mobile") else "E   " + details

func announce(details: String) -> void:
	notice.text = details
	notice.show()
	banner_timer.start(4.3)

func _label(copy: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = copy
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("#151626"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _box(fill: Color, edge: Color, corner: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(corner)
	style.content_margin_left = 17
	style.content_margin_right = 17
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color("#0b142777")
	style.shadow_size = 8
	return style
