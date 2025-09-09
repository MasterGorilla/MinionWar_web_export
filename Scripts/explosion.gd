extends GPUParticles3D

func _ready() -> void:
	emitting = true  # Ensure particles start emitting immediately

func _on_finished() -> void:
	queue_free()
