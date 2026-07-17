extends Control

const SUN := preload("res://kingdom_demo/assets/pixel/sun.png")
const MOON := preload("res://kingdom_demo/assets/pixel/moon.png")

@onready var coin_value: Label = $CoinValue
@onready var time_icon: TextureRect = $TimeIcon

var _day_night: Node = null

func _ready() -> void:
	call_deferred("_connect")

func _connect() -> void:
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm:
		gm.coins_changed.connect(_on_coins_changed)
		_on_coins_changed(gm.coins)
	_day_night = get_tree().get_first_node_in_group("day_night_cycle")

func _on_coins_changed(total: int) -> void:
	coin_value.text = str(total)

func _process(_delta: float) -> void:
	if _day_night:
		time_icon.texture = MOON if _day_night.is_night() else SUN
