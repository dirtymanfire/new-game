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


## 공격이 적에게 맞았을 때. 속성 → 피해 → 조건 순서로 처리합니다.
func hit(attack: Attack, enemy: Enemy) -> void:
	if enemy.is_dead:
		return
	for element: BehaviorTile in attack.elements:
		apply_status(attack, enemy, element)
	var killed := enemy.take_damage(attack.damage)
	if attack.can_trigger():
		_runner.notify_hit(attack.step, enemy)
		if killed:
			_runner.notify_kill(attack.step, enemy)


## 공격에 의해 속성을 겁니다. 지속 피해로 죽으면 그 공격의 '처치 시'로 칩니다.
func apply_status(attack: Attack, enemy: Enemy, element: BehaviorTile) -> void:
	if enemy.is_dead:
		return
	if not enemy.killed_by_status.is_connected(_on_enemy_killed_by_status):
		enemy.killed_by_status.connect(_on_enemy_killed_by_status)
	enemy.apply_element(element, attack)


## 범위 피해 (화염구가 터질 때). exclude는 이미 직접 맞은 적입니다.
func blast(attack: Attack, origin: Vector2, radius: float, exclude: Node2D = null) -> void:
	_spawn_effect(origin, radius, 0.0, 0.0, attack)
	for enemy: Enemy in get_enemies():
		if enemy == exclude:
			continue
		if enemy.global_position.distance_to(origin) <= radius + enemy.radius:
			hit(attack, enemy)


## 속성 장판을 깝니다.
func spawn_field(attack: Attack, element: BehaviorTile, origin: Vector2, radius: float = -1.0, counts_as_hit := false) -> GroundField:
	var field := GroundField.new()
	field.combat = self
	field.attack = attack
	field.element = element
	field.radius = element.field_radius if radius < 0.0 else radius
	field.duration = element.field_duration
	field.counts_as_hit = counts_as_hit
	var c: Color = Enemy.STATUS_COLORS.get(element.id, Color.WHITE)
	c.a = 0.25
	field.color = c
	add_child(field)
	field.global_position = origin
	return field


## 지속 피해로 죽은 적: 마지막으로 지속 피해를 건 순차 행동의 '처치 시'를 발동합니다.
## 조건으로 걸린 상태이상(source == null)이나 조건으로 발동된 공격이면 발동하지 않습니다 (A안).
func _on_enemy_killed_by_status(enemy: Enemy, source: Attack) -> void:
	if source and source.can_trigger():
		_runner.notify_kill(source.step, enemy)


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
		&"fire":
			_perform_fireball(attack, origin, exclude)
		&"frost":
			_perform_ice_spear(attack, origin, exclude)
		&"poison":
			_perform_poison_cloud(attack, origin)
		_:
			push_warning("구현되지 않은 행동입니다: %s" % attack.tile.id)


## 투사체를 쏩니다 (사격·화염구·얼음창 공용). 만든 투사체를 돌려줍니다.
func _perform_shoot(attack: Attack, origin: Vector2, exclude: Node2D) -> Array[Projectile]:
	var exclude_ids := {}
	if exclude:
		exclude_ids[exclude.get_instance_id()] = true
	var target := find_nearest_enemy(origin, exclude_ids)
	var dir := (target.global_position - origin).normalized() if target else _player.facing
	var tile := attack.tile
	var spread := deg_to_rad(attack.spread_degrees)
	var projectiles: Array[Projectile] = []
	for i in attack.shot_count:
		var offset := (i - (attack.shot_count - 1) / 2.0) * spread
		var p := _spawn_projectile(attack, origin, dir.rotated(offset), tile.speed, tile.attack_range, tile.radius, exclude_ids)
		p.trail_elements = attack.trail_elements
		projectiles.append(p)
	return projectiles


## 화염구: 가장 가까운 적에게 날아가 맞으면 터집니다.
func _perform_fireball(attack: Attack, origin: Vector2, exclude: Node2D) -> void:
	for p in _perform_shoot(attack, origin, exclude):
		p.blast_radius = attack.tile.area_radius


## 얼음창: 빠르고 적을 꿰뚫는 투사체
func _perform_ice_spear(attack: Attack, origin: Vector2, exclude: Node2D) -> void:
	_perform_shoot(attack, origin, exclude)


## 독구름: 시전 위치에 독구름을 퍼뜨립니다. 처음 닿은 적마다 적중으로 칩니다.
func _perform_poison_cloud(attack: Attack, origin: Vector2) -> void:
	spawn_field(attack, attack.tile, origin, attack.tile.area_radius, true)
	for element in attack.trail_elements:
		spawn_field(attack, element, origin, attack.tile.area_radius)


func _perform_swing(attack: Attack, origin: Vector2) -> void:
	var tile := attack.tile
	var facing := _player.facing
	var half_arc := deg_to_rad(tile.angle_degrees) / 2.0
	_spawn_effect(origin, tile.radius, deg_to_rad(tile.angle_degrees), facing.angle(), attack)
	# 행동 뒤 속성: 휘두른 범위 가운데에 장판
	for element in attack.trail_elements:
		spawn_field(attack, element, origin + facing * tile.radius * 0.5, tile.radius * 0.5)
	for enemy: Enemy in get_enemies():
		var to_enemy := enemy.global_position - origin
		if to_enemy.length() > tile.radius + enemy.radius:
			continue
		if absf(facing.angle_to(to_enemy)) <= half_arc:
			hit(attack, enemy)


func _perform_explosion(attack: Attack, origin: Vector2) -> void:
	var tile := attack.tile
	_spawn_effect(origin, tile.radius, 0.0, 0.0, attack)
	# 행동 뒤 속성: 폭발 범위에 장판
	for element in attack.trail_elements:
		spawn_field(attack, element, origin, tile.radius)
	for enemy: Enemy in get_enemies():
		if enemy.global_position.distance_to(origin) <= tile.radius + enemy.radius:
			hit(attack, enemy)


func _spawn_projectile(attack: Attack, origin: Vector2, dir: Vector2, speed: float, attack_range: float, radius: float, exclude_ids: Dictionary) -> Projectile:
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
	return p


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
