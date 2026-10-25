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
signal chest_collected
signal double_gold_pressed
signal dash_pressed
signal banish_pressed
signal skip_pressed
signal costumes_pressed
signal costume_chosen(id: String)

const Art := preload("res://art.gd")
const JOY_RING := 180.0
const JOY_KNOB := 76.0

var root: Control
var menu: ColorRect
var play: Control
var cards: ColorRect
var death: ColorRect
var over: ColorRect
var chest: ColorRect
var chest_title: Label
var chest_reels: VBoxContainer
var chest_gold: Label
var chest_button: Button
var chest_final: Array = []
var chest_pool: Array = []
var chest_time := 0.0
var menu_stats: Label
var gold_label: Label
var combo_label: Label
var double_button: Button
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
var dash_button: Button
var banish_button: Button
var skip_button: Button
var costumes: ColorRect
var costume_grid: GridContainer
var costume_gold: Label


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
	_build_chest()
	_build_costumes()


func _process(delta: float) -> void:
	if banner_time > 0.0:
		banner_time -= delta
		banner.modulate.a = clampf(banner_time / 0.5, 0.0, 1.0)
		banner.visible = banner_time > 0.0
	if damage_flash.color.a > 0.0:
		damage_flash.color.a = maxf(0.0, damage_flash.color.a - delta * 1.5)
	if chest.visible:
		_spin_chest(delta)


# --- Screens ----------------------------------------------------------------

func show_menu(stats: String) -> void:
	menu_stats.text = stats
	menu_stats.visible = stats != ""
	_only(menu)


func show_play() -> void:
	_only(play)


func show_cards(infos: Array, third_left: int, reroll_left: int, chest: bool, banish_left: int, banish_mode: bool) -> void:
	for child in card_list.get_children():
		child.queue_free()
	card_title.text = "TAP A CARD TO BANISH IT" if banish_mode else ("POWER CHEST!" if chest else "LEVEL UP!")
	for i in infos.size():
		var info_d: Dictionary = infos[i]
		var card := Button.new()
		card.text = "%s\n%s\n%s" % [info_d["title"], info_d["tag"], info_d["desc"]]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.custom_minimum_size = Vector2(0, 170)
		card.add_theme_font_size_override("font_size", 24)
		if info_d["icon"] != null:
			card.icon = info_d["icon"]
			card.add_theme_constant_override("icon_max_width", 96)
			card.add_theme_constant_override("h_separation", 16)
		var col: Color = Color(1.0, 0.35, 0.3) if banish_mode else info_d["color"]
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
		# Cards fade and slide in one after another; rare ones pulse.
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.tween_interval(0.06 * i)
		tw.tween_property(card, "modulate:a", 1.0, 0.15)
		if col.v > 0.9 and col.s > 0.5:
			var pulse := card.create_tween().set_loops(4)
			pulse.tween_property(card, "self_modulate", Color(1.3, 1.2, 1.0), 0.25)
			pulse.tween_property(card, "self_modulate", Color.WHITE, 0.25)
	third_button.visible = infos.size() < 3 and third_left > 0
	third_button.text = "Show 3rd card (ad) · %d left" % third_left
	reroll_button.disabled = reroll_left <= 0
	reroll_button.text = "Reroll (free)" if reroll_left > 0 else "Reroll used"
	banish_button.disabled = banish_left <= 0
	banish_button.text = ("Cancel banish" if banish_mode else "Banish · %d left" % banish_left)
	play.visible = true
	cards.visible = true


func show_death(can_revive: bool) -> void:
	revive_button.visible = can_revive
	play.visible = true
	cards.visible = false
	death.visible = true


func show_results(victory: bool, text: String, gold: int) -> void:
	results = text
	over_title.text = "STAGE CLEARED!" if victory else "DEFEATED"
	over_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if victory else Color(1.0, 0.4, 0.35))
	over_text.text = text
	copy_button.text = "Copy results"
	double_button.visible = gold > 0
	double_button.disabled = false
	double_button.text = "Double your %d gold (watch ad)" % gold
	_only(over)


