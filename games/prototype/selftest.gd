extends RefCounted
## Self-tests run by CI: the smoke test (-- --smoke: a bot plays the stage,
## then every item at once, the defenses, a maxed legal build and the final
## push) and the screenshots (-- --shots=<dir>). They drive game.gd through
## `g`, the game node.

const Data := preload("res://data.gd")

var g: Node


func _init(game: Node) -> void:
	g = game


func grant(items: Dictionary) -> void:
	for id in items:
		if Data.WEAPON_IDS.has(id):
			g.weapons[id] = items[id]
		else:
			g.powers[id] = items[id]
	g._recalc()
	g.hp = g.max_hp


func run_smoke() -> void:
	print("SMOKE: start")
	g._set_quality("Ultra")
	g._start(true)
	var n := 0
	while g.state != g.State.OVER and n < 60 * 420:
		await g.get_tree().process_frame
		n += 1
	print("SMOKE: stage run ended state=%d t=%.0f level=%d kills=%d boss_spawned=%s" % [g.state, g.t, g.level, g.kills, g.boss_spawned])
	print(g.rep.text(g, g._results_text(g.boss_dead_t >= 0.0), g._cards_line()))
	if not check(g.t > 30.0 and g.kills > 0, "the bot played the stage"):
		return
	# Every weapon and power at once (more than the slots allow) for a few
	# seconds, so every code path runs at least once.
	g._start(true)
	var all := {}
	for id in Data.WEAPON_IDS:
		all[id] = 8
	for id in Data.POWER_IDS:
		all[id] = 8
	grant(all)
	for id in Data.EVOLUTIONS:
		g.evolved[id] = true
	g._recalc()
	g.god = true
	g.t = 200.0
	await frames(60 * 8)
	print("SMOKE: everything-at-once kills=%d logic_worst=%.1f" % [g.kills, g.logic_worst])
	if not check(g.synergies.size() == Data.SYNERGIES.size(), "every synergy unlocks"):
		return
	# Defense: the dome blocks a hit, Fortify cuts damage, the EMP wipes bullets.
	g._start(true)
	g.god = false
	grant({"barrier": 8, "emp": 8, "repair": 8, "fortify": 8})
	g._recalc()
	g.invuln = 0.0
	var hp_before: float = g.hp
	g._hurt(50.0)
	if not check(g.hp == hp_before and g.barrier_t > 0.0, "Barrier Dome blocks a hit"):
		return
	g.barrier_t = 0.0
	g.barrier_cd = 99.0
	g.invuln = 0.0
	g._hurt(50.0)
	if not check(hp_before - g.hp < 50.0 * 0.75 and g.hp < hp_before, "Fortify cuts damage"):
		return
	g._ebullet(g.player + Vector2(100.0, 0.0), Vector2.ZERO, 5.0, 5.0)
	g._emp()
	if not check(g.b_life[g.b_count - 1] <= 0.0, "EMP wipes enemy bullets"):
		return
	print("SMOKE: defense ok")
	# Second run: a heavy legal build (4 weapons, 4 powers plus the defense
	# slot) maxed and evolved, near the boss.
	g._start(true)
	g.weapons = {}  # Drop the starting rifle so the slots hold exactly this build.
	grant({"flame": 8, "drones": 8, "mines": 8, "grenade": 8, "titan": 8, "magnet": 8, "stomp": 8, "luck": 8, "fortify": 8})
	for id in ["flame", "drones", "mines", "grenade"]:
		g.evolved[id] = true
	g._recalc()
	var lb_offers: Array = g._make_offers(2, false, [])
	if not check(lb_offers.all(func(o): return o.get("limit", false)), "a maxed build is offered Limit Breaks"):
		return
	g.god = true
	g.t = 280.0
	await frames(60 * 70)
	g.god = false
	print("SMOKE: all-items run t=%.0f state=%d enemies=%d kills=%d boss_max=%.0f boss_fight=%.1fs boss_dead=%s logic_worst=%.1f" % [g.t, g.state, g.e_count, g.kills, g.boss_max, (g.boss_dead_t if g.boss_dead_t >= 0.0 else g.t) - g.STAGE_TIME, g.boss_dead_t >= 0.0, g.logic_worst])
	if not check(g.kills > 100, "the all-items run killed enemies"):
		return
	if not check(g.boss_dead_t < 0.0 or g.boss_dead_t - g.STAGE_TIME > 8.0, "a maxed build does not kill the boss in seconds"):
		return
	# The final push: killing the Colossus starts it, and clearing it wins.
	g._start(true)
	g.god = true
	g.t = g.STAGE_TIME
	await frames(10)
	if not check(g.boss_on, "the Colossus spawns at the stage time"):
		return
	g.boss_hp = 1.0
	g._damage_boss(1000.0, true)
	await frames(5)
	if not check(g.type_alive[Data.SIEGE] >= 1 and g.state == g.State.PLAYING, "the final push spawns Siege Colossi"):
		return
	for j in g.e_count:
		if g.e_type[j] == Data.SIEGE and g.e_hp[j] > 0.0:
			g._damage(j, 1.0e9, g.e_pos[j], true)
	# Wait for the win itself: hitstops (slams, Meteor Blitzes) pause the clock.
	var waited := 0
	while g.state != g.State.OVER and waited < int(60 * (Data.FINAL_TIME + 25.0)):
		await g.get_tree().process_frame
		waited += 1
	print("SMOKE: final push state=%d final_clear=%.1f jets_seen=%s" % [g.state, g.final_clear_t, str(g.peak_enemies > 0)])
	if not check(g.state == g.State.OVER, "clearing the final push wins the stage"):
		return
	g.god = false
	print("SMOKE: passed")
	g.get_tree().quit(0)


