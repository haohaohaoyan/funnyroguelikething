extends Node2D

@onready var Game = get_node("/root/Game")

# Controls a bunch of enemies with the same behavior

@export var type : String :
	set(new_type):
		type = new_type
		enemy_info = EnemyPatterns.get("enemy_info_" + new_type)
		enemy_animation_base = load(enemy_info["animation_resource"])
		enemy_attack_hitbox = load(enemy_info["attack_collision_resource"])

var enemy_scene_base = preload("res://scene/enemy.tscn")
var enemy_animation_base # Depends on enemy type
var enemy_attack_hitbox # Also depends on enemy type

# Dictionary of enemy stat constants like speed and stuff
var enemy_info : Dictionary

# Data for enemies is stored as their metadata, which isn't convenient but they're 
# attached only to the enemy now, not their master.

# Spawn an enemy, obviously. Position can be inputted from other nodes
func spawn_typed_enemy(spawn_position):
	# Instantiate enemy, add it, place it
	var new_enemy = enemy_scene_base.instantiate()
	new_enemy.global_position = spawn_position
	
	# Set things according to enemy type
	new_enemy.get_node("SightArea/CollisionShape2D").shape.radius = enemy_info["notice_distance"]
	new_enemy.get_node("CollisionShape2D").shape.radius = enemy_info["collision_radius"]
	new_enemy.get_node("AttackArea/CollisionShape2D").shape = enemy_attack_hitbox
	new_enemy.get_node("AttackArea/CollisionShape2D").position = enemy_info["attack_collision_transform"]
	new_enemy.get_node("AnimatedSprite2D").sprite_frames = enemy_animation_base
	
	# Set metadata about hp, state, attack state, etc
	new_enemy.set_meta("hp", enemy_info["hp"])
	new_enemy.set_meta("state", "idle")
	new_enemy.set_meta("attack_state", "idle")
	new_enemy.set_meta("movement_velocity", Vector2(0,0))
	new_enemy.set_meta("knockback_velocity", Vector2(0,0))
	
	# random animation direction
	if type == "small":
		new_enemy.get_node("AnimatedSprite2D").flip_h = [true, false].pick_random()
	
	add_child(new_enemy)
	
	new_enemy.get_node("AttackArea").connect("area_entered", func (_blank) :
		EnemyPatterns.call("on_attack_connect_" + enemy_info["attack_type"], new_enemy, enemy_info)
		)
		
func _physics_process(_delta: float) -> void:
	if !Game.floor_active:
		return
	# Handles movement & actions
	for enemy in get_children():
		# Per-enemy script
		match enemy.get_meta("state"):
			"idle":
				# Use an Area2D to detect player/enemies that have spotted player
				# Detects bodies only, not other enemy areas or walls
				if len(enemy.get_node("SightArea").get_overlapping_bodies()) > 0:
					if enemy.get_node("SightArea").get_overlapping_bodies().any(
						func (node) : return node is CharacterBody2D # Check if node is player
					):
						Game.emit_floating_text(enemy, "!", Vector2.UP, 0, Color.RED, 32)
						enemy.set_meta("state", "chase")
			"chase":
				enemy.get_node("AttackArea").look_at(Game.player_position)
				
				# If not close enough to player to attack, start getting close to attack, duh!
				enemy.set_meta("movement_velocity", (Game.player_position - enemy.global_position).normalized() * enemy_info["speed"])
				
				# Start attacking if close enough
				if (enemy.global_position - Game.player_position).length() <= enemy_info["attack_distance"]:
					# Change state to attack
					enemy.set_meta("movement_velocity", Vector2(0,0))
					enemy.set_meta("state", "attack")
			"attack":
				# Pass control over to the enemy attack handler
				EnemyPatterns.call("attack_" + type, enemy)
					
		# Handles damage and health
		if enemy.get_node("DamageArea").has_overlapping_bodies() or enemy.get_node("DamageArea").has_overlapping_areas():
			EnemyPatterns.on_damage_take(enemy, enemy_info, type)
			# Aggros them just in case 
			enemy.set_meta("state", "chase")
			
		# Process & add knockback velocity
		# The enemy's own movement & knockback are stored separately to process separately
		enemy.velocity = enemy.get_meta("movement_velocity") + enemy.get_meta("knockback_velocity")
		# After adding, give friction to knockback velocity
		enemy.set_meta("knockback_velocity", 
			enemy.get_meta("knockback_velocity").move_toward(Vector2(0,0), 15)) # Delta is friction value
		
		enemy.move_and_slide()
		
		# Handle enemy animations
		# Separate from movement...
		var animation_node = enemy.get_node("AnimatedSprite2D")
		if type == "small":
			animation_node.flip_h = Game.player_position.x - enemy.global_position.x < 0
		match enemy.get_meta("state"): 
			"idle":
				animation_node.play("idle")
			"chase": 
				animation_node.play("chase")
			"attack":
				animation_node.play(enemy.get_meta("attack_state"))
