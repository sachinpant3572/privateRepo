extends Node2D
## How each enemy dies. game.gd calls play() from _kill(); this node then
## builds the death from the game's own effects (sparks, rings, fireballs,
## smoke, scorch marks) plus what it draws itself:
## - Troopers are knocked back away from the hero, crumple and fade, with a
##   burst of armor fragments.
## - Shield Troopers: the shield shatters into glowing shards.
## - Grenadiers: their grenades cook off in a short chain of pops.
## - Juggernauts: armor plates fly off and arcs crackle in a heavy blast; the
##   hulk burns on the ground.
## - Battle Tanks: the turret is blown high into the air and crashes down
##   nearby; the burning hull stays for a few seconds.
## - Helicopters and Gunships spin out trailing smoke and fire, lose their
##   rotor, then crash. Bomber Jets streak on in flames and crash ahead.
## - Siege Colossus: a chain of blasts runs across the hull, then a huge one.
## This node draws what lies on the ground (hulls, bodies); `air` draws what
## is still in the air (aircraft, turrets, fragments).
## Everything is capped by the graphics tier, and over the cap a death falls
## back to just its burst, so a screen of 300 kills costs no more.

const Data := preload("res://data.gd")
const Art := preload("res://art.gd")

enum { CORPSE, WRECK, FALL, PART, DOOMED }

const GRAVITY := 1500.0
const CHARRED := Color(0.24, 0.21, 0.2)
const ARMOR_CHIPS := [Color(0.55, 0.12, 0.12), Color(0.2, 0.21, 0.23), Color(0.42, 0.45, 0.5)]
const SHARD := Color(0.6, 0.9, 1.0)


class Body:
	var kind := CORPSE
	var tex: Texture2D
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var ang := 0.0
	var spin := 0.0
	var size := 40.0
	var life := 1.0
	var total := 1.0
	var z := 0.0  # Height above the ground: drawn bigger, with its shadow further off.
	var vz := 0.0
	var burn := 0.0  # Seconds of fire and smoke still to come.
	var ty := 0
	var tier := 0
	var emit := 0.0


class Chip:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var z := 0.0
	var vz := 0.0
	var ang := 0.0
	var spin := 0.0
	var size := 4.0
	var col := Color.WHITE
	var life := 1.0
	var glow := false


var game: Node
var air: Node2D
var bodies: Array[Body] = []
var flying: Array[Body] = []
var chips: Array[Chip] = []
var later: Array = []  # [seconds left, position, radius, power, sound or ""]
var body_cap := 100
var chip_cap := 300
var textures := {}  # atlas cell -> texture, read from the game's unit layers
var playing := 0
var last_t := 0.0


## Adds the ground layer just above the scorch marks and the air layer above
## the units, then reads the unit textures from the game's layers.
func attach(g: Node) -> void:
	game = g
	var world: Node2D = g.world
	var decals: int = -1
	var units := {}
	for child in world.get_children():
		if child is MultiMeshInstance2D:
			var mm: MultiMesh = (child as MultiMeshInstance2D).multimesh
			if mm == g.decal_mm:
				decals = child.get_index()
			var cell: int = g.unit_mms.find(mm)
			if cell >= 0:
				units[cell] = (child as MultiMeshInstance2D).texture
	textures = units
	world.add_child(self)
	if decals >= 0:
		world.move_child(self, decals + 1)
	air = Node2D.new()
	air.draw.connect(_draw_air)
	world.add_child(air)
	var hero: Node = g.hero
	world.move_child(air, hero.get_index())
	playing = int(g.get_script().get_script_constant_map().get("State", {}).get("PLAYING", 1))


func set_tier(tier: Dictionary) -> void:
	var vfx := float(tier.get("vfx", 1000))
	body_cap = int(vfx / 14.0)
	chip_cap = int(vfx / 5.0)


func clear() -> void:
	bodies.clear()
	flying.clear()
	chips.clear()
	later.clear()


func _tex(cell: int, tier: int) -> Texture2D:
	return textures.get(game._cell(cell, tier), textures.get(cell))


# --- Deaths -----------------------------------------------------------------

