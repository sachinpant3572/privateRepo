extends RefCounted
## The hero's special moves, on their own buttons and charged by kills:
## - Meteor Slam: a leap toward the camera and a crater (everything nearby
##   destroyed, heavies badly hurt).
## - Blitz Dash: a lightning streak that cuts down everything in a wide line.
## - Meteor Blitz: both together (one pressed while the other is under way):
##   a leaping streak at the biggest horde and a far bigger crater. Its power
##   comes from the timing (see slam_timing).
## The state (charges, timers) lives in game.gd, which calls in here.

const Data := preload("res://data.gd")

var g: Node


func _init(game: Node) -> void:
	g = game


## Meteor Slam: up, a moment in the air, then down hard.
func slam() -> void:
	if g.state != g.State.PLAYING or g.slam_t >= 0.0 or g.combo_t >= 0.0 or g.slam_charge < g.slam_need:
		return
	if g.dash_t > 0.0:
		start_combo(0.7 + 0.3 * (1.0 - g.dash_t / g.BLITZ_TIME))  # Later in the dash: more momentum.
		return
	g.slam_t = 0.0
	g.slam_charge = 0.0
	g.slam_need = minf(g.slam_need + 100.0, 900.0)
	g.slams += 1
	g.invuln = maxf(g.invuln, g.SLAM_RISE + g.SLAM_HANG + g.SLAM_FALL + 0.3)
	g.hud.set_jump(0.0)
	g.hud.show_banner("METEOR SLAM!", Color(1.0, 0.55, 0.2))
	g.hero.slam_launch()
	g._ring(g.player, 2.5)
	g.sfx.play("slam_launch")


func update_slam(dt: float) -> void:
	if g.slam_t < 0.0:
		if g.autoplay and g.slam_charge >= g.slam_need and g.e_count > 40:
			slam()
		return
	g.slam_t += dt
	var total: float = g.SLAM_RISE + g.SLAM_HANG + g.SLAM_FALL
	g.invuln = maxf(g.invuln, 0.2)
	var h := 1.0
	if g.slam_t < g.SLAM_RISE:
		h = sin(g.slam_t / g.SLAM_RISE * PI * 0.5)
	elif g.slam_t > g.SLAM_RISE + g.SLAM_HANG:
		var k: float = (g.slam_t - g.SLAM_RISE - g.SLAM_HANG) / g.SLAM_FALL
		h = 1.0 - k * k
	g.hero.set_air(clampf(h, 0.0, 1.0), clampf(g.slam_t / total, 0.0, 1.0))
	if g.slam_t >= total:
		g.slam_t = -1.0
		g.hero.set_air(0.0, 0.0)
		slam_impact()


## Power of a Meteor Blitz started during a slam: PERFECT at the top of
## the jump, less on the way up or down; pressing both together is GREAT.
func slam_timing() -> float:
	if g.slam_t < 0.12:
		return 0.8
	if g.slam_t < g.SLAM_RISE:
		return 0.6 + 0.4 * g.slam_t / g.SLAM_RISE
	if g.slam_t <= g.SLAM_RISE + g.SLAM_HANG:
		return 1.0
	return 1.0 - 0.4 * (g.slam_t - g.SLAM_RISE - g.SLAM_HANG) / g.SLAM_FALL


func start_combo(q: float) -> void:
	if g.slam_t < 0.0:  # The slam's charge goes too.
		g.slam_charge = 0.0
		g.slam_need = minf(g.slam_need + 100.0, 900.0)
		g.slams += 1
		g.hud.set_jump(0.0)
	g.blitz_charge = 0.0
	g.hud.set_blitz(0.0)
	g.slam_t = -1.0
	g.dash_t = 0.0
	g.combo_t = 0.0
	g.combo_q = q
	g.combos += 1
	g.combo_from = g.player
	g.combo_to = densest_point()
	g.blitz_hit = {}
	g.blitz_cuts = 0
	g.invuln = maxf(g.invuln, g.MBLITZ_TIME + 0.4)
	g.hero.slam_launch()
	g.hero.dash((g.combo_to - g.player).angle())
	var grade := "PERFECT!" if q >= 0.97 else ("GREAT!" if q >= 0.8 else "GOOD")
	g.hud.show_banner("METEOR BLITZ! %s" % grade, Color(1.0, 0.8, 0.3).lerp(Color(0.6, 0.95, 1.0), 1.0 - q))
	g.sfx.play("dash_launch")
	g.sfx.play("slam_launch")


