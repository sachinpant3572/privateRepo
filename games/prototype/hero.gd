extends Node2D
## The hero, drawn in layers: costume body, back item (or energy wings),
## shoulder armor, helmet and the weapon in hand, plus an element aura and a
## shield bubble. The gear grows with the build during a run (gear tables in
## data.gd); every change pops and flashes, and a new main weapon swaps in
## with its own animation.

const Data := preload("res://data.gd")
const Art := preload("res://art.gd")
const SIZE := 72.0  # On-screen size of the body.
const TEX := 128.0  # Layer positions below are in body-texture pixels (facing +x).
const HEAD := Vector2(-4, -2)
const SHOULDER := Vector2(6, 17)  # Mirrored on y for the other shoulder.
const BACK := Vector2(-18, 0)
const WINGS := Vector2(-30, 0)
const HAND := Vector2(48, 2)
const HELMET_PX := 40.0
const SHOULDER_PX := 30.0
const BACK_PX := 44.0
const WINGS_PX := 120.0
const HAND_PX := 54.0

var body: Sprite2D
var back: Sprite2D
var wings: Sprite2D
var helmet: Sprite2D
var shoulders: Array = []
var hand: Sprite2D
var aura: Sprite2D
var bubble: Sprite2D
var helmet_tier := 0
var shoulder_tier := 0
var back_id := ""
var hand_id := ""
var hand_evolved := false
var element := ""
var shield_on := false
var t := 0.0


func setup(costume: Texture2D, glow: Texture2D, ring: Texture2D) -> void:
	scale = Vector2.ONE * SIZE / TEX
	aura = _layer(glow, Vector2.ZERO, 150.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	aura.material = add
	wings = _layer(null, WINGS, WINGS_PX)
	wings.material = add
	body = _layer(costume, Vector2.ZERO, TEX)
	# Seen from above, a pack sits on top of the back, so it draws over the body.
	back = _layer(null, BACK, BACK_PX)
	for side in [-1.0, 1.0]:
		var s := _layer(null, Vector2(SHOULDER.x, SHOULDER.y * side), SHOULDER_PX)
		# The art has its outer edge at the top; the lower shoulder is mirrored.
		s.flip_v = side > 0.0
		shoulders.append(s)
	helmet = _layer(null, HEAD, HELMET_PX)
	hand = _layer(null, HAND, HAND_PX)
	bubble = _layer(ring, Vector2.ZERO, 170.0)
	bubble.material = add
	bubble.modulate = Color(0.45, 0.85, 1.0, 0.0)
	reset()


func set_costume(costume: Texture2D) -> void:
	body.texture = costume


## Back to a bare costume at the start of a run.
func reset() -> void:
	helmet_tier = 0
	shoulder_tier = 0
	back_id = ""
	hand_id = ""
	hand_evolved = false
	element = ""
	for s in [helmet, back, wings, hand, aura]:
		s.visible = false
	for s in shoulders:
		s.visible = false
	set_shield(false)


func set_shield(on: bool) -> void:
	shield_on = on
	bubble.visible = on


## Re-dresses the hero for the current build. Returns banner lines for the
## pieces that changed (empty when nothing did).
func refresh(weapons: Dictionary, powers: Dictionary, evolved: Dictionary) -> Array:
	var news := []
	var ht := _tier(_levels(powers, Data.HELMET_POWERS), Data.HELMET_TIERS)
	if ht != helmet_tier:
		helmet_tier = ht
		helmet.visible = ht > 0
		if ht > 0:
			_set_tex(helmet, "gear/helmet%d" % ht, HELMET_PX)
			_pop(helmet)
			news.append(["HELMET", ["", "COMBAT HELMET", "ASSAULT HELMET", "LEGEND HELMET"][ht]])
	var st := _tier(_levels(powers, Data.SHOULDER_POWERS), Data.SHOULDER_TIERS)
	if st != shoulder_tier:
		shoulder_tier = st
		for s in shoulders:
			s.visible = st > 0
			if st > 0:
				_set_tex(s, "gear/shoulder%d" % st, SHOULDER_PX)
				_pop(s)
		if st > 0:
			news.append(["ARMOR", ["", "LIGHT PAULDRONS", "HEAVY PAULDRONS", "TITAN PAULDRONS"][st]])
	var best := ""
	var best_n := 1
	for fam in Data.BACK_FAMILIES:
		var n := _levels(powers, Data.BACK_FAMILIES[fam]) + _levels(weapons, Data.BACK_FAMILIES[fam])
		if n > best_n:
			best_n = n
			best = fam
	if best != back_id:
		back_id = best
		back.visible = best != "" and best != "wings"
		wings.visible = best == "wings"
		if best == "wings":
			_set_tex(wings, "gear/wings", WINGS_PX)
			_pop(wings)
		elif best != "":
			_set_tex(back, "gear/" + best, BACK_PX)
			_pop(back)
		if best != "":
			news.append(["GEAR", {"jetpack": "JETPACK", "missiles": "MISSILE POD", "dronepack": "DRONE DOCK", "wings": "ENERGY WINGS"}[best]])
	var el := ""
	var el_n := 0
	for id in Data.ELEMENT_COLORS:
		if int(powers.get(id, 0)) > el_n:
			el_n = powers[id]
			el = id
	if el != element:
		element = el
		aura.visible = el != ""
		if el != "":
			aura.modulate = Data.ELEMENT_COLORS[el]
			wings.modulate = Data.ELEMENT_COLORS[el].lightened(0.4)
	# The main weapon: the highest level one (the current one wins ties).
	var main := hand_id
	var main_l := int(weapons.get(hand_id, 0)) + (100 if evolved.has(hand_id) else 0)
	for id in Data.WEAPON_IDS:
		var l := int(weapons.get(id, 0)) + (100 if evolved.has(id) else 0)
		if l > main_l:
			main_l = l
			main = id
	if main != hand_id and main != "":
		_swap_weapon(main)
		news.append(["WEAPON", String(Data.NAMES[main]).to_upper()])
	hand_evolved = evolved.has(hand_id)
	return news


func _process(delta: float) -> void:
	t += delta
	if aura.visible:
		aura.scale = Vector2.ONE * (150.0 / aura.texture.get_width()) * (1.0 + 0.08 * sin(t * 5.0))
		aura.modulate.a = 0.3 + 0.12 * sin(t * 7.0)
	if wings.visible:
		wings.rotation = 0.06 * sin(t * 4.0)
	if bubble.visible:
		bubble.modulate.a = 0.45 + 0.25 * sin(t * 6.0)
	if hand.visible and hand_evolved:
		hand.self_modulate = Color(1.0, 0.85, 0.4).lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 8.0)) * 1.4


