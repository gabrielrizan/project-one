extends StaticBody3D
## A tree the monarch marks for felling with a daub of paint. Marked trees
## advertise themselves through the "marked_tree" group; exactly one idle worker
## claims a tree, chops it down, and carries the GOLD_YIELD coins back to the king.
##
## The marking visuals are shared with berry bushes -- see [MarkFx].

const MARK_COST := 1
const GOLD_YIELD := 2
## Paired with `villager.gd::SWING_TIME` -- together these set how long a tree
## takes to come down (8 x 1.1s ~= 9s). Felling is meant to feel earned; at the
## old 6 blows a 0.46s apart a whole trunk was gone in under three seconds.
const CHOPS_TO_FELL := 8

const COIN_SCENE := preload("res://kingdom_demo/scenes/coin.tscn")
const AXE_MODEL := preload("res://kingdom_demo/assets/3d/props/axe_marker.glb")

## **Deliberately not scaled with the tree.** The tree tripled to ~4.5 m, but a
## worker's shoulder did not: he still swings at the same height, so the axe bite
## and the paint blaze stay where a 1.3 m person can reach. Only the banner and
## the hinge follow the model.
const TRUNK_Y := 1.10         # height the axe bites at / the blaze is painted at
const TRUNK_BASE_Y := 0.18    # where the trunk meets the grass -- the topple hinge
const BANNER_Y := 4.90
const FALL_TIME := 0.85

## Both clips were trimmed so their loudest moment sits exactly 1.09s in, which is
## when the trunk hits the grass here: 0.24s of lean plus FALL_TIME. So the sound
## starts with the topple and the crash lands *with* the impact rather than near
## it. **If the lean or FALL_TIME change, the clips need re-aligning** -- see
## ASSETS.md.
const FALL_CLIPS := [
	preload("res://kingdom_demo/assets/audio/tree_fall_1.ogg"),
	preload("res://kingdom_demo/assets/audio/tree_fall_2.ogg"),
]
const FALL_DB := -3.0
const FALL_PITCH := 1.06
const FALL_REACH := 50.0

static var _fall_pool: AudioStreamRandomizer = null

@onready var model: Node3D = $Model
@onready var stump: Node3D = $Stump
@onready var prompt: Label3D = $Prompt
@onready var collision: CollisionShape3D = $CollisionShape3D

var marked := false
var felled := false

var _cutter: Node3D = null
var _chops := 0
var _busy := false
var _base_x := 0.0
var _blaze: Sprite3D = null
var _banner: Node3D = null
var _banner_t := 0.0

# --- the tree's own body, from the nature-pack (NaturePack), and its season coat.
#     Family + member index are fixed per tree so a re-skin keeps its shape; only
#     the variant (green / autumn / snow) changes as the season clock turns. ---
const TREE_H := Vector2(4.0, 5.2)   # ~ the 4.5 m collider, so blaze/banner heights hold
const STUMP_H := 0.9
## Season indices mirror weather.gd's Season enum (SPRING/SUMMER/AUTUMN/WINTER).
const _AUTUMN_SEASON := 2
const _WINTER_SEASON := 3

var _family := "common"
var _idx := 1
var _tree_h := 4.5
var _variant := NaturePack.GREEN
var _tree_rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("tree")
	# fixed per tree (seeded off its spot) so each trunk differs but a re-skin keeps
	# the same shape and only changes its seasonal coat
	_tree_rng.seed = hash(Vector2(global_position.x, global_position.z))
	_family = NaturePack.TREE_FAMILIES[_tree_rng.randi() % NaturePack.TREE_FAMILIES.size()]
	_idx = _tree_rng.randi_range(1, NaturePack.TREE_MEMBERS)
	_tree_h = _tree_rng.randf_range(TREE_H.x, TREE_H.y)
	_build_model()
	_build_stump()
	# the Model sways, never the body -- moving the StaticBody3D would drag its
	# collider around and the navmesh is baked from exactly that. See wind.gd.
	model.add_to_group("wind_sway")
	_base_x = model.position.x
	set_process(false)   # only marked trees need per-frame work
	# hook the season clock deferred, so it doesn't matter whether Weather has
	# joined its group yet when this tree readies (scene _ready order isn't fixed)
	call_deferred("_hook_weather")

