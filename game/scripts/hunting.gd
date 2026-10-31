extends Node
## Hunting (phase 2 of HANDOFF-hill-content.md). The hunting store in
## Hollin sells a licence, a rifle and rounds and buys pelts. The rifle
## only comes out in the back-range forest (GROUND, off the closed lab
## valley) with the player on foot, and it only ever hits animals
## (wildlife.gd): it is not a general weapon. A kill out of season or
## without a valid licence is poaching (a wanted star). Skinning a carcass
## gives a pelt to sell.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")

## The hunting ground, from tools/hill_design_map.py ZONES "forest", less
## the closed lab valley.
const GROUND := [Vector2(-550, -4950), Vector2(1250, -4950), Vector2(1250, -4600), Vector2(1150, -4150),
	Vector2(850, -3500), Vector2(-550, -3500)]
const CLOSED := Rect2(360, -4250, 380, 390)
## Shop items: id -> name, price, what it does (the shop menu reads these).
const GEAR := {
	"licence": {"name": "Hunting licence (one season)", "price": 60, "note": "28 days from today"},
	"rifle": {"name": "Bolt-action hunting rifle", "price": 420, "note": "Animals only, in the hunting ground"},
	"ammo": {"name": "Rifle rounds (box of 10)", "price": 18, "note": "Carry up to 40"},
}
const PELT_PRICE := {"deer": 90, "coyote": 45, "rabbit": 14}
const PELT_NAMES := {"deer": "deer", "coyote": "coyote", "rabbit": "rabbit", "lion": "mountain lion"}
const LICENCE_DAYS := 28
const AMMO_MAX := 40
const PELT_MAX := 6
## A shot reaches RANGE m and picks the animal nearest the aim inside AIM
## (cosine of the half-angle); it hits surely within SURE m, less often
## out to RANGE.
const RANGE := 75.0
const AIM := 0.93
const SURE := 30.0
const SKIN_RANGE := 2.6
const STARTLE := 140.0
const AIM_TIME := 0.7

var game
var rifle := false
var ammo := 0
## The last calendar day the licence covers (-1: none).
var licence_until := -1
var pelts := {}
var _aim := 0.0
var _gun: MeshInstance3D


func _ready() -> void:
	game = get_parent()


func _process(delta: float) -> void:
	if _aim > 0.0:
		_aim -= delta
		if _aim <= 0.0 and _gun != null:
			_gun.visible = false


static func in_ground(p: Vector3) -> bool:
	var q := Vector2(p.x, p.z)
	return Geometry2D.is_point_in_polygon(q, PackedVector2Array(GROUND)) and not CLOSED.has_point(q)


func _today() -> int:
	return game.calendar.day() if game != null and game.get("calendar") != null else 0


func licence_valid() -> bool:
	return licence_until >= _today()


func _open_season(kind: String) -> bool:
	if game == null or game.get("calendar") == null:
		return kind != "lion"
	return game.calendar.is_open_season(kind)


func _wildlife():
	return game.atmosphere.get("wildlife") if game != null and game.atmosphere != null else null


## True while the attack button fires the rifle instead of punching.
func can_shoot() -> bool:
	var p = game.player if game != null else null
	return rifle and p != null and p.vehicle == null and not p.dead and in_ground(p.global_position)


## Fires one round along the player's facing. Returns the animal hit
## (its record from wildlife.animals_in) or null.
func shoot():
	var player = game.player
	if ammo <= 0:
		game.hud.show_message("Out of rounds: the hunting store in Hollin sells them")
		return null
	ammo -= 1
	_show_gun(player)
	player.gesture = "film"
	var muzzle: Vector3 = player.global_position + Vector3(0, 1.45, 0) + player.forward() * 1.1
	Fx.puff(muzzle, player.forward() * 2.0, 0.25, 1.4, 0.6, Color(0.85, 0.85, 0.82, 0.6))
	var target = _pick_target(player)
	# A lion shot while it stalks or charges the hunter is self-defence
	# (its state before the bang startles it).
	var defence: bool = target != null and target.kind == "lion" and target.get("state", "") in ["stalk", "charge"]
	var w = _wildlife()
	if w != null and w.has_method("startle"):
		w.startle(player.global_position, STARTLE)
	preload("res://scripts/birds.gd").startle(player.global_position, STARTLE)
	if target == null:
		return null
	var pos: Vector3 = target.position
	var d: float = pos.distance_to(player.global_position)
	var chance := 1.0 if d <= SURE else lerpf(1.0, 0.45, (d - SURE) / (RANGE - SURE))
	if randf() > chance:
		return null
	var kind: String = target.kind
	w.kill(target, (pos - player.global_position).normalized())
	if defence:
		game.hud.show_message("Self-defence: the rangers let it go")
	elif not (licence_valid() and _open_season(kind)):
		Wanted.report_crime(1)
		var why := "no licence" if not licence_valid() else "out of season"
		game.hud.show_message("Poaching (%s): the rangers are after you" % why)
	return target


