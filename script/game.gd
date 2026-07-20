extends Node2D

@onready var floor_packed = preload("res://scene/level.tscn")
@onready var upgrade_box_template = preload("res://upgrades/upgrade_box.tscn")
const TRANSITION_DURATION = 0.5

# Pointers for UI elements
@onready var hp_bar = $HUDLayer/HUD/HPBar
@onready var xp_bar = $HUDLayer/HUD/XPBar

# Information pertinent to current game

# Big reminder to self: These are the physics layers in order:
# Layer 1: both player AND enemy collision, specifically for things like walls and obstacles
# Layer 2: enemy-enemy collision, to stop them from like stacking up
# Layer 3: Your attacks
# Layer 4: Enemy attacks
# Layer 5: Interactive objects

var player_position : Vector2 = Vector2(0,0)
var player_state : String = "idle"

signal game_over

var player_max_health : int = 50 :
	set(new_max_health) : 
		# Increase health by increment if positive but still caps it to max
		var old_max_health = player_max_health # needs to be preserved
		player_max_health = new_max_health
		player_health += max(0, new_max_health - old_max_health)
		hp_bar.get_node("Label").text = "HP: " + str(player_health) + "/" + str(player_max_health)
		hp_bar.max_value = new_max_health

var player_health : int = 50 :
	set(new_health) : 
		# Emit health change signal to game scene
		player_health = min(new_health, player_max_health)
		hp_bar.get_node("Label").text = "HP: " + str(new_health) + "/" + str(player_max_health)
		hp_bar.value = new_health
		if player_health <= 0:
			game_over.emit()

# List of nodes already hit by the current attack to avoid dealing 5000 hits in a second
var player_current_attack := {
	"direction" : Vector2.UP,
	"enemies_hit": []
}

# Extra player stats that can be changed by upgrades and weapons
var player_stats := {
	"attack_power": 12, # Base damage points per attack
	"attack_cooldown": 0.15, # Time between attacks
	"attack_range": 200, # Attack distance, plus/minus 100
	"dash_cooldown": 0.8, # Dash wait cooldown
	"dash_range": 400, # Dash distance, plus/minus 20
	"critical_chance": 0.05, # Chance out of 1 that an attack is critical
	"critical_bonus": 3, # Number to multiply by on critical
	"autoheal": 0, # Value to heal by at end of each floor
	"critical_rush": 0, # int boolean, if raised grants 1 second of increased base damage after crit
	"counter_damage": 5, # int, damage boost on split second dodge
	"counter_length": 1, # int, seconds for which counter damage boost lasts
	"counter_heal": 0, # int, amount to heal by when triggering counter
}

# Other more specific things
var current_rush_tween : Tween
var current_counter_tween : Tween

# Player level, current XP count, this level's necessary amount
var player_level := {
	"level": 0,
	"current_xp": 0,
	"this_level_req": 8, 
}

# Array of upgrades
var current_upgrades := []

# Setter, definitely
func give_xp(xp):
	player_level["current_xp"] += xp
	if player_level["current_xp"] >= player_level["this_level_req"]:
		# Update stats
		player_level["current_xp"] = 0
		player_level["level"] += 1
		player_level["this_level_req"] = round(player_level["this_level_req"] * 1.2)
		upgrade_select()
		
	# Update UI
	xp_bar.max_value = player_level["this_level_req"]
	xp_bar.value = player_level["current_xp"]
	xp_bar.get_node("Label").text = "Level "+ str(player_level["level"])
	
# Criteria checker to make sure that the upgrade fits its own criteria
func upgrade_filter(upgrade_name):
	# Flags
	var prerequisites_met = false
	var not_a_duplicate = false
	
	var upgrade = Upgrades.upgrade_info[upgrade_name]
	prerequisites_met = false
	not_a_duplicate = false
	# Check for prerequisite meeting
	if "prerequisites" in upgrade:
		for prereq in upgrade["prerequisites"]:
			if prereq in current_upgrades:
				prerequisites_met = true
	else:
		prerequisites_met = true
		
	# Check if this upgrade is already in the thing
	if not "duplicate" in upgrade:
		if not upgrade_name in current_upgrades:
			not_a_duplicate = true
	else:
		not_a_duplicate = true
		
	if (not prerequisites_met) or (not not_a_duplicate):
		# reset upgrade and try again
		upgrade_name = Upgrades.upgrade_info.keys().pick_random()
		upgrade_name = upgrade_filter(upgrade_name)
	return upgrade_name
		
	# Return after limit anyway
	# return upgrade_name