func _hook_weather() -> void:
	var w := get_tree().get_first_node_in_group("weather")
	if w == null or not w.has_signal("season_changed"):
		return
	if not w.season_changed.is_connected(_on_season_changed):
		w.season_changed.connect(_on_season_changed)
	_on_season_changed(w.season())   # dress to the current season now

## Plant this tree's trunk model under the (empty) Model holder, at the current
## seasonal variant. Rebuilt in place on a season change while the tree still stands.
func _build_model() -> void:
	for c in model.get_children():
		c.queue_free()
	var body := NaturePack.spawn(NaturePack.tree(_family, _variant, _idx), _tree_h)
	if body:
		model.add_child(body)

func _build_stump() -> void:
	for c in stump.get_children():
		c.queue_free()
	var s := NaturePack.spawn(NaturePack.random_stump(_variant, _tree_rng), STUMP_H)
	if s:
		stump.add_child(s)

func _variant_for(season: int) -> String:
	if season == _AUTUMN_SEASON:
		return NaturePack.AUTUMN
	if season == _WINTER_SEASON:
		return NaturePack.SNOW
	return NaturePack.GREEN

## Re-skin to the new season. A standing tree swaps its trunk (mark/blaze untouched
## -- they live on separate child nodes); a felled tree, already toppled, only needs
## its stump re-coated.
func _on_season_changed(season: int) -> void:
	var v := _variant_for(season)
	if v == _variant:
		return
	_variant = v
	if felled:
		_build_stump()
	elif not _busy:
		_build_model()

func _process(delta: float) -> void:
	if is_instance_valid(_banner):
		_banner_t += delta
		_banner.position.y = BANNER_Y + sin(_banner_t * 2.6) * 0.08
	if is_instance_valid(_blaze):
		MarkFx.face_camera(_blaze, chop_anchor())

# ---------------------------------------------------------------- marking

func show_prompt() -> void:
	if marked or felled or _busy:
		return
	prompt.text = "Hold E  Mark Tree (%d)" % MARK_COST
	prompt.visible = true

func hide_prompt() -> void:
	prompt.visible = false

func interact(who: Node3D) -> void:
	if marked or felled or _busy:
		return
	if not GoldFx.can_afford(MARK_COST):
		return
	_busy = true
	hide_prompt()
	var ok: bool = await GoldFx.pay(who, self, MARK_COST, BANNER_Y)
	_busy = false
	if ok:
		_mark()
	elif is_instance_valid(who) and global_position.distance_to(who.global_position) < 3.5:
		show_prompt()

func _mark() -> void:
	marked = true
	remove_from_group("interactable")
	add_to_group("marked_tree")
	hide_prompt()
	MarkFx.mark_sound(self)
	MarkFx.shake(self, model, _base_x, 0.09)
	_blaze = MarkFx.blaze(self, TRUNK_Y, 0.013)
	MarkFx.face_camera(_blaze, chop_anchor())
	_banner = MarkFx.banner(self, AXE_MODEL, BANNER_Y, 0.85)
	MarkFx.leaves(self, global_position, 7, 2.3, 1.7, 0.6)
	set_process(true)

# ---------------------------------------------------------------- worker claims

func chop_anchor() -> Vector3:
	return global_position + Vector3(0, TRUNK_Y, 0)

func is_open_for_cutting() -> bool:
	return marked and not felled and not is_instance_valid(_cutter)

func claim_cutter(worker: Node3D) -> bool:
	if not is_open_for_cutting():
		return false
	_cutter = worker
	return true

func release_cutter(worker: Node3D) -> void:
	if _cutter == worker:
		_cutter = null

## One axe swing. Returns true on the blow that brings the tree down.
func take_chop(from: Vector3) -> bool:
	if felled:
		return false
	_chops += 1
	MarkFx.shake(self, model, _base_x, 0.06)
	MarkFx.hit_flash(self, model)
	var back := from - global_position
	back.y = 0.0
	MarkFx.debris(self, chop_anchor(),
		(back.normalized() if back.length() > 0.01 else Vector3.BACK),
		5, Color(1, 1, 1, 1), 0.01, 1.1)
	if _chops < CHOPS_TO_FELL:
		return false
	_fell(from)
	return true

