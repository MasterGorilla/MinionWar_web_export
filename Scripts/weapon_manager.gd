extends Node3D

signal weapon_changed(weapon_name: String, constant_dot: bool, dot_color: Color, background: bool, constant_circle: bool, circle_color: Color, _circle_radius: float, constant_cross: bool, cross_color: Color, _cross_inner: float, _cross_outer: float)
signal update_ammo(ammo: int)
signal update_weapon_stack(weapon_stack)
signal scope_changed(scoping: bool, scope_factor: float, constant_dot: bool, constant_circle: bool, constant_cross: bool)

@onready var world = get_tree().get_root().get_child(0)
@onready var spawn_points = Array(world.spawn_points.get_children())

@onready var anim_player = %AnimationPlayer
@onready var bullet_spawn_point = %BulletSpawnPoint
@onready var muzzle_flash = %MuzzleFlash
@onready var raycast = $RayCast3D
@onready var explosion_scene = preload("res://Scenes/explosion.tscn")

@onready var melee_check = %MeleeCheck

#********************
#SFX
#********************
@onready var shoot_sound = %ShootSound
@onready var thump_sound = %ThumpSound
@onready var slice_sound = %SliceSound
@onready var swipe_sound = %SwipeSound

@onready var sounds_ints = {
	shoot_sound: 0,
	thump_sound: 1,
	slice_sound: 2,
	swipe_sound: 3
}

@onready var ints_sounds = {
	0: shoot_sound,
	1: thump_sound,
	2: slice_sound,
	3: swipe_sound
}

@onready var camera = $".."
@onready var camera_focus = camera.fov

@onready var weapon_rig = %WeaponRig

var scoping := false

var current_weapon: Weapon_Resource

var weapon_stack = [] #weapons held

var next_weapon: String

#var weapon_index = 0

var weapon_list = {}

@export var weapon_resources: Array[Weapon_Resource]

@export var start_weapons: Array[String]

enum {NULL, HITSCAN, PROJECTILE}

func _ready() -> void:
	initialize(start_weapons)

func _input(event) -> void:
	if !is_multiplayer_authority(): return
	
	if event.is_action_pressed("weapon up"):
		var getref = weapon_stack.find(current_weapon.weapon_name)
		getref = min(getref + 1, weapon_stack.size() - 1)
		exit(weapon_stack[getref])
	
	if event.is_action_pressed("weapon down"):
		var getref = weapon_stack.find(current_weapon.weapon_name)
		getref = max(getref - 1, 0)
		exit(weapon_stack[getref])
	
	if event.is_action_pressed("shoot"):
		shoot()
	
	if event.is_action_pressed("reload"):
		reload()
	
	if event.is_action_pressed("drop"):
		drop_weapon(current_weapon.weapon_name)
	
	if event.is_action_pressed("melee"):
		melee()
	
	if event.is_action_pressed("scope"):
		if !current_weapon.Scopable:
			return
		if anim_player.is_playing():
			return
		scope(!scoping)

func initialize(_start_weapons):
	for weapon in weapon_resources:
		weapon_list[weapon.weapon_name] = weapon
	
	for weapon in start_weapons:
		weapon_stack.push_back(weapon)
	
	current_weapon = weapon_list[weapon_stack[0]]
	emit_signal("update_weapon_stack", weapon_stack)
	#call_enter()
	enter()
	call_deferred("set_up_melee_check", current_weapon.Melee_Range)

#@rpc("call_local")
func enter():
	if is_multiplayer_authority():
		emit_signal("weapon_changed", current_weapon.weapon_name, current_weapon.constant_dot, current_weapon.Dot_Color, current_weapon.constant_circle, current_weapon.Circle_Color, current_weapon.Circle_Radius, current_weapon.constant_cross, current_weapon.Cross_Color, current_weapon.Cross_Inner_Radius, current_weapon.Cross_Outer_Radius)
		emit_signal("update_ammo", [current_weapon.Current_Ammo, current_weapon.Reload_Ammo])
		scoping = false
		scope_signal()
		anim_player.queue(current_weapon.Activate_Anim)

