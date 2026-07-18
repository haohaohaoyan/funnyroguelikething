extends Node2D

# Specifically for boss

@onready var Game = get_node("/root/Game")
@onready var bullet_packed = preload("res://scene/boss_bullet.tscn")

signal boss_defeated

var boss_current_info := {
	"hp": 800,
	"state": "chase",
	"attack_state": "idle",
	"movement_velocity": Vector2(0,0),
	# There is no knockback
}

var base_boss_info := {
	# Unmagicnumbering everything
	"attack_distance": 100,
	"movement_speed": 60,
	"hp_threshold": 400, # HP value to have faster/more hard-hitting attacks
}

func _ready():
	# enemy is boss, it has prepacked stuff 
	$Enemy/AnimatedSprite2D.sprite_frames = load("res://asset/enemy_assets/boss.tres")
	# Set things according to enemy type
	# Position is already set
	$Enemy/SightArea/CollisionShape2D.shape.radius = 200
	$Enemy/CollisionShape2D.shape.radius = 30
	$Enemy/AttackArea/CollisionShape2D.shape = load("res://asset/enemy_assets/bossattackbase.tres")
	$Enemy/AttackArea/CollisionShape2D.position = Vector2(60,0)
	
	$Enemy/AttackArea.connect("area_entered", func (_blank) :
		_damage_player(10)
		)
		
	$BossAttackTimer.start()
	
func _damage_player(value):
	# same shit as enemy patterns but you can manually set the damage now
	if not Game.player_state == "dash":
		# Hit once, attack power plus or minus 15%
		var damage_mod = round((randf() - 0.5) * (value * 0.15))
		Game.player_health -= (value + damage_mod)
	# Still hits and stops to trigger any flurry rush things
	$Enemy/AttackArea.set_deferred("monitoring", false)
	$Enemy/AttackArea.set_deferred("monitorable", false)
	
func _boss_damage_take():
	# Shit copied from enemy patterns
	if $Enemy not in Game.player_current_attack["enemies_hit"]:
		# Attack damage formula: player attack base +- 15 percent, multiply by crit if critting
		var crit_boost = 1 if randf() >= Game.player_stats["critical_chance"] else Game.player_stats["critical_bonus"]
		var damage_amount = Game.player_stats["attack_power"] + Game.player_stats["attack_bonus"]
		var damage_taken = (damage_amount + round((randf() - 0.5) * (damage_amount * 0.15))
			) * crit_boost
			
		boss_current_info["hp"] -= damage_taken
		Game.player_current_attack["enemies_hit"].append($Enemy)
		
		# Emitting text & triggering critical
		if crit_boost > 1:
			Game.call_deferred("emit_floating_text", $Enemy, "CRITICAL " + str(int(damage_taken)), 
			Game.player_current_attack["direction"], 0.3, Color.GREEN, 32)
			# Trigger critical boost
			if Game.player_stats["critical_rush"] == 1:
				Game.emit_floating_text($Enemy, "CRITICAL RUSH", Vector2.DOWN, 0.3, Color.GREEN_YELLOW, 32)
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
			Game.call_deferred("emit_floating_text", $Enemy, str(int(damage_taken)), 
		Game.player_current_attack["direction"], 0.7)
		
		if boss_current_info["hp"] <= 0:
			$Enemy.call_deferred("queue_free")
			boss_defeated.emit()
			# Stop processing
			set_physics_process(false)
	