func show_results_gold(gold: int) -> void:
	double_button.disabled = true
	double_button.text = "Doubled! %d gold" % gold


## The treasure chest: reels spin through item names and stop one by one.
func show_chest(names: Array, pool: Array, gold: int) -> void:
	chest_final = names
	chest_pool = pool
	chest_time = 0.0
	var colors := {1: Color(0.4, 0.7, 1.0), 3: Color(0.8, 0.45, 1.0), 5: Color(1.0, 0.8, 0.25)}
	chest_title.text = {1: "TREASURE!", 3: "BIG TREASURE!", 5: "JACKPOT!!"}.get(names.size(), "TREASURE!")
	chest_title.add_theme_color_override("font_color", colors.get(names.size(), Color.WHITE))
	for child in chest_reels.get_children():
		child.queue_free()
	for n in names.size():
		var reel := _label("", 30)
		reel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chest_reels.add_child(reel)
	chest_gold.text = "+%d gold" % gold
	chest_gold.visible = false
	chest_button.visible = false
	play.visible = true
	chest.visible = true


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


func show_banner(text: String, color: Color = Color(1.0, 0.85, 0.4)) -> void:
	banner.add_theme_color_override("font_color", color)
	banner.text = text
	banner_time = 2.5
	banner.visible = true


func flash_damage() -> void:
	flash(Color(1.0, 0.0, 0.0, 0.3))


func flash(color: Color) -> void:
	damage_flash.color = color


func set_gold(gold: int) -> void:
	gold_label.text = "● %d" % gold


func set_combo(count: int, frac: float) -> void:
	combo_label.visible = count >= 10
	combo_label.text = "x%d COMBO" % count
	combo_label.modulate.a = clampf(frac * 2.0, 0.3, 1.0)
	combo_label.add_theme_font_size_override("font_size", 26 + mini(count / 50, 14))


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
	var row2 := HBoxContainer.new()
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row2)
	combo_label = _label("", 26)
	combo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	combo_label.visible = false
	row2.add_child(combo_label)
	gold_label = _label("● 0", 26)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	row2.add_child(gold_label)
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
	banner.anchor_top = 0.22
	banner.anchor_bottom = 0.22
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

	dash_button = Button.new()
	dash_button.text = "DASH"
	dash_button.add_theme_font_size_override("font_size", 28)
	dash_button.anchor_left = 1.0
	dash_button.anchor_right = 1.0
	dash_button.anchor_top = 1.0
	dash_button.anchor_bottom = 1.0
	dash_button.offset_left = -190
	dash_button.offset_right = -30
	dash_button.offset_top = -220
	dash_button.offset_bottom = -90
	var dash_style := StyleBoxFlat.new()
	dash_style.bg_color = Color(0.3, 0.2, 0.55, 0.75)
	dash_style.set_corner_radius_all(64)
	dash_style.border_color = Color(0.75, 0.55, 1.0)
	dash_style.set_border_width_all(4)
	dash_button.add_theme_stylebox_override("normal", dash_style)
	dash_button.add_theme_stylebox_override("pressed", dash_style)
	dash_button.add_theme_stylebox_override("hover", dash_style)
	dash_button.pressed.connect(dash_pressed.emit)
	dash_button.visible = false
	play.add_child(dash_button)


## The dash button: hidden until Phase Dash is owned; dims while cooling down.
func set_dash(on: bool, cooldown_frac: float) -> void:
	dash_button.visible = on
	dash_button.modulate.a = 1.0 if cooldown_frac <= 0.0 else 0.35 + 0.3 * (1.0 - cooldown_frac)


