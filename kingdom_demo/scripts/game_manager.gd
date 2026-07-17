extends Node3D

signal coins_changed(total: int)

var coins: int = 0

func _ready() -> void:
	add_to_group("game_manager")

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true
