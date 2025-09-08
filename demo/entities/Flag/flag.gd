extends Node2D

@export var coins : Array[Node]
@onready var label: Label = $Label

func _ready():
	label.text = "Coins Collected: %s" % [coins]
