extends "res://scripts/missions/mission.gd"
## Mission 2, Empty Rooms: Nia turns up at Moreau House, angry, and hands
## Jules the phone with Teo's last messages. At Teo's ransacked apartment
## Jules searches for clues; at the Floodline Clinic, Remy (beaten by men
## asking about Teo) points at the man in gold.

const Cast = preload("res://scripts/missions/cast.gd")

## [point in the apartment's street frame (see Mission.near), what it is]
const CLUES := [
	[Vector3(2.5, 0, -1.0), "A torn shipping label: \"IRONWHARF - W9\"."],
	[Vector3(9.8, 0, -6.8), "A gold cufflink, engraved with an A."],
	[Vector3(-9.5, 0, -5.3), "A Blue Lantern matchbook. \"Ask for C.\" in Teo's writing."],
]
const SEARCH_RANGE := 2.2
const SEARCH_TIME := 1.4


func _init() -> void:
	reward = 300
	unlocks = "Phone"


func start_point() -> Vector3:
	return front("moreau_house")


func run() -> void:
	if not await card("EMPTY ROOMS", "Act 1  ·  Mission 2"):
		return
	var nia = npc("Nia", Cast.NIA, near("moreau_house", Vector3(18.0, 0, 0)))
	nia.walk_to(near("moreau_house", Vector3(1.6, 0, 0)))
	await until(func(): return nia.arrived, 12.0)
	if ended:
		return
	if not await say([
		["Nia", "Twelve years, Jules. Not a call. Not a letter."],
		["Jules", "I came as soon as I heard. Where's Teo?"],
		["Nia", "Gone four days. His phone's dead and somebody tossed his place."],
		["Nia", "Your old number still works. Teo's been texting it. Read them."],
	], true):
		return

	# The phone.
	manager.phone_unlocked = true
	var opened: int = manager.hud.phone.open_count
	objective("Check your phone (tap PHONE)")
	manager.hud.pulse_phone(true)
	await until(func(): return manager.hud.phone.open_count > opened)
	manager.hud.pulse_phone(false)
	if not await wait(0.3):
		return
	if not await say([
		["Jules", "\"The river crates.\" \"The man in gold.\" What did you get into, Teo?"],
		["Nia", "Meet me at his apartment. Bring your eyes."],
	]):
		return
	nia.walk_to(near("moreau_house", Vector3(30.0, 0, 0)))

	# Teo's apartment.
	if not await reach(curb("teo_apartment"), "Go to Teo's apartment", 8.0, false, "Teo's apartment"):
		return
	nia.queue_free()
	nia = npc("Nia", Cast.NIA, near("teo_apartment", Vector3(-2.0, 0, 0)))
	if not await reach(near("teo_apartment", Vector3(-0.5, 0, 0)), "Meet Nia at the door", 2.5, true, "Nia"):
		return
	if not await say([["Nia", "Look around outside. Whoever did this was looking for something, and they were sloppy."]]):
		return

	var found := 0
	var left: Array = []
	for c in CLUES:
		var at: Vector3 = near("teo_apartment", c[0])
		left.append({"pos": at, "text": c[1], "mark": mark(at, "Clue", BLUE)})
	while not left.is_empty():
		objective("Search for clues (%d/%d)" % [found, CLUES.size()])
		var near = null
		for clue in left:
			if Vector2(clue.pos.x - game.player.global_position.x, clue.pos.z - game.player.global_position.z).length() < SEARCH_RANGE:
				near = clue
		if near != null and game.player.vehicle == null:
			prompt("Search: E", "SEARCH")
			if Controls.just_pressed("interact"):
				clear_prompt()
				game.player.controllable = false
				game.player.gesture = "search"
				if not await wait(SEARCH_TIME):
					return
				game.player.gesture = ""
				game.player.controllable = true
				unmark(near.mark)
				left.erase(near)
				found += 1
				line("Clue", near.text)
		else:
			clear_prompt()
		if not await tick():
			return
	clear_prompt()
	if not await wait(1.5):
		return
	if not await say([
		["Nia", "A cufflink with an A. That's Aurum money."],
		["Nia", "Last night a High Water kid got jumped by men asking about Teo. Remy. He's at the Floodline Clinic."],
		["Jules", "Then that's where we go."],
	]):
		return

	# The clinic.
	if not await reach(curb("floodline_clinic"), "Go to the Floodline Clinic", 8.0, false, "Floodline Clinic"):
		return
	var clinic := front("floodline_clinic")
	var remy = npc("Remy", Cast.REMY, near("floodline_clinic", Vector3(1.2, 0, 0)))
	remy.gesture = "cower"
	remy.max_health = 30.0
	nia.global_position = near("floodline_clinic", Vector3(-2.2, 0, 0))
	nia.reset_physics_interpolation()
	nia.mode = Npc.Mode.IDLE
	if not await reach(clinic, "Talk to Remy", 2.6, true, "Remy"):
		return
	remy.gesture = ""
	await say([
		["Remy", "Men in gold jackets. Suits, sunglasses, the whole thing."],
		["Remy", "Kept asking where Teo hid \"the crates\". Said the man in gold wants them back."],
		["Jules", "Then I'll find the man in gold first."],
		["Nia", "Careful. In this town gold buys the police too."],
	], true)
