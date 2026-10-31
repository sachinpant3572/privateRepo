extends "res://scripts/vehicle.gd"
## A flyable helicopter (#82): the civilian Skylark and the police one.
##
## Built on vehicle.gd for what it shares with a car: the class row
## (vehicle_classes.gd "heli"), damage, fire and the explosion (car_fire.gd),
## debris, dents, the see-through x-ray and getting in and out
## (take_player / release_player). The flying is its own: the car physics
## steer wheels on a road, and a helicopter has neither (the reasons and the
## numbers are in HANDOFF-helicopters.md).
##
## Arcade but weighed: the rotor spools up before it lifts, the collective
## climbs and sinks, the stick tilts the body to accelerate (the tilt eases
## in, so it carries its weight round), drag slows it, and with nothing held
## it hovers where it is. The ground is Terrain (not a collider): the skids
## sit on the highest ground under them or on a roof below. A fast
## touchdown or a crash hurts it, a heavy one wrecks it.
##
## Out of the "vehicles" group while it flies (above LOW): traffic,
## parking, pedestrians and the car spawners read that group as cars on
## the ground. "helicopters" holds them all.

const HeliKit = preload("res://scripts/kits/heli_kit.gd")

const G := 9.8
## Seconds for the rotor to spin up from still, and to run down.
const SPOOL_UP := 4.0
const SPOOL_DOWN := 8.0
## Highest the collective takes it over the land under it (metres): high
## enough to clear the towers by a long way, low enough that the view stays
## within what the streaming keeps loaded (top_down_camera.gd caps it).
const CEILING := 250.0
## Sink rate at full DOWN; near the ground the descent is held to what
## braking at CUSHION m/s² stops by TOUCH_SPEED at the skids, so a held
## DOWN sets it down softly.
const SINK := 12.0
const CUSHION := 4.0
const TOUCH_SPEED := 1.5
## How hard the collective chases the wanted climb rate (1/s).
const HOLD := 6.0
## Horizontal: the most the tilt gives (m/s²), how quickly the tilt follows
## the stick (m/s³), how hard it chases the wanted speed (1/s) and the drag
## (per m/s of speed).
const ACCEL := 8.0
const TILT_RATE := 18.0
const RESPONSE := 1.1
const DRAG := 0.0009
## Backwards and sideways at full stick (m/s).
const BACK_SPEED := 10.0
const SIDE_SPEED := 9.0
## How fast a turn builds (rad/s²).
const YAW_ACCEL := 3.0
## Extra lift with the skids near the ground, gone by one rotor diameter up.
const GROUND_EFFECT := 0.15
## Skid friction on the ground (m/s²).
const SKID_GRIP := 8.0
## Touchdown: m/s straight into the ground or a roof the skids take without
## harm, and the damage per m/s beyond (before the class's x1.3).
const LAND_SPEED := 3.0
const LAND_HURT := 9.0
## A rise ahead taller than this over the skids is a hillside to stop at,
## not a slope to skid up.
const STEP := 0.8
## Getting out: on the ground or this low; higher it is a bail-out.
const LOW := 3.0
## A support this far over the land under it is a roof.
const ROOF := 1.0
## Ground under this is water (city.gd draws the water plane at -0.55).
const WATER_Y := -0.5
## Into a wall (or a hillside) slower than this (m/s) it only slides along:
## no bounce and no harm, so holding the stick against a tower after the
## blow doesn't grind it down.
const NUDGE := 5.0
## Drawn rotor speeds at full rpm (rad/s); the blur disc shows above DISC_AT.
const ROTOR_SPIN := 14.0
const TAIL_SPIN := 30.0
const DISC_AT := 0.45

## Hard standings over the land it sets down on (heliports.gd's aprons, no
## colliders): [centre Vector2, yaw, half size Vector2, top].
static var decks: Array = []

## Marks an aircraft for the camera, HUD, touch controls and streaming.
var flies := true
## Rotor speed: 0 still, 1 flying.
var rpm := 0.0
## Height of the skids over the ground or roof under them (m).
var altitude := 0.0
## Height over the land itself, roofs aside: what CEILING counts.
var above_land := 0.0
var landed := true
## The support under the skids is a roof (well over the land).
var on_roof := false
## What the pilot asks for: horizontal velocity, turn rate, climb rate.
var _v_des := Vector3.ZERO
var _yaw_want := 0.0
var _vy_want := 0.0
## The horizontal acceleration the tilt gives now (eases toward the stick's).
var _tilt_a := Vector3.ZERO
var _yaw_v := 0.0
var _land := 0.0
var _floor := 0.0
var _rotor: MeshInstance3D
var _tail: MeshInstance3D
var _disc: MeshInstance3D
var _disc_mat: StandardMaterial3D
var _shadow: MeshInstance3D
var _shadow_mat: StandardMaterial3D
var _pivot := 1.3
var _hit_frame := -100
## Something solid (a wall top, a prop) took the skids this frame.
var _stood := false


