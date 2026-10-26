extends CanvasLayer
## Menus, the in-game HUD, level-up cards, the death screen and results, in
## the holo-military style from ui_style.gd: gunmetal panels with cut corners,
## cyan for information, amber for rewards and the main action, red for
## danger. Every screen fades in; cards slide in one after another.

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
signal jump_pressed
signal banish_pressed
signal skip_pressed
signal costumes_pressed
signal costume_chosen(id: String)

const Art := preload("res://art.gd")
const UI := preload("res://ui_style.gd")
const Bar := preload("res://ui_bar.gd")
const Ring := preload("res://ui_ring.gd")
const JOY_RING := 180.0
const JOY_KNOB := 76.0
const KEY_ART := "res://sprites/ui/key_art.jpg"
# Seconds to choose an upgrade before one is picked at random.
const CARD_TIME := 6.0
const CHEST_CARD_TIME := 8.0

var root: Control
var menu: Control
var play: Control
var cards: ColorRect
var death: ColorRect
var over: Control
var chest: ColorRect
var chest_title: Label
var chest_reels: VBoxContainer
var chest_gold: Label
var chest_button: Button
var chest_final: Array = []
var chest_pool: Array = []
var chest_time := 0.0
var menu_stats: Label
var menu_stats_panel: PanelContainer
var gold_label: Label
var combo_label: Label
var double_button: Button
var hp_bar: Bar
var xp_bar: Bar
var level_label: Label
var info: Label
var clock: Label
var build_label: Label
var boss_box: VBoxContainer
var boss_bar: Bar
var banner_band: PanelContainer
var banner: Label
var banner_time := 0.0
var damage_flash: ColorRect
var joy_ring: TextureRect
var joy_knob: TextureRect
var card_title: Label
var card_tag: Label
var card_list: VBoxContainer
var third_button: Button
var reroll_button: Button
var revive_button: Button
var over_title: Label
var over_tag: Label
var over_text: Label
var copy_button: Button
var quality_button: Button
var cap_button: Button
var results := ""
var dash_button: Button
var slam_root: Control
var slam_ring: Ring
var slam_hit: Button
var slam_ready := false
var banish_button: Button
var skip_button: Button
var costumes: ColorRect
var costume_grid: GridContainer
var costume_gold: Label
var sfx  # sfx.gd, set by it: UI sounds and the announcer.
var level_re := RegEx.create_from_string("Lv (\\d+)\\s+Kills (\\d+)")
var card_timer_bar: Bar
var card_timer_label: Label
var card_timer := 0.0
var card_timer_max := 1.0
var card_timer_on := false
var card_fresh := true  # Next show_cards is a new choice (not a reroll).
var card_count := 0
var card_last_tick := -1
var card_infos: Array = []
var card_banish := false


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
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
		banner_band.modulate.a = clampf(banner_time / 0.45, 0.0, 1.0)
		banner_band.visible = banner_time > 0.0
	if damage_flash.color.a > 0.0:
		damage_flash.color.a = maxf(0.0, damage_flash.color.a - delta * 1.5)
	if chest.visible:
		_spin_chest(delta)
	if cards.visible and card_timer_on:
		_tick_card_timer(delta)


# --- Screens ----------------------------------------------------------------

func show_menu(stats: String) -> void:
	menu_stats.text = stats
	menu_stats_panel.visible = stats != ""
	_only(menu)


func show_play() -> void:
	_only(play)


