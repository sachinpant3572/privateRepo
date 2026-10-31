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


## The running build's ticket (null when idle) and the tickets waiting
## their turn. One build runs at a time: builds hold CharacterKit.lock, so
## a second would only sit on a worker thread waiting for it. It runs at
## high priority so it doesn't take the low-priority threads that stream
## city cells, country tiles and interiors (a phone gets few of them).
static var _running: Ticket = null
static var _queue: Array = []


## Queues `look` for building on a worker thread.
static func request(look: Dictionary) -> Ticket:
	var t := Ticket.new()
	t.look = look
	_queue.append(t)
	_collect(false)
	return t


static func _prepare(t: Ticket) -> void:
	t.made = CharacterKit.prepare(t.look)


## Whether `t` is built (and t.made safe to read).
static func ready(t: Ticket) -> bool:
	_collect(false)
	return t.done


## How many builds are running or waiting.
static func busy() -> int:
	_collect(false)
	return _queue.size() + (0 if _running == null else 1)


## Waits for every queued build (tests that time or check the caches).
static func drain() -> void:
	_collect(true)


## Finishes the running build if it is done (or, waiting, anyway) and
## starts the next; each task is waited on once.
static func _collect(wait_all: bool) -> void:
	while true:
		if _running != null:
			if not wait_all and not WorkerThreadPool.is_task_completed(_running._task):
				return
			WorkerThreadPool.wait_for_task_completion(_running._task)
			_running.done = true
			_running = null
		if _queue.is_empty():
			return
		_running = _queue.pop_front()
		_running._task = WorkerThreadPool.add_task(_prepare.bind(_running), true, "person")
