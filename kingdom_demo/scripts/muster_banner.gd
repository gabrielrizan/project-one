extends StaticBody3D
## The muster banner (COMBAT_PROMPTS P9). Hold-E and pay, and a squad of free archers
## falls in behind the monarch and follows wherever he rides -- the escort *is* the
## assault mechanic. Coming home (near the campfire) dismisses them. Never an order in
## either direction (§1). This is offence -- not §3's defensive rally banner.
##
## A StaticBody so the monarch's InteractArea (which listens for bodies) finds it, and
## duck-typed with show_prompt/hide_prompt/interact like every other interactable.

const PENNANT := preload("res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/flag-pennant.glb")
const BURGUNDY := Color(0.45, 0.12, 0.18)   # the monarch's colour, like the wall pennants

const SQUAD_N := 3        # archers per muster -- PLACEHOLDER
const MUSTER_BASE := 4    # first squad's price; each squad already out raises it (§ROADMAP R1)
const DISBAND_R := 4.0    # the monarch this close to home (the campfire) dismisses the party
const PENNANT_SCALE := 3.4

var _prompt: Label3D = null
var _busy := false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("muster_banner")
	global_position = MapTerrain.muster_point()

	# a slim collider so the InteractArea detects the pole (it bakes as a small
	# nav obstacle, off the corridor centre, which units walk round like the fire)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 2.0, 0.5)
	cs.shape = box
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs)

	var pole := PENNANT.instantiate()
	add_child(pole)
	pole.scale = Vector3.ONE * PENNANT_SCALE
	MarkFx.tint(pole, BURGUNDY)

	_prompt = Label3D.new()
	_prompt.pixel_size = 0.007
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.modulate = Color(1, 0.9, 0.4)
	_prompt.outline_modulate = Color(0.1, 0.08, 0.05)
	_prompt.font_size = 46
	_prompt.outline_size = 12
	_prompt.position = Vector3(0, 2.6, 0)
	_prompt.visible = false
	add_child(_prompt)

	NavWorld.rebake(self)

func _process(_delta: float) -> void:
	# home dismisses: the monarch back near the campfire with a party still out.
	var party := _followers()
	if party.is_empty():
		return
	var m := get_tree().get_first_node_in_group("monarch")
	var fire := get_tree().get_first_node_in_group("campfire")
	if is_instance_valid(m) and is_instance_valid(fire) \
			and m.global_position.distance_to(fire.global_position) < DISBAND_R:
		for v in party:
			v.disband()

# ---- the party ----

func _followers() -> Array:
	var out: Array = []
	for v in get_tree().get_nodes_in_group("villager"):
		if v.has_method("is_following") and v.is_following():
			out.append(v)
	return out

func party_size() -> int:
	return _followers().size()

## Each squad already out raises the next squad's price, so a bigger army is a bigger
## commitment -- and the tally already sizes the hold to it (§ROADMAP R1).
func _cost() -> int:
	var squads := int(ceil(float(_followers().size()) / float(SQUAD_N)))
	return MUSTER_BASE * (squads + 1)

func _available() -> Array:
	var out: Array = []
	for v in get_tree().get_nodes_in_group("villager"):
		if v.has_method("can_muster") and v.can_muster():
			out.append(v)
	out.sort_custom(_nearer)
	return out

func _nearer(a: Node3D, b: Node3D) -> bool:
	return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)

# ---- interaction (duck-typed) ----

func show_prompt() -> void:
	if _busy:
		return
	if _available().is_empty():
		_prompt.text = "Muster  needs an archer"
	else:
		_prompt.text = "Hold E  Muster (%d)" % _cost()
	_prompt.visible = true

func hide_prompt() -> void:
	if is_instance_valid(_prompt):
		_prompt.visible = false

func interact(who: Node3D) -> void:
	if _busy:
		return
	var cost := _cost()
	if _available().is_empty() or not GoldFx.can_afford(cost):
		return
	_busy = true
	hide_prompt()
	var ok: bool = await GoldFx.pay(who, self, cost, 2.6)
	_busy = false
	if ok:
		var n := 0
		for v in _available():   # re-fetch: an archer may have changed state during the hold
			v.muster(who)
			n += 1
			if n >= SQUAD_N:
				break
	elif is_instance_valid(who) and global_position.distance_to(who.global_position) < 3.5:
		show_prompt()

## Dev: send the whole party home at once.
func dismiss() -> void:
	for v in _followers():
		v.disband()
