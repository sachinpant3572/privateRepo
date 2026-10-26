extends Node2D
## The hero, drawn in layers: costume body, back item (or energy wings),
## shoulder armor, helmet and the weapon in hand, plus an element aura and a
## shield bubble. The gear grows with the build during a run (gear tables in
## data.gd); every change pops and flashes, and a new main weapon swaps in
## with its own animation.
##
## All animation is procedural, so it works for every costume, gear piece and
## weapon: a step bob and lean while moving, breathing when still, the weapon
## aiming and recoiling per weapon, and poses for dash, stomp, power-ups, hits,
## death and revive. The game calls move(), aim(), fire() and the pose
## functions; effect sprites come from sprites/fx/.

const Data := preload("res://data.gd")
const Art := preload("res://art.gd")
const SIZE := 72.0  # On-screen size of the body.
const TEX := 128.0  # Layer positions below are in body-texture pixels (facing +x).
const HEAD := Vector2(-4, -2)
const SHOULDER := Vector2(6, 17)  # Mirrored on y for the other shoulder.
const BACK := Vector2(-18, 0)
const WINGS := Vector2(-30, 0)
const HAND_PIVOT := Vector2(14, 2)  # The weapon swings around the chest...
const HAND_REACH := 34.0  # ...and sits this far in front of it.
const MUZZLE := 62.0  # Muzzle flash distance from the pivot.
const HELMET_PX := 40.0
const SHOULDER_PX := 30.0
const BACK_PX := 44.0
const WINGS_PX := 120.0
const HAND_PX := 54.0
const AIM_LIMIT := 1.1  # How far the weapon turns from the body (radians).
const FX_CAP := 28  # Most world effect sprites alive at once.
# Recoil kick (0..1) and muzzle flash per weapon; "" = no flash.
const RECOIL := {
	"rifle": [0.35, "muzzle_plasma"], "scatter": [1.0, "muzzle"], "rail": [1.0, "muzzle_plasma"],
	"rockets": [0.3, ""], "grenade": [0.2, ""], "halo": [0.0, ""], "drones": [0.0, ""],
	"tesla": [0.4, "spark_electric"], "flame": [0.1, "flame_puff"], "mines": [0.2, ""],
	"sentry": [0.3, ""], "airstrike": [0.25, ""],
}

var rig: Node2D  # Everything below; animated as one figure.
var body: Sprite2D
var back: Sprite2D
var wings: Sprite2D
var helmet: Sprite2D
var shoulders: Array = []
var hand_pivot: Node2D
var hand: Sprite2D
var flash: Sprite2D
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
# Animation state.
var speed_frac := 0.0  # 0 standing still .. 1 full speed.
var step := 0.0  # Walk cycle phase.
var last_angle := 0.0
var lean := 0.0
var aim_angle := 0.0
var recoil := 0.0
var jitter := 0.0
var squash := Vector2.ONE
var flinch := 0.0
var glow := 0.0
var glow_color := Color.WHITE
var flash_t := 0.0
var dash_t := 0.0
var ghost_t := 0.0
var dust_t := 0.0
var back_kick := 0.0
var dead := false
var fx_alive := 0
var fx_tex := {}  # Effect textures by name, loaded once.


