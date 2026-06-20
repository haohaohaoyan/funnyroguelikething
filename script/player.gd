extends CharacterBody2D

const SPEED = 200
const DASH_LENGTH = 5
const DASH_FRICTION = 40

var mouse_events: Array = []
var dash_velocity: Vector2
var base_move_velocity: Vector2

func _physics_process(_delta: float) -> void:
	
	# Basic movement
	var direction = Input.get_vector("LEFT", "RIGHT", "UP", "DOWN").normalized()
	if direction:
		base_move_velocity.x = direction.x * SPEED
		base_move_velocity.y = direction.y * SPEED
	else:
		base_move_velocity.x = 0
		base_move_velocity.y = 0
	
	# Click-based movement
	# Read from array of deferred mouse events
	if len(mouse_events) != 0:
		for event in mouse_events:
			# Movement vector for dashing
			var move_direction = Vector2(event.position.x - (get_viewport().size.x)/2, event.position.y - (get_viewport().size.y)/2)
			var move_vector = move_direction.normalized() * clamp(move_direction.length(),10, 200) * DASH_LENGTH
			# Attack on left click
			# if !$AtkCooldown.is_stopped() and event.button_mask == 1:
				
			dash_velocity = move_vector
			mouse_events.erase(event)
			
	dash_velocity = dash_velocity.move_toward(Vector2(0,0), DASH_FRICTION)
	
	velocity = base_move_velocity + dash_velocity
	move_and_slide()
	
func _input(event):
	# Catches all mouse events but defers them to physics process
	if event is InputEventMouseButton:
		if event.button_mask != 0:
			mouse_events.append(event)
	
