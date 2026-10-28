## Physics layer bits shared by all prototype scripts.

const WORLD := 1
const CHARACTERS := 2
const VEHICLES := 4
const DOWNED := 8
## Street furniture: blocks movement but not sight lines or the camera.
const PROPS := 16
## Roofs over places people stand (bus shelters, fuel-station canopies,
## porches): nothing collides with it; only the camera's sight rays test it,
## so the see-through hole opens when the player walks under one.
const SIGHT := 32


## Whether a kit's collider entry ([centre, size, yaw, info]) is a roof for
## the camera's sight rays only (SIGHT), not a solid.
static func sight_only(c: Array) -> bool:
	return c.size() > 3 and c[3].has("sight")
