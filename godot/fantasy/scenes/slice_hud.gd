extends CanvasLayer

var chapter: Label
var objective: Label
var message: Label
var action: Button
var roster: Label
var armor: ProgressBar
var enemy_hp: ProgressBar
var encounter: VBoxContainer
var debug: PanelContainer
var debug_rows: VBoxContainer
var _notice: Timer
var _rig: AdventureLightRig

signal interact
signal visual_toggle(kind: StringName, on: bool)

func _ready() -> void:
	var ui := Control.new()
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var overview := PanelContainer.new()
	overview.custom_minimum_size.x = 324
	overview.position = Vector2(22, 18)
	overview.add_theme_stylebox_override("panel", _panel())
	ui.add_child(overview)
	var info := VBoxContainer.new()
	overview.add_child(info)
	info.add_theme_constant_override("separation", 4)
	info.add_child(_label("VỌNG NGUYỆT", 12, Color("#d4ab76")))
	chapter = _label("", 24, Color("#fbe5c7"))
	info.add_child(chapter)
	objective = _label("", 15, Color("#d9e4ec"))
	info.add_child(objective)

	var status := PanelContainer.new()
	ui.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_top = -77
	status.offset_bottom = -16
	status.offset_left = 22
	status.offset_right = -22
	status.add_theme_stylebox_override("panel", _panel())
	var strip := VBoxContainer.new()
	status.add_child(strip)
	roster = _label("", 16, Color("#f8d6a8"))
	strip.add_child(roster)
	strip.add_child(_label("WASD / ↑↓←→  Đi   ·   J  Đánh   ·   Space  Né   ·   1–3  Đổi vai   ·   F  Hỗ trợ   ·   E  Tương tác   ·   C  Zoom   ·   F1  Ánh sáng", 14, Color("#c3d2df")))

	encounter = VBoxContainer.new()
	ui.add_child(encounter)
	encounter.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	encounter.offset_top = 24
	encounter.offset_left = -130
	encounter.offset_right = 130
	encounter.add_child(_label("Thạch Vệ · Giáp / HP", 15, Color("#f8dfbc")))
	armor = _meter(Color("#69cbbc"))
	enemy_hp = _meter(Color("#d47f68"))
	encounter.add_child(armor)
	encounter.add_child(enemy_hp)
	encounter.hide()

	var prompts := VBoxContainer.new()
	ui.add_child(prompts)
	prompts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompts.offset_left = -273
	prompts.offset_right = 273
	prompts.offset_top = -174
	prompts.offset_bottom = -90
	prompts.alignment = BoxContainer.ALIGNMENT_END
	message = _label("", 17, Color("#fff0c7"))
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompts.add_child(message)
	action = Button.new()
	action.custom_minimum_size.y = 39
	action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action.focus_mode = Control.FOCUS_NONE
	action.pressed.connect(func() -> void: interact.emit())
	prompts.add_child(action)
	action.hide()
	_notice = Timer.new()
	_notice.one_shot = true
	_notice.timeout.connect(func() -> void: message.text = "")
	add_child(_notice)

	debug = PanelContainer.new()
	ui.add_child(debug)
	debug.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	debug.offset_top = 18
	debug.offset_left = -299
	debug.offset_right = -22
	debug.add_theme_stylebox_override("panel", _panel())
	debug_rows = VBoxContainer.new()
	debug.add_child(debug_rows)
	debug.hide()

func _label(copy: String, size: int, tone: Color) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tone)
	label.add_theme_color_override("font_shadow_color", Color("#151824"))
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _panel() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#182535f1")
	panel.border_color = Color("#52637a")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(7)
	panel.content_margin_top = 9
	panel.content_margin_bottom = 9
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	return panel

func _meter(color: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.custom_minimum_size.y = 8
	meter.show_percentage = false
	var strip := StyleBoxFlat.new()
	strip.bg_color = color
	strip.set_corner_radius_all(3)
	meter.add_theme_stylebox_override("fill", strip)
	return meter

func notify(copy: String) -> void:
	message.text = copy
	_notice.start(3.4)

func set_interaction(copy: String) -> void:
	action.visible = not copy.is_empty()
	if action.visible:
		action.text = "  E   " + copy + "  "

func show_debug(rig: AdventureLightRig) -> void:
	if debug.visible:
		debug.hide()
		return
	debug.show()
	inspect_rig(rig)

func inspect_rig(rig: AdventureLightRig) -> void:
	_rig = rig
	if not debug.visible:
		return
	for node in debug_rows.get_children():
		debug_rows.remove_child(node)
		node.queue_free()
	debug_rows.add_child(_label("So sánh ánh sáng", 18, Color("#f5d1a2")))
	_toggle("Glow  [B]", &"glow", rig.glow_enabled)
	_toggle("Sunray  [R]", &"sunray", rig.sunray_enabled)
	_slider("Glow intensity", &"intensity", 0, 1, .01)
	_slider("Glow threshold", &"threshold", 0, 1, .01)
	_color("Glow tint", &"tint")
	_slider("Falloff", &"falloff", .5, 5, .05)
	_slider("Ray intensity", &"ray_intensity", 0, .6, .01)
	_color("Ray tint", &"ray_tint")
	_slider("Ray angle", &"ray_angle", 12, 80, 1)
	_slider("Width", &"width", .3, 5, .05)
	_slider("Length", &"length", 1, 14, .1)
	_slider("Drift speed", &"drift_speed", 0, 2.5, .05)

func _line(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	debug_rows.add_child(row)
	var caption := _label(title, 13, Color("#d6e0e9"))
	caption.custom_minimum_size.x = 97
	row.add_child(caption)
	return row

func _toggle(title: String, kind: StringName, initial: bool) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.button_pressed = initial
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(func(on: bool) -> void: visual_toggle.emit(kind, on))
	debug_rows.add_child(toggle)

func _slider(title: String, property: StringName, minimum: float, maximum: float, step: float) -> void:
	var row := _line(title)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = _rig.get(property)
	slider.custom_minimum_size.x = 96
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var current := _label("%.2f" % slider.value, 12, Color("#f5d1a2"))
	current.custom_minimum_size.x = 40
	row.add_child(current)
	slider.value_changed.connect(func(value: float) -> void:
		current.text = "%.2f" % value
		_rig.set(property, value)
		_rig.apply_settings())

func _color(title: String, property: StringName) -> void:
	var picker := ColorPickerButton.new()
	picker.color = _rig.get(property)
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(64, 18)
	picker.color_changed.connect(func(value: Color) -> void:
		_rig.set(property, value)
		_rig.apply_settings())
	_line(title).add_child(picker)
