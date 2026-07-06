extends Node

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
		

var floor_active : bool = false
