extends Node

# Information pertinent to current game

# Big reminder to self: These are the physics layers in order:
# Layer 1: both player AND enemy collision, specifically for things like walls and obstacles
# Layer 2: enemy-enemy collision, to stop them from like stacking up
# Layer 3: Your attacks
# Layer 4: Enemy attacks
# Layer 5: Interactive objects

var player_position : Vector2 = Vector2(0,0)
var player_state : String = "idle"

signal player_health_changed(new_health)
var player_max_health : int = 50 :
	set(new_max_health) : 
		# Increase health by increment if positive but still caps it to max
		player_health += max(min(0, new_max_health - player_max_health), new_max_health)
		player_max_health = new_max_health

var player_health : int = 50 :
	set(new_health) : 
		# Emit health change signal to game scene
		player_health = new_health
		player_health_changed.emit(new_health)

# List of nodes already hit by the current attack to avoid dealing 5000 hits in a second
var player_current_attack := {
	"direction" : Vector2.UP,
	"enemies_hit": []
}

# Extra player stats that can be changed by upgrades and weapons
var player_stats := {
	"attack_power": 18, # Base damage points per attack
	"critical_chance": 0.1, # Chance out of 1 that an attack is critical
	"critical_bonus": 3, # Number to multiply by on critical
}

var player_xp

# Boolean for if the floor gameplay is active or not
# Mostly to prevent loads of enemies immediately ganging up on you
var floor_active : bool = false

# Function for creating floating text like for upgrades, healing, damage
# Make sure to include origin for where it's springing off of
# Spread is 0-1, 1 being about 90deg of spread area
## IMPORTANT!!!! Uses Game root for object pool
func emit_floating_text(origin: Node2D, value : String, 
	direction : Vector2 = Vector2.UP, spread : float = 1, 
	color: Color = Color.WHITE, size : int = 26):
	# Currently summons & discards a label for whenever it happens
	# Nodes are orphans but will kill themselves after a set time so hopefully no leak
	# That sounds very wrong
	var new_label = Label.new()
	new_label.text = value
	new_label.top_level = true
	new_label.global_position = origin.global_position
	get_tree().root.get_node("Game").add_child(new_label)
	# print(new_label.global_position)
	
	var floating_text_tween = new_label.create_tween()
	# Add property to make it move in the direction of the Vector2 and fade out
	floating_text_tween.tween_property(new_label, "global_position", 
		# Rotate direction by spread
		new_label.global_position + (direction.normalized() * 50).rotated(randf_range(-spread, spread)), 1)
	floating_text_tween.parallel().tween_property(new_label, "modulate:a", 
		0, 2)
	floating_text_tween.tween_callback(func () : new_label.queue_free())
	
