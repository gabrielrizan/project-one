extends StaticBody3D
## A village building. The Tent is the main building at L1 and climbs the ladder
## (Tent -> Wooden Hall -> Stone Hall); the Workers and Archers huts are
## workplaces: the monarch pays gold to create jobs and loyal villagers walk over
## to fill them. The hammer / bow icons over the roof count the positions still
## *open*, so they tick down as villagers take work.
##
## No upgrade tier is instant. Paying opens a construction site just like a wall
## does (see [BuildCrew], [WallSide]) and it sits there at whatever percentage
## the crew has managed until workers walk over and finish it. Adding a job
## position *is* instant -- that's a decision, not construction; the villager
## walking over is the delay.

@export var model_scene: PackedScene            # the base (tier 1) model
@export var display_name: String = ""
@export var model_scale: float = 1.0
@export var model_height: float = 1.5           # used to seat prompts / label / collision
@export var job_type: String = ""              # "worker" | "archer" | "" (no jobs)
@export var is_hall: bool = false               # the main building -- the run's heart + tech ladder

## The upgrade rungs above the base, in order (COMBAT_PROMPTS P0 / ROADMAP R2). Each is
## a dict `{model: PackedScene, name: String, scale: float, height: float, cost: int}`.
## The base (tier 1) is the exports above; every entry here is one more crew-built rung.
## Empty for a hut. Replaced the old three flat `upgrade_*` slots -- a five-tier ladder
## needs an array, not a fourth copy of five exports.
@export var tiers: Array = []

const MAX_JOBS := 4
const JOB_COST := 3

# --- HP, collapse & the hall's fall (COMBAT_PROMPTS P6b). PLACEHOLDER numbers. ---
## A hut's pool; the hall's is bigger and climbs with its tier (it's the run's heart).
const HUT_HP := 90.0
const HALL_HP: Array[float] = [200.0, 260.0, 340.0, 460.0, 600.0]   # L1 Tent .. L5 Castle
const HUT_REPAIR_COST := 6      # flat, placeholder -- a hut was free to raise
const REPAIR_TIME := 20.0       # crew-seconds to mend a collapsed hut
const LOG_MODEL := preload("res://kingdom_demo/assets/3d/props/log_marker.glb")
const ARROW_MODEL := preload("res://kingdom_demo/assets/3d/props/arrow_marker.glb")
const HAMMER_MODEL := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/tool-hammer.glb")
const ICON_SCALE := 0.45
const DUST_TEX := preload("res://kingdom_demo/assets/pixel/wood_chip.png")
const BANNER_SCALE := 5.0
## Base crew-seconds to raise each rung, indexed by the upgrade being built (L1→L2
## first). A crew scales it (see [BuildCrew]). PLACEHOLDER, like the costs.
const BUILD_TIMES: Array[float] = [20.0, 28.0, 45.0, 60.0]

# ---- the sound of a tier landing ----
#
## **A building should sound like what it is made of**, the same way the gate does
## (see `wall_side.gd::GATE_SFX`). The Wooden Hall lands as timber and rubble; the
## Stone Hall lands as stone with a long decay. When L4 Castle arrives, adding a
## `"castle"` key here is the whole change -- `_raise_sfx()` falls back to wood for
## any material with no set of its own, so nothing breaks in the meantime.
const RAISE_SFX := {
	"wood": [
		preload("res://kingdom_demo/assets/audio/build_raise_wood_1.ogg"),
		preload("res://kingdom_demo/assets/audio/build_raise_wood_2.ogg"),
	],
	"stone": [
		preload("res://kingdom_demo/assets/audio/build_raise_stone_1.ogg"),
		preload("res://kingdom_demo/assets/audio/build_raise_stone_2.ogg"),
	],
	# "castle": [ ... ]   <- L4, when it exists
}
const RAISE_DB := -2.0
const RAISE_PITCH := 1.07
const RAISE_REACH := 45.0

static var _raise_pools := {}

@onready var model_root: Node3D = $Model
@onready var label: Label3D = $Label
@onready var _prompt: Label3D = $Prompt
@onready var _icons: Node3D = $Icons
@onready var _collision: CollisionShape3D = $CollisionShape3D

var jobs := 0          # positions created (paid for)
var filled := 0        # positions taken by loyal villagers
var _tier := 0         # current rung: 0 = base (tier 1); each upgrade adds one
var _raising := 0      # the rung a crew is currently raising, as a 1-based upgrade
                       # number (1 = base→tiers[0]); 0 = no upgrade site open
