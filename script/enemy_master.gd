extends Node2D

# Controls a bunch of enemies with the same behavior

@export var type : String :
	set(new_type):
		type = new_type
		enemy_info = EnemyPatterns.get("enemy_info_" + new_type)

var enemy_scene_base = preload("res://scene/enemy.tscn")

# Big information dict! HP numbers should be high because who doesn't like meaty big damage numbers?
# Basic enemy is used as placeholder
var enemy_info : Dictionary

var controlled_enemies := [] # Dictionaries of the enemy's data, like health and state. 



# Spawn an enemy, obviously. Position can be inputted from other nodes
func spawn_typed_enemy(spawn_position):
	# Instantiate enemy, add it, place it
	var new_enemy = enemy_scene_base.instantiate()
	add_child(new_enemy)
	new_enemy.global_position = spawn_position
	
	# Set the notice radius according to this enemy group's type
	new_enemy.get_node("SightArea/CollisionShape2D").shape.radius = enemy_info["notice_distance"]
	
	controlled_enemies.append(
		{
			"node": new_enemy,
			"hp": enemy_info["hp"],
			"state": "idle",
			"attack-state": "idle"
		}
		)
	
func _physics_process(_delta: float) -> void:
	for enemy in controlled_enemies:
		# Per-enemy script
		var enemy_node = enemy["node"]
		match enemy["state"]:
			"idle":
				# Use an Area2D to detect player/enemies that have spotted player
				# Detects bodies only, not other enemy areas or walls
				if len(enemy_node.get_node("SightArea").get_overlapping_bodies()) > 0:
					if enemy_node.get_node("SightArea").get_overlapping_bodies().any(
						func (node) : return node is CharacterBody2D # Check if node is player
					):
						# Emit notice signal TODO
						enemy["state"] = "chase"
			"chase":
				enemy_node.look_at(Global.player_position)
				
				# If not close enough to player to attack, start getting close to attack, duh!
				enemy_node.velocity = (Global.player_position - enemy_node.global_position).normalized() * enemy_info["speed"]
				enemy_node.move_and_slide()
				
				# Start attacking if close enough
				if (enemy_node.global_position - Global.player_position).length() <= enemy_info["attack_distance"]:
					# Change state to attack
					enemy["state"] = "attack"
			"attack":
					# Pass control over to the enemy attack handler
					EnemyPatterns.call("attack_" + type, enemy)
