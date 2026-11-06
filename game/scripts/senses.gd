extends RefCounted
## What people on foot hear and see, how each kind of person reacts, and how
## long the reaction takes to start.
##
## Events are broadcast once: emit() walks the "perceivers" group (people who
## add themselves; see humanoid.gd) and tells each one in range. Sounds carry
## all round to their hearing radius; sights need the 65° view cone, except
## within AWARE metres where people notice anything. There are no raycasts:
## from the top-down camera a cone and a radius read right and cost nothing.
## States rather than events (a car coming at someone, the wanted player in
## view, a body on the ground) are found by each pedestrian's staggered scan
## and reported to it through the same perceive() call.
##
## choose() picks the reaction class from the person's category and
## personality; delay() is the reaction time, 0.15-0.6 s: loud and close is
## fast, sound takes distance / 343 m/s to arrive, the timid are quicker and
## the elderly slower. The perceiver queues the reaction and starts it on
## the first physics tick at or after that time.

## kind: [hear radius m, see radius m, danger 0..3, base delay s, near m].
## Danger orders reactions: a new event replaces the current reaction only
## when it is at least as dangerous.
const KINDS := {
	"gunshot": [60.0, 0.0, 3, 0.15, 12.0],
	"explosion": [80.0, 0.0, 3, 0.15, 20.0],
	"aim": [0.0, 15.0, 3, 0.2, 15.0],
	"car_threat": [0.0, 10.0, 3, 0.15, 10.0],
	"crash": [35.0, 30.0, 2, 0.2, 7.0],
	"fight": [12.0, 22.0, 2, 0.28, 4.0],
	"scream": [14.0, 0.0, 2, 0.22, 5.0],
	"car_on_sidewalk": [0.0, 14.0, 2, 0.2, 6.0],
	"body": [0.0, 12.0, 2, 0.4, 4.0],
	"horn": [22.0, 0.0, 1, 0.15, 6.0],
	"siren": [45.0, 0.0, 1, 0.35, 10.0],
	"car_close": [0.0, 6.0, 1, 0.15, 3.0],
	"wanted": [0.0, 18.0, 1, 0.35, 5.0],
	"sprint_past": [0.0, 4.0, 0, 0.2, 2.0],
	"rain": [0.0, 0.0, 0, 0.5, 0.0],
}
## cos(65°): the half-angle of the view cone.
const CONE_COS := 0.4226
const AWARE := 3.0
const MIN_DELAY := 0.15
const MAX_DELAY := 0.6

const CATEGORIES := ["general", "office", "worker", "tourist", "gang", "elderly", "athlete", "shopkeeper", "medic", "cop"]
const PERSONALITIES := ["calm", "brave", "timid", "curious"]
## Every reaction class and how long it holds, in seconds.
const HOLD := {
	"look": 2.2, "startle": 1.1, "dodge": 0.9, "duck": 1.1, "cower": 4.5, "flee": 7.0, "film": 6.0,
	"call": 4.5, "cheer": 4.0, "shout": 2.4, "approach": 9.0, "help": 10.0, "hurry": 12.0, "avoid": 5.0,
	"hands_up": 4.0, "investigate": 6.0,
}
## Reactions that get the body away or under cover; one of these replaces a
## reaction to something equally dangerous (see humanoid.gd _replaces()).
const ESCAPE := ["flee", "cower", "duck", "dodge", "hands_up"]


## Tells every perceiver in range about `kind` at `pos`. `source` (who or
## what caused it) is never told about itself. data: "loud" scales the
## hearing radius; "from" is where the danger is when it differs from pos;
## "victim" is skipped too (a punched person reacts to the hit, not the
## fight). Witness calls are only a gesture: crimes reach Wanted through the
## existing take_hit / vehicle paths, never from here.
## Returns how many people noticed.
static func emit(tree: SceneTree, kind: String, pos: Vector3, source = null, data := {}) -> int:
	if tree == null or not KINDS.has(kind):
		return 0
	var k: Array = KINDS[kind]
	var hear: float = k[0] * float(data.get("loud", 1.0))
	var see: float = k[1]
	var reach := maxf(maxf(hear, see), AWARE)
	var n := 0
	for who in tree.get_nodes_in_group("perceivers"):
		if who == source or not who.can_perceive():
			continue
		var to: Vector3 = pos - who.global_position
		to.y = 0.0
		var d := to.length()
		if d > reach:
			continue
		if d <= hear or d <= AWARE or (d <= see and sees(who, pos)):
			who.perceive(kind, pos, source, d, data)
			n += 1
	return n