func play(ty: int, p: Vector2, ang: float, tier: int) -> void:
	var away: Vector2 = (p - game.player).normalized()
	if away == Vector2.ZERO:
		away = Vector2.from_angle(randf() * TAU)
	var sparks := int(game.fx.tier["sparks"])
	var few := int(sparks * 0.5) + 1
	var size: float = game.t_size[ty] * (1.08 if tier == 3 else 1.0)
	match ty:
		Data.TROOPER, Data.GRENADIER, Data.SHIELD:
			_flash(p, 22.0)
			game._sparks(p, few)
			_corpse(ty, p, ang, tier, size, away)
			_burst(p, away, 3, ARMOR_CHIPS, 3.5, 260.0)
			if randf() < 0.25:
				game._vfx(p, Vector2(0.0, -20.0), 0.6, 6.0, 16.0, Color(0.35, 0.33, 0.32, 0.4), Color(0.2, 0.2, 0.2, 0.0), false)
			if ty == Data.SHIELD:
				_shatter(p, away)
				game.sfx.play("shatter", randf_range(0.9, 1.15), -9.0)
			elif ty == Data.GRENADIER:
				# The grenades on his belt cook off.
				game._explosion(p, 34.0, 0.45)
				for k in 2:
					later.append([0.1 + 0.12 * k + randf() * 0.05, p + Vector2.from_angle(randf() * TAU) * randf_range(16.0, 34.0), 24.0, 0.35, "pop"])
				game.sfx.play("grenade", randf_range(1.1, 1.3), -10.0)
			else:
				game.sfx.play("crunch", randf_range(0.9, 1.15), -9.0)
		Data.ELITE:
			_flash(p, 90.0)
			game._sparks(p, sparks * 3)
			game._ring(p, 3.5)
			game._explosion(p, 95.0, 1.3)
			_arcs(p, 10, 140.0)
			for k in 4:
				_part(_tex(Data.ELITE, tier), p, away.rotated(randf_range(-1.6, 1.6)), size * 0.3, 360.0, Color(0.3, 0.32, 0.35))
			_burst(p, away, 8, ARMOR_CHIPS, 6.0, 360.0)
			for k in 2:
				later.append([0.14 + 0.16 * k, p + Vector2.from_angle(randf() * TAU) * 30.0, 55.0, 0.8, "boom"])
			_wreck(_tex(Data.ELITE, tier), p, ang, size, 2.5, ty, tier)
			game.sfx.play("big_boom", randf_range(0.9, 1.1), -2.0)
			game.sfx.play("debris", randf_range(0.9, 1.1), -8.0)
		Data.TANK:
			_flash(p, 70.0)
			game._sparks(p, sparks * 2)
			game._ring(p, 2.6)
			game._explosion(p, 70.0, 1.0)
			_wreck(_tex(Art.TANK, tier), p, ang, size, 3.0, ty, tier)
			# The turret is blown off, high into the air.
			var turret := _part(_tex(Art.TURRET, tier), p, away.rotated(randf_range(-0.8, 0.8)), size, 520.0, Color.WHITE)
			if turret:
				turret.vel *= 0.35
				turret.ang = (game.player - p).angle()
				turret.ty = ty
				turret.burn = 1.0
			_burst(p, away, 5, [Color(0.3, 0.33, 0.25), Color(0.2, 0.21, 0.23)], 5.0, 300.0)
			game.sfx.play("boom", randf_range(0.85, 1.05), -4.0)
			game.sfx.vehicle_down("tank", int(game.type_alive[Data.TANK]) == 0, false)
		Data.HELI, Data.GUNSHIP, Data.JET:
			var gun := ty == Data.GUNSHIP
			var jet := ty == Data.JET
			_flash(p, 60.0 if gun else 40.0)
			game._sparks(p, sparks * 2)
			game._explosion(p, 50.0 if gun else 34.0, 0.6)
			var cell: int = Art.JET if jet else (Art.GUNSHIP if gun else Art.HELI)
			var b := _fall(_tex(cell, tier), p, ang, size, ty, tier)
			if b:
				var fwd := Vector2.from_angle(ang)
				if jet:
					b.vel = fwd * game.t_speed[ty] * 0.8
					b.spin = randf_range(-1.5, 1.5)
					b.life = 0.55
				else:
					b.vel = fwd * 90.0 + away * 70.0
					b.spin = randf_range(4.0, 6.0) * (1.0 if randf() < 0.5 else -1.0)
					b.life = 1.4 if gun else 0.95
				b.total = b.life
				if not jet:
					var rotor := _part(textures.get(Art.ROTOR), p, away.rotated(randf_range(-1.2, 1.2)), size * 1.1, 260.0, Color.WHITE)
					if rotor:
						rotor.spin = 30.0
			game.sfx.play("boom", randf_range(0.9, 1.1), -6.0)
			game.sfx.play("crash_start", randf_range(0.95, 1.05), -6.0 if gun else -9.0)
			var aloft := int(game.type_alive[Data.HELI]) + int(game.type_alive[Data.GUNSHIP]) + int(game.type_alive[Data.JET])
			game.sfx.vehicle_down("air", aloft == 0, gun)
		Data.SIEGE:
			_flash(p, 120.0)
			game._ring(p, 3.0)
			var b := Body.new()
			b.kind = DOOMED
			b.tex = _tex(Art.SIEGE, tier)
			b.pos = p
			b.ang = ang
			b.size = size
			b.life = 1.3
			b.total = 1.3
			b.ty = ty
			b.tier = tier
			bodies.append(b)
			for k in 6:
				later.append([0.1 + 0.19 * k, p + Vector2.from_angle(randf() * TAU) * randf_range(20.0, size * 0.4), 50.0, 0.9, "boom"])
			game.sfx.play("big_boom", 0.9, -4.0)
		_:
			_flash(p, 30.0)
			game._sparks(p, sparks)
			game._ring(p, 1.8)
			game.sfx.play("boom", randf_range(0.85, 1.15), -10.0)


