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
			pierce_left -= 1
			if pierce_left < 0:
				queue_free()
				return


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
