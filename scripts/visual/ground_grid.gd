extends Node2D
## 임시 바닥 격자. 이동이 눈에 보이도록 카메라 주변에 격자를 그립니다.

@export var cell_size: float = 128.0
@export var line_color: Color = Color(1, 1, 1, 0.08)
@export var background_color: Color = Color("1b1d24")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view_rect := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	draw_rect(view_rect, background_color)
	var start_x := floorf(view_rect.position.x / cell_size) * cell_size
	var start_y := floorf(view_rect.position.y / cell_size) * cell_size
	var x := start_x
	while x <= view_rect.end.x:
		draw_line(Vector2(x, view_rect.position.y), Vector2(x, view_rect.end.y), line_color)
		x += cell_size
	var y := start_y
	while y <= view_rect.end.y:
		draw_line(Vector2(view_rect.position.x, y), Vector2(view_rect.end.x, y), line_color)
		y += cell_size
