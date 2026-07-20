extends Area2D

func _physics_process(_delta: float) -> void:
	if len(get_overlapping_areas()) != 0:
		$CollisionShape2D/Label.visible = true
		if Input.is_action_just_pressed("ACTION"):
			owner.next_floor.emit()
	else:
		$CollisionShape2D/Label.visible = false