func _ready() -> void:
	add_to_group("vehicles")
	add_to_group("helicopters")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = L.VEHICLES
	collision_mask = L.WORLD | L.PROPS | L.VEHICLES | L.CHARACTERS
	if not HeliKit.is_heli(kind):
		kind = "heli"
	is_police = kind == "police_heli"
	_spec = HeliKit.spec(kind)
	_cls = VehicleClasses.of(kind)
	max_speed = _spec.max_speed
	mass = _spec.mass
	max_health = _spec.health
	health = max_health
	shows_rider = false
	_size = _spec.size
	_game = get_tree().get_first_node_in_group("game")
	var k: float = _spec.scale
	_pivot = 1.3 * k
	# The cabin, the tail boom and the rotor disc: boxes for the body and a
	# thin cylinder that strikes walls the blades would.
	for b in [[Vector3(0, 1.15, -0.3), Vector3(2.2, 2.3, 4.0)], [Vector3(0, 1.7, 3.6), Vector3(0.6, 0.9, 3.8)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b[1] * k
		shape.shape = box
		shape.position = b[0] * k
		add_child(shape)
	var disc := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = _spec.rotor
	cyl.height = 0.3
	disc.shape = cyl
	disc.position = _spec.rotor_at
	add_child(disc)
	_build_model()
	_land = _land_under(global_position)
	_floor = _land
	if global_position.y > _land + LOW:
		# Placed in the air (tests, probes): flying already.
		rpm = 1.0
		landed = false
		altitude = global_position.y - _land
		above_land = altitude
		remove_from_group("vehicles")
	else:
		global_position.y = _land
	_update_shadow()


func _physics_process(delta: float) -> void:
	if driver == Driver.NONE and rpm <= 0.0 and landed and velocity == Vector3.ZERO:
		motion = Vector3.ZERO
		return # parked: nothing to fly until someone gets in or something hits it
	var piloted := not wrecked and driver != Driver.NONE
	_v_des = Vector3.ZERO
	_yaw_want = 0.0
	_vy_want = 0.0
	if piloted and driver == Driver.PLAYER:
		_pilot_input()
	rpm = move_toward(rpm, 1.0 if piloted else 0.0, delta / (SPOOL_UP if piloted else SPOOL_DOWN))
	_fly(delta, piloted)
	motion = Vector3(velocity.x, 0.0, velocity.z)
	speed = motion.dot(-global_basis.z)
	_spin_rotors(delta)
	_body_pose()
	_update_shadow()
	_update_group()
	_flash_lights(delta)


## The player's stick and collective (Controls). With the view turning
## behind it the stick is the helicopter's own: up flies ahead, down backs
## off, a lean turns it toward the lean (as a car steers by stick); north up
## it flies where the stick points on screen and turns to face that way.
func _pilot_input() -> void:
	var s := Controls.move_vector()
	var c := Controls.collective()
	_vy_want = c * (float(_spec.climb) if c > 0.0 else SINK)
	if s.length() < 0.12:
		return
	var top: float = _spec.max_speed
	var fwd := -global_basis.z
	var right := global_basis.x
	var cam = Controls.camera
	if cam != null and cam.has_method("turns") and cam.turns():
		var f := -s.y
		var r := s.x
		var a := atan2(r, f)
		if absf(a) < 2.2:
			_yaw_want = -signf(a) * float(_spec.yaw) * smoothstep(0.0, 1.2, absf(a)) * minf(s.length(), 1.0)
		_v_des = fwd * (f * top if f > 0.0 else f * BACK_SPEED) + right * r * SIDE_SPEED
	else:
		var w := Controls.world_move()
		w.y = 0.0
		_v_des = w * top
		var gap := wrapf(atan2(-w.x, -w.z) - rotation.y, -PI, PI)
		_yaw_want = clampf(gap * 2.5, -float(_spec.yaw), float(_spec.yaw))


func _fly(delta: float, piloted: bool) -> void:
	var pos := global_position
	# Lift: the rotor's thrust at this rpm, more in ground effect, less hurt.
	var lift: float = float(_spec.lift) * G * rpm * rpm
	lift *= 1.0 + GROUND_EFFECT * clampf(1.0 - altitude / (2.0 * float(_spec.rotor)), 0.0, 1.0)
	lift *= lerpf(0.6, 1.0, clampf(health / max_health, 0.0, 1.0))
	var want_vy := _vy_want
	var vy := velocity.y
	# The slowing the cushion asks for as the ground comes up, given ahead
	# so the descent keeps to it instead of trailing it.
	var brake := 0.0
	if piloted:
		if want_vy < 0.0:
			var cushion := -sqrt(TOUCH_SPEED * TOUCH_SPEED + 2.0 * CUSHION * maxf(altitude, 0.0))
			if cushion > want_vy:
				want_vy = cushion
				brake = clampf(CUSHION * vy / cushion, 0.0, 2.0 * CUSHION)
		want_vy = minf(want_vy, maxf((CEILING - above_land) * 0.5, 0.0))
		if landed and _vy_want <= 0.0:
			want_vy = -1.0 # sits on its skids
			brake = 0.0
	elif not wrecked:
		want_vy = -1.5 # nobody at the controls: it settles while the rotor runs down
	var thrust := 0.0 if wrecked else clampf((want_vy - vy) * HOLD + G + brake, 0.0, lift)
	vy += (thrust - G) * delta
	# Horizontal: the tilt follows the stick's wish, eased, as far as the
	# rotor has the power; nothing while the skids are down.
	var vh := Vector3(velocity.x, 0.0, velocity.z)
	var want_a := Vector3.ZERO
	if piloted and not landed:
		want_a = ((_v_des - vh) * RESPONSE).limit_length(ACCEL * clampf((lift / G - 0.5) * 2.0, 0.0, 1.0))
	_tilt_a = _tilt_a.move_toward(want_a, TILT_RATE * delta)
	vh += _tilt_a * delta
	vh -= vh * vh.length() * DRAG * delta
	if landed:
		vh = vh.move_toward(Vector3.ZERO, SKID_GRIP * delta)
		_tilt_a = Vector3.ZERO
	# Turning: only off the ground; a wreck spins down.
	var yaw_goal := _yaw_want if piloted and not landed else 0.0
	if wrecked and not landed:
		yaw_goal = 3.0
	_yaw_v = move_toward(_yaw_v, yaw_goal, YAW_ACCEL * delta)
	if absf(_spin) > 0.0:
		_yaw_v = clampf(_yaw_v + _spin, -4.0, 4.0) # a glancing blow swings it round
		_spin = 0.0
	if landed and not wrecked:
		_yaw_v = 0.0
	rotation.y = wrapf(rotation.y + _yaw_v * delta, -PI, PI)
	# A hillside ahead (Terrain is no collider): it stops there, along the
	# slope, and a fast one is a crash.
	var step := vh * delta
	if step.length_squared() > 1e-8:
		var dir := step.normalized()
		var probe := pos + step + dir * 3.0 * float(_spec.scale)
		if _ground(probe.x, probe.z) - pos.y > STEP:
			var n := Terrain.normal(probe.x, probe.z)
			var out := Vector3(n.x, 0.0, n.z)
			out = out.normalized() if out.length_squared() > 1e-4 else -dir
			var closing := -vh.dot(out)
			if closing > 0.0:
				vh += out * closing
				_strike(closing, probe + Vector3.UP * 1.0, out)
	velocity = Vector3(vh.x, vy, vh.z)
	var before := velocity
	_stood = false
	move_and_slide()
	_collisions(before)
	# On the ground (or a roof): the skids stop it there.
	pos = global_position
	_land = _land_under(pos)
	var floor_y := _land
	var roof := _roof_under(pos)
	on_roof = roof > _land + ROOF
	floor_y = maxf(floor_y, roof)
	if _stood:
		floor_y = maxf(floor_y, global_position.y)
	_floor = floor_y
	if pos.y < floor_y:
		var n := Vector3.UP if roof >= _land else Terrain.normal(pos.x, pos.z)
		_touchdown(-before.dot(n), Vector3(before.x, 0.0, before.z).length())
		global_position.y = floor_y
		velocity -= n * minf(velocity.dot(n), 0.0)
		velocity.y = maxf(velocity.y, 0.0)
	altitude = global_position.y - floor_y
	above_land = global_position.y - _land
	# Down only once the skids took it (a centimetre up at speed it is
	# still falling: the touchdown comes next frame).
	landed = altitude < 0.05 and absf(velocity.y) <= 0.05


## The highest drawn ground under the skids.
func _land_under(p: Vector3) -> float:
	var k: float = _spec.scale
	var best := -INF
	for off: Vector3 in [Vector3(-1.08, 0, -1.75), Vector3(1.08, 0, -1.75), Vector3(-1.08, 0, 1.45), Vector3(1.08, 0, 1.45)]:
		var q := p + global_basis * (off * k)
		best = maxf(best, _ground(q.x, q.z))
	return best


## The ground at x, z: the drawn land, or a heliport's apron over it.
static func _ground(x: float, z: float) -> float:
	var g := Terrain.height(x, z) - Terrain.drop(x, z)
	for d in decks:
		var q: Vector2 = (Vector2(x, z) - d[0]).rotated(d[1])
		if absf(q.x) <= d[2].x and absf(q.y) <= d[2].y:
			g = maxf(g, d[3])
	return g


## Height over what it would land on (the ground, a roof or a deck).
func height_over_floor() -> float:
	return global_position.y - _floor


## The nearest open ground to `p` (no roof over the land, no water),
## rings out to 80 m; `p` itself if none is found.
func open_ground_near(p: Vector3) -> Vector3:
	if not is_inside_tree():
		return p
	var space := get_world_3d().direct_space_state
	var game = get_tree().get_first_node_in_group("game")
	var city = game.get("city") if game != null else null
	var plan = city.plan if city != null else null
	for r in [0.0, 6.0, 12.0, 20.0, 30.0, 45.0, 60.0, 80.0]:
		for k in (1 if r == 0.0 else 12):
			var q := p + Vector3(r, 0.0, 0.0).rotated(Vector3.UP, TAU * k / 12.0)
			var g := _ground(q.x, q.z)
			if _wet(plan, Vector2(q.x, q.z), g):
				continue
			var ray := PhysicsRayQueryParameters3D.create(Vector3(q.x, g + 200.0, q.z), Vector3(q.x, g - 0.5, q.z), L.WORLD, [get_rid()])
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or float(hit.position.y) <= g + ROOF:
				return Vector3(q.x, g, q.z)
	return p


## Water at (x, z) with ground g: the sea and the banks lie under the water
## plane (-0.55, city.gd); the plan's river and park lakes are drawn over flat
## ground.
static func _wet(plan, p: Vector2, g: float) -> bool:
	if g < WATER_Y:
		return true
	if plan == null:
		return false
	if plan.is_water_point(p):
		return true
	for lake in plan.lakes:
		if Geometry2D.is_point_in_polygon(p, lake):
			return true
	return false


## The top of a roof (or anything solid) under it, or -INF.
func _roof_under(p: Vector3) -> float:
	if not is_inside_tree():
		return -INF
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, Vector3(p.x, _land - 0.5, p.z), L.WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else -INF


## Set down at `into` m/s into the ground (`slide` m/s along it): soft up to
## LAND_SPEED, harder hurts, and a heavy one wrecks it.
func _touchdown(into: float, slide: float) -> void:
	if into <= LAND_SPEED:
		return
	if Engine.get_physics_frames() - _hit_frame < 6:
		return # one blow, however many frames it takes
	_hit_frame = Engine.get_physics_frames()
	Fx.crash(global_position, into, driver == Driver.PLAYER)
	_damage((into - LAND_SPEED) * LAND_HURT + maxf(slide - 12.0, 0.0) * 2.0)
	_crumple(global_position + Vector3.UP * 0.5, Vector3.UP, into)
	if into > 8.0 and get_parent() != null:
		for i in 3:
			CarDebris.throw(get_parent(), global_position + Vector3.UP * 0.8, Vector3(rng.randf_range(-5, 5), rng.randf_range(3, 7), rng.randf_range(-5, 5)), body_color, 0.7)


## Hit a hillside (or anything) at `impact` m/s, at `at`, pushed along `n`.
func _strike(impact: float, at: Vector3, n: Vector3) -> void:
	if impact < NUDGE or Engine.get_physics_frames() - _hit_frame < 6:
		return
	_hit_frame = Engine.get_physics_frames()
	Fx.crash(at, impact, driver == Driver.PLAYER)
	_damage(impact * 1.5)
	_jolt(at, n * impact)
	_crumple(at, n, impact)


## What move_and_slide ran into: people are struck, small props go down,
## another vehicle shares the blow by mass, a wall or a tower takes it all
## and bounces it off; a flat top under it is a touchdown.
func _collisions(before: Vector3) -> void:
	var struck := []
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other != null and other.has_method("hit_by_vehicle"):
			other.hit_by_vehicle(self, before.length())
			continue
		if before.length() > Breakables.MIN_SPEED and not Breakables.prop_of(col).is_empty():
			Breakables.smash(col, before, driver == Driver.PLAYER)
			_damage(2.0)
			continue
		if struck.has(other):
			continue
		struck.append(other)
		var n := col.get_normal()
		var impact := maxf(-before.dot(n), 0.0)
		var vehicle: bool = other != null and other.has_method("bump")
		if n.y > 0.7 and not vehicle:
			_stood = true
			_touchdown(impact, Vector3(before.x, 0.0, before.z).length())
			continue
		if not vehicle:
			# A wall: it stops there and slides along it (move_and_slide
			# leaves the speed into it, which would build up frame on frame
			# and strike again); a blow of NUDGE or more comes back a little.
			velocity -= n * minf(velocity.dot(n), 0.0)
			if impact >= NUDGE:
				velocity += Vector3(n.x, 0.0, n.z) * impact * 0.35
				_strike(impact, col.get_position(), n)
			continue
		if impact < 3.0:
			continue
		var players: bool = driver == Driver.PLAYER or other.get("driver") == Driver.PLAYER
		Fx.crash(col.get_position(), impact, players)
		var mine := mass / (mass + float(other.mass))
		_damage(impact * 1.2 * (1.0 - mine))
		other.bump(before * 1.2 * mine, col.get_position())
		_jolt(col.get_position(), n * impact)
		_crumple(col.get_position(), n, impact)


## Wrecked: the fire (it goes up the next frame, car_fire.gd), pieces flying
## and the wreck falls.
func _damage(amount: float, raw := false) -> void:
	var was := wrecked
	super(amount, raw)
	if wrecked and not was:
		if _fire == null:
			_fire = CarFire.ignite(self)
		if get_parent() != null:
			for i in 4:
				var fly := Vector3(rng.randf_range(-6, 6), rng.randf_range(4, 9), rng.randf_range(-6, 6)) + velocity * 0.5
				CarDebris.throw(get_parent(), global_position + Vector3.UP * 1.6, fly, body_color, 0.9)
		_disc.visible = false


## Hit by another vehicle or a blast: moved and hurt as a car is.
func shove(offset: Vector3) -> void:
	move_and_collide(Vector3(offset.x, 0.0, offset.z))


## Whether the pilot may get out now: "" yes (on the ground or low), "bail"
## (higher: a jump, and a fall), "roof" (over a roof: people can't stand on
## roofs, so it has to land on open ground first).
func exit_check() -> String:
	if on_roof:
		return "roof"
	return "" if altitude <= LOW else "bail"


## The body tilts with the acceleration the rotor gives (nose down to speed
## up, a bank into turns), about a point near the rotor mast.
func _body_pose() -> void:
	if _model == null:
		return
	var b := Basis()
	if not landed:
		var local := global_basis.inverse() * _tilt_a
		var hs := Vector2(velocity.x, velocity.z).length()
		var top := deg_to_rad(float(_spec.tilt))
		var pitch := clampf(atan(local.z / G), -top, top)
		var roll := clampf(-atan((local.x - _yaw_v * hs) / G), -top, top)
		b = Basis.from_euler(Vector3(pitch, 0.0, roll))
	var p := Vector3(0.0, _pivot, 0.0)
	_model.transform = Transform3D(b, p - b * p)


func _spin_rotors(delta: float) -> void:
	if _rotor == null:
		return
	_rotor.rotation.y = wrapf(_rotor.rotation.y + rpm * ROTOR_SPIN * delta, 0.0, TAU)
	_tail.rotation.x = wrapf(_tail.rotation.x + rpm * TAIL_SPIN * delta, 0.0, TAU)
	var blur := smoothstep(DISC_AT, 1.0, rpm)
	_disc.visible = blur > 0.01 and not wrecked
	_disc_mat.albedo_color.a = 0.3 * blur


## The drop shadow on the ground (or roof) under it, fading with height:
## from up high it is what shows where the helicopter is over the map.
func _update_shadow() -> void:
	if _shadow == null:
		return
	_shadow.visible = altitude > 0.4
	if not _shadow.visible:
		return
	var p := global_position
	var n := Vector3.UP if on_roof else Terrain.normal(p.x, p.z)
	_shadow_mat.albedo_color.a = 0.45 * clampf(1.0 - altitude / 260.0, 0.25, 1.0)
	var grow := 1.0 + minf(altitude, 200.0) * 0.004
	var b := Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, rotation.y).scaled(Vector3(grow, 1.0, grow))
	_shadow.global_transform = Transform3D(b, Vector3(p.x, _floor + 0.12, p.z))


## In the "vehicles" group (the cars' world) only on or near the ground.
func _update_group() -> void:
	var low := altitude < LOW
	if low != is_in_group("vehicles"):
		if low:
			add_to_group("vehicles")
		else:
			remove_from_group("vehicles")


func _build_model() -> void:
	var key := "%s|%s" % [kind, body_color.to_html()]
	if not _meshes.has(key):
		var mb := MeshBuilder.new()
		var gloss := MeshBuilder.new()
		HeliKit.build(mb, kind, body_color, gloss)
		var rotor := MeshBuilder.new()
		HeliKit.build_rotor(rotor, kind)
		var tail := MeshBuilder.new()
		HeliKit.build_tail_rotor(tail, kind)
		var disc := MeshBuilder.new()
		HeliKit.build_disc(disc, float(_spec.rotor))
		_meshes[key] = [mb.commit(), gloss.commit(), rotor.commit(), tail.commit(), disc.commit()]
	var m: Array = _meshes[key]
	_model = MeshInstance3D.new()
	_model.mesh = m[0]
	_gloss = MeshInstance3D.new()
	_gloss.mesh = m[1]
	_model.add_child(_gloss)
	_rotor = MeshInstance3D.new()
	_rotor.mesh = m[2]
	_rotor.position = _spec.rotor_at
	_model.add_child(_rotor)
	_tail = MeshInstance3D.new()
	_tail.mesh = m[3]
	_tail.position = _spec.tail_at
	_model.add_child(_tail)
	_disc = MeshInstance3D.new()
	_disc.mesh = m[4]
	_disc.position = _spec.rotor_at + Vector3(0, 0.03, 0)
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_disc_mat.albedo_color = Color(0.1, 0.1, 0.11, 0.0)
	_disc.material_override = _disc_mat
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.visible = false
	_model.add_child(_disc)
	_skin(MeshBuilder.material(), MeshBuilder.gloss_material())
	if is_police:
		set_xray(POLICE_XRAY)
	add_child(_model)
	if is_police:
		var k: float = _spec.scale
		for i in 2:
			var light := MeshInstance3D.new()
			var lens := BoxMesh.new()
			lens.size = Vector3(0.24, 0.1, 0.24) * k
			light.mesh = lens
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.9, 0.1, 0.1) if i == 0 else Color(0.1, 0.3, 1.0)
			light.material_override = mat
			light.position = Vector3(-0.2 if i == 0 else 0.2, 0.56, 0.9) * k
			_model.add_child(light)
			_lights.append(light)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = _shadow_mesh(kind)
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.vertex_color_use_as_albedo = true
	_shadow_mat.albedo_color = Color(1, 1, 1, 0.45)
	_shadow.material_override = _shadow_mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	_shadow.visible = false
	add_child(_shadow)


static var _shadows := {}


## The drop shadow: the body and tail dark, the rotor disc faint round them.
static func _shadow_mesh(k: String) -> ArrayMesh:
	if _shadows.has(k):
		return _shadows[k]
	var s := HeliKit.spec(k)
	var sc: float = s.scale
	var mb := MeshBuilder.new()
	var body := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		body.append(Vector2(cos(a) * 1.0, sin(a) * 2.1 - 0.4) * sc)
	mb.flat(body, 0.0, Color(0, 0, 0, 1))
	mb.flat(PackedVector2Array([Vector2(-0.25, 1.4) * sc, Vector2(0.25, 1.4) * sc, Vector2(0.12, 5.6) * sc, Vector2(-0.12, 5.6) * sc]), 0.0, Color(0, 0, 0, 1))
	var disc := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		disc.append(Vector2(cos(a), sin(a)) * float(s.rotor))
	mb.flat(disc, 0.0, Color(0, 0, 0, 0.3))
	_shadows[k] = mb.commit()
	return _shadows[k]


func _skin(body: Material, shell: Material) -> void:
	super(body, shell)
	if _rotor != null:
		_rotor.material_override = body
		_tail.material_override = body
