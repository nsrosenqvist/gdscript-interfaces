class_name KillableObject extends Node

const implements = [preload("res://example/can_take_damage.gd")]
#const implements = ["CanTakeDamage"]


var tester

signal foobar

func deal_damage() -> void:
	pass

func _ready() -> void:
	print(Interfaces.implements(self, CanTakeDamage))