## A white-hot flash where the unit was.
func _flash(p: Vector2, r: float) -> void:
	game._vfx(p, Vector2.ZERO, 0.1, r * 0.3, r, Color(1.0, 0.97, 0.88, 0.95), Color(1.0, 0.65, 0.25, 0.0), true)


func _corpse(ty: int, p: Vector2, ang: float, tier: int, size: float, away: Vector2) -> void:
	if bodies.size() >= body_cap:
		return
	var b := Body.new()
	b.kind = CORPSE
	b.tex = _tex(ty, tier)
	b.pos = p
	b.vel = away * randf_range(260.0, 420.0)
	b.ang = ang
	b.spin = randf_range(-7.0, 7.0)
	b.size = size
	b.life = 0.75
	b.total = 0.75
	b.z = 0.2
	b.vz = randf_range(1.5, 2.5)
	b.ty = ty
	bodies.append(b)


func _wreck(tex: Texture2D, p: Vector2, ang: float, size: float, burn: float, ty: int, tier: int) -> Body:
	if bodies.size() >= body_cap or tex == null:
		return null
	var b := Body.new()
	b.kind = WRECK
	b.tex = tex
	b.pos = p
	b.ang = ang
	b.size = size
	b.life = burn + 1.2
	b.total = b.life
	b.burn = burn
	b.ty = ty
	b.tier = tier
	bodies.append(b)
	return b


func _fall(tex: Texture2D, p: Vector2, ang: float, size: float, ty: int, tier: int) -> Body:
	if tex == null:
		return null
	var b := Body.new()
	b.kind = FALL
	b.tex = tex
	b.pos = p
	b.ang = ang
	b.size = size
	b.z = 1.0
	b.ty = ty
	b.tier = tier
	flying.append(b)
	return b


## A piece thrown into the air: it spins up, comes down and lands.
func _part(tex: Texture2D, p: Vector2, dir: Vector2, size: float, vz: float, tint: Color) -> Body:
	if tex == null or flying.size() * 2 >= body_cap:
		return null
	var b := Body.new()
	b.kind = PART
	b.tex = tex
	b.pos = p
	b.vel = dir * randf_range(140.0, 260.0)
	b.ang = randf() * TAU
	b.spin = randf_range(-9.0, 9.0)
	b.size = size
	b.vz = vz * randf_range(0.85, 1.1)
	b.life = 3.0
	b.total = 3.0
	b.ty = -1
	b.emit = tint.r  # Darkness of the piece (1 = untouched).
	flying.append(b)
	return b


## Fragments flying out, mostly away from the hero.
func _burst(p: Vector2, away: Vector2, n: int, cols: Array, size: float, speed: float) -> void:
	for k in n:
		if chips.size() >= chip_cap:
			return
		var c := Chip.new()
		c.pos = p
		c.vel = away.rotated(randf_range(-1.3, 1.3)) * randf_range(0.4, 1.0) * speed
		c.vz = randf_range(200.0, 420.0)
		c.ang = randf() * TAU
		c.spin = randf_range(-14.0, 14.0)
		c.size = size * randf_range(0.6, 1.3)
		c.col = cols[randi() % cols.size()]
		c.life = randf_range(0.6, 1.0)
		chips.append(c)


