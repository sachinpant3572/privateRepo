extends RefCounted
## Hunting (scripts/hunting.gd): the Hollin store's gear and pelts, where
## the rifle comes out, and the save. Run from tests/test_runner.gd
## (TEST_MODULES); `t` is the runner.

const TESTS := ["test_hunting_gear_and_ground", "test_hunting_pelts_and_save", "test_hunting_shoots_a_deer_in_season",
	"test_hunting_poaching_gives_a_star", "test_hunting_skins_a_carcass"]
const Hunting = preload("res://scripts/hunting.gd")
const IN_GROUND := Vector3(0, 0, -4200)
const Calendar = preload("res://scripts/calendar.gd")


func test_hunting_gear_and_ground(t) -> void:
	await t._new_game(false)
	var game = t.game
	var h = game.hunting
	t.check(h != null, "the game has a hunting module")
	t.check(Hunting.in_ground(IN_GROUND) and not Hunting.in_ground(Vector3(500, 0, -4100))
			and not Hunting.in_ground(Vector3.ZERO), "the ground is the back-range forest, less the lab valley")
	game.cash = 1000
	t.check(h.gear_block("ammo") != "" and not h.buy_gear("ammo"), "no rounds before a rifle")
	t.check(h.buy_gear("rifle") and h.rifle and h.ammo == 10 and game.cash == 580, "the rifle comes with a box of rounds")
	t.check(not h.buy_gear("rifle") and game.cash == 580, "one rifle is enough")
	t.check(not h.licence_valid() and h.buy_gear("licence") and h.licence_valid() and game.cash == 520,
			"a licence costs $60 and covers today")
	t.check(not h.buy_gear("licence"), "no second licence while one runs")
	for i in 3:
		h.buy_gear("ammo")
	t.check(h.ammo == Hunting.AMMO_MAX and h.gear_block("ammo") != "" and not h.buy_gear("ammo"),
			"rounds stop at %d, got %d" % [Hunting.AMMO_MAX, h.ammo])
	game.cash = 5
	h.ammo = 0
	t.check(not h.buy_gear("ammo") and h.ammo == 0 and game.cash == 5, "no rounds without the cash")
	# The rifle only comes out on foot in the ground.
	t._place_player_at(IN_GROUND + Vector3(0, 300, 0))
	t.check(h.can_shoot(), "on foot in the ground the rifle is out")
	game.hud._process(0.016)
	t.check(game.hud.touch == null or game.hud.touch.labels.get("attack", "") == "SHOOT",
			"the attack button reads SHOOT")
	t._place_player_at(Vector3(0, 300, 0))
	t.check(not h.can_shoot(), "in the city it stays put")
	h.rifle = false
	t._place_player_at(IN_GROUND + Vector3(0, 300, 0))
	t.check(not h.can_shoot(), "no rifle, no shooting")


func test_hunting_pelts_and_save(t) -> void:
	await t._new_game(false)
	var game = t.game
	var h = game.hunting
	var mm = game.missions
	h.pelts = {"deer": 2, "rabbit": 1}
	t.check(h.pelts_total() == 3 and h.pelt_value() == 2 * 90 + 14, "the store values deer and rabbit")
	game.cash = 0
	t.check(h.sell_pelts() == 194 and game.cash == 194 and h.pelts.is_empty(), "selling empties the bag")
	h.rifle = true
	h.ammo = 23
	h.licence_until = 9
	h.pelts = {"coyote": 3}
	mm.save_enabled = true
	mm.save_path = "user://test_save_hunting.json"
	mm.save_game()
	h.load_save({})
	t.check(not h.rifle and h.ammo == 0 and h.licence_until == -1 and h.pelts.is_empty(), "load_save({}) clears it")
	mm.load_game()
	t.check(h.rifle and h.ammo == 23 and h.licence_until == 9 and h.pelts == {"coyote": 3},
			"rifle, rounds, licence and pelts survive save and load, got %s" % [h.to_save()])
	h.load_save({"rifle": true, "ammo": 999, "pelts": {"deer": 50, "unicorn": 2}})
	t.check(h.ammo == Hunting.AMMO_MAX and h.pelts == {"deer": Hunting.PELT_MAX}, "a bad save is clamped")
	h.load_save({"pelts": {"lion": 1, "deer": 4, "coyote": 4, "rabbit": 4}})
	t.check(not h.pelts.has("lion") and h.pelts_total() == Hunting.PELT_MAX,
			"an old save's lion pelt is dropped and the total is capped, got %s" % [h.pelts])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mm.save_path))


## A game with the hunter on foot in the ground: rifle and rounds, the
## calendar on the first day of `season`, the clock at noon, a licence if
## `licensed`. Returns the wildlife node.
func _hunter(t, season: String, licensed: bool):
	await t._new_game(false)
	var game = t.game
	var atm = game.atmosphere
	atm.minutes_per_second = 0.0
	atm.weather_changes = false
	atm.hour = 12.0
	var d := 0
	while Calendar.season_of(d) != season:
		d += 1
	game.calendar.set_day(d)
	var h = game.hunting
	h.rifle = true
	h.ammo = 10
	h.licence_until = d + 5 if licensed else -1
	Wanted.clear()
	t._place_player_at(IN_GROUND + Vector3(0, 300, 0))
	await t._frames(1)
	return atm.get("wildlife")