## True when `pos` is inside who's view cone or within AWARE metres.
static func sees(who: Node3D, pos: Vector3) -> bool:
	var to := pos - who.global_position
	to.y = 0.0
	var d := to.length()
	if d <= AWARE:
		return true
	var fwd := -who.global_basis.z
	fwd.y = 0.0
	return fwd.normalized().dot(to / d) >= CONE_COS


## Whether `distance` counts as near for this kind of event.
static func is_near(kind: String, distance: float) -> bool:
	return distance <= float(KINDS.get(kind, [0, 0, 0, 0, 0.0])[4])


## The reaction class for a person of `category` and `personality` to an
## event of `kind`, `near` or not. "ignore" means carry on.
static func choose(category: String, personality: String, kind: String, near := false) -> String:
	var brave := personality == "brave"
	var timid := personality == "timid"
	var curious := personality == "curious"
	if category == "cop":
		match kind:
			"gunshot", "explosion", "fight", "scream", "crash", "body", "car_on_sidewalk", "aim":
				return "investigate"
			"car_threat":
				return "dodge"
			"car_close", "horn":
				return "startle" if near else "look"
			"sprint_past", "siren", "wanted":
				return "look"
		return "ignore"
	match kind:
		"gunshot", "explosion":
			if category == "elderly" or (timid and near):
				return "cower"
			if near:
				return "duck"
			if category == "gang" and brave:
				return "look"
			return "flee"
		"aim":
			if category == "gang" and brave:
				return "shout"
			return "hands_up"
		"car_threat":
			return "dodge"
		"fight":
			if timid:
				return "call" if category == "elderly" else "flee"
			match category:
				"gang":
					return "cheer"
				"tourist":
					return "film"
				"office", "shopkeeper", "elderly":
					return "call"
				"medic":
					return "look"
				"worker", "athlete":
					return "shout" if brave else "look"
			if curious:
				return "film"
			return "shout" if brave else "look"
		"scream":
			return "flee" if timid else "look"
		"crash":
			if near:
				return "flee" if timid else "startle"
			match category:
				"medic":
					return "help"
				"tourist", "gang":
					return "film"
				"office", "shopkeeper":
					return "call"
				"worker":
					return "approach"
				"elderly":
					return "look"
			if curious:
				return "film"
			return "approach" if brave else "look"
		"car_on_sidewalk":
			if category in ["gang", "worker"] or brave:
				return "shout"
			return "flee"
		"body":
			if category == "medic" or (brave and category != "gang"):
				return "help"
			if category == "gang":
				return "avoid"
			if timid:
				return "flee"
			if curious or category == "tourist":
				return "film"
			return "call"
		"horn":
			if near:
				return "startle"
			if category == "gang" or (brave and category == "worker"):
				return "shout"
			return "look"
		"siren":
			return "hurry" if category == "gang" else "look"
		"car_close":
			if category in ["gang", "worker"] or brave:
				return "shout"
			return "startle"
		"wanted":
			if category == "gang":
				return "look"
			if curious or category == "tourist":
				return "film"
			if category in ["office", "shopkeeper"]:
				return "call"
			if timid or category == "elderly":
				return "avoid"
			return "look" if brave else "avoid"
		"sprint_past":
			if category == "elderly":
				return "startle"
			if category == "gang":
				return "shout"
			return "look"
		"rain":
			if category in ["athlete", "gang"] or brave:
				return "ignore"
			return "hurry"
	return "ignore"


## Seconds from the event to the reaction, MIN_DELAY..MAX_DELAY.
static func delay(kind: String, distance: float, personality := "calm", category := "general") -> float:
	var k: Array = KINDS.get(kind, [0.0, 0.0, 0, 0.3, 0.0])
	var d: float = k[3]
	if k[0] > 0.0:
		d += distance / 343.0
	match personality:
		"timid":
			d -= 0.04
		"brave":
			d += 0.03
	match category:
		"elderly":
			d += 0.12
		"athlete", "cop":
			d -= 0.03
	return clampf(d, MIN_DELAY, MAX_DELAY)


## A danger rank for a reaction kind (KINDS), -1 for none.
static func danger(kind: String) -> int:
	return int(KINDS[kind][2]) if KINDS.has(kind) else -1