## The energy shield breaking: fast, glowing shards.
func _shatter(p: Vector2, away: Vector2) -> void:
	game._ring(p, 1.2)
	for k in 7:
		if chips.size() >= chip_cap:
			return
		var c := Chip.new()
		c.pos = p + away * 10.0
		c.vel = away.rotated(randf_range(-1.6, 1.6)) * randf_range(220.0, 480.0)
		c.vz = randf_range(80.0, 220.0)
		c.ang = randf() * TAU
		c.spin = randf_range(-20.0, 20.0)
		c.size = randf_range(4.0, 8.0)
		c.col = SHARD
		c.life = randf_range(0.35, 0.6)
		c.glow = true
		chips.append(c)


## Electric arcs crackling out of a destroyed heavy unit.
func _arcs(p: Vector2, n: int, speed: float) -> void:
	for k in n:
		var d := Vector2.from_angle(randf() * TAU)
		game._vfx(p + d * 10.0, d * randf_range(0.5, 1.0) * speed, randf_range(0.15, 0.3), 3.0, 7.0, Color(0.6, 0.9, 1.0, 0.95), Color(0.3, 0.5, 1.0, 0.0), true)


func _crash(b: Body) -> void:
	var gun := b.ty == Data.GUNSHIP
	var r := 120.0 if gun else 80.0
	_flash(b.pos, r)
	game._ring(b.pos, 3.2 if gun else 2.4)
	game._explosion(b.pos, r, 1.6 if gun else 1.2)
	game._sparks(b.pos, int(game.fx.tier["sparks"]) * 2)
	_burst(b.pos, Vector2.from_angle(randf() * TAU), 6 if gun else 4, [Color(0.25, 0.27, 0.22), Color(0.2, 0.21, 0.23)], 5.0, 260.0)
	_wreck(b.tex, b.pos, b.ang, b.size * 0.9, 2.5, b.ty, b.tier)
	game.trauma = minf(game.trauma + (0.25 if gun else 0.12), 0.6)
	if b.ty == Data.JET:
		game.sfx.play("big_boom", randf_range(0.95, 1.1), -6.0)
	else:
		game.sfx.play("crash", randf_range(0.9, 1.05), -2.0 if gun else -5.0)


# --- Update -----------------------------------------------------------------

func _process(delta: float) -> void:
	air.queue_redraw()
	queue_redraw()
	if game == null:
		return
	if float(game.t) < last_t:
		clear()  # A new run.
	last_t = float(game.t)
	set_tier(game.fx.tier)
	if int(game.state) != playing or game.hitstop > 0.0:
		return
	var dt := 1.0 / 60.0 if game.smoke else minf(delta, 0.05)
	_update_later(dt)
	_update_bodies(dt)
	_update_flying(dt)
	_update_chips(dt)


func _update_later(dt: float) -> void:
	var i := 0
	while i < later.size():
		var e: Array = later[i]
		e[0] -= dt
		if e[0] > 0.0:
			i += 1
			continue
		later.remove_at(i)
		var p: Vector2 = e[1]
		game._explosion(p, e[2], e[3])
		game._sparks(p, int(int(game.fx.tier["sparks"]) * 0.5) + 1)
		match String(e[4]):
			"boom":
				game._ring(p, e[2] / 40.0)
				game.sfx.play("boom", randf_range(0.9, 1.2), -9.0)
				game.trauma = minf(game.trauma + 0.05, 0.6)
			"pop":
				game.sfx.play("grenade", randf_range(1.2, 1.4), -14.0)


func _update_bodies(dt: float) -> void:
	var drag := maxf(0.0, 1.0 - 7.0 * dt)
	var i := 0
	while i < bodies.size():
		var b := bodies[i]
		b.life -= dt
		if b.life <= 0.0:
			if b.kind == DOOMED:
				_siege_blast(b)
			bodies.remove_at(i)
			continue
		match b.kind:
			CORPSE:
				b.pos += b.vel * dt
				b.vel *= drag
				b.ang += b.spin * dt
				b.spin *= drag
				b.vz -= 12.0 * dt
				b.z = maxf(0.0, b.z + b.vz * dt * 0.1)
			WRECK:
				b.burn -= dt
				if b.burn > 0.0:
					_smoulder(b, dt, b.burn / (b.total - 1.2))
			DOOMED:
				# The Colossus shudders and glows as its hull blows apart.
				b.pos += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 3.0
				_smoulder(b, dt, 1.5)
		i += 1


