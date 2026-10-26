extends CanvasLayer
## Menu, live stats and results screen for the stress test.

signal start_requested(kind: String, enemies: int, bullets: int)
signal stop_requested
signal option_toggled(option: String)

var root: Control
var menu_panel: ColorRect
var hud: MarginContainer
var hud_label: Label
var results_label: Label
var copy_button: Button
var quality_button: Button
var cap_button: Button
var heat_button: Button
var results := ""


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 28
	root.theme = theme
	add_child(root)
	_build_menu()
	_build_hud()
	show_menu("")


func _build_menu() -> void:
	menu_panel = ColorRect.new()
	menu_panel.color = Color(0.0, 0.0, 0.0, 0.8)
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	menu_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)

	_label(box, "Stress Test", 44)
	_label(box, "Checks how many enemies, bullets and explosions this phone can run smoothly. For fair numbers: phone unplugged, normal brightness, other apps closed.", 24)
	_button(box, "Quick check: 500 enemies + 1,000 bullets", func(): start_requested.emit("fixed", 500, 1000))
	_button(box, "Auto ramp: find this phone's limit", func(): start_requested.emit("ramp", 0, 0))
	_button(box, "5-minute heat soak: 500 + 1,000", func(): start_requested.emit("soak", 0, 0))
	_button(box, "Heavy: 1,000 enemies + 2,000 bullets", func(): start_requested.emit("fixed", 1000, 2000))
	_button(box, "Extreme: 2,000 enemies + 4,000 bullets", func(): start_requested.emit("fixed", 2000, 4000))
	_label(box, "Settings", 32)
	quality_button = _button(box, "", func(): option_toggled.emit("quality"))
	cap_button = _button(box, "", func(): option_toggled.emit("cap"))
	heat_button = _button(box, "", func(): option_toggled.emit("heat"))
	results_label = _label(box, "", 22)
	copy_button = _button(box, "Copy results", _copy_results)


func _build_hud() -> void:
	hud = MarginContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top"]:
		hud.add_theme_constant_override("margin_" + side, 16)
	root.add_child(hud)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(row)

	hud_label = Label.new()
	hud_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.add_theme_constant_override("outline_size", 6)
	hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	row.add_child(hud_label)

	var stop := Button.new()
	stop.text = "Stop"
	stop.custom_minimum_size = Vector2(140, 80)
	stop.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stop.pressed.connect(func(): stop_requested.emit())
	row.add_child(stop)


func show_menu(new_results: String) -> void:
	results = new_results
	results_label.text = results
	results_label.visible = results != ""
	copy_button.visible = results != ""
	copy_button.text = "Copy results"
	menu_panel.visible = true
	hud.visible = false


func show_hud() -> void:
	menu_panel.visible = false
	hud.visible = true
	hud_label.text = ""


func set_hud_text(text: String) -> void:
	hud_label.text = text


func set_options(quality: String, fps_cap: int, heat_on: bool) -> void:
	quality_button.text = "Graphics quality: %s" % quality
	cap_button.text = "Frame rate cap: %s" % ("%d FPS" % fps_cap if fps_cap > 0 else "none (screen max)")
	heat_button.text = "Read phone heat sensor: %s" % ("ON" if heat_on else "OFF")


func _copy_results() -> void:
	DisplayServer.clipboard_set(results)
	copy_button.text = "Copied. Paste it into the chat."


func _label(parent: Control, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 88)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	parent.add_child(button)
	return button
