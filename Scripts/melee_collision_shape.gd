extends CollisionShape3D

@onready var col_shape: ConvexPolygonShape3D = shape

func set_size(length: float):
	#col_shape.points[4] = Vector3(0, 0, -length)
	scale = Vector3(1, 1, length)
