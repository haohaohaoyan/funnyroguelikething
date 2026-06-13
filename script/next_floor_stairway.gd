extends Area2D

func _physics_process(_delta: float) -> void:
	if len(get_overlapping_areas()) != 0 and Input.is_action_just_pressed("ACTION"):
		owner.next_floor.emit()
