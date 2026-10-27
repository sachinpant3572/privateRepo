extends Control
## The menu at a place's counter (built in code like the phone): what's for
## sale with prices and how much health each gives, cash and the bag.
## Corner-store snacks can be eaten now or taken (the bag holds three);
## diner meals are ordered and eaten at a table. The game keeps running
## behind it; the interior manager does the buying.

const BG := Color(0.07, 0.08, 0.11, 0.94)
const ACCENT := Color(1.0, 0.78, 0.25)
const Inventory = preload("res://scripts/inventory.gd")

## Called with (item id, "eat" | "take" | "order").
var on_buy := Callable()
var on_close := Callable()
var game
## The panel (the touch controls ignore taps on it).
var frame: PanelContainer

var _title: Label
var _status: Label
var _list: VBoxContainer
var _type := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	frame = PanelContainer.new()
	frame.anchor_left = 1.0
	frame.anchor_right = 1.0
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -560
	frame.offset_right = -24
	frame.offset_top = -330
	frame.offset_bottom = 330
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.set_corner_radius_all(18)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	frame.add_child(col)
	_title = _text("", 28, ACCENT)
	col.add_child(_title)
	_status = _text("", 20, Color(0.75, 0.95, 0.7))
	col.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	var done := _button("DONE", func(): close())
	col.add_child(done)


func open(place: Dictionary) -> void:
	_type = place.type
	_title.text = place.name
	visible = true
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	if on_close.is_valid():
		on_close.call()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


## Rebuilds the rows (after a purchase: cash and the bag changed).
func refresh() -> void:
	var inv = game.inventory
	_status.text = "Cash $%d   ·   Bag %d/%d" % [game.cash, inv.bag.size(), Inventory.BAG_SIZE]
	if _type == "diner":
		_status.text = "Cash $%d   ·   Sit down and eat" % game.cash
	for c in _list.get_children():
		c.queue_free()
	for id in Inventory.menu(_type):
		var item: Dictionary = Inventory.ITEMS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_text(item.name, 21, Color.WHITE))
		info.add_child(_text("$%d   ·   +%d health" % [item.price, item.heal], 17, Color(0.7, 0.72, 0.78)))
		row.add_child(info)
		var afford: bool = game.cash >= item.price
		if item.get("seated", false):
			row.add_child(_buy_button("ORDER", afford, func(): on_buy.call(id, "order")))
		else:
			row.add_child(_buy_button("EAT", afford, func(): on_buy.call(id, "eat")))
			row.add_child(_buy_button("TAKE", afford and not inv.bag_full(), func(): on_buy.call(id, "take")))
		_list.add_child(row)


## Shows a short note in the status line (until the next refresh).
func say(text: String) -> void:
	_status.text = text


func _buy_button(text: String, enabled: bool, press: Callable) -> Button:
	var b := _button(text, press)
	b.custom_minimum_size = Vector2(104, 56)
	b.disabled = not enabled
	return b


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 20)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
