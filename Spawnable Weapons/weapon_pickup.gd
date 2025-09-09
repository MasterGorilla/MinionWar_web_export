extends RigidBody3D

@export var weapon_name: String
@export var current_ammo: int = 0
@export var reload_ammo: int = 0

var pick_up_ready := false

func _ready():
	await get_tree().create_timer(2.0).timeout
	pick_up_ready = true
	await get_tree().create_timer(30.0).timeout
	queue_free()