var _progress := 0.0
var _crew: BuildCrew = null
var _banner: Node3D = null
var _banner_t := 0.0
var _model: Node3D = null
var _height := 1.5
var _busy := false

# HP, collapse & repair (P6b)
var _hp := 0.0
var _hp_max := 0.0
var _collapsed := false          # a hut knocked flat, awaiting repair
var _repairing := false          # a crew is mending it

func _ready() -> void:
	add_to_group("building")
	_show_model(model_scene, model_scale)
	_fit(model_height)
	label.text = display_name
	if job_type != "":
		add_to_group("workplace")
	_refresh_hp()
	set_process(false)
	_update_interactable()

# ---- damage, collapse & the hall's fall (COMBAT_PROMPTS P6b) ----

## The main building is flagged at spawn (P0). Kept as a method so the P6b call
## sites read unchanged.
func _is_hall() -> bool:
	return is_hall

func _max_hp() -> float:
	if is_hall:
		return HALL_HP[clampi(_tier, 0, HALL_HP.size() - 1)]
	return HUT_HP

func _refresh_hp() -> void:
	_hp_max = _max_hp()
	_hp = _hp_max

## The hall's tier: 1-based (1 = L1 Tent .. 5 = L5 Castle). Campfire reads this for
## hall_tier(), and the wall gating reads it through there (P0).
func tier() -> int:
	return _tier + 1

## 0-based tier index, for the campfire's population-cap table.
func tier_index() -> int:
	return _tier

## A bandit vandalising the nearest building (bandit.gd, when there's nothing to
## rob). A hut at zero collapses into a repair site; the hall at zero ends the run.
func take_hit(amount: float, at: Vector3) -> void:
	if _collapsed or _repairing or _raising > 0:
		return
	if _hp_max <= 0.0:
		_refresh_hp()
	_hp -= amount
	MarkFx.hit_flash(self, _model)
	var hit := at
	hit.y = 0.6
	MarkFx.debris(self, hit, Vector3.UP, 4, Color(0.7, 0.66, 0.56, 0.95), 0.016, 0.8)
	if _hp <= 0.0:
		if _is_hall():
			_fall()
		else:
			_collapse()

## The hall is gone -- hand the lose condition to the game manager.
func _fall() -> void:
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("end_run"):
		gm.end_run()

