extends Node2D

@export var speed := 80.0
@export var end_point : Vector2
@onready var label: Label = $Label

func _ready():
	label.text = "Speed: %s\n EndPoint: %s" % [speed, end_point]
