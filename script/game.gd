extends Node2D

@onready var floor_packed = preload("res://scene/level.tscn")
const TRANSITION_DURATION = 0.5

# Pointers for UI elements
@onready var hp_bar = $HUDLayer/HUD/HPBar

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

# Things for creating floating text 
var floating_text_available := []
var floating_text_occupied := []
# Function for creating floating text like for upgrades, healing, damage
# Make sure to include origin for where it's springing off of
# Spread is 0-1, 1 being about 90deg of spread area
func emit_floating_text(origin: Node2D, value : String, 
	direction : Vector2 = Vector2.UP, spread : float = 1, 
	color: Color = Color.WHITE, size : int = 24):
	# Checks from available object pool 
	# If there are available ones, uses those. 
	# If none, creates a new one
	var new_label : Object
	if len(floating_text_available) > 0:
		new_label = floating_text_available.pop_front()
		floating_text_occupied.append(new_label)
	else:
		# Creates a new label
		new_label = Label.new()
		new_label.top_level = true
		$FloatingText.add_child(new_label)
		# Give it a label settings resource
		new_label.label_settings = LabelSettings.new()
		
	print("available: " + str(len(floating_text_available)) + ", occupied : " + str(len(floating_text_occupied)))
		
	# print(new_label.global_position)
	# Fill in args
	new_label.text = value
	new_label.global_position = origin.global_position
	new_label.label_settings.font_size = size
	new_label.label_settings.font_color = color
	new_label.visible = true
	new_label.modulate.a = 1
	
	var floating_text_tween = new_label.create_tween()
	# Add property to make it move in the direction of the Vector2 and fade out
	floating_text_tween.tween_property(new_label, "global_position", 
		# Rotate direction by spread
		new_label.global_position + (direction.normalized() * 50).rotated(randf_range(-spread, spread)), 1)
	floating_text_tween.parallel().tween_property(new_label, "modulate:a", 
		0, 2)
	floating_text_tween.tween_callback(func () : 
		# Returns label to available pool
		floating_text_occupied.erase(new_label)
		floating_text_available.append(new_label)
		)

# Boolean for if the floor gameplay is active or not
# Mostly to prevent loads of enemies immediately ganging up on you
var floor_active : bool = false

# FULLY handles a single floor
func gameplay_main():
	# ensure black screen
	$ScreenTransition/ColorRect.color = Color(0,0,0,1)
	
	var current_floor = floor_packed.instantiate()
	add_child(current_floor)
		
	var current_floor_data =  await current_floor.setup()
	
	$Player.position = current_floor_data["player_start_pos"]
	$Player/Camera2D.position = Vector2i(0,0)
	$Player/Camera2D.reset_smoothing()
	
	# wipe floating text pool
	for text in $FloatingText.get_children():
		$FloatingText.remove_child(text)
		text.queue_free()
	floating_text_available = []
	floating_text_occupied = []
	
	# setup done, screen transition
	var fade_out = get_tree().create_tween()
	fade_out.tween_property($ScreenTransition/ColorRect, "color", Color(0,0,0,0), TRANSITION_DURATION)
	await fade_out.finished
	fade_out.kill()
	
	# Activate enemies and things on floor
	floor_active = true
	
	# play state
		
	await current_floor.next_floor
	
	# Stop floor activity
	floor_active = false
	
	# screen transition again
	var fade_in = get_tree().create_tween()
	$ScreenTransition/ColorRect.color = Color(0,0,0,0)
	fade_in.tween_property($ScreenTransition/ColorRect, "color", Color(0,0,0,1), TRANSITION_DURATION)
	await fade_in.finished
	fade_in.kill()
	
	# clean up
	current_floor.queue_free()

func _ready():
	# Connect signals for health changes from Globals
	connect("player_health_changed", func (hp_value) :
		hp_bar.get_node("Label").text = "HP: " + str(hp_value) + "/" + str(player_max_health)
		)
	
	# Set starting stats to trigger setters
	player_max_health = 50
	player_health = 50
	
	while true:
		await gameplay_main()
