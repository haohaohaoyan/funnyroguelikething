extends CharacterBody2D

const SPEED = 200
const DASH_LENGTH = 5
const DASH_FRICTION = 40

var mouse_events: Array = []
var dash_velocity: Vector2
var base_move_velocity: Vector2

# important state thing
var state: String = "idle"

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
			var move_direction: Vector2 = Vector2(event.position.x - (get_viewport().size.x)/2, event.position.y - (get_viewport().size.y)/2)
			var move_length: Array # [length_min, length_max]
			# Cooldown timers are for until next of either action, so after dashing you can only dash or move again after that amount of time
			if $AtkCooldown.is_stopped() and $DashCooldown.is_stopped():
				# Attack on left click
				if event.button_mask == 1:
					$AtkCooldown.start()
					move_length = [10, 200]
					state = "attack"
				# Dash on right click
				elif event.button_mask == 2:
					$DashCooldown.start()
					move_length = [300,400]
					state = "dash"
			else:
				mouse_events.erase(event)
				break
			# Convert vector to the actual movement (with velocity & movement cap)
			var move_vector: Vector2 = move_direction.normalized() * clamp(move_direction.length(), move_length[0], move_length[1]) * DASH_LENGTH
			dash_velocity = move_vector
			# Toss event because it's been processed
			mouse_events.erase(event)
	
	# Decelerate dash
	dash_velocity = dash_velocity.move_toward(Vector2(0,0), DASH_FRICTION)
	
	# Movements are separate to make dashing have a more expected behavior
	velocity = base_move_velocity + dash_velocity
	move_and_slide()
	
	print(state)
	
func _input(event):
	# Catches all mouse events but defers them to physics process
	if event is InputEventMouseButton:
		if event.button_mask != 0:
			mouse_events.append(event)
			
func _ready():
	$AtkCooldown.connect("timeout", func () : state = "idle")
	$DashCooldown.connect("timeout", func () : state = "idle")
	