#@rpc("call_local")
func exit(_next_weapon: String, deactivate := true):
	if _next_weapon != current_weapon.weapon_name:
		if !anim_player.is_playing():
			next_weapon = _next_weapon
			if deactivate:
				anim_player.play(current_weapon.Deactivate_Anim)
				if scoping:
					camera.fov = camera_focus
					scoping = false
					scope_signal()
			else:
				anim_player.play("RESET")
				change_weapon(next_weapon)
				#scope_signal()

#@rpc("call_local")
func change_weapon(weapon_name: String):
	current_weapon = weapon_list[weapon_name]
	next_weapon = ""
	#call_enter()
	
	set_up_melee_check(current_weapon.Melee_Range)
	
	enter()
	if scoping:
		scoping = false
		camera.fov = camera_focus
		scope_signal()

func set_up_melee_check(_range: float):
	melee_check.set_size(_range + .5)
	melee_check.set_position2(Vector3(0, 0, -(_range + .5) / 2))

func shoot():
	if current_weapon.Current_Ammo > 0:
		if !anim_player.is_playing():
			
			if current_weapon.Melee_Only:
				melee_shoot()
				return
			
			rpc("shoot_effect")
			shoot_sound.play()
			
			anim_player.play(current_weapon.Shoot_Anim)
			current_weapon.Current_Ammo -= 1
			emit_signal("update_ammo", [current_weapon.Current_Ammo, current_weapon.Reload_Ammo])
			var camera_collision_pos = get_camera_collision(current_weapon.Weapon_Range)[1]
			match current_weapon.Type:
				NULL:
					print("No type chosen")
				HITSCAN:
					hit_scan_collision(camera_collision_pos)
				PROJECTILE:
					#print(str(get_parent().get_parent().get_parent().get_path()))
					rpc("launch_projectile", camera_collision_pos, current_weapon.weapon_name, get_parent().get_parent().get_parent().get_path())
			
			recoil()
	else:
		if current_weapon.Melee_Only:
			melee()
		else:
			reload()

func melee_shoot():
	if current_weapon.Melee_Only:
		if !anim_player.is_playing():
			if anim_player.get_current_animation() == current_weapon.Scope_Anim: return
			anim_player.play(current_weapon.Shoot_Anim)
			if current_weapon.Blade:
				play_sound.rpc(sounds_ints[swipe_sound])
			if scoping:
				camera.fov = camera_focus
				scoping = false
				scope_signal()
			
			set_up_melee_check(current_weapon.Weapon_Range)
			await get_tree().create_timer(.05).timeout
			#var collision = get_camera_collision(current_weapon.Melee_Range)
			var collision = melee_check.get_collision()
			if collision[0]:
				#if swipe_sound.is_playing():
					#swipe_sound.stop()
				if current_weapon.Blade:
					play_sound.rpc(sounds_ints[slice_sound])
				else:
					play_sound.rpc(sounds_ints[thump_sound])
				#thump_sound.play()
				var direction = (collision[1] - owner.get_global_transform().origin).normalized()
				hit_scan_damage(collision[0], direction, collision[1], current_weapon.Projectile_Velocity, current_weapon.Damage)
				current_weapon.Current_Ammo -= 1
				emit_signal("update_ammo", [current_weapon.Current_Ammo, current_weapon.Reload_Ammo])
			
			set_up_melee_check(current_weapon.Melee_Range)

func recoil():
	if scoping:
		camera.apply_recoil(current_weapon.RecoilAmmount / 4)
	else:
		camera.apply_recoil(current_weapon.RecoilAmmount)

@rpc("any_peer", "call_local")
func play_sound(sound: int):
	ints_sounds[sound].play()

#@rpc("call_local")
func reload():
	if current_weapon.Current_Ammo == current_weapon.Magazine:
		return
	elif !anim_player.is_playing():
		if scoping:
			scope(false)
		if !current_weapon.Reload_Ammo <= 0:
			anim_player.queue(current_weapon.Reload_Anim)
		else:
			anim_player.queue(current_weapon.Out_Of_Ammo_Anim)

