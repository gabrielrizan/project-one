extends StaticBody3D

const MAX_CHOPS := 5
const COIN_SCENE := preload("res://kingdom_demo/scenes/coin.tscn")

@onready var sprite: Sprite3D = $Sprite
@onready var stump: Sprite3D = $Stump
@onready var prompt: Label3D = $Prompt
@onready var collision: CollisionShape3D = $CollisionShape3D

var chops_remaining: int = MAX_CHOPS
var _base_x := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("tree")
	_base_x = sprite.position.x

func show_prompt() -> void:
	if chops_remaining > 0:
		prompt.visible = true

func hide_prompt() -> void:
	prompt.visible = false

func interact(_who: Node3D) -> void:
	if chops_remaining <= 0:
		return
	chops_remaining -= 1
	_spawn_coin()
	if chops_remaining == 0:
		_fall()
	else:
		_shake()

func _shake() -> void:
	var t := create_tween()
	t.tween_property(sprite, "position:x", _base_x + 0.06, 0.04)
	t.tween_property(sprite, "position:x", _base_x - 0.06, 0.06)
	t.tween_property(sprite, "position:x", _base_x, 0.05)

func _fall() -> void:
	remove_from_group("interactable")
	remove_from_group("tree")
	hide_prompt()
	collision.set_deferred("disabled", true)
	stump.visible = true
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(sprite, "scale", Vector3(1, 0.05, 1), 0.45)
	t.parallel().tween_property(sprite, "modulate:a", 0.0, 0.45)
	t.tween_callback(func(): sprite.visible = false)

func _spawn_coin() -> void:
	var coin := COIN_SCENE.instantiate()
	get_parent().add_child(coin)
	coin.global_position = global_position + Vector3(0.0, 1.0, 0.0)
	var landing := global_position + Vector3(randf_range(-1.2, 1.2), 0.2, randf_range(-1.2, 1.2))
	coin.pop(landing)