func _siege_blast(b: Body) -> void:
	_flash(b.pos, 200.0)
	game._ring(b.pos, 4.5)
	game._ring(b.pos, 6.5)
	game._explosion(b.pos, 170.0, 1.8)
	game._sparks(b.pos, int(game.fx.tier["sparks"]) * 4)
	_burst(b.pos, Vector2.from_angle(randf() * TAU), 12, [Color(0.3, 0.3, 0.32), Color(0.45, 0.2, 0.15), Color(0.2, 0.21, 0.23)], 8.0, 420.0)
	for k in 3:
		_part(b.tex, b.pos, Vector2.from_angle(randf() * TAU), b.size * 0.22, 480.0, Color(0.3, 0.3, 0.3))
	_wreck(b.tex, b.pos, b.ang, b.size, 4.5, b.ty, b.tier)
	game.trauma = 0.6
	game.hitstop = maxf(game.hitstop, 0.06)
	game.sfx.play("big_boom", 0.85, 0.0)
	game.sfx.play("debris", 0.8, -6.0)


## Fire and smoke rising from a wreck, `heat` (0-1.5) scaling how much.
func _smoulder(b: Body, dt: float, heat: float) -> void:
	b.emit += dt * (6.0 + 10.0 * heat) * clampf(b.size / 80.0, 0.6, 2.0)
	while b.emit >= 1.0:
		b.emit -= 1.0
		var at := b.pos + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)) * b.size
		if randf() < 0.45 * heat:
			game._vfx(at, Vector2(randf_range(-10.0, 10.0), -40.0), randf_range(0.25, 0.45), 4.0, b.size * 0.22, Color(1.0, 0.7, 0.25, 0.85), Color(0.8, 0.15, 0.05, 0.0), true)
		else:
			game._vfx(at, Vector2(randf_range(-12.0, 12.0), -35.0), randf_range(0.9, 1.6), b.size * 0.12, b.size * 0.4, Color(0.18, 0.17, 0.16, 0.5), Color(0.1, 0.1, 0.1, 0.0), false)


func _update_flying(dt: float) -> void:
	var i := 0
	while i < flying.size():
		var b := flying[i]
		b.life -= dt
		b.pos += b.vel * dt
		b.ang += b.spin * dt
		var landed := false
		if b.kind == FALL:
			# Spiral down: spin faster, slow, sink towards the ground.
			b.spin *= 1.0 + 1.6 * dt
			b.vel *= maxf(0.0, 1.0 - 0.8 * dt)
			b.z = clampf(b.life / b.total, 0.0, 1.0)
			b.emit += dt * 40.0
			while b.emit >= 1.0:
				b.emit -= 1.0
				var tail := b.pos - b.vel.normalized() * b.size * 0.2
				if randf() < 0.4:
					game._vfx(tail, -b.vel * 0.1, 0.3, 5.0, b.size * 0.25, Color(1.0, 0.7, 0.3, 0.9), Color(0.8, 0.2, 0.05, 0.0), true)
				else:
					game._vfx(tail, Vector2(0.0, -20.0), randf_range(0.7, 1.2), b.size * 0.12, b.size * 0.35, Color(0.15, 0.14, 0.14, 0.55), Color(0.1, 0.1, 0.1, 0.0), false)
			if b.ty == Data.GUNSHIP and randf() < dt * 3.0:
				game._explosion(b.pos + Vector2.from_angle(randf() * TAU) * b.size * 0.25, 40.0, 0.5)
				game.sfx.play("boom", randf_range(1.0, 1.2), -12.0)
			landed = b.life <= 0.0
			if landed:
				_crash(b)
		else:
			b.vz -= GRAVITY * dt
			b.z += b.vz * dt / 400.0
			if b.burn > 0.0:
				b.burn -= dt
				if randf() < dt * 30.0:
					game._vfx(b.pos, Vector2(0.0, -20.0), 0.8, 6.0, 22.0, Color(0.16, 0.15, 0.15, 0.5), Color(0.1, 0.1, 0.1, 0.0), false)
			if b.z <= 0.0:
				landed = true
				if b.ty >= 0:
					# A tank turret slamming back down.
					game._explosion(b.pos, 30.0, 0.5)
					game._ring(b.pos, 1.4)
					game.sfx.play("debris", randf_range(0.9, 1.1), -7.0)
					_wreck(b.tex, b.pos, b.ang, b.size, 1.5, b.ty, 0)
		if landed or b.life <= 0.0:
			flying.remove_at(i)
			continue
		i += 1