## The old weapon spins away behind the hero; the new one snaps in with a flash.
func _swap_weapon(id: String) -> void:
	if hand.visible and hand.texture != null:
		var ghost := Sprite2D.new()
		ghost.texture = hand.texture
		ghost.position = hand.position
		ghost.scale = hand.scale
		add_child(ghost)
		var tw := ghost.create_tween().set_parallel()
		tw.tween_property(ghost, "position", hand.position + Vector2(-60, -40), 0.35)
		tw.tween_property(ghost, "rotation", -TAU, 0.35)
		tw.tween_property(ghost, "scale", Vector2.ZERO, 0.35)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(ghost.queue_free)
	hand_id = id
	hand.visible = true
	_set_tex(hand, "hand/" + id, HAND_PX)
	var full := hand.scale
	hand.scale = Vector2.ZERO
	hand.rotation = 1.2
	hand.self_modulate = Color(3, 3, 3)
	var tw2 := hand.create_tween().set_parallel()
	tw2.tween_property(hand, "scale", full, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)
	tw2.tween_property(hand, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)
	tw2.tween_property(hand, "self_modulate", Color.WHITE, 0.45).set_delay(0.12)


func _pop(s: Sprite2D) -> void:
	var full := s.scale
	s.scale = full * 1.8
	s.self_modulate = Color(3, 3, 3)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", full, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "self_modulate", Color.WHITE, 0.5)


func _layer(tex: Texture2D, pos: Vector2, px: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.position = pos
	add_child(s)
	if tex != null:
		s.texture = tex
		s.scale = Vector2.ONE * px / tex.get_width()
	return s


func _set_tex(s: Sprite2D, tex_name: String, px: float) -> void:
	var tex := Art.sprite(tex_name)
	if tex == null:
		return
	s.texture = tex
	s.scale = Vector2.ONE * px / tex.get_width()


func _levels(owned: Dictionary, ids: Array) -> int:
	var n := 0
	for id in ids:
		n += int(owned.get(id, 0))
	return n


func _tier(n: int, steps: Array) -> int:
	var tier := 0
	for k in steps.size():
		if n >= int(steps[k]):
			tier = k + 1
	return tier
