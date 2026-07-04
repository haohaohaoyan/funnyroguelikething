extends Node2D

# Controls a bunch of enemies with the same behavior

@export var type : String

var enemy_scene_base = preload("res://scene/enemy.tscn")

# Big information dict! HP numbers should be high because who doesn't like meaty big damage numbers?
var enemy_info := {
	"hp": 50, 
	"speed": 80,
}
