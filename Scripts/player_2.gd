extends CharacterBody3D

signal health_changed(health_value: float)
signal sprint_changed(sprint_reload_timer: float)

@onready var world = get_tree().get_root().get_child(0)
@onready var spawn_points = Array(world.spawn_points.get_children())

@onready var head = %Head
@onready var camera = $Head/Camera3D
@onready var weapon_manager = %WeaponManager
@onready var weapon_rig = weapon_manager.weapon_rig

@onready var kill_timer = %KillTimer
#@onready var anim_player = $Camera3D/AnimationPlayer
#@onready var muzzle_flash = $Camera3D/BulletSpawnPoint/MuzzleFlash
#@onready var pistol = $Camera3D/Pistol
#@onready var rifle = $Camera3D/Rifle
#@onready var raycast = $Camera3D/RayCast3D
#@onready var bullet_spawn_point = $Camera3D/BulletSpawnPoint
#
#@onready var explosion_scene = preload("res://Scenes/explosion.tscn")
#@onready var bullet_scene = preload("res://Scenes/bullet.tscn")

@onready var body_scene = preload("res://Scenes/body.tscn")

@onready var skins = $Skins
@onready var skin_number = 0

var max_health = 3
var health = max_health
@onready var regen_timer = %RegenTimer

const SPEED = 10.0
const SPRINT = 15.0
var speed = SPEED
@onready var sprint_start_timer = %SprintStartTimer
const max_sprint_time = 5
var sprint_time = max_sprint_time
var sprint_reload_time = max_sprint_time
const JUMP_VELOCITY = 10.0
var start_cam_speed = .005
var cam_speed = start_cam_speed

var input_dir: Vector2
var mouse_input: Vector2

var def_weapon_holder_pos: Vector3

var sprinting: bool = false

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 20.0
#var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var text_to_show: String
@onready var text_label = %TextLabel

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
	
	#var skin = skins.get_child(skin_number)
	#skin.visible = true
	#skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	def_weapon_holder_pos = weapon_manager.position
	if get_multiplayer_authority() == 1:
		if text_label.text == "":
			text_label.text = "You are trying to host"
	else:
		text_label.text = "You are not the host"
	#show_text("text_to_show")

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * cam_speed)
		head.rotate_x(-event.relative.y * cam_speed)
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)
		mouse_input = event.relative

	if event.is_action_pressed("up"):
		var current_time = Time.get_ticks_msec() / 1000.0
		if first_tap_detected and (current_time - last_tap_time <= double_tap_delay):
			sprinting = true
			first_tap_detected = false
		else:
			first_tap_detected = true
			last_tap_time = current_time

	if event.is_action_released("up"):
		sprinting = false

func apply_impulse(impulse: Vector3) -> void:
	# Add the impulse (change in velocity) to the current velocity
	velocity += impulse

@rpc("call_local", "any_peer")
func take_hit(_velocity, direction, _position):
	# Flatten the direction to avoid launching the player vertically
	#direction.y = 0
	direction.y /= 10
	if _velocity > 200:
		_velocity /= 2
	if _velocity > 350:
		_velocity = 350
	#if direction != Vector3.ZERO:
		#direction = direction.normalized()
	apply_impulse(_velocity * direction / 5)

func _push_away_rigid_bodies():
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		#if c.get_collider() is CharacterBody3D:
			#pass
			#c.get_collider().rpc("take_hit", velocity, 3, null)
		
		if c.get_collider() == null: return
		if c.get_collider().is_in_group("pushable"):
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
		
		if position.length() > 100:
			if !kill_timer.is_stopped():
				pass
			else:
				$KillTimer.start()

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	update_sprint_timer(delta)
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	
	_push_away_rigid_bodies()
	regenerate(delta)
	
	move_and_slide()

func _process(delta: float) -> void:
	cam_tilt(input_dir.x, delta)
	weapon_tilt(input_dir.x, delta)
	weapon_sway(delta)
	weapon_bob(velocity.length(), delta)

func cam_tilt(input_x: float, delta: float):
	camera.rotation.z = lerp(camera.rotation.z, -input_x * .05, 10 * delta)

func weapon_tilt(input_x: float, delta: float):
	weapon_rig.rotation.z = lerp(weapon_rig.rotation.z, -input_x * .05, 10 * delta)

func weapon_sway(delta):
	mouse_input = lerp(mouse_input,Vector2.ZERO,10*delta)
	#mouse_input = lerp(mouse_input,Vector2(randf_range(-100, 100), randf_range(-100, 100)),10*delta)
	weapon_manager.rotation.x = lerp(weapon_manager.rotation.x, mouse_input.y * .003, 10 * delta)
	weapon_manager.rotation.y = lerp(weapon_manager.rotation.y, mouse_input.x * .003, 10 * delta)
	#weapon_manager.position.x = lerp(weapon_manager.position.x, -mouse_input.x * .05, 10 * delta)
	#weapon_manager.position.y = lerp(weapon_manager.position.y, -mouse_input.y * .05, 10 * delta)
	weapon_rig.rotation.z = lerp(weapon_rig.rotation.z, mouse_input.x * .005, 10 * delta)

