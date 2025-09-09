extends CharacterBody3D

signal health_changed(health_value: float)

@onready var camera = $Camera3D
@onready var weapon_manager = $Camera3D/WeaponManager
#@onready var anim_player = $Camera3D/AnimationPlayer
#@onready var muzzle_flash = $Camera3D/BulletSpawnPoint/MuzzleFlash
#@onready var pistol = $Camera3D/Pistol
#@onready var rifle = $Camera3D/Rifle
#@onready var raycast = $Camera3D/RayCast3D
#@onready var bullet_spawn_point = $Camera3D/BulletSpawnPoint
#
#@onready var explosion_scene = preload("res://Scenes/explosion.tscn")
#@onready var bullet_scene = preload("res://Scenes/bullet.tscn")


enum weapon_type {pistol, rifle}
#@export var weapon_choice = weapon_type["pistol"]
@export var weapon_choice = 0

@export var color := Color.RED

var health = 3

const SPEED = 10.0
const JUMP_VELOCITY = 10.0
var start_cam_speed = .005
var cam_speed = start_cam_speed

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 20.0

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority(): return
	
	#match weapon_choice:
		#weapon_type["rifle"]:
			#$Camera3D/Rifle.visible = true
		#weapon_type["pistol"]:
			#$Camera3D/Pistol.visible = true
	
	#camera.project_ray_origin(get_viewport().get_size())
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true

	for i in $Minion.get_children():
		i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * cam_speed)
		camera.rotate_x(-event.relative.y * cam_speed)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func apply_impulse(impulse: Vector3) -> void:
	# Add the impulse (change in velocity) to the current velocity
	velocity += impulse

@rpc("call_local", "any_peer")
func take_hit(_velocity, direction, _position):
	apply_impulse(100 * direction / 3)

func _push_away_rigid_bodies():
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		#if c.get_collider() is CharacterBody3D:
			#pass
			#c.get_collider().rpc("take_hit", velocity, 3, null)
		
		if c.get_collider() is RigidBody3D:
			var push_dir = -c.get_normal()
			# How much velocity the object needs to increase to match player velocity in the push direction
			var velocity_diff_in_push_dir = self.velocity.dot(push_dir) - c.get_collider().linear_velocity.dot(push_dir)
			# Only count velocity towards push dir, away from character
			velocity_diff_in_push_dir = max(0., velocity_diff_in_push_dir)
			# Objects with more mass than us should be harder to push. But doesn't really make sense to push faster than we are going
			const MY_APPROX_MASS_KG = 10.0
			var mass_ratio = min(1., MY_APPROX_MASS_KG / c.get_collider().mass)
			# Optional add: Don't push object at all if it's 4x heavier or more
			if mass_ratio < 0.25:
				continue
			# Don't push object from above/below
			push_dir.y = 0
			# 5.0 is a magic number, adjust to your needs
			var push_force = mass_ratio * .25
			c.get_collider().apply_impulse(push_dir * velocity_diff_in_push_dir * push_force, c.get_position() - c.get_collider().global_position)

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	
	_push_away_rigid_bodies()
	
	
	move_and_slide()

#func place_explosion(target):
	#var direction = (target - bullet_spawn_point.get_global_transform().origin).normalized()
	#var intersection = PhysicsRayQueryParameters3D.create(bullet_spawn_point.get_global_transform().origin, target + direction * 2)
	#var collision = get_world_3d().direct_space_state.intersect_ray(intersection)
	#
	#if collision:
		#var hit_player = collision.collider
		#if hit_player != self and hit_player.has_method("receive_damage"):
			#hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority(), rifle.damage)
			##hit_player.apply_impulse(Vector3(10, 10, 0), hit_player.global_position - raycast.get_collision_point())
	#
	#if collision.has("position"):
		#rpc("explode", collision.position)

#@rpc("any_peer", "call_local")
#func explode(target):
	#var explosion = explosion_scene.instantiate()
	#explosion.position = target
	#get_tree().current_scene.add_child(explosion)

#@rpc("any_peer", "call_local")
#func spawn_bullet(target, shooter):
	#var direction = (target - bullet_spawn_point.get_global_transform().origin).normalized()
	#var bullet = bullet_scene.instantiate()
	#
	#get_tree().current_scene.add_child(bullet)
	#bullet.damage = pistol.damage
	#bullet.set_linear_velocity(direction * rifle.velocity)
	#bullet.position = bullet_spawn_point.global_position
	#bullet.look_at(target)
	#bullet.shooter = shooter

#@rpc("call_local")
#func play_shoot_effects():
	##anim_player.stop()
	##anim_player.play("Pistol Shoot")
	#muzzle_flash.restart()
	#muzzle_flash.emitting = true

@rpc("any_peer")
func receive_damage(damage):
	health -= damage
	if health <= 0:
		weapon_manager.respawn()
		health = 3
		position = Vector3.ZERO
	health_changed.emit(health)

@rpc("any_peer", "call_local", "reliable")
func set_gamertag(new_gamertag: String) -> void:
	if new_gamertag == "" or new_gamertag == null:
		$Gamertag.text = "I have no gamertag and I am sad"
	else:
		$Gamertag.text = new_gamertag

@rpc("any_peer", "call_local", "reliable")
func set_color(new_color: Color) -> void:
	if new_color == Color.WHITE or new_color == null:
		$Gamertag.modulate = Color.WHITE
	else:
		$Gamertag.modulate = new_color


func _on_weapon_manager_scope_changed(scoping: bool, scope_factor: float) -> void:
	if scoping:
		cam_speed = start_cam_speed / scope_factor
	else:
		cam_speed = start_cam_speed