func _pick_target(player):
	var w = _wildlife()
	if w == null:
		return null
	var at: Vector3 = player.global_position
	var fwd: Vector3 = player.forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best = null
	var best_dot := AIM
	for a in w.animals_in(at, RANGE):
		if not a.alive:
			continue
		var to: Vector3 = a.position - at
		to.y = 0.0
		if to.length() < 0.5:
			continue
		var dot := fwd.dot(to.normalized())
		if dot > best_dot:
			best = a
			best_dot = dot
	return best


## A rifle held at the shoulder while the shot plays (on the player node,
## not a bone: the "film" pose raises both arms to it).
func _show_gun(player) -> void:
	if _gun == null or not is_instance_valid(_gun):
		var mb := MeshBuilder.new()
		var steel := Color(0.16, 0.16, 0.17)
		var stock := Color(0.42, 0.27, 0.16)
		mb.box(Vector3(0, 0, -0.45), Vector3(0.05, 0.06, 0.9), steel)
		mb.box(Vector3(0, -0.02, 0.05), Vector3(0.07, 0.1, 0.5), stock)
		mb.box(Vector3(0, -0.07, 0.38), Vector3(0.07, 0.18, 0.2), stock)
		mb.box(Vector3(0, 0.06, -0.05), Vector3(0.05, 0.05, 0.3), steel)
		_gun = MeshInstance3D.new()
		_gun.mesh = mb.commit()
		_gun.material_override = MeshBuilder.material()
		player.add_child(_gun)
		_gun.position = Vector3(0.12, 1.42, -0.35)
	_gun.visible = true
	_aim = AIM_TIME


## The HUD's prompt near a carcass: [text, button] or [].
func prompt() -> Array:
	var c = _carcass()
	if c == null:
		return []
	return ["Skin the %s: E / SKIN" % PELT_NAMES.get(c.kind, c.kind), "SKIN"]


func _carcass():
	var w = _wildlife()
	var p = game.player if game != null else null
	if w == null or p == null or p.vehicle != null or not w.has_method("carcass_near"):
		return null
	var c: Dictionary = w.carcass_near(p.global_position, SKIN_RANGE)
	return null if c.is_empty() else c


## Skins the carcass at the player's feet. True when it did.
func try_interact() -> bool:
	var c = _carcass()
	if c == null:
		return false
	if pelts_total() >= PELT_MAX:
		game.hud.show_message("You can carry %d pelts: sell some in Hollin" % PELT_MAX)
		return true
	var kind: String = _wildlife().take_carcass(c)
	if kind == "":
		return false
	pelts[kind] = int(pelts.get(kind, 0)) + 1
	game.player.gesture = "kneel"
	game.hud.show_message("Skinned the %s (%d pelts)" % [PELT_NAMES.get(kind, kind), pelts_total()])
	return true


func pelts_total() -> int:
	var n := 0
	for k in pelts:
		n += int(pelts[k])
	return n


## What the store pays for the pelts it takes (a mountain lion's it won't
## touch: they are never in season).
func pelt_value() -> int:
	var v := 0
	for k in pelts:
		v += int(PELT_PRICE.get(k, 0)) * int(pelts[k])
	return v


## Sells the pelts the store takes; returns the cash paid.
func sell_pelts() -> int:
	var v := pelt_value()
	for k in pelts.keys():
		if PELT_PRICE.has(k):
			pelts.erase(k)
	game.cash += v
	return v


## Whether gear `id` can be bought now, and why not ("" when it can).
func gear_block(id: String) -> String:
	match id:
		"rifle":
			return "You have a rifle" if rifle else ""
		"licence":
			return "Your licence runs %d more days" % (licence_until - _today() + 1) if licence_valid() else ""
		"ammo":
			if not rifle:
				return "Buy a rifle first"
			return "You carry the most rounds" if ammo >= AMMO_MAX else ""
	return "?"


func buy_gear(id: String) -> bool:
	if not GEAR.has(id) or gear_block(id) != "" or game.cash < GEAR[id].price:
		return false
	match id:
		"rifle":
			rifle = true
			ammo = maxi(ammo, 10)
		"licence":
			licence_until = _today() + LICENCE_DAYS - 1
		"ammo":
			ammo = mini(AMMO_MAX, ammo + 10)
	game.cash -= GEAR[id].price
	return true


func to_save() -> Dictionary:
	return {"rifle": rifle, "ammo": ammo, "licence_until": licence_until, "pelts": pelts.duplicate()}


func load_save(d: Dictionary) -> void:
	rifle = bool(d.get("rifle", false))
	ammo = clampi(int(d.get("ammo", 0)), 0, AMMO_MAX)
	licence_until = int(d.get("licence_until", -1))
	pelts = {}
	var p = d.get("pelts", {})
	if typeof(p) == TYPE_DICTIONARY:
		for k in p:
			if PELT_NAMES.has(k):
				pelts[k] = clampi(int(p[k]), 0, PELT_MAX)