func weapon_bob(vel : float, delta):
	if vel > 0 and is_on_floor():
		var bob_amount : float = 0.04
		var bob_freq : float = 0.01
		weapon_manager.position.y = lerp(weapon_manager.position.y, def_weapon_holder_pos.y + sin(Time.get_ticks_msec() * bob_freq) * bob_amount, 10 * delta)
		weapon_manager.position.x = lerp(weapon_manager.position.x, def_weapon_holder_pos.x + sin(Time.get_ticks_msec() * bob_freq * 0.5) * bob_amount, 10 * delta)
		
	else:
		var bob_amount : float = 0.02
		var bob_freq : float = 0.003
		weapon_manager.position.y = lerp(weapon_manager.position.y, def_weapon_holder_pos.y + sin(Time.get_ticks_msec() * bob_freq) * bob_amount, 10 * delta)
		weapon_manager.position.x = lerp(weapon_manager.position.x, def_weapon_holder_pos.x + sin(Time.get_ticks_msec() * bob_freq * 0.5) * bob_amount, 10 * delta)
		#weapon_manager.position.y = lerp(weapon_manager.position.y, def_weapon_holder_pos.y, 10 * delta)
		#weapon_manager.position.x = lerp(weapon_manager.position.x, def_weapon_holder_pos.x, 10 * delta)

var first_tap_detected := false
var last_tap_time := 0.0
var double_tap_delay := 0.25  # Seconds

func _on_sprint_start_timer_timeout():
	# Time window expired — reset
	first_tap_detected = false

func update_sprint_timer(delta: float):
	if sprinting:
		if sprint_time > 0:
			speed = SPRINT
			sprint_time -= delta
			if sprint_time <= 0:
				sprinting = false
				speed = SPEED
		else:
			sprinting = false
			speed = SPEED
	else:
		if sprint_time < sprint_reload_time:
			sprint_time += delta
		speed = SPEED
	emit_signal("sprint_changed", sprint_time)
	#print("Sprinting:", sprinting, " | Sprint time:", sprint_time)

@rpc("any_peer")
func receive_damage(damage):
	if damage > max_health:
		damage = max_health
	health -= damage
	if health <= .05:
		rpc("spawn_body", get_global_transform(), skin_number)
		respawn.call_deferred()
	health_changed.emit(health)
	regen_timer.start()

func respawn():
	weapon_manager.respawn()
	health = max_health
	emit_signal("health_changed", health)
	velocity = Vector3.ZERO
	position = spawn_points[randi_range(0, spawn_points.size() - 1)].global_position

@rpc("any_peer", "call_local", "reliable")
func set_gamertag(new_gamertag: String) -> void:
	if new_gamertag == "" or new_gamertag == null:
		$Gamertag.text = "I have no gamertag and I am sad"
	else:
		$Gamertag.text = new_gamertag

@rpc("any_peer", "call_local", "reliable")
func set_skin(_skin_number: int) -> void:
	#print(_skin_number)
	if _skin_number == null:
		skin_number = 0
	else:
		skin_number = _skin_number

func set_skin_transparent():
	var skin = skins.get_child(skin_number)
	skin.visible = true
	skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

var bodies: int = 0

@rpc("call_local", "any_peer", "reliable")
func spawn_body(transform_: Transform3D, _skin_number: int):
	var body = body_scene.instantiate()
	bodies += 1
	body.name = str(bodies)
	body.skin = _skin_number
	get_tree().get_root().get_child(0).body_folder.add_child(body)
	body.set_global_transform(transform_)
	body.linear_velocity = Vector3.ZERO
	#print("spawning body")

func _on_weapon_manager_scope_changed(scoping: bool, scope_factor: float, _background: bool, _constant_dot: bool, _constant_circle: bool, _constant_cross: bool) -> void:
	if scoping:
		cam_speed = start_cam_speed / scope_factor
	else:
		cam_speed = start_cam_speed

func _on_kill_timer_timeout() -> void:
	if position.length() > 100:
		weapon_manager.respawn()
		health = max_health
		position = Vector3.ZERO
		health_changed.emit(health)

func regenerate(delta: float):
	if regen_timer.is_stopped():
		if health < max_health:
			health += delta / 5
		else:
			health = max_health
	emit_signal("health_changed", health)
	#print("Sprinting:", sprinting, " | Sprint time:", sprint_time)

func _on_regen_timer_timeout() -> void:
	#regenerate()
	pass

func show_text(text: String):
	text_label.text = text
