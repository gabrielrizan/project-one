extends Node3D

signal coins_changed(total: int)

const STARTING_COINS := 100

var coins: int = STARTING_COINS
var stone_unlocked := false    # true once the main building reaches L3 Stone Hall --
                                # wall sides can then be individually paid and built into stone

func _ready() -> void:
	add_to_group("game_manager")
	coins_changed.emit(coins)

## Called once the L3 Stone Hall finishes. Nothing converts on its own --
## this only opens the "Upgrade to Stone" offer on each wall side, which still
## needs its own gold and its own crew.
func unlock_stone_walls() -> void:
	stone_unlocked = true

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true