func scope(_scoping: bool):
	scoping = _scoping

	if _scoping:
		anim_player.play(current_weapon.Scope_Anim)
		scope_signal()
	
	else:
		anim_player.play_backwards(current_weapon.Scope_Anim)
		camera.fov = camera_focus
		make_weapon_transparent(false)

	# Always emit the signal immediately
	#scope_signal()

func scope_signal():
	emit_signal("scope_changed", scoping, current_weapon.Scope_Factor, current_weapon.Background, current_weapon.constant_dot, current_weapon.constant_circle, current_weapon.constant_cross)
	if scoping:
		muzzle_flash.visible = false
	
	else:
		muzzle_flash.visible = true
		make_weapon_transparent(false)

func make_weapon_transparent(_scoping: bool):
	if _scoping:
		for weapon in weapon_rig.get_children():
			if weapon.is_in_group("Weapon Node"):
				if weapon.visible:
					weapon.get_child(0).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
					#print(str(weapon.get_child(0)) + " setting transparent")
					#weapon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	else:
		for weapon in weapon_rig.get_children():
			if weapon.is_in_group("Weapon Node"):
				if weapon.visible:
					#weapon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
					weapon.get_child(0).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func calc_reload():
	var reload_ammount = min(current_weapon.Magazine - current_weapon.Current_Ammo,\
			current_weapon.Reload_Ammo)
	current_weapon.Current_Ammo += reload_ammount
	current_weapon.Reload_Ammo -= reload_ammount
	emit_signal("update_ammo", [current_weapon.Current_Ammo, current_weapon.Reload_Ammo])

func melee():
	if anim_player.get_current_animation() != current_weapon.Melee_Anim:
		if anim_player.get_current_animation() == current_weapon.Scope_Anim: return
		anim_player.play(current_weapon.Melee_Anim)
		if scoping:
			camera.fov = camera_focus
			scoping = false
			scope_signal()
		#var collision = get_camera_collision(current_weapon.Melee_Range)
		await get_tree().create_timer(.05).timeout
		var collision = melee_check.get_collision()
		if collision[0]:
			thump_sound.play()
			var direction = (collision[1] - owner.get_global_transform().origin).normalized()
			hit_scan_damage(collision[0], direction, collision[1], 400, current_weapon.Melee_Damage)

func get_camera_collision(_range) -> Array:
	#var camera = get_viewport().get_camera_3d()
	#var viewport = get_viewport().get_size()
	#
	#var ray_origin = camera.project_ray_origin(viewport/2)
	#var ray_end = camera.project_ray_normal(viewport/1) * current_weapon.Weapon_Range
	#
	#var intersection_ray = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	##intersection_ray.collision_mask = 1 | 2 | 3
	#var intersection = get_world_3d().direct_space_state.intersect_ray(intersection_ray)
	#
	#if !intersection.is_empty():
		#print("camera collided at " + str(intersection.position))
		#var col_point = intersection.position
		#return col_point
	#else:
		#return ray_end
	raycast.target_position = Vector3(0,0,-_range)
	raycast.force_raycast_update()
	var collider = raycast.get_collider()
	if collider == self or collider == null:
		pass
	
	if raycast.is_colliding():
		if raycast.get_collider() == null: 
			return [null, raycast.to_global(raycast.target_position)]
		return [raycast.get_collider(), raycast.get_collision_point()]
	else:
		return [null, raycast.to_global(raycast.target_position)]

