extends Node
## The game's calendar: a day count that goes up each time the clock wraps
## past midnight, and from it the weekday, the day of the year and the season.
##
## The year is 4 seasons x 28 days = 112 days, which is exactly 16 weeks, so
## a given day of the year always falls on the same weekday and a season is
## four whole weeks (the "month" the rodeo uses is one season-quarter of
## 28 days: day_of_season() 0..27). A new game starts on a Friday in autumn
## (day 10 of the season), so the first evening already has a speed trap and
## the first night a rave; the deer season is open.
##
## The count is days since the game began (0 on the first day) and is saved
## (to_save/load_save). It is the game's only day count: sky.gd reads it
## (atmosphere.calendar) and uses the same moon formula, so the night sky and
## the events agree.
##
## Hunting reads is_open_season(); events.gd reads weekday() and the moon.

signal day_changed(day: int)

const SEASONS := ["spring", "summer", "autumn", "winter"]
const WEEKDAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const DAYS_PER_SEASON := 28
const YEAR_DAYS := 112
## Day 0 is the 10th day of autumn (day of year 65, seasons start at 0, 28,
## 56 and 84) and a Friday.
const START_DAY_OF_YEAR := 65
const START_WEEKDAY := 4
## sky.gd's moon: phase = fposmod(PHASE0 + (day + hour / 24) / LUNAR_DAYS, 1)
## with 0.5 the full moon. Keep in step with sky.gd's constants.
const LUNAR_DAYS := 8.0
const PHASE0 := 0.08
## How near full a night's moon must be to count (phase units; the moon
## moves 0.125 a day, so one night in eight qualifies).
const FULL_MOON_BAND := 0.0625

## What may be hunted when: kind -> the seasons it is open in. A kind not
## listed is never open (and a mountain lion is closed all year). Keys are
## wildlife.gd's kinds ("lion" is the mountain lion).
const OPEN_SEASONS := {
	"deer": ["autumn"],
	"rabbit": ["spring", "summer", "autumn", "winter"],
	"coyote": ["spring", "summer", "autumn", "winter"],
	"lion": [],
}

## The main game (sets atmosphere through it); tests may set `atmosphere`.
var game
var atmosphere

var _day := 0
var _last_hour := -1.0


func _ready() -> void:
	add_to_group("calendar")


func _process(_delta: float) -> void:
	var atm = atmosphere
	if atm == null and game != null:
		atm = game.atmosphere
	if atm != null:
		tick(atm.hour)


## Feeds the clock (hour 0..24). A jump back of more than 12 hours is a
## midnight wrap, the same rule sky.gd uses for its day.
func tick(hour: float) -> void:
	if _last_hour >= 0.0 and hour < _last_hour - 12.0:
		_day += 1
		day_changed.emit(_day)
	_last_hour = hour


## `n` whole days pass at once (Atmosphere.advance); `hour` is the clock
## after them, so the next tick is not taken for another wrap.
func add_days(n: int, hour: float) -> void:
	_last_hour = hour
	if n <= 0:
		return
	_day += n
	day_changed.emit(_day)


## Days since the game began.
func day() -> int:
	return _day


## Sets the day count (tests, loading); the clock's last reading is dropped
## so the next tick is never taken for a wrap.
func set_day(n: int) -> void:
	_day = maxi(n, 0)
	_last_hour = -1.0
	day_changed.emit(_day)


## 0 Monday .. 6 Sunday.
func weekday() -> int:
	return weekday_of(_day)


func weekday_name() -> String:
	return WEEKDAYS[weekday()]


## 0..111.
func day_of_year() -> int:
	return day_of_year_of(_day)


## 0..27.
func day_of_season() -> int:
	return day_of_season_of(_day)


## "spring", "summer", "autumn" or "winter".
func season() -> String:
	return season_of(_day)


## Whether `kind` may be hunted now: deer in autumn, rabbit and coyote all
## year, mountain lion never.
func is_open_season(kind: String) -> bool:
	return season_allows(kind, season())


## The moon's phase now (0.5 full), from the sky's formula.
func moon_phase(hour := 12.0) -> float:
	return moon_phase_at(_day, hour)


## Whether tonight (the evening of today to the small hours of tomorrow) has
## a full moon.
func is_full_moon_night() -> bool:
	return full_moon_night(_day)


## "Friday, day 10 of autumn".
func date_text() -> String:
	return "%s, day %d of %s" % [weekday_name(), day_of_season() + 1, season()]


func to_save() -> Dictionary:
	return {"day": _day}


## Restores a save (a JSON round trip turns the count into a float, and an
## old or damaged save may lack it).
func load_save(d) -> void:
	var n := 0
	if d is Dictionary:
		var v = d.get("day", 0)
		if v is int or v is float:
			n = int(v)
	_day = maxi(n, 0)
	_last_hour = -1.0
	day_changed.emit(_day)


# --- Pure helpers (no node needed) --------------------------------------------

static func weekday_of(d: int) -> int:
	return posmod(START_WEEKDAY + d, 7)


static func day_of_year_of(d: int) -> int:
	return posmod(START_DAY_OF_YEAR + d, YEAR_DAYS)


static func day_of_season_of(d: int) -> int:
	return day_of_year_of(d) % DAYS_PER_SEASON


static func season_of(d: int) -> String:
	return SEASONS[floori(float(day_of_year_of(d)) / DAYS_PER_SEASON)]


static func season_allows(kind: String, season_name: String) -> bool:
	var key := kind.to_lower().replace(" ", "_").trim_prefix("mountain_")
	return OPEN_SEASONS.has(key) and season_name in OPEN_SEASONS[key]


static func moon_phase_at(d: int, hour: float) -> float:
	return fposmod(PHASE0 + (float(d) + hour / 24.0) / LUNAR_DAYS, 1.0)


## Full moon for the night that starts on day `d`: the moon at the coming
## midnight is within FULL_MOON_BAND of full. With the sky's constants that
## is the night of day 2 and every eighth day after.
static func full_moon_night(d: int) -> bool:
	return absf(moon_phase_at(d + 1, 0.0) - 0.5) <= FULL_MOON_BAND


## The first day number >= `from` that falls on `weekday` (0 Monday).
static func next_day_with_weekday(from: int, weekday: int) -> int:
	return from + posmod(weekday - weekday_of(from), 7)