func show_costumes(items: Array, wallet: int) -> void:
	for child in costume_grid.get_children():
		child.queue_free()
	costume_gold.text = "Gold: %d" % wallet
	for it in items:
		var b := Button.new()
		b.icon = it["tex"]
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(0, 230)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		var status := "EQUIPPED" if it["on"] else ("Owned" if it["owned"] else "%d gold" % it["price"])
		b.text = "%s\n%s" % [it["name"], status]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.08, 0.11, 0.96)
		sb.border_color = Color(0.4, 0.95, 1.0) if it["on"] else (Color(0.5, 0.55, 0.6) if it["owned"] else Color(1.0, 0.8, 0.3))
		sb.set_border_width_all(4 if it["on"] else 2)
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(10)
		for style_name in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(style_name, sb)
		b.pressed.connect(costume_chosen.emit.bind(it["id"]))
		costume_grid.add_child(b)
	_only(costumes)


func _build_costumes() -> void:
	costumes = ColorRect.new()
	costumes.color = Color(0.0, 0.0, 0.0, 0.8)
	_full(costumes)
	costumes.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(costumes)
	var box := _centered_box(costumes)
	var title := _label("COSTUMES", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	box.add_child(title)
	costume_gold = _label("", 26)
	costume_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	costume_gold.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	box.add_child(costume_gold)
	var hint := _label("Your gear (helmet, armor, back item, weapon) grows on top of any costume during a run.", 20)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	costume_grid = GridContainer.new()
	costume_grid.columns = 3
	costume_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	costume_grid.add_theme_constant_override("h_separation", 12)
	costume_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(costume_grid)
	_button(box, "Back", menu_pressed.emit)


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
	menu_stats = _label("", 22)
	menu_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_stats.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	box.add_child(menu_stats)
	_button(box, "Play Stage 1", start_pressed.emit.bind(false))
	_button(box, "Costumes", costumes_pressed.emit)
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
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	box.add_child(row2)
	banish_button = _button(row2, "", banish_pressed.emit)
	skip_button = _button(row2, "Skip (+5 gold, +10% HP)", skip_pressed.emit)


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
	double_button = _button(box, "", double_gold_pressed.emit)
	copy_button = _button(box, "Copy results", _copy_results)
	_button(box, "Play again", start_pressed.emit.bind(false))
	_button(box, "Menu", menu_pressed.emit)


func _build_chest() -> void:
	chest = ColorRect.new()
	chest.color = Color(0.0, 0.0, 0.0, 0.75)
	_full(chest)
	chest.mouse_filter = Control.MOUSE_FILTER_STOP
	chest.visible = false
	root.add_child(chest)
	var box := _centered_box(chest)
	chest_title = _label("TREASURE!", 54)
	chest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(chest_title)
	chest_reels = VBoxContainer.new()
	chest_reels.add_theme_constant_override("separation", 14)
	box.add_child(chest_reels)
	chest_gold = _label("", 34)
	chest_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chest_gold.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	box.add_child(chest_gold)
	chest_button = _button(box, "Collect", _collect_chest)


func _collect_chest() -> void:
	chest.visible = false
	chest_collected.emit()


func _spin_chest(delta: float) -> void:
	chest_time += delta
	var reels := chest_reels.get_children()
	for i in reels.size():
		var reel: Label = reels[i]
		var stop_at := 0.6 + 0.35 * i
		if chest_time < stop_at:
			if not chest_pool.is_empty():
				reel.text = chest_pool[int(chest_time * 18.0 + i * 3) % chest_pool.size()]
			reel.modulate = Color(0.7, 0.7, 0.7)
		elif reel.text != chest_final[i]:
			reel.text = chest_final[i]
			reel.modulate = Color(1.0, 0.9, 0.5)
	var done := chest_time >= 0.6 + 0.35 * reels.size()
	chest_gold.visible = done
	chest_button.visible = done


func _copy_results() -> void:
	DisplayServer.clipboard_set(results)
	copy_button.text = "Copied. Paste it into the chat."


func _only(screen: Control) -> void:
	for s in [menu, play, cards, death, over, chest, costumes]:
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
