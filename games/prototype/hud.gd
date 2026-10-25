extends CanvasLayer
## Menus, the in-game HUD, level-up cards, the death screen and results.

signal start_pressed(autoplay: bool)
signal card_chosen(index: int)
signal third_pressed
signal reroll_pressed
signal revive_pressed
signal give_up_pressed
signal menu_pressed
signal option_toggled(option: String)

const Art := preload("res://art.gd")
const JOY_RING := 180.0
const JOY_KNOB := 76.0

var root: Control
var menu: ColorRect
var play: Control
var cards: ColorRect
var death: ColorRect
var over: ColorRect
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var info: Label
var clock: Label
var build_label: Label
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var banner: Label
var banner_time := 0.0
var damage_flash: ColorRect
var joy_ring: TextureRect
var joy_knob: TextureRect
var card_title: Label
var card_list: VBoxContainer
var third_button: Button
var reroll_button: Button
var revive_button: Button
var over_title: Label
var over_text: Label
var copy_button: Button
var quality_button: Button
var cap_button: Button
var results := ""


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 26
	root.theme = theme
	add_child(root)
	_build_play()
	_build_menu()
	_build_cards()
	_build_death()
	_build_over()


func _process(delta: float) -> void:
	if banner_time > 0.0:
		banner_time -= delta
		banner.modulate.a = clampf(banner_time / 0.5, 0.0, 1.0)
		banner.visible = banner_time > 0.0
	if damage_flash.color.a > 0.0:
		damage_flash.color.a = maxf(0.0, damage_flash.color.a - delta * 1.5)


# --- Screens ----------------------------------------------------------------

func show_menu() -> void:
	_only(menu)


func show_play() -> void:
	_only(play)


func show_cards(infos: Array, third_left: int, reroll_left: int, chest: bool) -> void:
	for child in card_list.get_children():
		child.queue_free()
	card_title.text = "POWER CHEST!" if chest else "LEVEL UP!"
	for i in infos.size():
		var info_d: Dictionary = infos[i]
		var card := Button.new()
		card.text = "%s\n%s\n%s" % [info_d["title"], info_d["tag"], info_d["desc"]]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.custom_minimum_size = Vector2(0, 170)
		card.add_theme_font_size_override("font_size", 24)
		var col: Color = info_d["color"]
		for style_name in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.07, 0.08, 0.11, 0.96) if style_name != "pressed" else Color(0.15, 0.16, 0.2, 0.96)
			sb.border_color = col
			sb.set_border_width_all(4)
			sb.set_corner_radius_all(12)
			sb.set_content_margin_all(18)
			card.add_theme_stylebox_override(style_name, sb)
		card.pressed.connect(card_chosen.emit.bind(i))
		card_list.add_child(card)
	third_button.visible = infos.size() < 3 and third_left > 0
	third_button.text = "Show 3rd card (ad) · %d left" % third_left
	reroll_button.disabled = reroll_left <= 0
	reroll_button.text = "Reroll (free)" if reroll_left > 0 else "Reroll used"
	play.visible = true
	cards.visible = true


func show_death(can_revive: bool) -> void:
	revive_button.visible = can_revive
	play.visible = true
	cards.visible = false
	death.visible = true


func show_results(victory: bool, text: String) -> void:
	results = text
	over_title.text = "STAGE CLEARED!" if victory else "DEFEATED"
	over_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if victory else Color(1.0, 0.4, 0.35))
	over_text.text = text
	copy_button.text = "Copy results"
	_only(over)


# --- In-game updates --------------------------------------------------------

func set_bars(hp_frac: float, xp_frac: float) -> void:
	hp_bar.value = hp_frac
	xp_bar.value = xp_frac


func set_info(text: String, clock_text: String) -> void:
	info.text = text
	clock.text = clock_text


func set_build(text: String) -> void:
	build_label.text = text


func set_boss(visible_now: bool, frac: float) -> void:
	boss_box.visible = visible_now
	boss_bar.value = frac


func show_banner(text: String) -> void:
	banner.text = text
	banner_time = 2.5
	banner.visible = true


func flash_damage() -> void:
	damage_flash.color.a = 0.3


func set_joystick(on: bool, origin: Vector2, knob: Vector2) -> void:
	joy_ring.visible = on
	joy_knob.visible = on
	joy_ring.position = origin - Vector2(JOY_RING, JOY_RING) * 0.5
	joy_knob.position = knob - Vector2(JOY_KNOB, JOY_KNOB) * 0.5


