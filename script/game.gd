extends Node2D

@onready var floor_packed = preload("res://scene/level.tscn")
const TRANSITION_DURATION = 0.5

# Pointers for UI elements
@onready var hp_bar = $HUDLayer/HUD/HPBar

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
	
	# setup done, screen transition
	var fade_out = get_tree().create_tween()
	fade_out.tween_property($ScreenTransition/ColorRect, "color", Color(0,0,0,0), TRANSITION_DURATION)
	await fade_out.finished
	fade_out.kill()
	
	# Activate enemies and things on floor
	Global.floor_active = true
	
	# play state
		
	await current_floor.next_floor
	
	# Stop floor activity
	Global.floor_active = false
	
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
	Global.connect("player_health_changed", func (hp_value) :
		hp_bar.get_node("Label").text = "HP: " + str(hp_value) + "/" + str(Global.player_max_health)
		)
	
	# Set starting stats to trigger setters
	Global.player_max_health = 50
	Global.player_health = 50
	
	while true:
		await gameplay_main()
