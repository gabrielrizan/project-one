extends Control

const SUN := preload("res://kingdom_demo/assets/pixel/sun.png")
const MOON := preload("res://kingdom_demo/assets/pixel/moon.png")

@onready var coin_value: Label = $CoinValue
@onready var time_icon: TextureRect = $TimeIcon

var _day_night: Node = null
var _relic_value: Label = null

func _ready() -> void:
	_build_relic_counter()
	call_deferred("_connect")

## The relic counter (F6), beside the coin counter and built in code so there is no
## hand-authored UI scene to drift out of sync -- `menu.gd` does the same.
##
## **Hidden until the first one is found.** A zero next to an unexplained icon on
## night one is a question the game cannot answer yet; the counter appearing the
## moment a chest is opened is the answer arriving with the question.
func _build_relic_counter() -> void:
	_relic_value = Label.new()
	_relic_value.add_theme_font_size_override("font_size", 22)
	_relic_value.position = Vector2(18, 96)
	_relic_value.visible = false
	add_child(_relic_value)

func _connect() -> void:
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm:
		gm.coins_changed.connect(_on_coins_changed)
		_on_coins_changed(gm.coins)
		gm.relics_changed.connect(_on_relics_changed)
		_on_relics_changed(gm.relics)
	_day_night = get_tree().get_first_node_in_group("day_night_cycle")

func _on_coins_changed(total: int) -> void:
	coin_value.text = str(total)

func _on_relics_changed(total: int) -> void:
	if _relic_value == null:
		return
	_relic_value.visible = total > 0
	# the name comes from `GameManager.RELIC_NAME`, so settling what currency X is
	# actually called is one line in one file
	_relic_value.text = "%d %s" % [total,
		GameManager.RELIC_NAME if total == 1 else GameManager.RELIC_NAME_PLURAL]

func _process(_delta: float) -> void:
	if _day_night:
		time_icon.texture = MOON if _day_night.is_night() else SUN
