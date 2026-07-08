extends Node

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
	# "hp": 50, base HP
	# "speed": 80, units that enemy travels per physics process
	# "attack_distance": 80, distance that enemy travels before starting to attack player
	# "attack_power": 12, damage dealt to player, +- 15%
	# "notice_distance": 150,
# }

# Damage is handled by enemy to specify things.

var random = RandomNumberGenerator.new()

# Abstract enemy attack event
# Enemy type is the type-based base stats, enemy_node is the node, enemy_info is the info dict
# Only for one-hits! Combo and chained attacks should have a dedicated attack
func on_attack_connect_default(enemy_type, enemy):
	# Don't attack invincible dashing players
	if not Global.player_state == "dash":
		# Hit once, attack power plus or minus 15%
		var damage_mod = round((random.randf() - 0.5) * (enemy_type["attack_power"] * 0.15))
		Global.player_health -= (enemy_type["attack_power"] + damage_mod)
	# Still hits and stops to trigger any flurry rush things
	enemy.get_node("AttackArea").set_deferred("monitoring", false)
	
# Abstract enemy damage event
func on_damage_take(enemy):
	# Subtract from health
	# TODO: add knockback
	enemy.set_meta("hp", enemy.get_meta("hp") - Global.player_attack_power)
	# Placeholder death
	if enemy.get_meta("hp") <= 0:
		# Insert death animation
		enemy.queue_free()


# Basic enemy (demo)
var enemy_info_basic := {
	"hp": 50, 
	"speed": 80,
	"attack_distance": 80, 
	"attack_power": 4,
	"attack_type": "default",
	"notice_distance": 150,
}

func attack_basic(enemy : Node):
	# Stands in place and slashes, with a cooldown
	# Placeholder, will probably be more complex
	# Check if it CAN attack, then attacks and sets cooldown
	if enemy.get_meta("attack_state") == "idle":
		enemy.get_node("AttackArea").monitoring = true
		enemy.set_meta("attack_state", "attack-cooldown")
		
		# Hits once with a slightly randomized attack value and deactivates to only hit once
		
		# Sets timers to stop attacking and to attack again
		# Timers check for enemy first in case it dies while they're running
		get_tree().create_timer(0.2).connect("timeout", func () : 
			if enemy:
				enemy.get_node("AttackArea").monitoring = false)
		get_tree().create_timer(1.2).connect("timeout", func () :
			if enemy:
				enemy.set_meta("attack_state", "idle"))
	if (enemy.global_position - Global.player_position).length() >= enemy_info_basic["attack_distance"]:
		enemy.set_meta("state", "chase")
