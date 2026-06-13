extends Node2D

@onready var floor_packed = preload("res://scene/level.tscn")
const TRANSITION_DURATION = 0.5

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
	
	# play state
		
	await current_floor.next_floor
	
	# screen transition again
	var fade_in = get_tree().create_tween()
	$ScreenTransition/ColorRect.color = Color(0,0,0,0)
	fade_in.tween_property($ScreenTransition/ColorRect, "color", Color(0,0,0,1), TRANSITION_DURATION)
	await fade_in.finished
	fade_in.kill()
	
	# clean up
	current_floor.queue_free()
	

func _ready():
	while true:
		await gameplay_main()
