extends Node

var Game # filled in by game when used
# Big singleton for holding enemy behaviors so a giant match statement isn't necessary, instead directly pointing.
# Expect all functions to include a "enemy" arg for the enemy node
# Abstract, multi-use behaviors require the enemy type dict, enemy-specific ones won't

# Enemy dictionary reminder:
# {
	# "hp": int, Enemy current HP
	# "state": str, Enemy state
	# "attack-state" : str, used to control more complex attacks
# }

# Enemy base reminder:
# ALL of the relevant info about the enemy should be stored in here!
# var enemy_info_type := {
	# "animation_resource": String leading to .tres file, contains animation resource
	# "collision_radius": int, radius of collision circle
	# "hp": 70, base HP
	# "speed": 80, units that enemy travels per physics process
	# "attack_distance": 80, distance that enemy travels before starting to attack player
	# "attack_collision_resource": String leading to .tres file for the collision resource
	# "attack_collision_transform": Vector2 detailing position of attack
	# "attack_power": 12, damage dealt to player, +- 15%
	# "attack_windup": 0.2, time in seconds in which it takes to hit the player
	# "attack_time": 0.2, time for which the attack is active
	# "attack_cooldown": time until next attack can occur
	# "notice_distance": 150, radius the player has to get in to be noticed by enemy
	# "knockback_weight": 300, changes knockback strength
	# "xp_value": 2, amount of xp given to player
# }

# Damage is handled by enemy to specify things.

# Abstract enemy attack event
# Enemy type is the type-based base stats, enemy_node is the node, enemy_info is the info dict
# Only for one-hits! Combo and chained attacks should have a dedicated attack
func on_attack_connect_default(enemy, enemy_type):
	# Don't attack invincible dashing players
	if not Game.player_state == "dash":
		# Hit once, attack power plus or minus 15%
		var damage_mod = round((randf() - 0.5) * (enemy_type["attack_power"] * 0.15))
		Game.player_health -= (enemy_type["attack_power"] + damage_mod)
	# Still hits and stops to trigger any flurry rush things
	enemy.get_node("AttackArea").set_deferred("monitoring", false)
	enemy.get_node("AttackArea").set_deferred("monitorable", false)
	
# Abstract enemy damage event
func on_damage_take(enemy, enemy_type):
	# Subtract from health
	# If has not already been hit by this attack
	if enemy not in Game.player_current_attack["enemies_hit"]:
		# Attack damage formula: player attack base +- 15 percent, multiply by crit if critting
		var crit_boost = 1 if randf() >= Game.player_stats["critical_chance"] else Game.player_stats["critical_bonus"]
		var damage_amount = Game.player_stats["attack_power"] + Game.player_stats["attack_bonus"]
		var damage_taken = (damage_amount + round((randf() - 0.5) * (damage_amount * 0.15))
			) * crit_boost
		
		# Add knockback
		enemy.set_meta("knockback_velocity", 
			(Game.player_current_attack["direction"] * enemy_type["knockback_weight"])
			)
		
		# Emit damage number
		# Damage is float by defualt, int cuts out decimal
		if crit_boost > 1:
			Game.call_deferred("emit_floating_text", enemy, "CRITICAL " + str(int(damage_taken)), 
			Game.player_current_attack["direction"], 0.3, Color.GREEN, 32)
			# Trigger critical boost
			if Game.player_stats["critical_rush"] == 1:
				Game.emit_floating_text(enemy, "CRITICAL RUSH", Vector2.DOWN, 0.3, Color.GREEN_YELLOW, 32)
				# First kill old tween
				if Game.current_rush_tween:
					Game.player_stats["attack_bonus"] = max(0, Game.player_stats["attack_bonus"]  - 6)
					Game.current_rush_tween.kill()
				
				Game.player_stats["attack_bonus"] += 6
				Game.current_rush_tween = Game.create_tween()
				Game.current_rush_tween.tween_interval(1)
				Game.current_rush_tween.tween_callback(func () :
					# Floored at 0 so it doesn't go negative
					Game.player_stats["attack_bonus"] = max(0, Game.player_stats["attack_bonus"]  - 6)
					)
		else:
			Game.call_deferred("emit_floating_text", enemy, str(int(damage_taken)), 
		Game.player_current_attack["direction"], 0.7)
		
		enemy.set_meta("hp", enemy.get_meta("hp") - damage_taken)
		# Placeholder death
		if enemy.get_meta("hp") <= 0:
			# Insert death animation
			enemy.call_deferred("queue_free")
			Game.give_xp(enemy_type["xp_value"])
		
		# Add to attack list so it isn't attacked again in the same hit
		Game.player_current_attack["enemies_hit"].append(enemy)


