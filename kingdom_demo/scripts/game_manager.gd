extends Node3D

signal coins_changed(total: int)

const STARTING_COINS := 100

var coins: int = STARTING_COINS
var castle_age := false        # true once the Town Hall is raised -> stone walls

func _ready() -> void:
	add_to_group("game_manager")
	coins_changed.emit(coins)

## Called when the Town Hall goes up: the palisade is rebuilt in castle stone and
## any walls built from here on start as stone.
func raise_castle_age() -> void:
	if castle_age:
		return
	castle_age = true
	get_tree().call_group("wall_side", "set_castle_age")

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true
