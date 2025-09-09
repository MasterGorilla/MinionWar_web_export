extends RigidBody3D

@onready var explosion_scene = preload("res://Scenes/explosion_effect.tscn")
var damage = 0
var force = 0

var exclude_path: NodePath
var exclude: Node3D

func _ready():
	exclude = get_node_or_null(exclude_path)
	#print(str(exclude))
	if exclude:
		add_collision_exception_with(exclude)

func _on_body_entered(body: Node) -> void:
	if exclude:
		if body == exclude: return
		remove_collision_exception_with(exclude)
	explode(get_global_position(), null)
	
	#var shooter_node = get_node_or_null(shooter)
	#if shooter_node != null:
		#shooter_node.rpc("explode", global_position)
	
	#if body.has_method("take_hit"):
		#if !(body is RigidBody3D):
			#var direction = -linear_velocity.normalized()
			#body.take_hit.rpc(linear_velocity.length() * 5, direction, position)
	#
	#if body.has_method("receive_damage"):
		#if body.is_multiplayer_authority(): return
		#body.receive_damage.rpc_id(body.get_multiplayer_authority(), damage * 3)
		#queue_free()
	
	queue_free()

@rpc("call_local", "any_peer")
func take_hit(_velocity, _direction, _position):
	queue_free()

func _on_timer_timeout() -> void:
	queue_free()

func explode(target, _body):
	var explosion = explosion_scene.instantiate()
	explosion.position = target
	explosion.damage = damage + 1
	explosion.force = 200
	#explosion.exclusions[body] = true
	get_tree().get_root().get_child(0).add_child(explosion)
