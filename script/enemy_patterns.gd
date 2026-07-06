extends Node

# Big singleton for holding enemy behaviors so a giant match statement isn't necessary, instead directly pointing.
# Expect all functions to include a "enemy" arg for the enemy information dict

# Enemy dictionary reminder:
# {
	# "node": Node2D, Enemy node
	# "hp": int, Enemy current HP
	# "state": str, Enemy state
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

# Basic enemy (demo)
var enemy_info_basic := {
	"hp": 50, 
	"speed": 80,
	"attack_distance": 80, 
	"attack_power": 4,
	"notice_distance": 150,
}

func attack_basic(enemy):
	# Stands in place and slashes, with a cooldown
	# Placeholder, will probably be more complex
	var enemy_node = enemy["node"]
	# Check if it CAN attack, then attacks and sets cooldown
	if enemy["attack-state"] == "idle":
		enemy_node.get_node("AttackArea").monitoring = true
		enemy["attack-state"] = "attack-cooldown"
		
		# Hits once with a slightly randomized attack value and deactivates to only hit once
		if not enemy_node.get_node("AttackArea").area_entered.get_connections():
			enemy_node.get_node("AttackArea").connect("area_entered", func (_blank) :
				# Don't attack invincible dashing players
				if not Global.player_state == "dash":
					var damage_mod = round((random.randf() - 0.5) * (enemy_info_basic["attack_power"] * 0.15))
					Global.player_health -= (enemy_info_basic["attack_power"] + damage_mod)
				# Still hits and stops to trigger any flurry rush things
				enemy_node.get_node("AttackArea").set_deferred("monitoring", false)
				enemy["attack-state"] = "idle")
		
		# Sets timers to stop attacking and to attack again
		get_tree().create_timer(0.2).connect("timeout", func () : 
			enemy_node.get_node("AttackArea").monitoring = false)
		get_tree().create_timer(0.8).connect("timeout", func () :
			enemy["attack-state"] = "idle")
	if (enemy_node.global_position - Global.player_position).length() >= enemy_info_basic["attack_distance"]:
		enemy["state"] = "chase"
