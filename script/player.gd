extends CharacterBody2D

const SPEED = 200
const DASH_LENGTH = 5
const DASH_FRICTION = 70

var mouse_events: Array = [] # Stores the mouse events to defer to physics process
# Movement vectors are stored separately and then added before moving for more logical dashing movement
var dash_velocity: Vector2
var base_move_velocity: Vector2

# important state strimg
var state: String = "idle"

# Main movement loop, obviously
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
			# Attack on left click with more variable but shorter distance
			if $AtkCooldown.is_stopped() and event.button_mask == 1:
				$AtkCooldown.start()
				move_length = [180, 250]
				state = "attack"
				
				# Rotate damage hitbox to face the click direction
				$AttackCollision.look_at(move_direction + global_position)
				
			# Dash on right click
			elif $DashCooldown.is_stopped() and event.button_mask == 2: # a bit long ik but this makes logic look better
				$DashCooldown.start()
				move_length = [370,400]
				state = "dash"
				
				# Mechanic I think is pretty cool! To detect cool dodges for flurry rushes and the
				# like, leave behind an invisible hitbox that lasts for a fraction of a second and
				# triggers the action if it gets hit during that time!
				
				$DodgeDetect.global_position = global_position
				$DodgeDetect.monitoring = true
				$DodgeWindow.start()
				
			else: # If not valid, immediately tosses event and breaks from if/else. 
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
	
	# Update globals related to player
	
	Global.player_position = global_position
	Global.player_state = state
	
func _input(event):
	# Catches all mouse events but defers them to physics process
	if event is InputEventMouseButton:
		if event.button_mask != 0:
			mouse_events.append(event)
			
func _ready():
	$AtkCooldown.connect("timeout", func () : 
		state = "idle"
		$AttackCollision.monitoring = false)
	$DashCooldown.connect("timeout", func () : state = "idle")
	$DodgeWindow.connect("timeout", func () : 
		$DodgeDetect.monitoring = false
		$DodgeDetect.global_position = global_position) # debug for when collisions are visible
	