func set_options(quality: String, fps_cap: int) -> void:
	quality_button.text = "Graphics quality: %s" % quality
	cap_button.text = "Frame rate cap: %s" % ("%d FPS" % fps_cap if fps_cap > 0 else "none (screen max)")


# --- Building ---------------------------------------------------------------

func _build_play() -> void:
	play = Control.new()
	_full(play)
	root.add_child(play)

	damage_flash = ColorRect.new()
	damage_flash.color = Color(1.0, 0.0, 0.0, 0.0)
	_full(damage_flash)
	play.add_child(damage_flash)

	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 14
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 6)
	play.add_child(top)
	hp_bar = _bar(Color(0.25, 0.9, 0.45), 20)
	top.add_child(hp_bar)
	xp_bar = _bar(Color(0.35, 0.8, 1.0), 10)
	top.add_child(xp_bar)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	info = _label("", 24)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	clock = _label("5:00", 36)
	row.add_child(clock)
	build_label = _label("", 18)
	build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(build_label)
	boss_box = VBoxContainer.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.visible = false
	top.add_child(boss_box)
	var boss_name := _label("COLOSSUS SIEGE TANK", 22)
	boss_name.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	boss_box.add_child(boss_name)
	boss_bar = _bar(Color(1.0, 0.3, 0.2), 18)
	boss_box.add_child(boss_bar)

	banner = _label("", 40)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 0.3
	banner.anchor_bottom = 0.3
	banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	banner.visible = false
	play.add_child(banner)

	joy_ring = _image(Art.ring(128), JOY_RING)
	joy_ring.modulate = Color(1, 1, 1, 0.45)
	play.add_child(joy_ring)
	joy_knob = _image(Art.soft_disc(64, 0.6), JOY_KNOB)
	joy_knob.modulate = Color(0.7, 0.9, 1.0, 0.6)
	play.add_child(joy_knob)
	set_joystick(false, Vector2.ZERO, Vector2.ZERO)


func _build_menu() -> void:
	menu = ColorRect.new()
	menu.color = Color(0.0, 0.0, 0.0, 0.55)
	_full(menu)
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(menu)
	var box := _centered_box(menu)
	var title := _label("FRACTURE", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	box.add_child(title)
	var sub := _label("World 1: The Iron Dominion (prototype)", 26)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var help := _label("Drag anywhere to move. Your weapons fire on their own. Survive 5 minutes of escalating waves, then destroy the boss.", 22)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)
	_button(box, "Play Stage 1", start_pressed.emit.bind(false))
	_button(box, "Watch auto-play", start_pressed.emit.bind(true))
	quality_button = _button(box, "", option_toggled.emit.bind("quality"))
	cap_button = _button(box, "", option_toggled.emit.bind("cap"))


func _build_cards() -> void:
	cards = ColorRect.new()
	cards.color = Color(0.0, 0.0, 0.0, 0.7)
	_full(cards)
	cards.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(cards)
	var box := _centered_box(cards)
	card_title = _label("LEVEL UP!", 46)
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(card_title)
	card_list = VBoxContainer.new()
	card_list.add_theme_constant_override("separation", 16)
	box.add_child(card_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	third_button = _button(row, "", third_pressed.emit)
	reroll_button = _button(row, "", reroll_pressed.emit)


func _build_death() -> void:
	death = ColorRect.new()
	death.color = Color(0.25, 0.0, 0.0, 0.6)
	_full(death)
	death.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(death)
	var box := _centered_box(death)
	var title := _label("YOU FELL", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	revive_button = _button(box, "Revive (free, once per run)", revive_pressed.emit)
	_button(box, "Give up", give_up_pressed.emit)


func _build_over() -> void:
	over = ColorRect.new()
	over.color = Color(0.0, 0.0, 0.0, 0.8)
	_full(over)
	over.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(over)
	var box := _centered_box(over)
	over_title = _label("", 52)
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(over_title)
	over_text = _label("", 22)
	over_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(over_text)
	copy_button = _button(box, "Copy results", _copy_results)
	_button(box, "Play again", start_pressed.emit.bind(false))
	_button(box, "Menu", menu_pressed.emit)


func _copy_results() -> void:
	DisplayServer.clipboard_set(results)
	copy_button.text = "Copied. Paste it into the chat."


func _only(screen: Control) -> void:
	for s in [menu, play, cards, death, over]:
		s.visible = s == screen


func _full(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _centered_box(parent: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	parent.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	return box


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 84)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _bar(color: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.001
	bar.custom_minimum_size = Vector2(0, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _image(texture: Texture2D, size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
