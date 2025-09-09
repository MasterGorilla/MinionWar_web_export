extends Area3D

#@onready var col_shape: BoxShape3D = $CollisionShape3D.shape
@onready var col_shape: CollisionShape3D = $CollisionShape3D

func get_collision() -> Array:
	var bodies = get_overlapping_bodies()
	if bodies.size() > 1:
		var first_body = bodies[1]
		#return [first_body, first_body.get_global_position()]  # Area3D doesn't give exact collision point
		return [first_body, get_global_position()]  # Area3D doesn't give exact collision point
	else:
		return [null, global_position]

func set_size(new_size: float):
	#$CollisionShape3D.shape.size = new_size
	col_shape.set_size(new_size)

func set_position2(pos: Vector3):
	$CollisionShape3D.position = pos
