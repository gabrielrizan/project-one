class_name KayKitRig
extends Node3D
## Wraps one KayKit "Adventurers" character body with the pack's shared
## animation library and, optionally, a weapon socketed onto a handslot bone.
##
## The pack ships bodies (Knight.glb, Ranger.glb, Rogue_Hooded.glb, ...) with
## no animation of their own -- walk/run/idle/etc. live in two separate
## shared-rig files (Animations/gltf/Rig_Medium/*.glb) meant to be retargeted
## at runtime onto any body built on the same "Rig_Medium" skeleton. That
## split is KayKit's own design, not a limitation to work around.
##
## Auto-scaled to `target_height` with its base dropped to y = 0, the same
## AABB-fit trick as [NaturePack.spawn] -- KayKit's raw import scale can't be
## trusted, and this project's whole cast is sized against a 1.2 m villager.

const MOVE_LIB_SCENE := preload("res://kingdom_demo/assets/3d/characters/kaykit/Rig_Medium_MovementBasic.glb")
const GENERAL_LIB_SCENE := preload("res://kingdom_demo/assets/3d/characters/kaykit/Rig_Medium_General.glb")

## Clips that hold a pose or play once (a death, a hit, a jump) rather than
## repeat -- everything else loops so a walk or an idle never visibly resets.
const ONE_SHOT := {
	"T-Pose": true, "Death_A": true, "Death_A_Pose": true, "Death_B": true,
	"Death_B_Pose": true, "Hit_A": true, "Hit_B": true, "Interact": true,
	"PickUp": true, "Spawn_Air": true, "Spawn_Ground": true, "Throw": true,
	"Use_Item": true, "Jump_Full_Long": true, "Jump_Full_Short": true,
	"Jump_Idle": true, "Jump_Land": true, "Jump_Start": true,
}

static var _lib: AnimationLibrary = null

@export var body_scene: PackedScene
@export var weapon_scene: PackedScene
@export var weapon_bone := "handslot.r"
@export var weapon_position := Vector3.ZERO
@export var weapon_rotation_deg := Vector3.ZERO
## 1.0 fits any prop from the KayKit pack itself, which shares this rig's own
## unit scale. A prop from elsewhere (`tool-hammer.glb` is Kenney's, authored
## at a real-world 0.15 m) needs this to land at hand size.
@export var weapon_scale := 1.0
@export var target_height := 1.2

## Held frame used as a stand-in seated/mounted pose until the pack gets a real one --
## see ART_PIPELINE.md's "no seated pose in Rig_Medium" note. `Jump_Idle`'s hang has the
## most bent-knee, weight-back shape of anything in the library.
const SEATED_CLIP := "Jump_Idle"
const SEATED_TIME := 0.35   # tune by eye once screenshotted; placeholder

var body: Node3D = null
var anim: AnimationPlayer = null
var _seated := false

func _ready() -> void:
	body = body_scene.instantiate()
	add_child(body)
	_fit_height()
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	body.add_child(anim)
	anim.add_animation_library("", _shared_library())
	if weapon_scene != null:
		_attach_weapon()
	play("Idle_A")

## Plays `name` if it isn't already the current clip -- called every frame by
## a mover, so this is what stops a looping clip restarting on every tick.
func play(anim_name: String, blend := 0.15) -> void:
	if not is_instance_valid(anim) or not anim.has_animation(anim_name):
		return
	if anim.current_animation != anim_name:
		anim.play(anim_name, blend)

## Freezes on a held frame that reads as roughly seated -- there is no seated/mount clip
## in this pack. Idempotent like `play()`; calling this repeatedly is free.
func sit(clip := SEATED_CLIP, at := SEATED_TIME) -> void:
	if _seated or not is_instance_valid(anim) or not anim.has_animation(clip):
		return
	anim.play(clip)
	anim.seek(at, true)
	anim.pause()
	_seated = true

## Leaves the seated hold, e.g. if this rig is ever reused for a character that dismounts.
func stand() -> void:
	if not _seated:
		return
	_seated = false
	play("Idle_A")

func _fit_height() -> void:
	var box := _combined_aabb(body)
	var h: float = box.size.y
	if h > 0.001:
		body.position.y -= box.position.y
		var s: float = target_height / h
		body.scale = Vector3(s, s, s)

func _attach_weapon() -> void:
	var skeleton := body.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.find_bone(weapon_bone) < 0:
		push_warning("[kaykit_rig] no bone '%s' on %s" % [weapon_bone, body_scene.resource_path])
		return
	var att := BoneAttachment3D.new()
	att.bone_name = weapon_bone
	skeleton.add_child(att)
	var weapon := weapon_scene.instantiate()
	att.add_child(weapon)
	weapon.position = weapon_position
	weapon.rotation_degrees = weapon_rotation_deg
	weapon.scale = Vector3.ONE * weapon_scale

## Built once for the whole game (every KayKit character shares it) by
## instancing the two library files off-tree, lifting their default
## AnimationLibrary out, and freeing the temporary bodies.
static func _shared_library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	for scene in [MOVE_LIB_SCENE, GENERAL_LIB_SCENE]:
		var temp: Node = scene.instantiate()
		var src := temp.get_node("AnimationPlayer") as AnimationPlayer
		var src_lib := src.get_animation_library("")
		for anim_name in src_lib.get_animation_list():
			var clip: Animation = src_lib.get_animation(anim_name)
			if not ONE_SHOT.has(anim_name):
				clip.loop_mode = Animation.LOOP_LINEAR
			_lib.add_animation(anim_name, clip)
		temp.free()
	return _lib

## Union of every VisualInstance3D's AABB under `root`, in `root`'s parent
## space -- copied from [NaturePack._combined_aabb] rather than shared,
## since that script is about scattered scenery and this is about a rigged
## cast member; the two have no reason to depend on each other.
static func _combined_aabb(root: Node) -> AABB:
	var acc := AABB()
	var started := false
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var node: Node = pair[0]
		var xf: Transform3D = pair[1]
		if node is Node3D:
			xf = xf * (node as Node3D).transform
		if node is VisualInstance3D:
			var a: AABB = xf * (node as VisualInstance3D).get_aabb()
			if started:
				acc = acc.merge(a)
			else:
				acc = a
				started = true
		for c in node.get_children():
			stack.append([c, xf])
	return acc