# Medium/basic enemy. John Enemy, if you will
var enemy_info_medium := {
	"animation_resource": "res://asset/enemy_assets/mediumenemy.tres",
	"collision_radius": 10,
	"hp": 70, 
	"speed": 80,
	"attack_distance": 80, 
	"attack_collision_resource": "res://asset/enemy_assets/mediumenemyattack.tres",
	"attack_collision_transform": Vector2(50,0),
	"attack_power": 5,
	"attack_type": "default",
	"attack_windup": 0.2,
	"attack_time": 0.2,
	"attack_cooldown": 0.8,
	"notice_distance": 150,
	"knockback_weight": 300,
	"xp_value": 2,
}

func attack_medium(enemy : Node):
	# Stands in place and slashes, with a cooldown
	# Placeholder, will probably be more complex
	# Check if it CAN attack, then attacks and sets cooldown
	if enemy.get_meta("attack_state") == "idle":
		# Tell everything that it's attacking
		enemy.set_meta("attack_state", "attacking")
		# Tweens are assigned to enemy so that they are cleaned up when it dies
		var attack_process = enemy.create_tween()
		# enemy brightens while winding up
		attack_process.tween_property(enemy, "modulate", Color(2,2,2,1), enemy_info_medium["attack_windup"])
		await attack_process.finished
		enemy.modulate = Color(1,1,1,1)
		enemy.get_node("AttackArea").monitoring = true
		enemy.get_node("AttackArea").monitorable = true
		enemy.set_meta("attack_state", "attack-cooldown")
		
		# Hits once with a slightly randomized attack value and deactivates to only hit once
		# Handled in default attack
		
		# Sets timers to stop attacking and to attack again
		var attack_finish_tween = enemy.create_tween()
		attack_finish_tween.tween_interval(0.2)
		attack_finish_tween.tween_callback(func () : 
			enemy.get_node("AttackArea").monitoring = false
			enemy.get_node("AttackArea").monitorable = false)
			
		var attack_cooldown_tween = enemy.create_tween()
		attack_cooldown_tween.tween_interval(1.2)
		attack_cooldown_tween.tween_callback(func () : 
			enemy.set_meta("attack_state", "idle"))
			
	if (enemy.global_position - Game.player_position).length() >= enemy_info_medium["attack_distance"]:
		enemy.set_meta("state", "chase")

# Tiny little motherfucking bugs
# Does the thing all tiny enemies do, hold in place and dash forward
var enemy_info_small := {
	"animation_resource": "res://asset/enemy_assets/smallenemy.tres",
	"collision_radius": 10,
	"hp": 30, 
	"speed": 120,
	"attack_distance": 100, 
	"attack_collision_resource": "res://asset/enemy_assets/smallenemyattack.tres",
	"attack_collision_transform": Vector2(0,0),
	"attack_power": 2,
	"attack_type": "default",
	"attack_windup": 0.2,
	"attack_time": 0.4,
	"attack_cooldown": 0.8,
	"notice_distance": 180,
	"knockback_weight": 500,
	"xp_value": 1,
}

