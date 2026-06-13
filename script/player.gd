extends CharacterBody2D

const SPEED = 200
const ACCELERATION = 20
const FRICTION = 20

var mouse_events: Array

func _physics_process(_delta: float) -> void:
	var direction = Input.get_vector("LEFT", "RIGHT", "UP", "DOWN").normalized()
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * SPEED, ACCELERATION)
		velocity.y = move_toward(velocity.y, direction.y * SPEED, ACCELERATION)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION)
		velocity.y = move_toward(velocity.y, 0, FRICTION) 
	
	# Mouse input is read from variable
	
	move_and_slide()
	
func _input(event):
	# Catches all mouse events but defers them to physics process
	if event is InputEventMouseButton:
		pass
	
