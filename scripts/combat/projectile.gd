class_name Projectile
extends Node2D
## 직선(또는 유도) 투사체. 적과의 충돌은 거리로 판정합니다.

var combat: CombatSystem
var attack: Attack
var velocity := Vector2.ZERO
var radius := 8.0
var lifetime := 1.0
var pierce_left := 0
var homing := 0.0
var color := Color("ffe9a8")
## 0보다 크면 적에게 맞을 때 이 반경으로 터집니다 (화염구)
var blast_radius := 0.0
## 지나간 자리에 깔 장판 속성과 간격
var trail_elements: Array[BehaviorTile] = []
var trail_spacing := 50.0
var _trail_distance := 0.0
## 이미 맞힌 적 (instance id)
var hit_ids: Dictionary = {}


func _physics_process(delta: float) -> void:
	if homing > 0.0:
		var target := combat.find_nearest_enemy(global_position, hit_ids)
		if target:
			var desired := (target.global_position - global_position).angle()
			var current := velocity.angle()
			var turn := clampf(angle_difference(current, desired), -homing * delta, homing * delta)
			velocity = velocity.rotated(turn)

	global_position += velocity * delta
	rotation = velocity.angle()
	if not trail_elements.is_empty():
		_trail_distance += velocity.length() * delta
		if _trail_distance >= trail_spacing:
			_trail_distance = 0.0
			for element in trail_elements:
				combat.spawn_field(attack, element, global_position)
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	for enemy in combat.get_enemies():
		if enemy.is_dead or hit_ids.has(enemy.get_instance_id()):
			continue
		if global_position.distance_to(enemy.global_position) < radius + enemy.radius:
			hit_ids[enemy.get_instance_id()] = true
			combat.hit(attack, enemy)
			if blast_radius > 0.0:
				combat.blast(attack, global_position, blast_radius, enemy)
			pierce_left -= 1
			if pierce_left < 0:
				queue_free()
				return


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