func setup(costume: Texture2D, glow_tex: Texture2D, ring: Texture2D) -> void:
	scale = Vector2.ONE * SIZE / TEX
	aura = _layer(self, glow_tex, Vector2.ZERO, 150.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	aura.material = add
	rig = Node2D.new()
	add_child(rig)
	wings = _layer(rig, null, WINGS, WINGS_PX)
	wings.material = add
	body = _layer(rig, costume, Vector2.ZERO, TEX)
	# Seen from above, a pack sits on top of the back, so it draws over the body.
	back = _layer(rig, null, BACK, BACK_PX)
	for side in [-1.0, 1.0]:
		var s := _layer(rig, null, Vector2(SHOULDER.x, SHOULDER.y * side), SHOULDER_PX)
		# The art has its outer edge at the top; the lower shoulder is mirrored.
		s.flip_v = side > 0.0
		shoulders.append(s)
	helmet = _layer(rig, null, HEAD, HELMET_PX)
	hand_pivot = Node2D.new()
	hand_pivot.position = HAND_PIVOT
	rig.add_child(hand_pivot)
	hand = _layer(hand_pivot, null, Vector2(HAND_REACH, 0), HAND_PX)
	flash = _layer(hand_pivot, null, Vector2(MUZZLE, 0), 1.0)
	flash.material = add
	flash.visible = false
	bubble = _layer(self, ring, Vector2.ZERO, 170.0)
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
	revive(false)


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


# --- Animation hooks (called by the game) -----------------------------------

## Every frame: how fast the hero moves (move vector, length 0..1).
func move(move_vec: Vector2, dashing: bool) -> void:
	speed_frac = move_vec.length()
	# Lean into turns: the change of facing per frame tilts the figure.
	var turn := wrapf(rotation - last_angle, -PI, PI)
	last_angle = rotation
	lean = lerpf(lean, clampf(turn * 4.0, -0.3, 0.3), 0.2)
	if speed_frac > 0.5 and not dashing and not dead:
		dust_t -= get_process_delta_time()
		if dust_t <= 0.0:
			dust_t = 0.16
			var feet := global_position - Vector2.from_angle(rotation) * 18.0
			_fx_world("dust_puff", feet + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 0.45, 14.0, 30.0, randf() * TAU, Color(1, 1, 1, 0.7))


## Every frame: where the weapon should point (world angle).
func aim(world_angle: float) -> void:
	var rel := wrapf(world_angle - rotation, -PI, PI)
	aim_angle = clampf(rel, -AIM_LIMIT, AIM_LIMIT)


## A weapon fired: recoil, muzzle flash and a per-weapon gesture.
func fire(id: String) -> void:
	if dead:
		return
	var r: Array = RECOIL.get(id, [0.2, ""])
	if id != hand_id:
		# A weapon that isn't in hand still gives the body a small jolt.
		recoil = maxf(recoil, float(r[0]) * 0.3)
		if id == "rockets" or id == "airstrike":
			back_kick = 1.0
		return
	recoil = maxf(recoil, float(r[0]))
	if String(r[1]) != "":
		_flash(String(r[1]), 0.07 if id != "rail" else 0.12)
	match id:
		"scatter", "rail":
			squash = Vector2(0.9, 1.08)  # The whole body rocks back.
		"flame":
			jitter = 1.0
		"grenade":
			_swing(hand_pivot, -0.9, 0.28)
		"rockets":
			back_kick = 1.0
			_swing(hand_pivot, -0.25, 0.2)
		"mines", "sentry":
			_pulse(hand, 1.25, 0.22)  # Deploy gesture.
		"airstrike":
			_pulse(hand, 1.2, 0.3)
			_fx_world("spark_star", hand.global_position, 0.25, 6.0, 18.0, 0.0, Color(1.0, 0.4, 0.3))


## Phase Dash: stretch along the dash, speed streak and afterimages.
func dash(world_angle: float) -> void:
	dash_t = 0.2
	ghost_t = 0.0
	squash = Vector2(1.45, 0.7)
	_fx_world("dash_streak", global_position, 0.3, 70.0, 110.0, world_angle, Color(0.7, 0.95, 1.0, 0.9))


## Shockwave Stomp: crouch, slam, and a ground ring.
func stomp(radius: float) -> void:
	squash = Vector2(0.75, 0.75)
	var tw := rig.create_tween()
	tw.tween_property(self, "squash", Vector2(1.25, 1.25), 0.08)
	tw.tween_property(self, "squash", Vector2.ONE, 0.2)
	_fx_world("shock_ring", global_position, 0.4, 20.0, radius * 2.0, 0.0, Color(0.7, 0.95, 1.0, 0.9))
	for k in 5:
		var at := global_position + Vector2.from_angle(TAU * k / 5.0) * 26.0
		_fx_world("dust_puff", at, 0.5, 18.0, 40.0, randf() * TAU, Color(1, 1, 1, 0.8))


## Level-ups, card picks, evolutions: a burst behind the hero and a proud pop.
func power_up(strength: float, color: Color) -> void:
	glow = minf(1.0, 0.4 + strength * 0.3)
	glow_color = color
	squash = Vector2.ONE * (1.0 + 0.12 * minf(strength, 2.0))
	_fx_world("power_burst", global_position, 0.35 + 0.15 * strength, 30.0, 90.0 + 60.0 * minf(strength, 2.0), randf() * TAU, color.lightened(0.3), true)


func hurt() -> void:
	flinch = 1.0
	squash = Vector2(0.88, 1.1)
	_fx_world("spark_star", global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.2, 10.0, 26.0, randf() * TAU, Color(1.0, 0.5, 0.4))


func dodge() -> void:
	_ghost(Color(0.5, 0.9, 1.0, 0.6), Vector2(randf_range(-20, 20), randf_range(-20, 20)))


func shield_hit() -> void:
	_pulse(bubble, 1.35, 0.25)
	_fx_world("spark_electric", global_position, 0.25, 30.0, 60.0, randf() * TAU, Color(0.6, 0.9, 1.0))


func heal() -> void:
	_fx_world("heal_glow", global_position, 0.6, 30.0, 70.0, 0.0, Color(1, 1, 1, 0.9), true)


func die() -> void:
	dead = true
	var tw := rig.create_tween().set_parallel()
	tw.tween_property(rig, "rotation", rig.rotation + TAU * 1.5, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(rig, "scale", Vector2.ONE * 0.55, 0.7)
	tw.tween_property(rig, "modulate", Color(0.45, 0.45, 0.5, 0.8), 0.7)


func revive(effects: bool = true) -> void:
	dead = false
	rig.scale = Vector2.ONE
	rig.rotation = 0.0
	rig.modulate = Color.WHITE
	if effects:
		heal()
		power_up(1.2, Color(0.6, 1.0, 0.8))


func victory() -> void:
	power_up(2.0, Color(1.0, 0.85, 0.4))
	var tw := rig.create_tween().set_loops(3)
	tw.tween_property(self, "squash", Vector2(1.15, 1.15), 0.25)
	tw.tween_property(self, "squash", Vector2.ONE, 0.25)


# --- Per-frame animation ----------------------------------------------------

func _process(delta: float) -> void:
	t += delta
	if not dead:
		# Walk cycle: a side sway and a step bounce, faster when moving fast.
		step += delta * (6.0 + 8.0 * speed_frac)
		var sway := sin(step) * 3.0 * speed_frac
		var bounce := 1.0 + 0.045 * absf(sin(step)) * speed_frac
		var breathe := 1.0 + 0.02 * sin(t * 2.4) * (1.0 - speed_frac)
		squash = squash.lerp(Vector2.ONE, minf(1.0, delta * 9.0))
		rig.scale = Vector2(bounce * breathe, breathe / bounce) * squash
		rig.position = Vector2(-recoil * 6.0, sway)
		rig.rotation = lean
		hand_pivot.rotation = lerp_angle(hand_pivot.rotation, aim_angle, minf(1.0, delta * 14.0))
	recoil = maxf(0.0, recoil - delta * 6.0)
	jitter = maxf(0.0, jitter - delta * 3.0)
	hand.position = Vector2(HAND_REACH - recoil * 14.0, 0.0) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 3.0 * jitter
	back_kick = maxf(0.0, back_kick - delta * 5.0)
	back.position = BACK + Vector2(-6.0 * back_kick, 0.0)
	flinch = maxf(0.0, flinch - delta * 4.0)
	glow = maxf(0.0, glow - delta * 1.5)
	var tint := Color.WHITE.lerp(Color(1.8, 0.5, 0.45), flinch * 0.7)
	if glow > 0.0:
		tint = tint.lerp(glow_color * 1.6, glow * 0.5)
	if not dead:
		body.self_modulate = tint
	if flash_t > 0.0:
		flash_t -= delta
		flash.visible = flash_t > 0.0
	if dash_t > 0.0:
		dash_t -= delta
		ghost_t -= delta
		if ghost_t <= 0.0:
			ghost_t = 0.04
			_ghost(Color(0.5, 0.9, 1.0, 0.55), Vector2.ZERO)
	if aura.visible:
		aura.scale = Vector2.ONE * (150.0 / aura.texture.get_width()) * (1.0 + 0.08 * sin(t * 5.0))
		aura.modulate.a = 0.3 + 0.12 * sin(t * 7.0)
	if wings.visible:
		# Wings flap faster and wider when running.
		wings.rotation = (0.06 + 0.1 * speed_frac) * sin(t * (4.0 + 8.0 * speed_frac))
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
		hand_pivot.add_child(ghost)
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


func _flash(fx_name: String, time: float) -> void:
	var tex := _fx_tex(fx_name)
	if tex == null:
		return
	flash.texture = tex
	# Muzzle flashes are drawn from their left edge (the muzzle) to the right.
	flash.offset = Vector2(tex.get_width() * 0.5, 0.0) if fx_name != "spark_electric" else Vector2.ZERO
	flash.scale = Vector2.ONE * randf_range(34.0, 44.0) / tex.get_width()
	flash.rotation = randf_range(-0.15, 0.15)
	flash.visible = true
	flash_t = time


## A world effect for the game (impacts, chain sparks). It keeps `reserve`
## of the effect slots free so the hero's own effects always have room.
func effect(fx_name: String, at: Vector2, life: float, size0: float, size1: float, color: Color, reserve: int = 10) -> void:
	if fx_alive < FX_CAP - reserve:
		_fx_world(fx_name, at, life, size0, size1, randf() * TAU, color)


## A fading copy of the body left behind (dash afterimages, dodges).
func _ghost(color: Color, offset: Vector2) -> void:
	if fx_alive >= FX_CAP or get_parent() == null:
		return
	var g := Sprite2D.new()
	g.texture = body.texture
	g.global_position = global_position + offset
	g.rotation = rotation
	g.scale = scale * rig.scale
	g.modulate = color
	get_parent().add_child(g)
	get_parent().move_child(g, get_index())
	_track(g, 0.25)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)


## A one-shot effect sprite in the world: it grows from size0 to size1 pixels
## and fades out. behind = drawn under the hero.
func _fx_world(fx_name: String, at: Vector2, life: float, size0: float, size1: float, rot: float, color: Color, behind: bool = false) -> void:
	if fx_alive >= FX_CAP or get_parent() == null:
		return
	var tex := _fx_tex(fx_name)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.global_position = at
	s.rotation = rot
	s.modulate = color
	var w := float(tex.get_width())
	s.scale = Vector2.ONE * size0 / w
	get_parent().add_child(s)
	if behind:
		get_parent().move_child(s, get_index())
	_track(s, life)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2.ONE * size1 / w, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(s, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)


func _fx_tex(fx_name: String) -> Texture2D:
	if not fx_tex.has(fx_name):
		fx_tex[fx_name] = Art.sprite("fx/" + fx_name)
	return fx_tex[fx_name]


## Counts a live effect and frees it after its life.
func _track(node: Node, life: float) -> void:
	fx_alive += 1
	get_tree().create_timer(life).timeout.connect(func() -> void:
		fx_alive -= 1
		node.queue_free())


func _swing(node: Node2D, amount: float, time: float) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "rotation", node.rotation + amount, time * 0.35)
	tw.tween_property(node, "rotation", aim_angle, time * 0.65).set_trans(Tween.TRANS_BACK)


func _pulse(s: Node2D, amount: float, time: float) -> void:
	var full := s.scale
	var tw := s.create_tween()
	tw.tween_property(s, "scale", full * amount, time * 0.4)
	tw.tween_property(s, "scale", full, time * 0.6)


func _pop(s: Sprite2D) -> void:
	var full := s.scale
	s.scale = full * 1.8
	s.self_modulate = Color(3, 3, 3)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", full, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "self_modulate", Color.WHITE, 0.5)


func _layer(parent: Node, tex: Texture2D, pos: Vector2, px: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.position = pos
	parent.add_child(s)
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
