extends TextureRect

@export var dot_radius: float
@export var dot_color: Color
@export var constant_draw: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	queue_redraw()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if constant_draw:
		queue_redraw()

func _draw():
	modulate = dot_color
	draw_circle(Vector2(0,0), dot_radius, dot_color)
