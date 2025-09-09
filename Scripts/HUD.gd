extends CanvasLayer

@onready var current_weapon_label = $HUD/VBoxContainer/HBoxContainer/CurrentWeapon
@onready var ammo_label = $HUD/VBoxContainer/HBoxContainer2/Ammo
@onready var weapon_stack_label = $HUD/VBoxContainer/HBoxContainer3/WeaponStack

@onready var health_bar = %HealthBar
@onready var dot = $HUD/Crosshairs/Dot
@onready var circle = $HUD/Crosshairs/Circle
@onready var cross = $HUD/Crosshairs/Cross
@onready var sprint_bar = %SprintBar

var dot_color
var circle_radius
var circle_color
var cross_inner
var cross_outer
var cross_color

func _ready() -> void:
	if !is_multiplayer_authority():
		queue_free()

func _on_update_ammo(ammo) -> void:
	ammo_label.set_text(str(ammo[0]) + " / " + str(ammo[1]))


func _on_update_weapon_stack(weapon_stack) -> void:
	weapon_stack_label.set_text("")
	for weapon in weapon_stack:
		weapon_stack_label.text += "\n" + weapon


func _on_weapon_changed(weapon_name: String, constant_dot: bool, _dot_color: Color, constant_circle: bool, _circle_color: Color, _circle_radius: float, constant_cross: bool, _cross_color: Color, _cross_inner: float, _cross_outer: float) -> void:
	current_weapon_label.set_text(weapon_name)
	dot.set_visible(constant_dot)
	dot_color = _dot_color
	dot.dot_color = _dot_color
	dot.queue_redraw()
	
	circle.set_visible(constant_circle)
	circle.background = false
	circle_color = _circle_color
	circle.circle_color =  _circle_color
	circle_radius = _circle_radius
	circle.circle_radius = _circle_radius
	circle.queue_redraw()
	
	cross.set_visible(constant_cross)
	cross_color = _cross_color
	cross.color = _cross_color
	cross_inner = _cross_inner
	cross.inner_radius = _cross_inner
	cross_outer = _cross_outer
	cross.outer_radius = _cross_outer
	cross.queue_redraw()
	
	#if _scope_factor >= 3.0:
		#circle.background = true
	#else:
		#circle.background = false

func _on_player_health_changed(health_value: float) -> void:
	health_bar.set_value(health_value)

func _on_player_sprint_changed(sprint_reload_time: float) -> void:
	sprint_bar.set_value(sprint_reload_time)

func _on_weapon_manager_scope_changed(_scoping: bool, _scope_factor: float, background: bool, constant_dot, constant_circle, constant_cross) -> void:
	circle.background = background
	dot.visible = constant_dot or _scoping
	circle.visible = constant_circle or _scoping
	cross.visible = constant_cross or _scoping
	
	dot.constant_draw = false
	circle.constant_draw = false
	cross.constant_draw = false
	
	if !_scoping:
		reset()

func reset():
	circle.background = false
	
	dot.modulate.a = 1.0
	circle.modulate.a = 1.0
	cross.modulate.a = 1.0
	
	dot.dot_color = dot_color
	circle.circle_color = circle_color
	cross.color = cross_color
	
	circle.circle_radius = circle_radius
	cross.inner_radius = cross_inner
	cross.outer_radius = cross_outer
	
	dot.queue_redraw()
	circle.queue_redraw()
	cross.queue_redraw()
