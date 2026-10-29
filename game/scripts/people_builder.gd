extends RefCounted
## Builds people off the main thread. A MakeHuman person takes 6-14 ms to
## blend and dress on a desktop and 40-50 ms on a phone, too long for one
## frame, so the crowd (Population) and the seated riders of open cars
## (Convertible) order theirs here: CharacterKit.prepare() runs as a
## WorkerThreadPool task, and the owner calls CharacterKit.assemble() on
## the result once ready() says it is done.

const CharacterKit = preload("res://scripts/kits/character_kit.gd")


class Ticket:
	var look: Dictionary
	## CharacterKit.prepare()'s result, once done.
	var made := {}
	var done := false
	var _task := -1


## Tasks not yet waited on: every one is, even if its owner is gone.
static var _open: Array = []


## Starts building `look` on a worker thread.
static func request(look: Dictionary) -> Ticket:
	var t := Ticket.new()
	t.look = look
	t._task = WorkerThreadPool.add_task(_prepare.bind(t), false, "person")
	_open.append(t)
	return t


static func _prepare(t: Ticket) -> void:
	t.made = CharacterKit.prepare(t.look)


## Whether `t` is built (and t.made safe to read).
static func ready(t: Ticket) -> bool:
	_collect(false)
	return t.done


## How many builds are still running.
static func busy() -> int:
	_collect(false)
	return _open.size()


## Waits for every running build (tests that time or check the caches).
static func drain() -> void:
	_collect(true)


static func _collect(wait_all: bool) -> void:
	var still: Array = []
	for t in _open:
		if wait_all or WorkerThreadPool.is_task_completed(t._task):
			WorkerThreadPool.wait_for_task_completion(t._task)
			t.done = true
		else:
			still.append(t)
	_open = still
