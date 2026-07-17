extends StaticBody3D
## Upgradeable base. Coins upgrade it (press E), and assigned Builders feed a
## construction meter that auto-upgrades it for free. Each tier swaps in a
## larger composed castle sprite.

const UPGRADE_COSTS := [3, 6]  # coins / build-points to reach tier 1, then 2

var tier := 0
var construction := 0

@onready var castle: Node3D = get_parent()
@onready var prompt: Label3D = castle.get_node("Prompt")

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("base")
	_show_tier_sprite()
	_update_ui()

func _max_tier() -> int:
	return UPGRADE_COSTS.size()

func _tier_sprite(i: int) -> Node:
	return castle.get_node_or_null("CastleT%d" % i)

func _show_tier_sprite() -> void:
	for i in range(_max_tier() + 1):
		var s := _tier_sprite(i)
		if s:
			s.visible = (i == tier)

func _prompt_text() -> String:
	if tier >= _max_tier():
		return "Base fully upgraded"
	return "E  Upgrade Base (%d)" % UPGRADE_COSTS[tier]

func show_prompt() -> void:
	prompt.text = _prompt_text()
	prompt.visible = true

func hide_prompt() -> void:
	prompt.visible = false

func interact(_who: Node3D) -> void:
	_do_upgrade(false)

func add_construction(amount: int) -> void:
	if tier >= _max_tier():
		return
	construction += amount
	if construction >= UPGRADE_COSTS[tier]:
		_do_upgrade(true)
	else:
		_update_ui()

func _do_upgrade(free: bool) -> void:
	if tier >= _max_tier():
		return
	if not free:
		var cost: int = UPGRADE_COSTS[tier]
		var gm = get_tree().get_first_node_in_group("game_manager")
		if not (gm and gm.spend_coins(cost)):
			return
	tier += 1
	construction = 0
	_show_tier_sprite()
	_update_ui()
	if prompt.visible:
		prompt.text = _prompt_text()

func _update_ui() -> void:
	var label = get_tree().get_first_node_in_group("base_label")
	if not label:
		return
	if tier >= _max_tier():
		label.text = "Tier %d (max)" % tier
	elif construction > 0:
		label.text = "Tier %d  (%d/%d)" % [tier, construction, UPGRADE_COSTS[tier]]
	else:
		label.text = "Tier %d" % tier
