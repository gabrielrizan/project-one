class_name MarkFx
extends RefCounted
## The shared visual language for anything the monarch marks for his people to
## work: the paint blaze daubed onto it, the floating banner saying which crew it
## is waiting on, and the debris that flies while it is being worked.
##
## Used by trees (workers, axe banner) and berry bushes (archers, basket banner).
## All helpers take the marked node as `owner` since statics have no scene tree.

const MARK_TEX := preload("res://kingdom_demo/assets/pixel/mark_x.png")
const CHIP_TEX := preload("res://kingdom_demo/assets/pixel/wood_chip.png")

const BLAZE_LIFT := 0.16

static func sprite(tex: Texture2D, px: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	return s

## Alpha cutting off, so debris can fade out instead of popping.
static func particle(tex: Texture2D, px: float) -> Sprite3D:
	var s := sprite(tex, px)
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	return s

## Daubs the felling/foraging mark on, in one wet slap.
static func blaze(owner: Node3D, local_y: float, px: float) -> Sprite3D:
	var b := sprite(MARK_TEX, px)
	owner.add_child(b)
	b.position = Vector3(0, local_y, 0)
	b.scale = Vector3(0.2, 0.2, 1.0)
	b.modulate = Color(2.2, 2.2, 2.2, 1.0)
	var t := owner.create_tween()
	t.tween_property(b, "scale", Vector3(1.25, 1.25, 1.0), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(b, "modulate", Color(1, 1, 1, 1), 0.3)
	t.tween_property(b, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	return b

## Marked things are Y-billboarded sprites, so the blaze has to be nudged toward
## the camera every frame or it vanishes inside them when the view swings round.
static func face_camera(b: Sprite3D, anchor: Vector3) -> void:
	var cam := b.get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam := cam.global_position - anchor
	to_cam.y = 0.0
	if to_cam.length() < 0.01:
		return
	b.global_position = anchor + to_cam.normalized() * BLAZE_LIFT

static func banner(owner: Node3D, tex: Texture2D, y: float, px: float) -> Sprite3D:
	var s := sprite(tex, px)
	owner.add_child(s)
	s.position = Vector3(0, y - 0.4, 0)
	s.modulate = Color(1, 1, 1, 0)
	var t := owner.create_tween().set_parallel(true)
	t.tween_property(s, "position:y", y, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 1.0, 0.26)
	return s

static func shake(owner: Node3D, s: Sprite3D, base_x: float, amount: float) -> void:
	var t := owner.create_tween()
	t.tween_property(s, "position:x", base_x + amount, 0.04)
	t.tween_property(s, "position:x", base_x - amount, 0.06)
	t.tween_property(s, "position:x", base_x, 0.05)

static func hit_flash(owner: Node3D, s: Sprite3D) -> void:
	var t := owner.create_tween()
	t.tween_property(s, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.04)
	t.tween_property(s, "modulate", Color(1, 1, 1, 1), 0.14)

## Foliage shaken loose, fluttering down.
static func leaves(owner: Node3D, at: Vector3, n: int, high: float, low: float, spread: float) -> void:
	for i in range(n):
		var leaf := particle(CHIP_TEX, 0.012)
		leaf.modulate = Color(0.34 + randf() * 0.24, 0.52 + randf() * 0.26, 0.24, 1.0)
		owner.get_tree().current_scene.add_child(leaf)
		var a := randf() * TAU
		var start := at + Vector3(cos(a), 0, sin(a)) * randf_range(0.2, spread)
		start.y = randf_range(low, high)
		leaf.global_position = start
		var land := start + Vector3(cos(a), 0, sin(a)) * 0.45
		land.y = 0.08
		var t := leaf.create_tween()
		t.tween_property(leaf, "global_position", land, randf_range(1.0, 1.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(leaf, "modulate:a", 0.0, 1.5)
		t.tween_callback(leaf.queue_free)

## Chips / dust thrown out from a point, biased along `dir`.
static func debris(owner: Node3D, at: Vector3, dir: Vector3, n: int, tint: Color, px: float, reach: float) -> void:
	for i in range(n):
		var p := particle(CHIP_TEX, px)
		p.modulate = tint
		owner.get_tree().current_scene.add_child(p)
		p.global_position = at
		var d := (dir + Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))).normalized()
		var apex := at + d * 0.3 + Vector3(0, 0.35, 0)
		var land := at + d * randf_range(reach * 0.5, reach)
		land.y = 0.08
		var t := p.create_tween()
		t.tween_property(p, "global_position", apex, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(p, "global_position", land, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(p, "modulate:a", 0.0, 0.4)
		t.tween_callback(p.queue_free)
