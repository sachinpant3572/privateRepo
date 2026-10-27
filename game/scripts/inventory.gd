extends RefCounted
## What Jules carries besides cash (game.cash): snacks in the bag for now;
## clothes, vehicles, weapons and learned styles join it in later phases
## (INTERIORS_SERVICES_PLAN.md). Saved by the mission manager (save v2).

## Snacks Jules can carry at once.
const BAG_SIZE := 3

## Everything the places sell: name, price, health it gives and where it's
## sold. Diner meals ("seated") are eaten at a table, never carried.
const ITEMS := {
	"water": {"name": "Bottle of water", "price": 2, "heal": 6, "at": "corner_store"},
	"soda": {"name": "Cola", "price": 3, "heal": 8, "at": "corner_store"},
	"chips": {"name": "Crawfish chips", "price": 4, "heal": 12, "at": "corner_store"},
	"candy": {"name": "Praline bar", "price": 4, "heal": 12, "at": "corner_store"},
	"energy": {"name": "Energy drink", "price": 7, "heal": 20, "at": "corner_store"},
	"sandwich": {"name": "Ham sandwich", "price": 9, "heal": 30, "at": "corner_store"},
	"coffee": {"name": "Coffee and chicory", "price": 4, "heal": 12, "at": "diner", "seated": true},
	"pie": {"name": "Pecan pie", "price": 6, "heal": 20, "at": "diner", "seated": true},
	"pancakes": {"name": "Pancake stack", "price": 11, "heal": 40, "at": "diner", "seated": true},
	"poboy": {"name": "Shrimp po'boy", "price": 13, "heal": 50, "at": "diner", "seated": true},
	"gumbo": {"name": "Bowl of gumbo", "price": 14, "heal": 55, "at": "diner", "seated": true},
	"burger": {"name": "Burger and fries", "price": 15, "heal": 60, "at": "diner", "seated": true},
	"breakfast": {"name": "Big breakfast", "price": 18, "heal": 80, "at": "diner", "seated": true},
}

## Item ids in the bag, oldest first.
var bag: Array = []


## Item ids a place type sells, cheapest first.
static func menu(type: String) -> Array:
	var ids: Array = []
	for id in ITEMS:
		if ITEMS[id].at == type:
			ids.append(id)
	ids.sort_custom(func(a, b): return ITEMS[a].price < ITEMS[b].price)
	return ids


func bag_full() -> bool:
	return bag.size() >= BAG_SIZE


func add(id: String) -> bool:
	if bag_full() or not ITEMS.has(id) or ITEMS[id].get("seated", false):
		return false
	bag.append(id)
	return true


## Takes the snack that heals the most (the first of equals) out of the
## bag and returns its id, or "" when empty.
func take_best() -> String:
	if bag.is_empty():
		return ""
	var best: String = bag[0]
	for id in bag:
		if ITEMS[id].heal > ITEMS[best].heal:
			best = id
	bag.erase(best)
	return best


func to_save() -> Dictionary:
	return {"bag": bag.duplicate()}


func load_save(data: Dictionary) -> void:
	bag.clear()
	for id in data.get("bag", []):
		if ITEMS.has(id) and not bag_full():
			bag.append(id)