# Handling the upgrade menu
func upgrade_select():
	# Do the upgrade menu things
	$UpgradeMenu.visible = true
	floor_active = false
	# Also remove all previous upgrade slots
	for child in $UpgradeMenu/Base/Panel/MarginContainer/UpgradeContainer.get_children():
		if !child is Label:
			child.queue_free()
	
	var current_upgrade_selection = []
	# Decide on upgrades and add them
	for i in range(3):
		# Create upgrade selection box
		var upgrade_name = Upgrades.upgrade_info.keys().pick_random()
		
		# Check upgrade against rules
		upgrade_name = upgrade_filter(upgrade_name)
		
		while upgrade_name in current_upgrade_selection:
			upgrade_name = Upgrades.upgrade_info.keys().pick_random()
			upgrade_name = upgrade_filter(upgrade_name)

		current_upgrade_selection.append(upgrade_name)
		
		# Add to list of displayed upgrades
		var upgrade = Upgrades.upgrade_info[upgrade_name]
		
		var upgrade_box = upgrade_box_template.instantiate()
		upgrade_box.get_node("MarginContainer/VBoxContainer/Title").text = upgrade["title"]
		upgrade_box.get_node("MarginContainer/VBoxContainer/Description").text = upgrade["description"]
		$UpgradeMenu/Base/Panel/MarginContainer/UpgradeContainer.add_child(upgrade_box)
		
		# Funny effect, also forces player to notice menu
		await get_tree().create_timer(0.2).timeout
		
		# Make the upgrade do its thing
		upgrade_box.connect("pressed", func ():
			for stat in upgrade["stat_changes"].keys():
				# Max health is separate from other stats
				if stat == "max_health":
					player_max_health += upgrade["stat_changes"]["max_health"]
				else:
					player_stats[stat] += upgrade["stat_changes"][stat]
			# Add to upgrade list
			current_upgrades.append(upgrade_name)
			# Resume normal operation
			floor_active = true
			$UpgradeMenu.visible = false
			)
			
	# Enable buttons
	for child in $UpgradeMenu/Base/Panel/MarginContainer/UpgradeContainer.get_children():
		if !child is Label:
			child.disabled = false

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
	else:
		# Creates a new label
		new_label = Label.new()
		new_label.top_level = true
		$FloatingText.add_child(new_label)
		# Give it a label settings resource
		new_label.label_settings = LabelSettings.new()
	# It is now WORKING
	floating_text_occupied.append(new_label)
	
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

var current_game_stats := {
	"floor_count": 14,
	"enemies_spawned": 0,
	"enemies_killed_total": 0,
	"total_damage": 0,
	"small_killed": 0,
	"medium_killed": 0,
	"large_killed": 0,
	"damage_dealt": 0,
	"crits_dealt": 0,
	"counters_triggered": 0,
}

# FULLY handles a single floor
func gameplay_main():
	# ensure black screen
	$ScreenTransition/ColorRect.color = Color(0,0,0,1)
	
	var current_floor = floor_packed.instantiate()
	add_child(current_floor)
		
	var current_floor_data =  await current_floor.setup(current_game_stats["floor_count"])
	
	if current_game_stats["floor_count"] == 14:
		current_floor.get_node("BossArena").connect("boss_defeated", _on_victory)
		
	# add spawned enemies to enemy count
	current_game_stats["enemies_spawned"] += current_floor_data["enemy_count"]
	
	$Player.position = current_floor_data["player_start_pos"]
	$Player/Camera2D.position = Vector2i(0,0)
	$Player/Camera2D.reset_smoothing()
	
	# reset anim
	$Player/AnimatedSprite2D.play("default")
	
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
	
	# Do autoheal, pause player anim
	player_health += player_stats["autoheal"]
	$Player/AnimatedSprite2D.play("default")
	
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
	# Set starting stats to trigger setters
	player_max_health = 50
	player_health = 50
	
	# Set global game reference
	EnemyPatterns.Game = self
	Upgrades.Game = self
	
	while true:
		await gameplay_main()
		current_game_stats["floor_count"] += 1
		$HUDLayer/HUD/FloorCounter.text = str(15 - current_game_stats["floor_count"]) + " days until deadilne"
		
func _on_game_over() -> void:
	$GameOverScreen.visible = true
	$GameOverScreen/Panel/VBoxContainer/Label.text = [
		"Another side project abandoned.",
		"Were you sure you could even follow through on that one?",
		"At least you made an effort."
	].pick_random()
	$Player.visible = false
	floor_active = false
	
func _on_victory() -> void:
	$VictoryScreen.visible = true
	# Populate data
	$VictoryScreen/Panel/MarginContainer/VBoxContainer/Label.text = "
	Time: 0 \n
	\n
	Total Problems Solved: " + str(current_game_stats["enemies_killed_total"]) + " \n
	Bugs Fixed: " + str(current_game_stats["small_killed"]) + " \n
	Tasks Completed: " + str(current_game_stats["medium_killed"]) + " \n
	Errors Resolved: " + str(current_game_stats["large_killed"]) + " \n
	Deadlines Met: 1 \n
	% of Problems Solved: " + str(current_game_stats["enemies_killed_total"]/current_game_stats["enemies_spawned"]) + "\n
	\n
	Total Damage: " + str(current_game_stats["total_damage"]) + " \n
	Critical Hits Inflicted: " + str(current_game_stats["crits_dealt"]) + " \n
	Counterattacks Triggered: " + str(current_game_stats["counters_triggered"]) + " \n
	Upgrades Taken: " + str(len(current_upgrades)) + " \n
	\n
	" + ["We're out of beta, we're releasing on time", 
	"Well done, you.", 
	"Time to publish, preferably for free", 
	"You think it's gonna do well on the market?",
	"Can you believe you made the deadline?"
	].pick_random()
	# Player doesn't die
	floor_active = false
		
func _on_restart():
	# screen transition again
	var fade_in = get_tree().create_tween()
	$ScreenTransition/ColorRect.color = Color(0,0,0,0)
	fade_in.tween_property($ScreenTransition/ColorRect, "color", Color(0,0,0,1), TRANSITION_DURATION)
	await fade_in.finished
	fade_in.kill()
	
	# restart entire scene
	get_tree().reload_current_scene()