func show_cards(infos: Array, third_left: int, reroll_left: int, is_chest: bool, banish_left: int, banish_mode: bool) -> void:
	for child in card_list.get_children():
		child.queue_free()
	if banish_mode:
		card_tag.text = "//  BANISH PROTOCOL"
		card_title.text = "TAP A CARD TO BANISH IT"
		card_title.add_theme_color_override("font_color", UI.RED)
	else:
		card_tag.text = "//  POWER CHEST" if is_chest else "//  FIELD UPGRADE"
		card_title.text = "CHOOSE YOUR REWARD" if is_chest else "LEVEL UP"
		card_title.add_theme_color_override("font_color", UI.AMBER)
	# A new choice restarts the clock; a reroll, extra card or banish keeps it
	# running. Banish mode pauses it.
	if card_fresh or not cards.visible:
		card_timer_max = CHEST_CARD_TIME if is_chest else CARD_TIME
		card_timer = card_timer_max
		card_last_tick = -1
	card_fresh = false
	card_timer_on = not banish_mode
	card_count = infos.size()
	card_infos = infos
	card_banish = banish_mode
	card_timer_bar.visible = not banish_mode
	card_timer_label.visible = not banish_mode
	_tick_card_timer(0.0)
	# The banner would show through behind the cards' title.
	banner_time = 0.0
	banner_band.visible = false
	for i in infos.size():
		var parts := _card(infos[i], banish_mode)
		var card: PanelContainer = parts[0]
		var hit: Button = parts[1]
		hit.pressed.connect(_ui_sound.bind("card_pick"))
		hit.pressed.connect(_card_taken)
		hit.pressed.connect(_announce_card.bind(i))
		hit.pressed.connect(card_chosen.emit.bind(i))
		card_list.add_child(card)
		# Cards slide in from the right one after another; rare ones pulse.
		card.modulate.a = 0.0
		card.position.x += 80.0
		var tw := card.create_tween().set_parallel(true)
		tw.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(0.07 * i)
		tw.tween_property(card, "position:x", card.position.x - 80.0, 0.28).set_delay(0.07 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var col: Color = infos[i]["color"]
		if col.v > 0.9 and col.s > 0.5 and not banish_mode:
			var pulse := card.create_tween().set_loops(4)
			pulse.tween_property(card, "self_modulate", Color(1.25, 1.18, 1.05), 0.3)
			pulse.tween_property(card, "self_modulate", Color.WHITE, 0.3)
	if sfx:
		sfx.play("card_show")
		if infos.any(func(d): return String(d.get("tag", "")).begins_with("Legendary")):
			sfx.announce("legendary")
	third_button.visible = infos.size() < 3 and third_left > 0
	third_button.text = "+3RD CARD (AD) · %d" % third_left
	reroll_button.disabled = reroll_left <= 0
	reroll_button.text = "REROLL (FREE)" if reroll_left > 0 else "REROLL USED"
	banish_button.disabled = banish_left <= 0
	banish_button.text = "CANCEL BANISH" if banish_mode else "BANISH · %d" % banish_left
	play.visible = true
	_fade_in(cards)


func show_death(can_revive: bool) -> void:
	revive_button.visible = can_revive
	play.visible = true
	cards.visible = false
	_fade_in(death)


func show_results(victory: bool, text: String, gold: int, full_report: String = "") -> void:
	# Gameplay hook: COPY RESULTS copies the full run report (game.gd _report_text).
	results = full_report if full_report != "" else text
	over_tag.text = "//  MISSION REPORT"
	over_title.text = "SECTOR CLEARED" if victory else "MISSION FAILED"
	over_title.add_theme_color_override("font_color", UI.AMBER if victory else UI.RED)
	over_text.text = text
	copy_button.text = "COPY RESULTS"
	double_button.visible = gold > 0
	double_button.disabled = false
	double_button.text = "DOUBLE %d GOLD (WATCH AD)" % gold
	_only(over)


func show_results_gold(gold: int) -> void:
	double_button.disabled = true
	double_button.text = "DOUBLED! %d GOLD" % gold


## The treasure chest: reels spin through item names and stop one by one.
func show_chest(names: Array, pool: Array, gold: int) -> void:
	chest_final = names
	chest_pool = pool
	chest_time = 0.0
	var colors := {1: UI.CYAN, 3: UI.VIOLET, 5: UI.AMBER}
	chest_title.text = {1: "SUPPLY CACHE", 3: "WAR CHEST", 5: "JACKPOT!!"}.get(names.size(), "SUPPLY CACHE")
	chest_title.add_theme_color_override("font_color", colors.get(names.size(), UI.TEXT))
	for child in chest_reels.get_children():
		child.queue_free()
	for n in names.size():
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", UI.panel(UI.PANEL_HI, colors.get(names.size(), UI.LINE), 2, 0.0, 12))
		var reel := UI.title("", 36)
		reel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plate.add_child(reel)
		chest_reels.add_child(plate)
	if sfx and names.size() >= 5:
		sfx.announce("jackpot")
	chest_gold.text = "+%d GOLD" % gold
	chest_gold.visible = false
	chest_button.visible = false
	play.visible = true
	_fade_in(chest)


# --- In-game updates --------------------------------------------------------

func set_bars(hp_frac: float, xp_frac: float) -> void:
	hp_bar.set_value(hp_frac)
	xp_bar.set_value(xp_frac)


func set_info(text: String, clock_text: String) -> void:
	var m := level_re.search(text)
	if m:
		level_label.text = m.get_string(1)
		info.text = "KILLS  %s" % m.get_string(2)
	else:
		info.text = text
	clock.text = clock_text
	clock.add_theme_color_override("font_color", UI.RED if clock_text == "BOSS" else UI.TEXT)


func set_build(text: String) -> void:
	build_label.text = text


func set_boss(visible_now: bool, frac: float) -> void:
	boss_box.visible = visible_now
	boss_bar.set_value(frac)


func show_banner(text: String, color: Color = Color(1.0, 0.85, 0.4)) -> void:
	banner.add_theme_color_override("font_color", color)
	banner.text = text
	var sb: StyleBoxFlat = banner_band.get_theme_stylebox("panel")
	sb.border_color = Color(color.r, color.g, color.b, 0.9)
	sb.shadow_color = Color(color.r, color.g, color.b, 0.3)
	banner_time = 2.5
	banner_band.visible = true
	banner_band.pivot_offset = banner_band.size * 0.5
	banner_band.scale = Vector2(1.25, 1.25)
	var tw := banner_band.create_tween()
	tw.tween_property(banner_band, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if sfx:
		sfx.announce_banner(text)


func flash_damage() -> void:
	flash(Color(1.0, 0.0, 0.0, 0.3))


func flash(color: Color) -> void:
	damage_flash.color = color


func set_gold(gold: int) -> void:
	gold_label.text = "◆ %d" % gold


func set_combo(count: int, frac: float) -> void:
	combo_label.visible = count >= 10
	combo_label.text = "x%d COMBO" % count
	combo_label.modulate.a = clampf(frac * 2.0, 0.3, 1.0)
	combo_label.add_theme_font_size_override("font_size", 34 + mini(floori(count / 50.0), 18))


func set_joystick(on: bool, origin: Vector2, knob: Vector2) -> void:
	joy_ring.visible = on
	joy_knob.visible = on
	joy_ring.position = origin - Vector2(JOY_RING, JOY_RING) * 0.5
	joy_knob.position = knob - Vector2(JOY_KNOB, JOY_KNOB) * 0.5


func set_options(quality: String, fps_cap: int) -> void:
	quality_button.text = "GRAPHICS: %s" % quality.to_upper()
	cap_button.text = "FPS CAP: %s" % ("%d" % fps_cap if fps_cap > 0 else "MAX")


## The Meteor Slam charge, 0..1 (below 0 hides the button). Reaching full
## blazes the ring, plays a cue and the announcer calls it.
func set_jump(frac: float) -> void:
	slam_root.visible = frac >= 0.0
	if frac < 0.0:
		return
	slam_ring.charge = clampf(frac, 0.0, 1.0)
	var now_ready := frac >= 1.0
	slam_hit.disabled = not now_ready
	if now_ready and not slam_ready:
		if sfx:
			sfx.play("slam_ready")
			sfx.announce("slam_ready", 2)
		slam_root.scale = Vector2(1.35, 1.35)
		slam_root.create_tween().tween_property(slam_root, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam_ready = now_ready


func _on_slam() -> void:
	if not slam_ready:
		return
	slam_ready = false
	slam_hit.disabled = true
	slam_root.scale = Vector2(0.8, 0.8)
	slam_root.create_tween().tween_property(slam_root, "scale", Vector2.ONE, 0.25)
	jump_pressed.emit()


## The dash button: hidden until Phase Dash is owned; dims while cooling down.
func set_dash(on: bool, cooldown_frac: float) -> void:
	dash_button.visible = on
	dash_button.modulate.a = 1.0 if cooldown_frac <= 0.0 else 0.35 + 0.3 * (1.0 - cooldown_frac)


func show_costumes(items: Array, wallet: int) -> void:
	for child in costume_grid.get_children():
		child.queue_free()
	costume_gold.text = "◆ %d GOLD" % wallet
	for it in items:
		var b := Button.new()
		b.icon = it["tex"]
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(0, 240)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", UI.font("title"))
		b.add_theme_font_size_override("font_size", 26)
		var status := "EQUIPPED" if it["on"] else ("OWNED" if it["owned"] else "◆ %d" % it["price"])
		b.text = "%s\n%s" % [String(it["name"]).to_upper(), status]
		var edge: Color = UI.CYAN if it["on"] else (UI.LINE if it["owned"] else UI.AMBER)
		var sb := UI.panel(UI.PANEL_HI if it["on"] else UI.PANEL, edge, 3 if it["on"] else 2, 0.8 if it["on"] else 0.0, 14)
		sb.set_content_margin_all(10)
		for style_name in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(style_name, sb)
		b.pressed.connect(_ui_sound.bind("ui_tap"))
		b.pressed.connect(costume_chosen.emit.bind(it["id"]))
		costume_grid.add_child(b)
	_only(costumes)


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
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 14
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 6)
	play.add_child(top)

	# Level badge | HP and XP bars | clock.
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	top.add_child(row)
	var badge := _plate(UI.panel(UI.PANEL, UI.CYAN, 2, 0.6, 12))
	badge.custom_minimum_size = Vector2(86, 78)
	row.add_child(badge)
	var badge_box := VBoxContainer.new()
	badge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_box.add_theme_constant_override("separation", -14)
	badge.add_child(badge_box)
	var lv := _small("LEVEL", 16, UI.CYAN)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_box.add_child(lv)
	level_label = UI.title("1", 52)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_box.add_child(level_label)
	var bars := VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_theme_constant_override("separation", 8)
	row.add_child(bars)
	hp_bar = _bar(UI.GREEN, 30, 12)
	bars.add_child(hp_bar)
	xp_bar = _bar(UI.CYAN, 14, 1)
	bars.add_child(xp_bar)
	var clock_plate := _plate(UI.panel(UI.PANEL, UI.LINE, 2, 0.0, 12))
	clock_plate.custom_minimum_size = Vector2(124, 78)
	row.add_child(clock_plate)
	clock = UI.title("5:00", 54)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_plate.add_child(clock)

	# Kills | combo | gold.
	var row2 := HBoxContainer.new()
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row2)
	info = _small("", 22, UI.DIM)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(info)
	gold_label = UI.title("◆ 0", 36, UI.AMBER)
	row2.add_child(gold_label)
	combo_label = UI.title("", 36, Color(1.0, 0.55, 0.2))
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.visible = false
	top.add_child(combo_label)
	build_label = _small("", 16, Color(UI.DIM.r, UI.DIM.g, UI.DIM.b, 0.85))
	build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(build_label)

	boss_box = VBoxContainer.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.visible = false
	boss_box.add_theme_constant_override("separation", 2)
	top.add_child(boss_box)
	boss_box.add_child(UI.tag("BOSS  ·  COLOSSUS SIEGE TANK", UI.RED))
	boss_bar = _bar(UI.RED, 24, 20)
	boss_box.add_child(boss_bar)

	# Banner: a band across the screen, punched in and faded out.
	banner_band = PanelContainer.new()
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0.02, 0.03, 0.05, 0.72)
	band.border_width_top = 2
	band.border_width_bottom = 2
	band.border_color = UI.AMBER
	band.shadow_size = 14
	band.shadow_color = Color(1.0, 0.7, 0.2, 0.3)
	band.content_margin_top = 6
	band.content_margin_bottom = 2
	banner_band.add_theme_stylebox_override("panel", band)
	banner_band.anchor_left = 0.0
	banner_band.anchor_right = 1.0
	banner_band.anchor_top = 0.26
	banner_band.anchor_bottom = 0.26
	banner_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_band.visible = false
	play.add_child(banner_band)
	banner = UI.title("", 58, UI.AMBER)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_band.add_child(banner)

	joy_ring = _image(Art.ring(128), JOY_RING)
	joy_ring.modulate = Color(UI.CYAN.r, UI.CYAN.g, UI.CYAN.b, 0.4)
	play.add_child(joy_ring)
	joy_knob = _image(Art.soft_disc(64, 0.6), JOY_KNOB)
	joy_knob.modulate = Color(0.7, 0.95, 1.0, 0.65)
	play.add_child(joy_knob)
	set_joystick(false, Vector2.ZERO, Vector2.ZERO)

	dash_button = Button.new()
	dash_button.text = "DASH"
	UI.style_button(dash_button, "secondary")
	var dash_style := UI.panel(Color(0.2, 0.12, 0.38, 0.8), UI.VIOLET, 3, 0.8, 22)
	for k in ["normal", "hover", "pressed", "focus"]:
		dash_button.add_theme_stylebox_override(k, dash_style)
	dash_button.add_theme_font_size_override("font_size", 40)
	dash_button.anchor_left = 1.0
	dash_button.anchor_right = 1.0
	dash_button.anchor_top = 1.0
	dash_button.anchor_bottom = 1.0
	dash_button.offset_left = -190
	dash_button.offset_right = -30
	dash_button.offset_top = -220
	dash_button.offset_bottom = -100
	dash_button.pressed.connect(dash_pressed.emit)
	dash_button.visible = false
	play.add_child(dash_button)

	# Meteor Slam: bottom-left, opposite the dash.
	slam_root = Control.new()
	slam_root.anchor_top = 1.0
	slam_root.anchor_bottom = 1.0
	slam_root.offset_left = 26
	slam_root.offset_right = 186
	slam_root.offset_top = -250
	slam_root.offset_bottom = -90
	slam_root.pivot_offset = Vector2(80, 80)
	slam_root.visible = false
	play.add_child(slam_root)
	slam_ring = Ring.new()
	slam_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slam_root.add_child(slam_ring)
	slam_hit = Button.new()
	slam_hit.flat = true
	for k in ["normal", "hover", "focus", "pressed", "disabled"]:
		slam_hit.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	slam_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slam_hit.disabled = true
	slam_hit.pressed.connect(_on_slam)
	slam_root.add_child(slam_hit)


