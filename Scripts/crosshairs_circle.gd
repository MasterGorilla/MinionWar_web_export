extends TextureRect

@export var circle_radius: float
@export var circle_color: Color
@export var background := false
#@export var background_color: Color
@export var constant_draw: bool

var _size: Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	queue_redraw()
	_size = get_window().get_size()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if constant_draw:
		queue_redraw()

func _draw():
	modulate = circle_color
	if background:
		#draw_rect(Rect2(Vector2(-size/2), get_window().get_size()), background_color)
		draw_circle(Vector2(0,0), circle_radius + _size.x / 4, Color.BLACK, false, _size.x/2)
	draw_circle(Vector2(0,0), circle_radius, circle_color, false, 5)
