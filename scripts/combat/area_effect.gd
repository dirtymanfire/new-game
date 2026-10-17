class_name AreaEffect
extends Node2D
## 휘두르기(부채꼴)·폭발(원)의 임시 시각 효과. 잠시 보였다가 사라집니다.

const LIFETIME := 0.2

var radius := 100.0
## 0이면 원, 아니면 부채꼴 각도(라디안)
var arc := 0.0
var color := Color(1, 1, 1, 0.5)
var _time := LIFETIME


func _process(delta: float) -> void:
	_time -= delta
	if _time <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var c := color
	c.a *= _time / LIFETIME
	if arc <= 0.0:
		draw_circle(Vector2.ZERO, radius, c)
		return
	var points := PackedVector2Array([Vector2.ZERO])
	var segments := 16
	for i in segments + 1:
		points.append(Vector2.from_angle(-arc / 2.0 + arc * i / segments) * radius)
	draw_colored_polygon(points, c)
