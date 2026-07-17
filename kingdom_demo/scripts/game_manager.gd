extends Node3D

signal coins_changed(total: int)

const STARTING_COINS := 100

var coins: int = STARTING_COINS

func _ready() -> void:
	add_to_group("game_manager")
	coins_changed.emit(coins)

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true
