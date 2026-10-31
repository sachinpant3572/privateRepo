extends RefCounted
## Hunting (scripts/hunting.gd): the Hollin store's gear and pelts, where
## the rifle comes out, and the save. Run from tests/test_runner.gd
## (TEST_MODULES); `t` is the runner.

const TESTS := ["test_hunting_gear_and_ground", "test_hunting_pelts_and_save"]
const Hunting = preload("res://scripts/hunting.gd")
const IN_GROUND := Vector3(0, 0, -4200)


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
	h.pelts = {"deer": 2, "rabbit": 1, "lion": 1}
	t.check(h.pelts_total() == 4 and h.pelt_value() == 2 * 90 + 14, "the store values deer and rabbit, not the lion")
	game.cash = 0
	t.check(h.sell_pelts() == 194 and game.cash == 194 and h.pelts == {"lion": 1}, "selling keeps the lion pelt")
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mm.save_path))