# ---------------------------------------------------------------- felling

func _fell(from: Vector3) -> void:
	felled = true
	marked = false
	remove_from_group("marked_tree")
	remove_from_group("tree")
	if is_in_group("interactable"):
		remove_from_group("interactable")
	hide_prompt()
	collision.set_deferred("disabled", true)
	NavWorld.rebake(self)    # the trunk stops being something to walk around
	# hand the model back before the topple takes it over, or the wind would keep
	# writing rotation onto something mid-fall
	model.remove_from_group("wind_sway")
	model.rotation = Vector3.ZERO
	set_process(false)
	if is_instance_valid(_blaze):
		_blaze.queue_free()
	if is_instance_valid(_banner):
		_banner.queue_free()
	stump.visible = true
	_topple(from)

## Starts with the topple, not with the landing -- the clip carries its own creak
## and whoosh before the crash, and that lead-in is what sells the fall.
func _fall_sound() -> void:
	if _fall_pool == null:
		_fall_pool = AudioStreamRandomizer.new()
		for i in range(FALL_CLIPS.size()):
			_fall_pool.add_stream(i, FALL_CLIPS[i])
		_fall_pool.random_pitch = FALL_PITCH
		_fall_pool.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	var p := AudioStreamPlayer3D.new()
	p.stream = _fall_pool
	p.bus = &"SFX"
	p.volume_db = FALL_DB
	p.unit_size = 13.0
	p.max_distance = FALL_REACH
	add_child(p)
	p.global_position = global_position + Vector3(0, 1.2, 0)
	p.finished.connect(p.queue_free)
	p.play()

## Tip the whole 3D trunk over on a hinge at its base, falling away from the cutter.
func _topple(from: Vector3) -> void:
	_fall_sound()
	var away := global_position - from
	away.y = 0.0
	var fall_dir := away.normalized() if away.length() > 0.01 else Vector3.BACK

	var pivot := Node3D.new()
	add_child(pivot)
	pivot.position = Vector3(0, TRUNK_BASE_Y, 0)
	# Aim the pivot's local +Z along the fall direction, then tipping it about the
	# local X axis topples the trunk that way.
	pivot.rotation.y = atan2(fall_dir.x, fall_dir.z)

	# Re-home the standing model under the hinge, keeping its world pose.
	var world := model.global_transform
	model.get_parent().remove_child(model)
	pivot.add_child(model)
	model.global_transform = world

	var t := create_tween()
	t.tween_property(pivot, "rotation:x", deg_to_rad(-6.0), 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(pivot, "rotation:x", deg_to_rad(87.0), FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: _trunk_landed(pivot, fall_dir))

func _trunk_landed(pivot: Node3D, fall_dir: Vector3) -> void:
	if not is_instance_valid(pivot):
		return
	MarkFx.debris(self, global_position + fall_dir * 2.0 + Vector3(0, 0.1, 0),
		Vector3.ZERO, 8, Color(0.74, 0.70, 0.60, 0.9), 0.014, 1.1)
	var t := pivot.create_tween()
	t.tween_property(pivot, "rotation:x", deg_to_rad(84.0), 0.10).set_trans(Tween.TRANS_SINE)
	t.tween_property(pivot, "rotation:x", deg_to_rad(88.0), 0.14).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.5)
	t.tween_property(pivot, "scale", Vector3(0.01, 0.01, 0.01), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(pivot.queue_free)
	_drop_gold()

func _drop_gold() -> void:
	var coins: Array = []
	for i in range(GOLD_YIELD):
		var coin := COIN_SCENE.instantiate()
		get_tree().current_scene.add_child(coin)
		coin.global_position = global_position + Vector3(0, 0.9, 0)
		var a := randf() * TAU
		var landing := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.7, 1.2)
		landing.y = 0.12
		coin.pop(landing)
		coins.append(coin)
	if is_instance_valid(_cutter) and _cutter.has_method("receive_loot"):
		_cutter.receive_loot(coins)
	_cutter = null
