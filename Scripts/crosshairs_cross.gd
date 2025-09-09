extends TextureRect

@export var inner_radius: float
@export var outer_radius: float
@export var color: Color
@export var constant_draw: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	queue_redraw()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if constant_draw:
		queue_redraw()

func _draw():
	modulate = color
	draw_line(Vector2(inner_radius,0), Vector2(outer_radius, 0), color, 5)
	draw_line(Vector2(-inner_radius,0), Vector2(-outer_radius, 0), color, 5)
	draw_line(Vector2(0, inner_radius), Vector2(0, outer_radius), color, 5)
	draw_line(Vector2(0, -inner_radius), Vector2(0, -outer_radius), color, 5)