func _build_menu() -> void:
	menu = Control.new()
	_full(menu)
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(menu)
	var bg := ColorRect.new()
	bg.color = UI.BG
	_full(bg)
	menu.add_child(bg)
	if ResourceLoader.exists(KEY_ART):
		var art := TextureRect.new()
		art.texture = load(KEY_ART)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_full(art)
		menu.add_child(art)
		# Slow push-in, so the menu feels alive.
		art.pivot_offset = Vector2(360, 640)
		var drift := art.create_tween().set_loops()
		drift.tween_property(art, "scale", Vector2(1.06, 1.06), 14.0).set_trans(Tween.TRANS_SINE)
		drift.tween_property(art, "scale", Vector2.ONE, 14.0).set_trans(Tween.TRANS_SINE)
	var shade := TextureRect.new()
	shade.texture = _vertical_gradient([[0.0, 0.75], [0.3, 0.1], [0.5, 0.15], [0.72, 0.85], [1.0, 0.95]])
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	_full(shade)
	menu.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 40)
	menu.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var logo := UI.title("FRACTURE", 168, Color(0.75, 0.97, 1.0))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_constant_override("outline_size", 0)
	logo.add_theme_constant_override("shadow_outline_size", 18)
	logo.add_theme_color_override("font_shadow_color", Color(UI.CYAN.r, UI.CYAN.g, UI.CYAN.b, 0.55))
	logo.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_theme_constant_override("shadow_offset_y", 0)
	col.add_child(logo)
	var glow := logo.create_tween().set_loops()
	glow.tween_property(logo, "self_modulate", Color(1.15, 1.15, 1.2), 1.8).set_trans(Tween.TRANS_SINE)
	glow.tween_property(logo, "self_modulate", Color.WHITE, 1.8).set_trans(Tween.TRANS_SINE)
	var sub := UI.tag("WORLD 1  ·  THE IRON DOMINION", UI.AMBER)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	col.add_child(sub)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	menu_stats_panel = _plate(UI.panel(Color(0.03, 0.05, 0.07, 0.78), UI.LINE, 2, 0.0, 14))
	col.add_child(menu_stats_panel)
	menu_stats = _small("", 21, UI.TEXT)
	menu_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_stats_panel.add_child(menu_stats)
	var help := _small("Drag anywhere to move  ·  weapons fire on their own  ·  survive 5:00, then destroy the boss", 19, UI.DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(help)

	var deploy := _button(col, "DEPLOY", start_pressed.emit.bind(false), "primary")
	deploy.custom_minimum_size = Vector2(0, 110)
	var pulse := deploy.create_tween().set_loops()
	pulse.tween_property(deploy, "self_modulate", Color(1.12, 1.08, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(deploy, "self_modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_button(row, "ARMORY", costumes_pressed.emit)
	_button(row, "AUTO-PLAY", start_pressed.emit.bind(true))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	col.add_child(row2)
	quality_button = _button(row2, "", option_toggled.emit.bind("quality"), "ghost")
	cap_button = _button(row2, "", option_toggled.emit.bind("cap"), "ghost")
	for b in [quality_button, cap_button]:
		b.add_theme_font_size_override("font_size", 24)
		b.custom_minimum_size = Vector2(0, 64)


func _build_cards() -> void:
	cards = ColorRect.new()
	cards.color = Color(0.01, 0.02, 0.03, 0.78)
	_full(cards)
	cards.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(cards)
	var box := _centered_box(cards)
	card_tag = UI.tag("FIELD UPGRADE", UI.CYAN)
	card_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(card_tag)
	card_title = UI.title("LEVEL UP", 84, UI.AMBER)
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(card_title)
	var timer_row := HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", 12)
	timer_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(timer_row)
	card_timer_bar = _bar(UI.AMBER, 18, 6)
	card_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	timer_row.add_child(card_timer_bar)
	card_timer_label = UI.title("6", 44, UI.AMBER)
	card_timer_label.custom_minimum_size = Vector2(44, 0)
	card_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_row.add_child(card_timer_label)
	card_list = VBoxContainer.new()
	card_list.add_theme_constant_override("separation", 18)
	box.add_child(card_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	third_button = _button(row, "", third_pressed.emit)
	reroll_button = _button(row, "", reroll_pressed.emit)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	box.add_child(row2)
	banish_button = _button(row2, "", banish_pressed.emit, "ghost")
	skip_button = _button(row2, "SKIP (+5 GOLD, +10% HP)", skip_pressed.emit, "ghost")
	skip_button.pressed.connect(_card_taken)
	for b in [third_button, reroll_button, banish_button, skip_button]:
		b.add_theme_font_size_override("font_size", 26)
		b.custom_minimum_size = Vector2(0, 72)


## One level-up card: icon in a rarity frame, name, rarity chip, description.
## Returns [panel, button]: the panel grows to fit its text, and an invisible
## button over it takes the tap.
func _card(d: Dictionary, banish_mode: bool) -> Array:
	var col: Color = UI.RED if banish_mode else d["color"]
	var rarity_glow := clampf((col.s - 0.2) * 1.5, 0.0, 1.0)
	var normal := UI.panel(Color(0.055, 0.08, 0.11, 0.97), col, 3, rarity_glow, 22)
	var pressed := UI.panel(Color(0.12, 0.16, 0.21, 0.98), col.lightened(0.3), 4, 1.0, 22)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 170)
	card.add_theme_stylebox_override("panel", normal)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var hit := Button.new()
	hit.flat = true
	for k in ["normal", "hover", "focus", "pressed", "disabled"]:
		hit.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	hit.button_down.connect(card.add_theme_stylebox_override.bind("panel", pressed))
	hit.button_up.connect(card.add_theme_stylebox_override.bind("panel", normal))
	card.add_child(hit)
	var frame := _plate(UI.panel(Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 0.95), col, 2, 0.0, 14))
	frame.custom_minimum_size = Vector2(124, 124)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	if d.get("icon") != null:
		var icon := TextureRect.new()
		icon.texture = d["icon"]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var name_label := UI.title(String(d["title"]).to_upper(), 40, UI.TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(name_label)
	var chip := _small(String(d["tag"]).to_upper(), 19, col)
	chip.add_theme_font_override("font", UI.font("bold"))
	text.add_child(chip)
	var desc := _small(String(d["desc"]), 21, Color(0.8, 0.87, 0.92))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	return [card, hit]


func _build_death() -> void:
	death = ColorRect.new()
	death.color = Color(0.22, 0.0, 0.0, 0.62)
	_full(death)
	death.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(death)
	var box := _centered_box(death)
	var tag := UI.tag("VITALS CRITICAL", UI.RED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	var title := UI.title("SIGNAL LOST", 110, UI.RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	revive_button = _button(box, "REVIVE (FREE, ONCE PER RUN)", revive_pressed.emit, "primary")
	revive_button.custom_minimum_size = Vector2(0, 104)
	_button(box, "GIVE UP", give_up_pressed.emit, "danger")


func _build_over() -> void:
	over = ColorRect.new()
	(over as ColorRect).color = Color(0.01, 0.02, 0.03, 0.86)
	_full(over)
	over.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(over)
	var box := _centered_box(over)
	over_tag = UI.tag("MISSION REPORT", UI.CYAN)
	over_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(over_tag)
	over_title = UI.title("", 96)
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(over_title)
	var report := _plate(UI.panel(UI.PANEL, UI.LINE, 2, 0.0, 16))
	box.add_child(report)
	over_text = _small("", 21, UI.TEXT)
	over_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.add_child(over_text)
	double_button = _button(box, "", double_gold_pressed.emit, "primary")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_button(row, "PLAY AGAIN", start_pressed.emit.bind(false))
	_button(row, "MENU", menu_pressed.emit)
	copy_button = _button(box, "COPY RESULTS", _copy_results, "ghost")
	copy_button.add_theme_font_size_override("font_size", 24)


func _build_chest() -> void:
	chest = ColorRect.new()
	chest.color = Color(0.01, 0.02, 0.03, 0.8)
	_full(chest)
	chest.mouse_filter = Control.MOUSE_FILTER_STOP
	chest.visible = false
	root.add_child(chest)
	var box := _centered_box(chest)
	var tag := UI.tag("SUPPLY DROP", UI.AMBER)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	chest_title = UI.title("SUPPLY CACHE", 92)
	chest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(chest_title)
	chest_reels = VBoxContainer.new()
	chest_reels.add_theme_constant_override("separation", 12)
	box.add_child(chest_reels)
	chest_gold = UI.title("", 48, UI.AMBER)
	chest_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(chest_gold)
	chest_button = _button(box, "COLLECT", _collect_chest, "primary")


func _build_costumes() -> void:
	costumes = ColorRect.new()
	costumes.color = Color(0.01, 0.02, 0.03, 0.9)
	_full(costumes)
	costumes.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(costumes)
	var box := _centered_box(costumes)
	var tag := UI.tag("OUTFITS", UI.CYAN)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	var title := UI.title("ARMORY", 92, Color(0.75, 0.97, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	costume_gold = UI.title("", 36, UI.AMBER)
	costume_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(costume_gold)
	var hint := _small("Your gear (helmet, armor, back item, weapon) grows on top of any outfit during a run.", 19, UI.DIM)
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
	_button(box, "BACK", menu_pressed.emit)


## The upgrade clock: amber, then red with a rising tick each second for the
## last three; at zero a random card is taken.
func _tick_card_timer(delta: float) -> void:
	card_timer = maxf(card_timer - delta, 0.0)
	var frac := card_timer / card_timer_max
	var secs := int(ceil(card_timer))
	var urgent := card_timer <= 3.0
	card_timer_bar.color = UI.RED if urgent else UI.AMBER
	card_timer_bar.value = frac
	card_timer_bar.shown = frac
	card_timer_bar.queue_redraw()
	card_timer_label.text = str(secs)
	card_timer_label.add_theme_color_override("font_color", UI.RED if urgent else UI.AMBER)
	if urgent and secs != card_last_tick and secs > 0 and delta > 0.0:
		card_last_tick = secs
		if sfx:
			sfx.play("tick", 1.0 + 0.25 * (3 - secs), 6.0)
		card_timer_label.pivot_offset = card_timer_label.size * 0.5
		card_timer_label.scale = Vector2(1.5, 1.5)
		card_timer_label.create_tween().tween_property(card_timer_label, "scale", Vector2.ONE, 0.25)
	if card_timer <= 0.0 and card_count > 0:
		card_timer_on = false
		_ui_sound("card_pick")
		_card_taken()
		var pick := randi() % card_count
		_announce_card(pick)
		card_chosen.emit(pick)


## The announcer calls out the chosen upgrade (sfx.gd picks how hard).
func _announce_card(index: int) -> void:
	if sfx and not card_banish and index < card_infos.size():
		sfx.announce_upgrade(card_infos[index])


func _card_taken() -> void:
	card_fresh = true


func _collect_chest() -> void:
	chest.visible = false
	chest_collected.emit()


func _spin_chest(delta: float) -> void:
	chest_time += delta
	var plates := chest_reels.get_children()
	for i in plates.size():
		var reel: Label = plates[i].get_child(0)
		var stop_at := 0.6 + 0.35 * i
		if chest_time < stop_at:
			if not chest_pool.is_empty():
				reel.text = String(chest_pool[int(chest_time * 18.0 + i * 3) % chest_pool.size()]).to_upper()
			reel.modulate = Color(0.6, 0.65, 0.7)
		elif reel.text != String(chest_final[i]).to_upper():
			reel.text = String(chest_final[i]).to_upper()
			reel.modulate = Color(1.0, 0.92, 0.6)
			if sfx:
				sfx.play("coin")
	var done := chest_time >= 0.6 + 0.35 * plates.size()
	chest_gold.visible = done
	chest_button.visible = done


func _copy_results() -> void:
	DisplayServer.clipboard_set(results)
	copy_button.text = "COPIED. PASTE IT INTO THE CHAT."


func _only(screen: Control) -> void:
	for s in [menu, play, cards, death, over, chest, costumes]:
		s.visible = s == screen
	if screen != play:
		_fade_in(screen)


func _fade_in(screen: Control) -> void:
	screen.visible = true
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(screen, "modulate:a", 1.0, 0.18)


func _full(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _centered_box(parent: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	parent.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	return box


func _plate(style: StyleBox) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _small(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(parent: Control, text: String, action: Callable, kind: String = "secondary") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 84)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.style_button(button, kind)
	button.pressed.connect(_ui_sound.bind("ui_tap"))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _bar(color: Color, height: int, segments: int) -> Bar:
	var bar := Bar.new()
	bar.color = color
	bar.segments = segments
	bar.custom_minimum_size = Vector2(0, height)
	bar.slant = height * 0.45
	return bar


func _image(texture: Texture2D, size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A tall gradient texture: stops are [offset, alpha] of black.
func _vertical_gradient(stops: Array) -> GradientTexture2D:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for s in stops:
		offsets.append(s[0])
		colors.append(Color(UI.BG.r, UI.BG.g, UI.BG.b, s[1]))
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 4
	tex.height = 256
	return tex


func _ui_sound(id: String) -> void:
	if sfx:
		sfx.play(id)
