class_name CombatSystem
extends Node2D
## 행동 수칙 실행기(RuleRunner)의 신호를 받아 실제 공격을 만듭니다.
## 적중 시 속성을 걸고, 순차 행동이면 조건(적중 시/처치 시)을 실행기에 알립니다.

const PROJECTILE_COLOR := Color("ffe9a8")
const EFFECT_COLOR := Color(1, 1, 1, 0.45)

var _player: Player
var _runner: RuleRunner


func setup(player: Player, runner: RuleRunner) -> void:
	_player = player
	_runner = runner
	runner.action_performed.connect(_on_action_performed)
	runner.triggered_action_performed.connect(_on_triggered_action)
	runner.triggered_modifier_performed.connect(_on_triggered_modifier)
	runner.status_applied.connect(_on_status_applied)


func get_enemies() -> Array[Node]:
	return get_tree().get_nodes_in_group(&"enemies")


func find_nearest_enemy(from: Vector2, exclude_ids: Dictionary = {}) -> Enemy:
	var best: Enemy = null
	var best_dist := INF
	for enemy: Enemy in get_enemies():
		if enemy.is_dead or exclude_ids.has(enemy.get_instance_id()):
			continue
		var d := from.distance_squared_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


## 공격이 적에게 맞았을 때. 피해 → 속성 → 조건 순서로 처리합니다.
func hit(attack: Attack, enemy: Enemy) -> void:
	if enemy.is_dead:
		return
	for element: BehaviorTile in attack.elements:
		enemy.apply_element(element, attack.elements[element])
	var killed := enemy.take_damage(attack.damage)
	if attack.can_trigger():
		_runner.notify_hit(attack.step, enemy)
		if killed:
			_runner.notify_kill(attack.step, enemy)


func _on_action_performed(step: RuleCompiler.ActionStep, origin: Vector2) -> void:
	_perform(Attack.from_step(step, 0), origin, null)


func _on_triggered_action(step: RuleCompiler.ActionStep, origin: Vector2, target: Node2D) -> void:
	_perform(Attack.from_step(step, step.depth), origin, target)


func _on_status_applied(element: BehaviorTile, target: Node2D) -> void:
	if target is Enemy:
		target.apply_element(element)


## 조건 뒤의 변형. 현재는 분열(맞은 적에서 파편으로 갈라짐)만 있습니다.
func _on_triggered_modifier(modifier: BehaviorTile, source_step: RuleCompiler.ActionStep, target: Node2D) -> void:
	match modifier.id:
		&"split":
			var fragment := Attack.from_step(source_step, source_step.depth + 1)
			fragment.damage = source_step.tile.damage * modifier.potency
			fragment.pierce = 0
			fragment.homing = 0.0
			var exclude := { target.get_instance_id(): true }
			var start_angle := randf() * TAU
			for i in modifier.count:
				var dir := Vector2.from_angle(start_angle + TAU * i / modifier.count)
				_spawn_projectile(fragment, target.global_position, dir, modifier.speed, modifier.attack_range, modifier.radius, exclude)
		_:
			push_warning("조건 뒤 변형 효과가 구현되지 않았습니다: %s" % modifier.id)


## exclude: 조건을 일으킨 적. 조건으로 발동된 사격이 그 적을 다시 노리지 않게 합니다.
func _perform(attack: Attack, origin: Vector2, exclude: Node2D) -> void:
	match attack.tile.id:
		&"shoot":
			_perform_shoot(attack, origin, exclude)
		&"swing":
			_perform_swing(attack, origin)
		&"explosion":
			_perform_explosion(attack, origin)
		_:
			push_warning("구현되지 않은 행동입니다: %s" % attack.tile.id)


func _perform_shoot(attack: Attack, origin: Vector2, exclude: Node2D) -> void:
	var exclude_ids := {}
	if exclude:
		exclude_ids[exclude.get_instance_id()] = true
	var target := find_nearest_enemy(origin, exclude_ids)
	var dir := (target.global_position - origin).normalized() if target else _player.facing
	var tile := attack.tile
	var spread := deg_to_rad(attack.spread_degrees)
	for i in attack.shot_count:
		var offset := (i - (attack.shot_count - 1) / 2.0) * spread
		_spawn_projectile(attack, origin, dir.rotated(offset), tile.speed, tile.attack_range, tile.radius, exclude_ids)


func _perform_swing(attack: Attack, origin: Vector2) -> void:
	var tile := attack.tile
	var facing := _player.facing
	var half_arc := deg_to_rad(tile.angle_degrees) / 2.0
	_spawn_effect(origin, tile.radius, deg_to_rad(tile.angle_degrees), facing.angle(), attack)
	for enemy: Enemy in get_enemies():
		var to_enemy := enemy.global_position - origin
		if to_enemy.length() > tile.radius + enemy.radius:
			continue
		if absf(facing.angle_to(to_enemy)) <= half_arc:
			hit(attack, enemy)


func _perform_explosion(attack: Attack, origin: Vector2) -> void:
	var tile := attack.tile
	_spawn_effect(origin, tile.radius, 0.0, 0.0, attack)
	for enemy: Enemy in get_enemies():
		if enemy.global_position.distance_to(origin) <= tile.radius + enemy.radius:
			hit(attack, enemy)


func _spawn_projectile(attack: Attack, origin: Vector2, dir: Vector2, speed: float, attack_range: float, radius: float, exclude_ids: Dictionary) -> void:
	var p := Projectile.new()
	p.combat = self
	p.attack = attack
	p.velocity = dir * speed
	p.lifetime = attack_range / speed
	p.radius = radius
	p.pierce_left = attack.pierce
	p.homing = attack.homing
	p.color = _attack_color(attack, PROJECTILE_COLOR)
	p.hit_ids = exclude_ids.duplicate()
	add_child(p)
	p.global_position = origin


func _spawn_effect(origin: Vector2, radius: float, arc: float, angle: float, attack: Attack) -> void:
	var fx := AreaEffect.new()
	fx.radius = radius
	fx.arc = arc
	fx.rotation = angle
	fx.color = _attack_color(attack, EFFECT_COLOR)
	add_child(fx)
	fx.global_position = origin


## 속성이 붙은 공격은 첫 속성 색으로 표시합니다.
func _attack_color(attack: Attack, fallback: Color) -> Color:
	for element: BehaviorTile in attack.elements:
		var c: Color = Enemy.STATUS_COLORS.get(element.id, fallback)
		c.a = fallback.a
		return c
	return fallback