## The middle of the biggest crowd within reach (or straight ahead).
func densest_point() -> Vector2:
	var me: Vector2 = g.player
	var best: Vector2 = me + g.facing * 400.0
	var best_n := 0
	var count: int = g.e_count
	var pos: PackedVector2Array = g.e_pos
	var hp: PackedFloat32Array = g.e_hp
	var reach2: float = g.MBLITZ_REACH * g.MBLITZ_REACH
	for a in range(0, count, maxi(1, int(count / 40.0))):
		var c := pos[a]
		if hp[a] <= 0.0 or c.distance_squared_to(me) > reach2:
			continue
		var n := 0
		for b in count:
			if hp[b] > 0.0 and pos[b].distance_squared_to(c) < 62500.0:
				n += 1
		if n > best_n:
			best_n = n
			best = c
	return best


## The flight: a leaping arc along a straight line, cutting through the path.
func update_combo(dt: float) -> void:
	g.combo_t += dt
	var k: float = clampf(g.combo_t / g.MBLITZ_TIME, 0.0, 1.0)
	var from: Vector2 = g.player
	g.player = g.combo_from.lerp(g.combo_to, k * k * (3.0 - 2.0 * k))
	blitz_cut(from, g.player)
	g.hero.set_air(sin(k * PI), k)
	g.invuln = maxf(g.invuln, 0.2)
	if int(g.t * 60.0) % 2 == 0:
		g._vfx(g.player, Vector2.ZERO, 0.3, 18.0, 4.0, Color(1.0, 0.8, 0.4, 0.6), Color(0.6, 0.9, 1.0, 0.0), true)
	if k >= 1.0:
		g.combo_t = -1.0
		g.hero.set_air(0.0, 0.0)
		g.blitz_from = g.combo_from
		blitz_end()
		slam_impact(g.combo_q)


## power 0 = a plain Meteor Slam; a Meteor Blitz passes its power (0.6..1)
## for a wider, harder crater.
func slam_impact(power: float = 0.0) -> void:
	g.cur_src = "slam" if power <= 0.0 else "combo"
	var big := 0.0 if power <= 0.0 else 0.3 + 0.7 * power
	var r: float = g.SLAM_RADIUS * g.area_mult * (1.0 + big)
	var dmg: float = (300.0 + 30.0 * g.level) * (1.0 + 2.0 * big)
	var grow: float = (1.0 + 0.2 * g._diff_t() / 60.0) * g.hp_mult
	for j in g.e_count:
		if g.e_hp[j] <= 0.0:
			continue
		var ty: int = g.e_type[j]
		var to: Vector2 = g.e_pos[j] - g.player
		var d := to.length()
		var rr: float = r + g.t_radius[ty]
		if d < rr:
			if ty == Data.ELITE or ty == Data.GUNSHIP or ty == Data.SIEGE:
				# The heavies survive a slam, badly hurt.
				g._damage(j, (g.t_hp[ty] * grow * g.big_mult * (0.4 + 0.35 * big)) / g.dmg_mult + dmg, g.player, false)
			else:
				g._damage(j, g.e_hp[j] * 4.0 / g.dmg_mult + dmg, g.player, false)  # Destroyed, shields and all.
		elif d < rr * 1.7 and ty < Data.TANK:
			g.e_pos[j] += to / maxf(d, 1.0) * 140.0 * (1.0 - (d - rr) / (rr * 0.7))
			g._damage(j, dmg * 0.3, g.player, false)
	if g.boss_on and g.player.distance_to(g.boss_pos) < r + g.BOSS_RADIUS:
		g._damage_boss(g.boss_max * (0.06 + 0.08 * big) / g.dmg_mult, false)
	var r2 := r * r * 1.7
	for i in g.b_count:
		if g.b_pos[i].distance_squared_to(g.player) < r2:
			g.b_life[i] = 0.0
	g._decal(g.player, r * 0.8)
	g._explosion(g.player, r * 0.55, 2.0)
	var n := 8 + int(10.0 * big)
	for k in n:
		g._explosion(g.player + Vector2.from_angle(TAU * k / n + randf()) * r * randf_range(0.4, 0.75), 90.0 + 60.0 * big, 1.2 + big)
	g._ring(g.player, r / g.RING_SIZE * 1.2)
	g._ring(g.player, r / g.RING_SIZE * 0.6)
	g._sparks(g.player, int(g.fx.tier["sparks"]) * 6)
	g.hero.slam_land(r)
	g.trauma = 1.0
	g.hitstop = maxf(g.hitstop, 0.1 + 0.1 * big)
	g.hud.flash(Color(1.0, 0.75, 0.45, 0.45 + 0.3 * big))
	g.sfx.play("slam_impact")
	if big > 0.0:
		g._ring(g.player, r / g.RING_SIZE * 1.6)
		g.sfx.play("dash_hit")
	if not g.smoke:
		Input.vibrate_handheld(120)