func attack_small(enemy: Node):
	# Pretty much just attack medium
	# Dashes forward though
	if enemy.get_meta("attack_state") == "idle":
		# Tell everything that it's attacking
		enemy.set_meta("attack_state", "windup")
		# Tweens are assigned to enemy so that they are cleaned up when it dies
		var attack_process = enemy.create_tween()
		# enemy brightens while winding up
		attack_process.tween_property(enemy, "modulate", Color(2,2,2,1), enemy_info_small["attack_windup"])
		await attack_process.finished
		enemy.modulate = Color(1,1,1,1)
		enemy.get_node("AttackArea").monitoring = true
		
		# face player
		enemy.get_node("AttackArea").look_at(Game.player_position)
		
		# set momentum
		var dash_direction = (enemy.global_position - Game.player_position).normalized()
		var dash_momentum = dash_direction * -500 # ????? why negative???
		
		enemy.set_meta("movement_velocity", enemy.get_meta("movement_velocity") + dash_momentum)
		
		enemy.set_meta("attack_state", "attack")
		
		# Sets timers to stop attacking and to attack again
		var attack_finish_tween = enemy.create_tween()
		attack_finish_tween.tween_interval(enemy_info_small["attack_time"])
		attack_finish_tween.tween_callback(func () : 
			enemy.get_node("AttackArea").monitoring = false)
			
		var attack_cooldown_tween = enemy.create_tween()
		attack_cooldown_tween.tween_interval(enemy_info_small["attack_cooldown"])
		attack_cooldown_tween.tween_callback(func () : 
			enemy.set_meta("attack_state", "idle"))
			
	if (enemy.global_position - Game.player_position).length() >= enemy_info_small["attack_distance"]:
		enemy.set_meta("state", "chase")

var enemy_info_large := {
	"animation_resource": "res://asset/enemy_assets/largeenemy.tres",
	"collision_radius": 30,
	"hp": 100, 
	"speed": 50,
	"attack_distance": 100, 
	"attack_collision_resource": "res://asset/enemy_assets/largeenemyattack.tres",
	"attack_collision_transform": Vector2(50,0),
	"attack_power": 12,
	"attack_type": "default",
	"attack_windup": 0.8,
	"attack_time": 0.2,
	"attack_cooldown": 1.2,
	"notice_distance": 150,
	"knockback_weight": 100,
	"xp_value" : 3,
}

func attack_large(enemy: Node):
	# Same damn attack as normal but I'm too lazy to make them point to the same thing
	if enemy.get_meta("attack_state") == "idle":
		enemy.set_meta("attack_state", "windup")
		var attack_process = enemy.create_tween()
		attack_process.tween_property(enemy, "modulate", Color(2,2,2,1), enemy_info_large["attack_windup"])
		await attack_process.finished
		enemy.modulate = Color(1,1,1,1)
		enemy.get_node("AttackArea").monitoring = true
		enemy.set_meta("attack_state", "attack")
		# add some movement
		var dash_direction = (enemy.global_position - Game.player_position).normalized()
		var dash_momentum = dash_direction * -100 # ????? same bullshit as in small enemy ????
		
		enemy.set_meta("movement_velocity", enemy.get_meta("movement_velocity") + dash_momentum)
		
		var attack_finish_tween = enemy.create_tween()
		attack_finish_tween.tween_interval(enemy_info_large["attack_time"])
		attack_finish_tween.tween_callback(func () : 
			enemy.get_node("AttackArea").monitoring = false)
			
		var attack_cooldown_tween = enemy.create_tween()
		attack_cooldown_tween.tween_interval(enemy_info_large["attack_cooldown"])
		attack_cooldown_tween.tween_callback(func () : 
			enemy.set_meta("attack_state", "idle"))
			
	if (enemy.global_position - Game.player_position).length() >= enemy_info_large["attack_distance"]:
		enemy.set_meta("state", "chase")

# Possible enemy patterns for different types of floors
# They're all randomized by like 1 or 2
var enemy_spawning_patterns := {
	"easy": [
		{"small": 4, "medium": 3},
		{"small": 7, "medium": 2},
		{"small": 3, "medium": 5},
	],
	"medium": [
		{"small": 6, "medium": 4},
		{"small": 8, "medium": 3},
		{"small": 5, "medium": 8},
		{"small": 20}, # hahahaha funny
		{"small": 4, "medium": 5, "large": 1},
		{"small": 6, "medium": 5, "large": 2},
	],
	"hard": [
		{"small": 8, "medium": 6, "large": 2},
		{"small": 4, "medium": 5, "large": 3},
		{"small": 6, "medium": 6, "large": 1},
		{"small": 5, "medium": 7, "large": 2},
		{"medium": 9, "large": 4}
	]
}
