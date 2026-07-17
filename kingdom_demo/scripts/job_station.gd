extends Area3D
## Walk a recruited (FOLLOWING) peasant into this zone to assign it a job.

@export var job: String = "archer"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("peasant") and body.has_method("can_take_job") and body.can_take_job():
		body.assign_job(job)