func blitz_need() -> float:
	return g.BLITZ_NEED * maxf(0.4, 1.0 - 0.08 * g.dash_lvl)


func blitz_len() -> float:
	return g.BLITZ_LEN * (1.0 + 0.05 * g.dash_lvl)


func blitz_width() -> float:
	return (g.BLITZ_WIDTH + 6.0 * g.dash_lvl) * g.area_mult


## Blitz Dash: along the stick (or the facing when still), through everything.
func dash() -> void:
	if g.state != g.State.PLAYING or g.dash_t > 0.0 or g.combo_t >= 0.0 or g.blitz_charge < blitz_need():
		return
	if g.slam_t >= 0.0:
		start_combo(slam_timing())
		return
	g.blitz_charge = 0.0
	g.hud.set_blitz(0.0)
	g.dash_t = g.BLITZ_TIME
	g.dash_dir = g.move_vec.normalized() if g.move_vec.length_squared() > 0.01 else g.facing
	g.blitz_from = g.player
	g.blitz_hit = {}
	g.blitz_cuts = 0
	g.invuln = maxf(g.invuln, g.BLITZ_TIME + 0.35)
	g.hero.dash(g.dash_dir.angle())
	g.hud.show_banner("BLITZ DASH!", Color(0.6, 0.95, 1.0))
	g._ring(g.player, 2.5)
	g.sfx.play("dash_launch")


## Cuts every enemy within the dash's width of the stretch just travelled.
func blitz_cut(a: Vector2, b: Vector2) -> void:
	g.cur_src = "blitz"
	var w := blitz_width()
	var dmg: float = 200.0 + 25.0 * g.level
	var grow: float = (1.0 + 0.2 * g._diff_t() / 60.0) * g.hp_mult
	for j in g.e_count:
		if g.e_hp[j] <= 0.0 or g.blitz_hit.has(j):
			continue
		var ty: int = g.e_type[j]
		var closest := Geometry2D.get_closest_point_to_segment(g.e_pos[j], a, b)
		var rr: float = w + g.t_radius[ty]
		if g.e_pos[j].distance_squared_to(closest) > rr * rr:
			continue
		g.blitz_hit[j] = true
		g.blitz_cuts += 1
		if g.blitz_cuts <= 12:
			g.hero.effect("spark_star", g.e_pos[j], 0.18, 14.0, 40.0, Color(0.7, 0.95, 1.0), 6)
		if ty == Data.ELITE or ty == Data.GUNSHIP or ty == Data.SIEGE:
			g._damage(j, (g.t_hp[ty] * grow * g.big_mult * 0.3) / g.dmg_mult + dmg, b, false)
		else:
			g._damage(j, g.e_hp[j] * 4.0 / g.dmg_mult + dmg, b, false)
	if g.boss_on and not g.blitz_hit.has(-1):
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(g.boss_pos, a, b)
		if g.boss_pos.distance_to(c) < w + g.BOSS_RADIUS:
			g.blitz_hit[-1] = true
			g._damage_boss(g.boss_max * 0.03 / g.dmg_mult, false)
	var w2 := w * w
	for i in g.b_count:
		if g.b_pos[i].distance_squared_to(Geometry2D.get_closest_point_to_segment(g.b_pos[i], a, b)) < w2:
			g.b_life[i] = 0.0


## The dash lands: a lightning trail along the path, a slice flash, a jolt.
func blitz_end() -> void:
	var path: Vector2 = g.player - g.blitz_from
	var side := path.orthogonal().normalized()
	var pts := PackedVector2Array()
	for k in 9:
		pts.append(g.blitz_from + path * (k / 8.0) + side * (0.0 if k == 0 or k == 8 else randf_range(-18.0, 18.0)))
	g.bolts.append([pts, 0.35])
	g.bolts.append([PackedVector2Array([g.blitz_from + side * 10.0, g.player + side * 10.0]), 0.2])
	g._ring(g.player, 3.0)
	if g.blitz_cuts > 0:
		g.sfx.play("dash_hit")
		g.hitstop = maxf(g.hitstop, 0.05)
		g.trauma = minf(g.trauma + 0.35, 0.8)
		g.hud.flash(Color(0.7, 0.95, 1.0, 0.25))