## One `kind` standing `dist` m straight ahead of the player.
func _ahead(t, w, kind: String, dist := 15.0) -> Dictionary:
	var p = t.game.player
	var made: Array = w.spawn(kind, p.global_position + p.forward() * dist, 1)
	return made[0] if not made.is_empty() else {}


## In autumn, with a licence, a deer in the sights dies to one round, the
## round is spent, and nobody comes after the hunter; a shot with nothing
## in the sights spends a round and hits nothing.
func test_hunting_shoots_a_deer_in_season(t) -> void:
	var w = await _hunter(t, "autumn", true)
	var h = t.game.hunting
	t.check(w != null, "the atmosphere has its wildlife")
	if w == null:
		return
	t.check(h.can_shoot(), "the rifle is out in the ground")
	t.check(h.shoot() == null and h.ammo == 9, "a shot at nothing hits nothing and spends a round")
	var deer := _ahead(t, w, "deer")
	t.check(not deer.is_empty() and deer.alive, "a deer stands ahead")
	if deer.is_empty():
		return
	var kills := []
	w.killed.connect(func(kind, _pos, by): kills.append([kind, by]))
	var hit = h.shoot()
	t.check(hit == deer and not deer.alive, "the round drops the deer")
	t.check(kills == [["deer", "rifle"]], "the kill is the player's rifle's, got %s" % [kills])
	t.check(h.ammo == 8, "two rounds spent, %d left" % h.ammo)
	t.check(Wanted.level == 0, "a licensed kill in season brings no star")
	var deer2 := _ahead(t, w, "deer", 12.0)
	h.ammo = 1
	t.game.hunting.shoot()
	t.check(not deer2.is_empty() and not deer2.alive and h.ammo == 0, "a second deer drops with the last round")
	t.check(h.shoot() == null and h.ammo == 0, "an empty rifle does nothing")


## A kill is poaching, a wanted star and a message, without a valid
## licence, out of season (deer in winter), or of a mountain lion in any
## season; a licensed coyote in winter is fine, and so is a lion shot while
## it stalks the hunter (self-defence).
func test_hunting_poaching_gives_a_star(t) -> void:
	var cases := [
		["autumn", false, "deer", 1, "no licence"],
		["winter", true, "deer", 1, "deer out of season"],
		["autumn", true, "lion", 1, "a mountain lion, never open"],
		["winter", true, "coyote", 0, "a coyote, open all year"],
		["autumn", false, "lion", 0, "a stalking lion, self-defence", "stalk"],
	]
	for c in cases:
		var w = await _hunter(t, c[0], c[1])
		if w == null:
			t.check(false, "the atmosphere has its wildlife")
			return
		var a := _ahead(t, w, c[2])
		if c.size() > 5 and not a.is_empty():
			a.state = c[5]
		var hit = t.game.hunting.shoot()
		t.check(hit != null and not a.alive, "%s: the shot kills" % c[4])
		t.check(Wanted.level == c[3], "%s: wanted %d, got %d" % [c[4], c[3], Wanted.level])
	Wanted.clear()


## Skinning: at a carcass the HUD offers SKIN; E takes it and gives a pelt;
## a full bag refuses and leaves the carcass; a live animal is no carcass.
func test_hunting_skins_a_carcass(t) -> void:
	var w = await _hunter(t, "autumn", true)
	if w == null:
		t.check(false, "the atmosphere has its wildlife")
		return
	var h = t.game.hunting
	var deer := _ahead(t, w, "deer", 8.0)
	t.check(h.prompt().is_empty(), "no skinning prompt with no carcass near")
	h.shoot()
	t.check(not deer.is_empty() and not deer.alive, "the deer is down")
	t._place_player_at(deer.position + Vector3(1.0, 0.0, 0.0))
	var pr: Array = h.prompt()
	t.check(pr.size() == 2 and pr[1] == "SKIN" and String(pr[0]).contains("deer"), "the HUD offers to skin it, got %s" % [pr])
	h.pelts = {"rabbit": Hunting.PELT_MAX}
	t.check(h.try_interact() and h.pelts_total() == Hunting.PELT_MAX and w.animals.has(deer),
			"a full bag takes no more and the carcass stays")
	h.pelts = {}
	t.check(h.try_interact() and h.pelts == {"deer": 1}, "skinning gives a deer pelt, got %s" % [h.pelts])
	t.check(not w.animals.has(deer) and h.prompt().is_empty(), "the carcass is gone")
	t.check(not h.try_interact(), "nothing left to skin")
	h.pelts = {}
	var live := _ahead(t, w, "rabbit", 1.5)
	t.check(not live.is_empty() and h.prompt().is_empty() and not h.try_interact(), "a live rabbit is not a carcass")
	# Only the player's own rifle kills of the kinds the store buys give a
	# pelt: roadkill and a punched animal are ruined, and a lion is not skinned.
	for c in [["deer", "car", "roadkill"], ["rabbit", "player", "a punched rabbit"], ["lion", "rifle", "a shot lion"]]:
		var a := _ahead(t, w, c[0], 1.5)
		t.check(not a.is_empty(), "%s: one stands near" % c[2])
		if a.is_empty():
			continue
		w.kill(a, Vector3.ZERO, c[1])
		t.check(not a.alive and h.prompt().is_empty() and not h.try_interact() and h.pelts.is_empty(),
				"%s gives no pelt, got %s" % [c[2], h.pelts])
		w.take_carcass(a)
