extends RigidBody3D

var skin: int = 0

func _ready() -> void:
	freeze = true
	linear_velocity = Vector3.ZERO
	get_child(skin).visible = true
	await get_tree().create_timer(.1).timeout
	unfreeze.call_deferred()
	await get_tree().create_timer(15).timeout
	queue_free.call_deferred()

func unfreeze():
	freeze = false

func _physics_process(_delta: float) -> void:
	if linear_velocity.length() >= 50:
		linear_velocity = linear_velocity.normalized() * 50

@rpc("call_local", "any_peer")
func take_hit(_velocity, _direction, _position):
	var dir = get_global_transform().origin - _position
	dir.y = 0
	
	if dir != Vector3.ZERO:
		if dir.length() > 100:
			dir = dir.normalized() * 100
		if _velocity > 250:
			_velocity = 250
		apply_impulse(dir * _velocity / 100 * mass, _position)