func _update_chips(dt: float) -> void:
	var drag := maxf(0.0, 1.0 - 2.5 * dt)
	var i := 0
	while i < chips.size():
		var c := chips[i]
		c.life -= dt
		if c.life <= 0.0:
			chips.remove_at(i)
			continue
		c.pos += c.vel * dt
		c.vz -= GRAVITY * dt
		c.z += c.vz * dt
		if c.z <= 0.0:
			# Bounce once, then skid to a stop.
			c.z = 0.0
			c.vz = -c.vz * 0.3 if c.vz < -120.0 else 0.0
			c.vel *= 0.55
			c.spin *= 0.5
		else:
			c.vel *= drag
		c.ang += c.spin * dt
		i += 1


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	for b in bodies:
		var k := b.life / b.total
		var fade := clampf(b.life / 0.35, 0.0, 1.0)
		match b.kind:
			CORPSE:
				# A white flash, then charred; knocked flat and fading.
				var age := 1.0 - k
				var hot := clampf(1.0 - age * 6.0, 0.0, 1.0)
				var col := CHARRED.lerp(Color(1.8, 1.7, 1.6), hot)
				col.a = fade
				var squash := 1.0 + 0.25 * minf(age * 5.0, 1.0)
				_sprite(self, b.tex, b.pos, b.ang, Vector2(b.size * squash, b.size / squash) * (1.0 + b.z * 0.4), col, b.z)
			WRECK:
				var col := CHARRED
				col.a = clampf(b.life / 1.2, 0.0, 1.0)
				_sprite(self, b.tex, b.pos, b.ang, Vector2(b.size, b.size), col, 0.0)
			DOOMED:
				var flick := 0.5 + 0.5 * sin(b.life * 40.0)
				var col := Color(1.0, 1.0, 1.0).lerp(Color(1.8, 1.0, 0.6), flick * (1.0 - k))
				_sprite(self, b.tex, b.pos, b.ang, Vector2(b.size, b.size), col, 0.0)


func _draw_air() -> void:
	for c in chips:
		var a := clampf(c.life / 0.3, 0.0, 1.0)
		var h := c.z / 300.0
		if c.z > 1.0:
			air.draw_set_transform(c.pos + Vector2(6.0, 8.0) * h * 3.0, c.ang, Vector2.ONE)
			air.draw_rect(Rect2(-c.size * 0.5, -c.size * 0.3, c.size, c.size * 0.6), Color(0.0, 0.0, 0.0, 0.3 * a))
		air.draw_set_transform(c.pos - Vector2(0.0, c.z * 0.5), c.ang, Vector2.ONE * (1.0 + h * 0.6))
		var col := c.col
		col.a = a
		if c.glow:
			air.draw_rect(Rect2(-c.size, -c.size * 0.5, c.size * 2.0, c.size), Color(col.r, col.g, col.b, 0.25 * a))
			air.draw_colored_polygon(PackedVector2Array([Vector2(-c.size, 0.0), Vector2(0.0, -c.size * 0.45), Vector2(c.size, 0.0), Vector2(0.0, c.size * 0.45)]), Color(1.0, 1.0, 1.0, a))
		else:
			air.draw_rect(Rect2(-c.size * 0.5, -c.size * 0.3, c.size, c.size * 0.6), col)
	for b in flying:
		if b.kind == FALL:
			var hot := clampf((1.0 - b.z) * 2.0, 0.0, 1.0)
			var col := Color.WHITE.lerp(Color(0.55, 0.45, 0.4), hot)
			_sprite(air, b.tex, b.pos, b.ang, Vector2(b.size, b.size) * (0.75 + 0.25 * b.z), col, b.z * 0.8)
		else:
			var lift := clampf(b.z, 0.0, 2.0)
			var col := Color(b.emit, b.emit, b.emit)
			_sprite(air, b.tex, b.pos - Vector2(0.0, lift * 40.0), b.ang, Vector2(b.size, b.size) * (1.0 + lift * 0.35), col, lift)
	air.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A unit sprite, centred on `p`, with a drop shadow that moves further off
## the higher it is.
func _sprite(on: CanvasItem, tex: Texture2D, p: Vector2, ang: float, size: Vector2, col: Color, height: float) -> void:
	if tex == null:
		return
	var rect := Rect2(-size * 0.5, size)
	if height > 0.02:
		on.draw_set_transform(p + Vector2(14.0, 20.0) * height, ang, Vector2.ONE)
		on.draw_texture_rect(tex, rect, false, Color(0.0, 0.0, 0.0, 0.35 * col.a))
	on.draw_set_transform(p, ang, Vector2.ONE)
	on.draw_texture_rect(tex, rect, false, col)
	on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
