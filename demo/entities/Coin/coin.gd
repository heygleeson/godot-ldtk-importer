extends Node2D

@export var is_collected = false
@export var reward_text : String = ""

@onready var label: Label = $Label

func _ready():
	label.text = "Is Collected: %s\n Reward Text: %s" % [is_collected, reward_text]
