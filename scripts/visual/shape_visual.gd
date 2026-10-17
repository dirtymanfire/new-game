@tool
class_name ShapeVisual
extends Node2D
## 임시 도형 표시용 노드.
## texture에 이미지를 지정하면 도형 대신 이미지를 그립니다.
## 아트 리소스가 준비되면 인스펙터에서 texture만 바꾸면 됩니다.

enum Shape { CIRCLE, RECT }

@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
@export var shape: Shape = Shape.CIRCLE:
	set(value):
		shape = value
		queue_redraw()
@export var size: Vector2 = Vector2(32, 32):
	set(value):
		size = value
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	if texture:
		draw_texture_rect(texture, rect, false)
		return
	match shape:
		Shape.CIRCLE:
			draw_circle(Vector2.ZERO, size.x / 2.0, color)
		Shape.RECT:
			draw_rect(rect, color)
