extends Area3D

@onready var particles = $Explosion

var _position
var force
var damage

var exclude_path: NodePath
var exclusions = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	if exclude_path:
		exclusions[get_node_or_null(exclude_path)] = true
	
	
	particles.emitting = true
	#$AudioStreamPlayer3D.play()
	#await get_tree().physics_frame
	await get_tree().process_frame
	$CollisionShape3D.disabled = true

func _on_body_entered(body: Node3D) -> void:
	if exclusions.has(body):
		return
	else: exclusions[body] = true
	_position = global_transform.origin
	var distance = (body.position - _position).length()
	var direction = (body.position - _position).normalized()

	if body.has_method("take_hit"):
		var force2 = force
		if body is CharacterBody3D:
			force2 *= 5
		body.take_hit.rpc(force2, direction, _position)
	
	if body.has_method("receive_damage"):
		if body.is_multiplayer_authority(): pass
		else:
			body.receive_damage.rpc_id(body.get_multiplayer_authority(), damage / distance)
			#print("damaging " + str(body) + " with " + str(damage))

func _on_explosion_finished() -> void:
	queue_free()