func hit_scan_collision(col_point):
	var direction = (col_point - bullet_spawn_point.get_global_transform().origin).normalized()
	#print(str(bullet_spawn_point.get_global_transform().origin))
	#print(str(bullet_spawn_point.global_position))
	var intersection_ray = PhysicsRayQueryParameters3D.create(bullet_spawn_point.get_global_transform().origin, col_point + direction * 2)
	
	var bullet_collision = get_world_3d().direct_space_state.intersect_ray(intersection_ray)
	#var direction = (col_point - bullet_spawn_point.get_global_transform().origin).normalized()
	#var intersection = PhysicsRayQueryParameters3D.create(bullet_spawn_point.get_global_transform().origin, col_point + direction * 2)
	#var bullet_collision = get_world_3d().direct_space_state.intersect_ray(intersection)
	
	if bullet_collision:
		hit_scan_damage(bullet_collision.collider, direction, bullet_collision.position)
		if bullet_collision.has("position"):
			rpc("explode", bullet_collision.position)

func hit_scan_damage(collider, direction, _position, _velocity := current_weapon.Projectile_Velocity, _damage := current_weapon.Damage):
	if collider == null: return
	if collider.has_method("take_hit"):
		collider.rpc("take_hit", _velocity, direction, _position)
	if collider.has_method("receive_damage"):
		if collider is CharacterBody3D:
			if collider.is_multiplayer_authority(): return
			collider.receive_damage.rpc_id(collider.get_multiplayer_authority(), _damage)
		else:
			#print("damaging box")
			collider.receive_damage.rpc(_damage)

@rpc("any_peer", "call_local")
func explode(target):
	var explosion = explosion_scene.instantiate()
	explosion.position = target
	get_tree().get_root().get_child(0).add_child(explosion)

@rpc("any_peer", "call_local")
func launch_projectile(target: Vector3, weapon_name, shooter_path: NodePath):
	var _current_weapon = weapon_list[weapon_name]
	var bullet_direction = (target - bullet_spawn_point.get_global_transform().origin).normalized()
	var projectile = _current_weapon.Projectile_Scene.instantiate()
	
	projectile.exclude_path = shooter_path
	get_tree().get_root().get_child(0).add_child(projectile)
	projectile.damage = _current_weapon.Damage
	projectile.set_linear_velocity(bullet_direction * _current_weapon.Projectile_Velocity)
	projectile.position = bullet_spawn_point.global_position
	projectile.look_at(target)

#@rpc("call_local")
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == current_weapon.Deactivate_Anim:
		change_weapon(next_weapon)
	
	if anim_name == current_weapon.Shoot_Anim and current_weapon.Auto_Fire:
		if Input.is_action_pressed("shoot"):
			shoot()
	
	if anim_name == current_weapon.Reload_Anim:
		calc_reload()
	
	if anim_name == current_weapon.Scope_Anim:
		scope_signal()
		if scoping:
			make_weapon_transparent(true)
			camera.fov = camera_focus / current_weapon.Scope_Factor
		#else:
			#camera.fov = camera_focus

func _on_pickup_detector_body_entered(body: Node3D) -> void:
	if body.pick_up_ready:
		var weapon_in_stack = weapon_stack.find(body.weapon_name, 0)
		
		if weapon_in_stack == -1:
			var getref = weapon_stack.find(current_weapon.weapon_name)
			getref += 1
			if getref < 0:
				getref = 0
			elif getref >= weapon_stack.size():
				getref = weapon_stack.size() - 1
			weapon_stack.insert(getref, body.weapon_name)
			#weapon_index = 0
			
			if !current_weapon.Melee_Only:
				weapon_list[body.weapon_name].Current_Ammo = body.current_ammo
				weapon_list[body.weapon_name].Reload_Ammo = body.reload_ammo
				emit_signal("update_ammo", [current_weapon.Current_Ammo, current_weapon.Reload_Ammo])
			
			emit_signal("update_weapon_stack", weapon_stack)
			exit(body.weapon_name)
			rpc("delete_node_everywhere", body.get_path())
		
		else:
			var weapon = weapon_list[body.weapon_name]
			if weapon.Reload_Ammo == weapon.Max_Ammo: return
			var remaining = add_ammo(body.weapon_name, body.current_ammo + body.reload_ammo)
			if remaining <= 0:
				rpc("delete_node_everywhere", body.get_path())
			else:
				var reload_ammo = remaining
				rpc("delete_node_everywhere", body.get_path())
				spawn_weapon.rpc(weapon.Weapon_Drop.resource_path, weapon_rig.get_global_transform(), 0, reload_ammo)