## A hut knocked flat: jobs suspended (no new hires), its offer icons pulled, the
## model slumped into rubble. It becomes interactable so the monarch can pay to mend.
func _collapse() -> void:
	_collapsed = true
	_hp = 0.0
	remove_from_group("workplace")
	_clear_job_icons()
	if is_instance_valid(_model):
		var t := create_tween()
		t.tween_property(_model, "position:y", -_height * 0.4, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(_model, "rotation:z", randf_range(0.18, 0.32), 0.4)
	_dust()
	if not is_in_group("interactable"):
		add_to_group("interactable")

func _clear_job_icons() -> void:
	for c in _icons.get_children():
		c.queue_free()

func _rebuild_job_icons() -> void:
	_clear_job_icons()
	for i in range(maxi(0, jobs - filled)):
		_add_job_icon()

# ---- repair (crew-built, like a wall's) ----

func _open_repair() -> void:
	_repairing = true
	_progress = 0.0
	_crew = BuildCrew.new()
	add_to_group("build_site")
	remove_from_group("interactable")
	_banner = MarkFx.banner(self, HAMMER_MODEL, _height + 1.6, BANNER_SCALE)
	_banner_t = 0.0
	set_process(true)

func _finish_repair() -> void:
	_repairing = false
	_collapsed = false
	set_process(false)
	remove_from_group("build_site")
	if is_instance_valid(_banner):
		_banner.queue_free()
	_banner = null
	_crew = BuildCrew.new()
	hide_prompt()
	# heave the hut back upright
	if is_instance_valid(_model):
		var t := create_tween()
		t.tween_property(_model, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(_model, "rotation:z", 0.0, 0.45)
	_dust()
	_raise_sound("wood")
	if job_type != "" and not is_in_group("workplace"):
		add_to_group("workplace")
	_rebuild_job_icons()
	_refresh_hp()
	_update_interactable()

# ---- layout ----

func _show_model(scene: PackedScene, sc: float) -> void:
	if is_instance_valid(_model):
		_model.queue_free()
	_model = null
	if scene == null:
		return
	_model = scene.instantiate()
	model_root.add_child(_model)
	_model.scale = Vector3(sc, sc, sc)

## Seats the label / prompt / job icons above the building and rebuilds a
## collision box that matches the requested height.
func _fit(height: float) -> void:
	_height = maxf(0.4, height)
	# stacked clear of each other: prompt over the roof, then name, then job icons
	_prompt.position.y = _height + 0.15
	label.position.y = _height + 0.55
	_icons.position.y = _height + 1.05
	# a fresh shape per building -- the one in the scene is shared between instances
	var box := BoxShape3D.new()
	var w := maxf(0.9, _height * 0.7)
	box.size = Vector3(w, _height, w)
	_collision.shape = box
	_collision.position.y = _height * 0.5
	# a new hut, or a tier that just grew a wider footprint -- either way the
	# villagers' paths through the village need to know about it
	NavWorld.rebake(self)

# ---- job positions (queried by villagers) ----

func open_jobs() -> int:
	return jobs - filled

func has_open_job() -> bool:
	return job_type != "" and open_jobs() > 0

func claim_job() -> bool:
	if not has_open_job():
		return false
	filled += 1
	_take_job_icon()
	_refresh_prompt()
	return true

## A robbed citizen leaves their post (COMBAT_PROMPTS P5): the position re-opens and
## its vacancy icon comes back, the mirror of claim_job. The workforce recovers when
## the victim is re-fed and takes the job again.
func vacate_job() -> void:
	if filled <= 0:
		return
	filled -= 1
	_add_job_icon()
	_refresh_prompt()
	_update_interactable()

func work_point() -> Vector3:
	# a spot just in front of the building for workers to stand
	return global_position + Vector3(0, 0, 1.4)

# ---- interaction ----

## The next rung's data, or `{}` if the ladder is topped out or capped for this map.
func _next_tier() -> Dictionary:
	if _raising > 0 or _tier >= tiers.size():
		return {}
	# per-map tech cap (P0): the rung's 1-based tier number must be within it. Huts
	# have no tiers so never reach here; only the hall consults the cap.
	if is_hall and (_tier + 2) > _hall_cap():
		return {}
	return tiers[_tier]

func _can_upgrade() -> bool:
	return not _next_tier().is_empty()

## Map's tech ceiling, read off the campfire (per-map, P0). No cap found = no cap.
func _hall_cap() -> int:
	var fire := get_tree().get_first_node_in_group("campfire")
	if fire and fire.has_method("hall_cap"):
		return fire.hall_cap()
	return 99

func _update_interactable() -> void:
	var should_be := job_type != "" or _can_upgrade()
	if should_be and not is_in_group("interactable"):
		add_to_group("interactable")
	elif not should_be and is_in_group("interactable"):
		remove_from_group("interactable")

## Every tier is raised by a crew, so with nobody holding a hammer there is nobody
## to raise it. Say so rather than taking gold for a site that would sit untouched.
func _workers_exist() -> bool:
	for v in get_tree().get_nodes_in_group("villager"):
		if v.has_method("is_worker") and v.is_worker():
			return true
	return false

func _upgrade_offer(dname: String, cost: int) -> String:
	return ("Hold E  %s (%d)" % [dname, cost]) if _workers_exist() else "%s  needs a worker" % dname

func _prompt_text() -> String:
	if _raising > 0:
		return ""   # the site status line takes over the prompt while building
	var next := _next_tier()
	if not next.is_empty():
		return _upgrade_offer(next["name"], next["cost"])
	if job_type == "":
		return ""
	if jobs >= MAX_JOBS:
		return "%s  (full)" % display_name
	return "Hold E  Add Job (%d)   %d/%d" % [JOB_COST, jobs, MAX_JOBS]

func show_prompt() -> void:
	if _busy or _repairing:
		return
	# a collapsed hut offers repair before anything else (P6b)
	if _collapsed:
		_prompt.text = ("Hold E  Repair (%d)" % HUT_REPAIR_COST) if _workers_exist() \
			else "Repair  needs a worker"
		_prompt.visible = true
		return
	if _prompt_text() == "":
		return
	_prompt.text = _prompt_text()
	_prompt.visible = true

func hide_prompt() -> void:
	_prompt.visible = false

func _refresh_prompt() -> void:
	if _prompt.visible:
		_prompt.text = _prompt_text()

func interact(who: Node3D) -> void:
	if _busy or _raising > 0 or _repairing:
		return
	# repair a collapsed hut (P6b) -- crew-built, like a wall
	if _collapsed:
		if _workers_exist():
			await _buy(who, HUT_REPAIR_COST, _open_repair)
		return
	var next := _next_tier()
	if not next.is_empty():
		if _workers_exist():
			await _buy(who, int(next["cost"]), _open_upgrade_site.bind(_tier + 1))
	elif job_type != "" and jobs < MAX_JOBS:
		await _buy(who, JOB_COST, _add_job)

func _buy(who: Node3D, cost: int, on_paid: Callable) -> void:
	if not GoldFx.can_afford(cost):
		return
	_busy = true
	hide_prompt()
	var ok: bool = await GoldFx.pay(who, self, cost, _height + 0.9)
	_busy = false
	if ok:
		on_paid.call()
	if is_in_group("interactable") and is_instance_valid(who) and global_position.distance_to(who.global_position) < 3.5:
		show_prompt()

# ---- jobs ----

func _add_job() -> void:
	jobs += 1
	_add_job_icon()

func _add_job_icon() -> void:
	var s := MarkFx.model(ARROW_MODEL if job_type == "archer" else LOG_MODEL, ICON_SCALE)
	_icons.add_child(s)
	_layout_icons()
	s.scale = Vector3.ZERO
	create_tween().tween_property(s, "scale", Vector3.ONE * ICON_SCALE, 0.15) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A villager just took this post, so its icon lifts off the roof and the row
## closes up -- what's left is the count of vacancies.
func _take_job_icon() -> void:
	var n := _icons.get_child_count()
	if n == 0:
		return
	var icon: Node3D = _icons.get_child(n - 1)
	var world := icon.global_position
	_icons.remove_child(icon)
	get_tree().current_scene.add_child(icon)
	icon.global_position = world
	_layout_icons()
	var t := icon.create_tween()
	t.tween_property(icon, "global_position", world + Vector3(0, 0.45, 0), 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(icon, "scale", Vector3.ZERO, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(icon.queue_free)

func _layout_icons() -> void:
	var n := _icons.get_child_count()
	if n == 0:
		return
	# A shallow fan, not a ruler-straight row: identical props lined up dead level
	# read as a UI widget bolted to the roof. Dipping and tilting them at the ends
	# makes it look like things propped up on a board.
	var spacing := 0.40
	var start_x := -spacing * (n - 1) * 0.5
	for i in range(n):
		var t := 0.0 if n == 1 else (float(i) / float(n - 1)) * 2.0 - 1.0   # -1..1
		var c: Node3D = _icons.get_child(i)
		c.position = Vector3(start_x + i * spacing, -absf(t) * 0.09, 0.0)
		c.rotation = Vector3(0.0, t * 0.30, -t * 0.34)

# ---- finishing a tier ----

## The new building heaves up out of the ground, the grass hiding the join --
## the moment a crew finishes either tier.
func _swap_and_heave(scene: PackedScene, dname: String, sc: float, height: float,
		material := "wood") -> void:
	display_name = dname
	_show_model(scene, sc)
	_fit(height if height > 0.0 else _height)
	label.text = display_name
	_dust()
	# with the dust, not after it -- the sound and the heave are one event
	_raise_sound(material)
	_model.position.y = -_height * 0.7
	_model.scale = Vector3(sc * 1.1, sc * 0.4, sc * 1.1)
	var t := create_tween()
	t.tween_property(_model, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_model, "scale", Vector3(sc, sc, sc), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Falls back to wood for any material without its own set, so a new tier can be
## added to `RAISE_SFX` whenever its recordings turn up rather than up front.
func _raise_sfx(material: String) -> AudioStreamRandomizer:
	var key: String = material if RAISE_SFX.has(material) else "wood"
	if not _raise_pools.has(key):
		var pool := AudioStreamRandomizer.new()
		var clips: Array = RAISE_SFX[key]
		for i in range(clips.size()):
			pool.add_stream(i, clips[i])
		pool.random_pitch = RAISE_PITCH
		pool.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		_raise_pools[key] = pool
	return _raise_pools[key]

## Its own emitter, because the building is mid-tween and the sound outlives it.
func _raise_sound(material: String) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _raise_sfx(material)
	p.bus = &"SFX"
	p.volume_db = RAISE_DB
	p.unit_size = 12.0
	p.max_distance = RAISE_REACH
	get_tree().current_scene.add_child(p)
	p.global_position = global_position + Vector3(0, 0.6, 0)
	p.finished.connect(p.queue_free)
	p.play()

func _dust() -> void:
	for i in range(10):
		var p := Sprite3D.new()
		p.texture = DUST_TEX
		p.pixel_size = 0.016
		p.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		p.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		p.modulate = Color(0.76, 0.72, 0.62, 0.95)
		get_tree().current_scene.add_child(p)
		var a := randf() * TAU
		p.global_position = global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.3, 1.0) + Vector3(0, 0.1, 0)
		var to := p.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 1.0)
		to.y += randf_range(0.4, 0.9)
		var t := p.create_tween()
		t.tween_property(p, "global_position", to, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(p, "scale", Vector3(2.0, 2.0, 2.0), 0.6)
		t.parallel().tween_property(p, "modulate:a", 0.0, 0.6)
		t.tween_callback(p.queue_free)

# ---- upgrades (every tier is built by a crew) ----

## Paying doesn't raise the building -- it opens a site. Workers walk over and
## put it up; see [BuildCrew] for the pace. `upgrade_no` is the 1-based rung.
func _open_upgrade_site(upgrade_no: int) -> void:
	_raising = upgrade_no
	_progress = 0.0
	_crew = BuildCrew.new()
	add_to_group("build_site")
	_banner = MarkFx.banner(self, HAMMER_MODEL, _height + 1.6, BANNER_SCALE)
	_banner_t = 0.0
	set_process(true)
	_update_interactable()

func _build_time() -> float:
	return BUILD_TIMES[clampi(_raising - 1, 0, BUILD_TIMES.size() - 1)]

func _process(delta: float) -> void:
	if _raising == 0 and not _repairing:
		return
	if is_instance_valid(_banner):
		_banner_t += delta
		if _banner_t > 0.4:
			_banner.position.y = _height + 1.6 + sin((_banner_t - 0.4) * 2.6) * 0.08
	var hands := _crew.hands()
	var verb := "Repairing" if _repairing else "Building"
	_prompt.text = "Needs workers" if hands == 0 else "%s  %d%%   x%d" % [verb, int(_progress * 100.0), hands]
	_prompt.visible = true
	if hands <= 0:
		return
	_progress += delta * _crew.speed() / (REPAIR_TIME if _repairing else _build_time())
	if _progress >= 1.0:
		if _repairing:
			_finish_repair()
		else:
			_finish_upgrade()

func _finish_upgrade() -> void:
	var t: Dictionary = tiers[_raising - 1]
	_tier = _raising
	_raising = 0
	set_process(false)
	remove_from_group("build_site")
	hide_prompt()
	if is_instance_valid(_banner):
		_banner.queue_free()
	_banner = null
	_crew = BuildCrew.new()
	# Stone from the Stone Hall (tier 4) up; timber below. `_raise_sfx()` falls back
	# to wood for any material with no set of its own, so this never lands silent.
	var material := "stone" if _tier >= 3 else "wood"
	_swap_and_heave(t["model"], t["name"], float(t["scale"]), float(t["height"]), material)
	# The wall stone/fortified unlocks read hall_tier() live now, so there is no
	# stone-unlocked flag to raise here any more (P0 deleted it).
	_refresh_hp()   # a new tier is a tougher hall, mended to full (P6b)
	_update_interactable()

# ---- the crew (asked by villagers, same duck-typed interface as a wall site) ----

## A standing building a bandit can vandalise -- not one already flat, mending, or
## mid-construction (COMBAT_PROMPTS P6b).
func is_attackable() -> bool:
	return not _collapsed and not _repairing and _raising == 0 and _hp > 0.0

func site_active() -> bool:
	return _raising > 0 or _repairing

func needs_builders() -> bool:
	return (_raising > 0 or _repairing) and _crew.needs_more()

func claim_builder(who: Node3D) -> bool:
	if not needs_builders():
		return false
	return _crew.claim(who)

func release_builder(who: Node3D) -> void:
	if _crew:
		_crew.release(who)

func builder_ready(who: Node3D) -> void:
	if _crew:
		_crew.arrived(who)

## Builders ring the building rather than lining up along it.
func build_spot(who: Node3D) -> Vector3:
	var i: int = _crew.station(who) if _crew else 0
	var angle := (float(i) / 3.0) * TAU
	var radius := _height * 0.6 + 1.6
	return global_position + Vector3(cos(angle), 0, sin(angle)) * radius

func face_point(_from: Vector3) -> Vector3:
	return global_position