func _physics_process(_delta: float) -> void:
	if !Game.floor_active or !get_node_or_null("Enemy"):
		return
	
	# Determine state separately
	# Attack every couple of seconds, otherwise chase player
	if $BossAttackTimer.is_stopped():
		boss_current_info["state"] = ["rush", "shoot"].pick_random()
	else:
		boss_current_info["state"] = "chase"
		
	# Match by state
	# Attacks are also handled here
	match boss_current_info["state"]:
		"chase": 
			# Just ominously move at player
			$Enemy.look_at(Game.player_position)
			
			boss_current_info["movement_velocity"] = (Game.player_position - $Enemy.global_position).normalized() * base_boss_info["movement_speed"]
		"rush":
			# Slash multiple times at player in quick succession
			if boss_current_info["attack_state"] == "idle":
				boss_current_info["attack_state"] = "attacking"
				var attack_windup = $Enemy.create_tween()
				# enemy brightens while winding up
				attack_windup.tween_property($Enemy, "modulate", Color(2,2,2,1), 0.2)
				await attack_windup.finished
				$Enemy.modulate = Color(1,1,1,1)
				
				var attack_count = 5 if boss_current_info["hp"] <= base_boss_info["hp_threshold"] else 3
				var attack_cooldown = 0.4 if boss_current_info["hp"] <= base_boss_info["hp_threshold"] else 0.8
				var distance_base = 400 if boss_current_info["hp"] <= base_boss_info["hp_threshold"] else 300
				for i in range(attack_count):
					# Flag that makes script kill itself if everything's over
					if !$Enemy: return
					
					var distance = distance_base + ((Game.player_position - $Enemy.global_position).length())
					boss_current_info["movement_velocity"] = (Game.player_position - $Enemy.global_position).normalized() * distance
					$Enemy.look_at(Game.player_position)
					$Enemy/AttackArea.monitoring = true
					$Enemy/AttackArea.monitorable = true
					# Set time for rush to stop being an active attack
					var attack_tween = $Enemy.create_tween()
					attack_tween.tween_interval(0.3)
					attack_tween.tween_callback(func () :
						$Enemy/AttackArea.monitoring = false
						$Enemy/AttackArea.monitorable = false
						boss_current_info["movement_velocity"] = Vector2(0,0))
						
					await get_tree().create_timer(attack_cooldown).timeout
				
				boss_current_info["attack_state"] = "idle"
				$BossAttackTimer.start()
		"shoot": 
			# Shoot multiple waves of bullets at player. 2 waves at high health, 3 at low
			if boss_current_info["attack_state"] == "idle":
				boss_current_info["attack_state"] = "attacking"
				# Stands still
				
				# Windup again 
				var attack_windup = $Enemy.create_tween()
				# enemy brightens while winding up
				attack_windup.tween_property($Enemy, "modulate", Color(2,2,2,1), 0.3)
				await attack_windup.finished
				$Enemy.modulate = Color(1,1,1,1)
				
				boss_current_info["movement_velocity"] = Vector2(0,0)
				
				# Flag that makes script kill itself if everything's over
				if !$Enemy: return
				
				# Creates fan of bullets a few times
				var attack_interval = 0.3 if boss_current_info["hp"] <= base_boss_info["hp_threshold"] else 0.6
				var bullet_speed = 500 if boss_current_info["hp"] <= base_boss_info["hp_threshold"] else 400
				
				var bullet_fan = func (list_of_directions) :
					for direction in list_of_directions:
						var new_bullet = bullet_packed.instantiate()
						add_child(new_bullet)
						new_bullet.global_position = $Enemy.global_position
						new_bullet.velocity = direction.normalized() * bullet_speed
						new_bullet.connect("collided", func(): 
							_damage_player(8)
							)
					await get_tree().create_timer(attack_interval).timeout
				
				# Directly repeats things
				await bullet_fan.call([Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT])
				await bullet_fan.call([Vector2(1,1), Vector2(1,-1), Vector2(-1,-1), Vector2(-1,1)])
				if boss_current_info["hp"] <= base_boss_info["hp_threshold"]:
					await bullet_fan.call([Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, 
					Vector2(1,1), Vector2(1,-1), Vector2(-1,-1), Vector2(-1,1)])
					
				boss_current_info["attack_state"] = "idle"
				$BossAttackTimer.start()
				
	# Handles damage and health
	if $Enemy/DamageArea.has_overlapping_bodies() or $Enemy/DamageArea.has_overlapping_areas():
		_boss_damage_take()
	# Set boss attack timer if low enough on health
	# I know this isn't optimal
	if boss_current_info["hp"] <= base_boss_info["hp_threshold"]:
		$BossAttackTimer.wait_time = 0.8
				
	$Enemy.velocity = boss_current_info["movement_velocity"]
	$Enemy.move_and_slide()
