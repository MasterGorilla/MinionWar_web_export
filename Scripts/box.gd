extends RigidBody3D

@onready var kill_timer = $KillTimer

@onready var start_position = get_global_position()

var max_distance = 50
var health: int = 10

func _process(_float):
	if position.length() > 100:
		if !kill_timer.is_stopped(): return
		#print("starting timer")
		$KillTimer.start()

@rpc("call_local", "any_peer")
func take_hit(_velocity, _direction, _position):
	var dir = get_global_transform().origin - _position
	
	if dir != Vector3.ZERO:
		apply_impulse(dir * _velocity / 50, _position)

@rpc("call_local", "any_peer")
func receive_damage(_damage: float):
	health -= 1
	#print(health)
	if health < 1:
		health = 10
		global_position = start_position
		global_position += Vector3(0, 25, 0)
		angular_velocity = Vector3.ZERO
		#rotation = Vector3.ZERO
		linear_velocity = Vector3.ZERO

func _on_kill_timer_timeout() -> void:
	if position.length() > max_distance:
		#print("respawning")
		health = 10
		global_position = start_position
		global_position += Vector3(0, 25, 0)
		angular_velocity = Vector3.ZERO
		#rotation = Vector3.ZERO
		linear_velocity = Vector3.ZERO
