class_name GroundField
extends Node2D
## 속성 장판. 일정 시간 동안 안에 있는 적에게 주기적으로 속성을 겁니다.
## 행동 뒤 속성(`사격 화염`)의 장판과 독구름에 씁니다.

## 속성을 거는 간격(초)
const TICK_INTERVAL := 0.5

var combat: CombatSystem
var attack: Attack
var element: BehaviorTile
var radius := 40.0
var duration := 2.5
## 켜면 처음 닿은 적마다 '적중'으로 처리합니다 (독구름처럼 장판 자체가 공격 행동일 때)
var counts_as_hit := false
var color := Color(1, 1, 1, 0.25)

var _time_left := 0.0
var _tick_left := 0.0
var _touched: Dictionary = {}


func _ready() -> void:
	# 바닥에 깔리므로 플레이어·적보다 아래에 그립니다.
	z_index = -1
	_time_left = duration


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left += TICK_INTERVAL
		for enemy: Enemy in combat.get_enemies():
			if enemy.is_dead or enemy.global_position.distance_to(global_position) > radius + enemy.radius:
				continue
			if counts_as_hit and not _touched.has(enemy.get_instance_id()):
				_touched[enemy.get_instance_id()] = true
				combat.hit(attack, enemy)
			else:
				combat.apply_status(attack, enemy, element)
	queue_redraw()


func _draw() -> void:
	var c := color
	c.a *= clampf(_time_left / 0.4, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, c)
