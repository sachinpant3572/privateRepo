extends Node
## Police heat. The full game plans five levels; the prototype stops at two.

signal level_changed(level: int)

const MAX_LEVEL := 2
## Seconds out of police sight needed to lose each level.
const EVADE_TIME := [0.0, 8.0, 12.0]

var level := 0
var unseen_time := 0.0


func report_crime(severity: int) -> void:
	unseen_time = 0.0
	_set_level(clampi(maxi(level, severity), 0, MAX_LEVEL))


## Called every physics frame by the police manager.
func tick(delta: float, seen_by_police: bool) -> void:
	if level == 0:
		return
	if seen_by_police:
		unseen_time = 0.0
		return
	unseen_time += delta
	if unseen_time >= EVADE_TIME[level]:
		clear()


func clear() -> void:
	unseen_time = 0.0
	_set_level(0)


func _set_level(value: int) -> void:
	if value == level:
		return
	level = value
	level_changed.emit(level)
