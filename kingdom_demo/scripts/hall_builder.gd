class_name HallBuilder
extends RefCounted
## Composes a main-building tier out of Kenney Fantasy Town Kit modules.
##
## **These are placeholders, and they exist to make the *scale* right.** The kit
## has no house model in it -- all 167 pieces are modular wall, roof and doorway
## panels, and the only assembled buildings are a windmill and two watermills --
## so a hall has to be built rather than dropped in. Building it here instead of
## hand-placing pieces in a `.tscn` means a tier is three numbers, and each tier
## is visibly the same building grown rather than a different model.
##
## The geometry is measured, not guessed: **every module occupies a 1 m cell with
## its panel on the cell's +X face**, and walls are exactly 1 m tall. So a hall
## `cx` by `cz` cells is `cx` by `cz` metres on the ground, and `storeys` metres
## to the eaves. That is the whole point -- footprints and heights are in real
## metres, which is what makes them comparable to a 1.2 m villager.
##
## The roof is deliberately **flat with a parapet**. A pitched roof needs its
## slope panels oriented per edge and gets the corners wrong the moment the
## footprint is not square; a flat cap cannot be oriented wrongly, and a parapet
## reads as a hall rather than a shed. Swap it for gables when these stop being
## placeholders.

const K := "res://kingdom_demo/assets/3d/kenney_fantasy-town-kit/Models/GLB format/"
const CELL := 1.0
const ROOF_T := 0.13        # measured thickness of a roof-flat panel
const PARAPET_H := 0.5      # measured height of a wall-half

## The kit's roof panels are baked **turquoise**, which is nowhere near the
## palette and reads as a swimming pool on top of every building from this
## camera. Tinted to slate. Deliberately not burgundy: the palette keeps red for
## the monarch, and a red roof on every hall would steal the focal point.
##
## A material override flattens whatever palette the model had of its own (see
## `CLAUDE.md`), which is normally a reason to avoid it -- here the panel is a
## single flat colour anyway, so there is nothing to lose.
const ROOF_TINT := Color(0.34, 0.33, 0.35)

## Rotation that puts a module's +X panel on each outward face. A Y rotation of
## theta sends +X to (cos, 0, -sin), which is why -Z is +90 and +Z is -90.
const FACE_PX := 0.0
const FACE_NZ := 90.0
const FACE_NX := 180.0
const FACE_PZ := -90.0

## Everything a tier needs. `stone` picks the material set; the wooden set is the
## same modules with a timber skin, so the two tiers are structurally identical
## and read purely as an upgrade in material and size.
static func build(cx: int, cz: int, storeys: int, stone: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Hall"
	var wall := "wall" if stone else "wall-wood"
	var door := "wall-door" if stone else "wall-wood-door"
	var window := "wall-window-small" if stone else "wall-wood-window-small"
	var half := "wall-half" if stone else "wall-wood-half"

	# The doorway goes on the +Z face, because that is the side villagers walk to
	# (`building.gd::build_spot` puts them at +Z) and the side the prompt faces.
	var door_i := int(cx / 2)

	for s in range(storeys):
		for i in range(cx):
			for j in range(cz):
				if i > 0 and i < cx - 1 and j > 0 and j < cz - 1:
					continue      # interior cell, no outside walls
				var p := _cell(i, j, cx, cz) + Vector3(0, float(s) * CELL, 0)
				if i == cx - 1:
					_place(root, wall, p, FACE_PX)
				if i == 0:
					_place(root, wall, p, FACE_NX)
				if j == 0:
					_place(root, wall, p, FACE_NZ)
				if j == cz - 1:
					var front := door if (s == 0 and i == door_i) else \
						(window if s > 0 else wall)
					_place(root, front, p, FACE_PZ)

	var top := float(storeys) * CELL
	for i in range(cx):
		for j in range(cz):
			var r := _place(root, "roof-flat", _cell(i, j, cx, cz) + Vector3(0, top, 0), 0.0)
			if r:
				_tint(r, ROOF_TINT)

	# Parapet, sitting on the roof deck rather than level with it.
	var para := top + ROOF_T
	for i in range(cx):
		for j in range(cz):
			if i > 0 and i < cx - 1 and j > 0 and j < cz - 1:
				continue
			var p := _cell(i, j, cx, cz) + Vector3(0, para, 0)
			if i == cx - 1:
				_place(root, half, p, FACE_PX)
			if i == 0:
				_place(root, half, p, FACE_NX)
			if j == 0:
				_place(root, half, p, FACE_NZ)
			if j == cz - 1:
				_place(root, half, p, FACE_PZ)

	return root

## Overall height, so `building.gd::model_height` can be set from the same numbers
## that built the thing rather than measured by eye and left to go stale.
static func height(storeys: int) -> float:
	return float(storeys) * CELL + ROOF_T + PARAPET_H

## Centred on the origin, so the building sits on its spawn point rather than
## growing out of one corner of it.
static func _cell(i: int, j: int, cx: int, cz: int) -> Vector3:
	return Vector3((float(i) - float(cx - 1) * 0.5) * CELL, 0.0,
		(float(j) - float(cz - 1) * 0.5) * CELL)

static func _place(root: Node3D, model: String, pos: Vector3, yaw: float) -> Node3D:
	var path := K + model + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	root.add_child(inst)
	inst.position = pos
	inst.rotation_degrees.y = yaw
	return inst

static func _tint(n: Node, c: Color) -> void:
	if n is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		n.material_override = m
	for child in n.get_children():
		_tint(child, c)

## `building.gd` takes a PackedScene per tier, so the composed node is packed
## rather than the interface changed. `pack()` only keeps children that are owned
## by the root, which is why the owner is stamped here and not in `_place`.
static func packed(n: Node3D) -> PackedScene:
	for c in n.get_children():
		c.owner = n
	var ps := PackedScene.new()
	ps.pack(n)
	return ps
