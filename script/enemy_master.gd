extends Node2D

# Controls a bunch of enemies with the same behavior

@export var type : String :
	set(new_type):
		type = new_type
		enemy_info = EnemyPatterns.get("enemy_info_" + new_type)

var enemy_scene_base = preload("res://scene/enemy.tscn")

# Dictionary of enemy stat constants like speed and stuff
var enemy_info : Dictionary

# Data for enemies is stored as their metadata, which isn't convenient but they're 
# attached only to the enemy now, not their master.

# Spawn an enemy, obviously. Position can be inputted from other nodes
func spawn_typed_enemy(spawn_position):
	# Instantiate enemy, add it, place it
	var new_enemy = enemy_scene_base.instantiate()
	add_child(new_enemy)
	new_enemy.global_position = spawn_position
	
	# Set the notice radius according to this enemy group's type
	new_enemy.get_node("SightArea/CollisionShape2D").shape.radius = enemy_info["notice_distance"]
	
	# Set metadata about hp, state, attack state, etc
	new_enemy.set_meta("hp", enemy_info["hp"])
	new_enemy.set_meta("state", "idle")
	new_enemy.set_meta("attack_state", "idle")
	
	new_enemy.get_node("AttackArea").connect("area_entered", func (_blank) :
		EnemyPatterns.call("on_attack_connect_" + enemy_info["attack_type"], enemy_info, new_enemy)
		)
		
	
	new_enemy.get_node("DamageArea").connect("body_entered", func(_blank) :
		EnemyPatterns.on_damage_take(new_enemy)
		)
	new_enemy.get_node("DamageArea").connect("area_entered", func(_blank) :
		EnemyPatterns.on_damage_take(new_enemy)
		)
	
func _physics_process(_delta: float) -> void:
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
						# Emit notice signal TODO
						enemy.set_meta("state", "chase")
			"chase":
				enemy.look_at(Global.player_position)
				
				# If not close enough to player to attack, start getting close to attack, duh!
				enemy.velocity = (Global.player_position - enemy.global_position).normalized() * enemy_info["speed"]
				enemy.move_and_slide()
				
				# Start attacking if close enough
				if (enemy.global_position - Global.player_position).length() <= enemy_info["attack_distance"]:
					# Change state to attack
					enemy.set_meta("state", "attack")
			"attack":
					# Pass control over to the enemy attack handler
					EnemyPatterns.call("attack_" + type, enemy)
