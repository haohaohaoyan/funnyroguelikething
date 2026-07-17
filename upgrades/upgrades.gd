extends Node

var Game

# Only for upgrades and their information
# Format:
# "name": {
#	"title": String, display name of upgrade
#	"description": String, displayed description
#	"stat_changes": dictionary of modifiable player stat variables and the change to apply to them
#	"duplicate": bool, checks if it's applicable more than once
#	"prerequisites": Array, list of upgrades to check for, must be present bc looper is simple
#}

var upgrade_info = {
	"damage_base_1": {
		"title": "Actual IDE",
		"description": "+3 base damage",
		"stat_changes": {
			"attack_power": 3
		},
	},
	
	"damage_base_2": {
		"title": "Organized file structure",
		"description": "+5 base damage",
		"stat_changes": {
			"attack_power": 5
		},
		"prerequisites": ["damage_base_1"]
	},
	
	"rubber_ducky": {
		"title": "Rubber duck debugging",
		"description": "+12 base damage, but +0.2 second attack cooldown",
		"stat_changes": {
			"attack_power": 12,
			"attack_cooldown": 0.2,
		},
		"prerequisites": ["damage_base_1"]
	},
	
	"higher_crit_1": {
		"title": "Working solution",
		"description": "Higher crit chance",
		"stat_changes": {
			"critical_chance": 0.05
		},
	},
	
	"higher_crit_2": {
		"title": "Complete refactor",
		"description": "+50% crit damage",
		"stat_changes": {
			"critical_bonus": 0.5,
		},
		"prerequisites": ["higher_crit_1"]
	},
	
	"max_health_add_1": {
		"title": "Caffeine",
		"description": "+20 max HP",
		"stat_changes": {
			"max_health": 20
		},
		"duplicate": true
	},
	
	"max_health_add_2": {
		"title": "Instant noodle pack",
		"description": "+30 max HP",
		"stat_changes": {
			"max_health": 30
		},
		"duplicate": true,
		"prerequisites": ["max_health_add_1"]
	},
	
	"dash_length_1": {
		"title": "Productive procrastination",
		"description": "Dash lasts longer and travels faster, but takes longer to recharge",
		"stat_changes": {
			"dash_range": 80,
			"dash_cooldown": 0.3
		}
	}, 
	
	"autoheal_1": {
		"title": "White noise for sleeping",
		"description": "+3 HP healed per floor",
		"stat_changes": {
			"autoheal": 3
		}
	}
}