func drop_weapon(_name: String):
	if anim_player.is_playing(): return
	var weapon_ref = weapon_stack.find(_name, 0)
	
	if weapon_ref != -1 and !weapon_stack.size() <= 1:
		weapon_stack.pop_at(weapon_ref)
		emit_signal("update_weapon_stack", weapon_stack)
		
		#var weapon_dropped_scene = weapon_list[_name].Weapon_Drop
		#var location = get_tree().get_current_scene()
		
		spawn_weapon.rpc(weapon_list[_name].Weapon_Drop.resource_path, bullet_spawn_point.get_global_transform(), current_weapon.Current_Ammo, current_weapon.Reload_Ammo)
		
		var getref = weapon_stack.find(current_weapon.weapon_name)
		getref = max(getref - 1, 0)
		exit(weapon_stack[getref], false)

func add_ammo(_Weapon: String, Ammo: int) -> int:
	var weapon = weapon_list[_Weapon]
	
	var required_ammo = weapon.Max_Ammo - weapon.Reload_Ammo
	var remaining = max(Ammo - required_ammo, 0)
	
	weapon.Reload_Ammo += min(Ammo, required_ammo)
	emit_signal("update_ammo", [current_weapon.Current_Ammo, current_weapon.Reload_Ammo])
	
	return remaining

@rpc("call_local")
func shoot_effect():
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	shoot_sound.play()

func respawn():
	anim_player.play("RESET")
	for _name in weapon_stack:
		var weapon = weapon_list[_name]
		spawn_weapon.rpc(weapon.Weapon_Drop.resource_path, bullet_spawn_point.get_global_transform(), weapon.Current_Ammo, weapon.Reload_Ammo)
	
	weapon_stack.clear()
	for weapon in start_weapons:
		weapon_stack.push_back(weapon)
		var w = weapon_list[weapon]
		w.Current_Ammo = w.Magazine
		w.Reload_Ammo = w.Max_Ammo
	
	current_weapon = weapon_list[weapon_stack[0]]
	emit_signal("update_weapon_stack", weapon_stack)
	camera.fov = camera_focus
	scoping = false
	enter()
	scope_signal.call_deferred()

@rpc("call_local", "any_peer", "reliable")
func spawn_weapon(weapon_dropped_scene_path: String, transform_: Transform3D, current_ammo: int, reload_ammo: int, _server: bool = false):
	var weapon_scene = load(weapon_dropped_scene_path)
	var weapon_dropped = weapon_scene.instantiate()
	weapon_dropped.current_ammo = current_ammo
	weapon_dropped.reload_ammo = reload_ammo
	#to add weapons spawned to the world's weapon_folder ***********************************
	if _server:
		get_tree().get_root().get_child(0).server_weapon_folder.add_child.call_deferred(weapon_dropped)
		weapon_dropped.gravity_scale = 0
		weapon_dropped.collision_mask = 0
		weapon_dropped.set_position(transform_.origin)
		#weapon_dropped.rotate_x(PI / 2)
	else:
		get_tree().get_root().get_child(0).weapon_folder.add_child(weapon_dropped)
		weapon_dropped.set_global_transform(transform_)

@export var server_spawns: Array[String] = ["Sniper", "Shotgun", "Rocket Launcher"]

func server_spawn_weapon():
	var weapon_name = server_spawns[randi_range(0, server_spawns.size() - 1)]
	var weapon = weapon_list[weapon_name]
	var spawn_point = spawn_points[randi_range(0, spawn_points.size() - 1)].global_transform
	rpc("spawn_weapon", weapon.Weapon_Drop.resource_path, spawn_point, weapon.Magazine, weapon.Max_Ammo, true)

@rpc("any_peer", "call_local")
func delete_node_everywhere(node_path: NodePath):
	var node = get_node_or_null(node_path)
	if node:
		node.queue_free()
