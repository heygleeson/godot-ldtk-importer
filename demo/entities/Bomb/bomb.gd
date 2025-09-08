extends Node2D

enum BombType {FIRE, ELECTRIC, ICE}

@export var damage_type: BombType = BombType.FIRE
@export var damage_amount: int = 1

@onready var label: Label = $Label

func _ready():
	label.text = "Bomb type: %s\n Damage: %s" % [BombType.keys()[damage_type], damage_amount]
