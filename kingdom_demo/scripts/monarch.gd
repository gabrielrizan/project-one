extends CharacterBody3D

const SPEED := 5.0
const ACCEL := 60.0

@onready var interact_area: Area3D = $InteractArea
@onready var sprite: Sprite3D = $Sprite

var followers: Array = []
var _nearby: Array = []
var _highlighted: Node3D = null
var _bob := 0.0
var _sprite_base_y := 0.0

func _ready() -> void:
	add_to_group("monarch")
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	_sprite_base_y = sprite.position.y

func _physics_process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	var screen_x := input_dir.x       # for sprite facing, before camera rotation
	input_dir = input_dir.normalized()

	# move relative to where the camera is looking (Thronefall-style)
	var rig = get_tree().get_first_node_in_group("camera_rig")
	if rig:
		input_dir = input_dir.rotated(Vector3.UP, rig.yaw)

	var target_velocity := input_dir * SPEED
	velocity.x = move_toward(velocity.x, target_velocity.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, ACCEL * delta)
	move_and_slide()

	if absf(screen_x) > 0.1:
		sprite.flip_h = screen_x < 0.0
	_animate(delta, input_dir.length() > 0.1)
	_update_highlight()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

func _animate(delta: float, moving: bool) -> void:
	if moving:
		_bob += delta * 12.0
		sprite.position.y = _sprite_base_y + abs(sin(_bob)) * 0.08
	else:
		sprite.position.y = move_toward(sprite.position.y, _sprite_base_y, delta * 0.6)

## A subject kneeling to present their take -- the king straightens and accepts it.
func receive_tribute() -> void:
	_punch()
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color(1.9, 1.7, 1.15, 1.0), 0.1)
	t.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.4)

func _punch() -> void:
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector3(1.25, 0.8, 1.25), 0.06)
	t.tween_property(sprite, "scale", Vector3.ONE, 0.12)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("interactable") and body not in _nearby:
		_nearby.append(body)

func _on_body_exited(body: Node3D) -> void:
	_nearby.erase(body)

func _closest_interactable() -> Node3D:
	var closest: Node3D = null
	var closest_dist := INF
	for body in _nearby:
		if not is_instance_valid(body) or not body.is_in_group("interactable"):
			continue
		var dist := global_position.distance_to(body.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = body
	return closest

func _update_highlight() -> void:
	# Mid-payment the king stays locked on whatever he is counting gold into:
	# walking past something else neither switches the highlight nor lights up a
	# second prompt, so only ever one tally is on screen.
	if GoldFx.is_paying():
		return
	var closest := _closest_interactable()
	if closest == _highlighted:
		return
	if is_instance_valid(_highlighted) and _highlighted.has_method("hide_prompt"):
		_highlighted.hide_prompt()
	_highlighted = closest
	if is_instance_valid(_highlighted) and _highlighted.has_method("show_prompt"):
		_highlighted.show_prompt()

func _try_interact() -> void:
	if GoldFx.is_paying():
		return
	if not is_instance_valid(_highlighted) or not _highlighted.has_method("interact"):
		return
	_highlighted.interact(self)
	_punch()

func add_follower(unit: Node3D) -> void:
	followers.append(unit)

func remove_follower(unit: Node3D) -> void:
	followers.erase(unit)

func get_leader_for(unit: Node3D) -> Node3D:
	var idx := followers.find(unit)
	if idx <= 0:
		return self
	return followers[idx - 1]