func run_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	g.god = true
	await frames(5)
	await save_shot(dir, "menu")
	for tier_name in ["Ultra", "High", "Medium", "Low"]:
		g._set_quality(tier_name)
		g._start(true)
		grant({"rifle": 5, "rockets": 4, "halo": 4, "tesla": 3, "airstrike": 3, "scatter": 2, "overclock": 3, "explosive": 2})
		g.t = 200.0
		await frames(60 * 3)
		# A fixed ring of every enemy type around a still player, made tough so
		# it survives until the screenshot.
		g.bot_still = true
		showcase()
		await frames(30)
		await save_shot(dir, "play_" + tier_name.to_lower())
		if tier_name == "Ultra":
			# Every unit type dying at once (deaths.gd): mid-blast, then the
			# wrecks and falling aircraft a moment later.
			for i in g.e_count:
				g.e_hp[i] = 0.0
				g._kill(i)
			await frames(8)
			await save_shot(dir, "deaths")
			await frames(30)
			await save_shot(dir, "deaths_late")
		g.bot_still = false
		if tier_name == "Ultra":
			g.bot_cards = false
			g.pending_levels += 1
			await frames(3)
			await save_shot(dir, "cards")
			g._bot_pick()
			grant({"rifle": 8, "overclock": 3})
			g._open_chest()
			await frames(90)
			await save_shot(dir, "chest")
			g._on_chest_collected()
			g.bot_cards = true
			g.t = g.STAGE_TIME - 1.0
			await frames(5)
			g.bot_still = true
			g.boss_pos = g.player + Vector2(0.0, -330.0)
			await frames(90)
			await save_shot(dir, "boss")
			g.bot_still = false
			# A fully geared hero: helmet, pauldrons, wings, aura and an evolved weapon.
			g._start(true)
			grant({"rail": 8, "drones": 6, "sentry": 5, "mines": 4, "flame": 8, "grenade": 4, "titan": 6, "shield": 4, "dodge": 3, "thorns": 3, "regen": 3, "burn": 5, "cryo": 3, "might": 3, "bullettime": 3})
			g.evolved["rail"] = true
			g._recalc()
			g.t = 150.0
			g.bot_still = true
			await frames(60 * 4)
			await save_shot(dir, "gear")
			g.bot_still = false
			g._to_menu()
			g._show_costumes()
			await frames(10)
			await save_shot(dir, "costumes")
	print("SHOTS: done")
	g.get_tree().quit(0)


func showcase() -> void:
	var kinds := [Data.TROOPER, Data.TROOPER, Data.SHIELD, Data.GRENADIER, Data.TROOPER, Data.TANK, Data.TROOPER, Data.HELI, Data.SHIELD, Data.TROOPER, Data.GRENADIER, Data.ELITE]
	for k in 36:
		var ty: int = kinds[k % kinds.size()]
		g._spawn_enemy(ty)
		var i: int = g.e_count - 1
		g.e_pos[i] = g.player + Vector2.from_angle(TAU * k / 36.0) * (190.0 + (k % 3) * 80.0)
		g.e_hp[i] = 1.0e6
	# The late-game units, outside the ring.
	for spot in [[Data.SIEGE, Vector2(0.0, 470.0)], [Data.GUNSHIP, Vector2(-250.0, -440.0)], [Data.JET, Vector2(260.0, -470.0)]]:
		g._spawn_enemy(spot[0])
		var i: int = g.e_count - 1
		g.e_pos[i] = g.player + spot[1]
		g.e_ang[i] = PI
		g.e_hp[i] = 1.0e6


func save_shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := dir.path_join(shot_name + ".png")
	g.get_viewport().get_texture().get_image().save_png(path)
	var units := 0
	for n in g.unit_n:
		units += n
	print("SHOTS: saved %s quality=%s state=%d enemies=%d unit_sprites=%d shots=%d rockets=%d enemy_bullets=%d gems=%d sparks=%d rings=%d boss=%s" % [path, g.quality, g.state, g.e_count, units, g.s_count, g.k_count, g.b_count, g.g_count, g.p_count, g.r_count, g.boss_on])


func frames(n: int) -> void:
	for _i in n:
		await g.get_tree().process_frame


func check(ok: bool, what: String) -> bool:
	if not ok:
		printerr("SMOKE FAILED: " + what)
		g.get_tree().quit(1)
	return ok
