extends Camera3D

# Recoil configuration
var target_recoil: float = 0.0
var current_recoil: float = 0.0
var recoil_speed: float = 7.5  # Fast recoil application (radians per second)
var recovery_speed: float = 5.0  # Fast recovery to neutral (radians per second)

func _process(delta: float) -> void:
	# Move current_recoil toward target_recoil quickly
	current_recoil = lerp(current_recoil, target_recoil, 1.0 - exp(-recoil_speed * delta))
	
	# Recover target_recoil back to 0
	target_recoil = lerp(target_recoil, 0.0, 1.0 - exp(-recovery_speed * delta))
	
	# Apply rotation (up is negative in X for Camera3D)
	rotation.x = current_recoil

func apply_recoil(amount: float) -> void:
	# Add recoil amount to target (in radians)
	target_recoil += amount
