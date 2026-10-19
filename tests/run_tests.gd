extends SceneTree
## 헤드리스 테스트: godot --headless --path . -s res://tests/run_tests.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	# 오토로드와 _ready가 실행되도록 한 프레임 기다립니다.
	await process_frame
	_test_rule_slots()
	_test_tile_library()
	_test_player_death()
	_test_compiler()
	_test_runner()
	await _test_combat()
	_test_shop()
	await _test_wave()
	print("테스트 %s" % ("통과" if _failures == 0 else "실패 %d건" % _failures))
	quit(_failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("실패: " + message)


func _t(id: String) -> BehaviorTile:
	return load("res://data/tiles/%s.tres" % id) as BehaviorTile


## "fire shoot pierce" 처럼 공백으로 구분, "_"는 빈 슬롯
func _slots(spec: String) -> Array[BehaviorTile]:
	var slots: Array[BehaviorTile] = []
	for id in spec.split(" "):
		slots.append(null if id == "_" else _t(id))
	while slots.size() < BehaviorRule.SLOT_COUNT:
		slots.append(null)
	return slots


func _compile(spec: String, reach := 1, depth := 1) -> RuleCompiler.CompiledRule:
	return RuleCompiler.compile(_slots(spec), reach, depth)


func _test_rule_slots() -> void:
	var rule := BehaviorRule.new()
	_check(rule.get_slots().size() == 5, "슬롯은 5개")
	_check(rule.is_slot_empty(0), "처음엔 빈 슬롯")
	var shoot := _t("shoot")
	rule.set_tile(0, shoot)
	rule.swap(0, 4)
	_check(rule.is_slot_empty(0) and rule.get_tile(4) == shoot, "슬롯 교환")


func _test_tile_library() -> void:
	var library = root.get_node("TileLibrary")
	_check(library.get_all().size() == 11, "기획서 타일 11종 로드")
	_check(library.get_tile(&"on_hit").kind == BehaviorTile.Kind.CONDITION, "적중 시 = 조건")


func _test_player_death() -> void:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	root.add_child(player)
	var died := [false]
	player.died.connect(func(): died[0] = true)
	player.take_damage(player.max_health)
	_check(died[0] and player.health == 0.0, "체력 0이면 사망 신호")
	player.queue_free()


func _test_compiler() -> void:
	# 속성은 앞, 변형은 뒤, 적중 시 뒤의 폭발은 조건 전용
	var r := _compile("fire pierce shoot on_hit explosion")
	_check(r.warnings.is_empty(), "정상 배치는 경고 없음")
	_check(r.actions.size() == 1, "조건 전용 폭발은 순차 실행에서 빠짐")
	var shoot := r.actions[0]
	_check(shoot.elements == [_t("fire")] and shoot.modifiers == [_t("pierce")], "화염·관통 앞")
	_check(shoot.triggers.size() == 1 and shoot.triggers[0].actions[0].tile == _t("explosion"), "적중 시 폭발")
	_check(shoot.triggers[0].actions[0].depth == 1, "조건 발동 행동은 깊이 1")

	r = _compile("fire frost shoot")
	_check(r.actions[0].elements.size() == 2, "행동 앞 속성 두 개 모두 적용")

	r = _compile("shoot fire")
	_check(r.warnings.is_empty() and r.actions[0].after_elements == [_t("fire")], "행동 뒤 속성 = 장판")

	r = _compile("shoot fire swing")
	_check(r.actions.size() == 2 and r.actions[0].after_elements == [_t("fire")] and r.actions[1].elements.is_empty(), "사이 속성은 앞 행동의 장판")

	r = _compile("fire")
	_check(r.warnings.is_empty() and r.actions.size() == 1 and r.actions[0].tile == _t("fire"), "속성 단독 = 공격 행동")

	r = _compile("frost poison")
	_check(r.actions.size() == 2, "속성 단독 두 개 = 행동 두 개")

	r = _compile("fire homing on_hit explosion")
	_check(r.warnings.is_empty() and r.actions[0].modifiers == [_t("homing")] and r.actions[0].triggers.size() == 1, "속성 행동에도 변형·조건이 붙음")

	r = _compile("shoot on_hit explosion fire")
	_check(r.actions.size() == 2 and r.actions[1].tile == _t("fire"), "조건 발동 행동 뒤 속성은 단독 행동")

	r = _compile("fire pierce shoot")
	_check(r.warnings.is_empty() and r.actions[0].modifiers == [_t("pierce")], "변형은 행동 앞에도 놓을 수 있음")

	r = _compile("pierce")
	_check(r.warnings.has(0), "변형 앞뒤에 행동 없음")

	r = _compile("split shoot")
	_check(r.warnings.is_empty() and r.actions[0].modifiers == [_t("split")], "분열은 행동 앞 = 여러 발")

	r = _compile("shoot split")
	_check(r.warnings.has(1) and r.actions[0].modifiers.is_empty(), "분열을 행동 뒤에 두면 경고")

	r = _compile("shoot on_hit split")
	_check(r.warnings.is_empty() and r.actions[0].triggers[0].modifiers == [_t("split")], "적중 시 분열 = 맞은 후 분열")

	r = _compile("shoot on_hit pierce")
	_check(r.warnings.has(2), "적중 시 관통은 경고")

	r = _compile("shoot pierce")
	_check(r.warnings.has(1) and r.actions[0].modifiers.is_empty(), "관통을 행동 뒤에 두면 경고")

	r = _compile("shoot pierce swing")
	_check(r.warnings.is_empty() and r.actions[1].modifiers == [_t("pierce")] and r.actions[0].modifiers.is_empty(), "관통은 앞(휘두르기)에 붙음")

	r = _compile("shoot on_hit fire on_kill explosion")
	_check(r.forbidden == [3], "조건 연달아 금지 (사이에 속성)")

	r = _compile("shoot on_hit fire swing on_kill")
	_check(not r.forbidden.has(4), "사이에 순차 행동이 있으면 연달아가 아님")

	r = _compile("shoot on_hit")
	_check(r.warnings.has(1), "조건이 맨 끝")

	r = _compile("on_hit explosion")
	_check(r.warnings.has(0) and r.actions.size() == 1, "앞 행동 없는 조건은 무시, 뒤 폭발은 일반 행동")

	r = _compile("shoot on_hit explosion homing")
	_check(r.warnings.has(3), "조건 뒤 폭발/유도 → 유도는 적용 안 됨(경고)")
	_check(r.actions[0].triggers[0].actions[0].modifiers.is_empty(), "조건 발동 폭발에 유도 없음")

	r = _compile("shoot on_hit explosion homing", 2)
	_check(r.warnings.is_empty() and r.actions[0].triggers[0].actions[0].modifiers.size() == 1, "강화(2칸) 시 유도까지 적용")

	r = _compile("shoot on_hit fire")
	_check(r.warnings.is_empty() and r.actions[0].triggers[0].statuses == [_t("fire")], "적중 시 화염 = 상태이상")

	r = _compile("shoot on_hit explosion on_kill fire")
	_check(r.forbidden.has(3), "A안: 조건 발동 행동에 조건 = 연달아 금지")

	r = _compile("shoot on_hit explosion on_kill fire", 1, -1)
	_check(not r.warnings.has(3), "무한 연쇄 업그레이드 시 허용")

	r = _compile("shoot on_hit on_kill explosion")
	_check(r.forbidden.has(2), "조건 바로 뒤 조건 금지")

	r = _compile("_ _ _ _ _")
	_check(r.warnings.has(-1), "행동 없음 경고")

	r = _compile("shoot _ swing")
	_check(r.actions.size() == 2 and r.warnings.is_empty(), "빈 슬롯은 건너뜀")


func _test_runner() -> void:
	var runner := RuleRunner.new()
	root.add_child(runner)
	var rule := BehaviorRule.new()
	rule.set_tile(0, _t("shoot"))
	rule.set_tile(2, _t("swing"))
	runner.load_rule(rule)
	var order: Array[int] = []
	runner.action_performed.connect(func(step, _o): order.append(step.slot_index))
	runner.start()
	runner._process(0.0) # 시작 즉시 첫 행동
	runner._process(0.75)
	runner._process(0.75) # 1.5초 후 다음 행동
	runner._process(1.5) # 다시 처음으로
	_check(order == [0, 2, 0], "순차 실행 + 1.5초 쿨다운 + 반복 (결과: %s)" % [order])

	rule = BehaviorRule.new()
	for i in 5:
		rule.set_tile(i, _t(["shoot", "on_hit", "explosion", "_", "_"][i]) if i < 3 else null)
	runner.load_rule(rule)
	var triggered := []
	runner.triggered_action_performed.connect(func(step, origin, _target): triggered.append([step.tile.id, origin]))
	var enemy := Node2D.new()
	enemy.position = Vector2(100, 50)
	root.add_child(enemy)
	runner.notify_hit(runner.compiled.actions[0], enemy)
	runner.notify_kill(runner.compiled.actions[0], enemy)
	_check(triggered.size() == 1 and triggered[0][1] == Vector2(100, 50), "적중 시 폭발은 적 위치에서 1회")
	runner.queue_free()
	enemy.queue_free()


func _make_enemy(pos: Vector2) -> Enemy:
	var enemy := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	root.add_child(enemy)
	enemy.global_position = pos
	return enemy


func _test_combat() -> void:
	var step := _compile("fire fire split pierce shoot").actions[0]
	var attack := Attack.from_step(step, 0)
	_check(attack.elements.size() == 1, "같은 속성 2개여도 한 번만 적용")
	_check(attack.shot_count == 3 and attack.pierce == 2, "분열 3발, 관통 2")
	var doubled := Attack.from_step(_compile("split split pierce pierce shoot").actions[0], 0)
	_check(doubled.shot_count == 3 and doubled.pierce == 2, "같은 변형 2개여도 합산 안 됨")

	var ice := Attack.from_step(_compile("pierce frost").actions[0], 0)
	_check(ice.pierce == _t("frost").pierce_count + _t("pierce").count and ice.elements.has(_t("frost")), "관통 얼음창 = 기본 관통 + 관통, 빙결 적용")
	var trail := Attack.from_step(_compile("shoot fire fire").actions[0], 0)
	_check(trail.trail_elements == [_t("fire")], "장판 속성 중복 없음")

	var poison := _t("poison")
	var fire := _t("fire")
	_check(poison.potency * 2 < fire.potency and poison.potency * 3 > fire.potency, "독은 3중첩부터 화염보다 강함")

	var enemy := _make_enemy(Vector2(5000, 0))
	var frost := _t("frost")
	for i in 3:
		enemy.apply_element(frost)
	_check(enemy._slow > 0.7 and enemy._frozen_time == 0.0, "빙결 3회 = 75% 둔화")
	enemy.apply_element(frost)
	_check(enemy._frozen_time > 0.0, "빙결 4회 = 정지")
	enemy.queue_free()

	# 적중 시 폭발: 순차 사격이 맞으면 적 위치에서 폭발, 폭발 피해는 조건을 다시 발동하지 않음
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	root.add_child(player)
	player.global_position = Vector2(-5000, 0)
	var runner: RuleRunner = player.get_node("RuleRunner")
	var rule := BehaviorRule.new()
	rule.set_tile(0, _t("shoot"))
	rule.set_tile(1, _t("on_hit"))
	rule.set_tile(2, _t("explosion"))
	runner.load_rule(rule)
	var combat := CombatSystem.new()
	root.add_child(combat)
	combat.setup(player, runner)
	var a := _make_enemy(Vector2(0, 0))
	var b := _make_enemy(Vector2(60, 0))
	var triggered := [0]
	runner.triggered_action_performed.connect(func(_s, _o, _t2): triggered[0] += 1)
	combat.hit(Attack.from_step(runner.compiled.actions[0], 0), a)
	_check(triggered[0] == 1, "적중 시 폭발 1회만 (연쇄 없음): %d" % triggered[0])
	_check(b.is_dead or b.health == b.max_health - _t("explosion").damage, "폭발이 주변 적에게 피해")

	# 적중 시 분열: 맞은 적에서 파편 생성
	rule.set_tile(2, _t("split"))
	runner.load_rule(rule)
	var before := combat.get_child_count()
	var fresh := _make_enemy(Vector2(0, 500))
	combat.hit(Attack.from_step(runner.compiled.actions[0], 0), fresh)
	var fragments := 0
	for c in combat.get_children().slice(before):
		if c is Projectile:
			fragments += 1
	_check(fragments == _t("split").count, "적중 시 분열 파편 %d개" % fragments)
	# 지속 피해 처치도 처치: 마지막으로 화염을 건 순차 행동의 '처치 시' 발동
	rule = BehaviorRule.new()
	rule.set_tile(0, _t("fire"))
	rule.set_tile(1, _t("shoot"))
	rule.set_tile(2, _t("on_kill"))
	rule.set_tile(3, _t("explosion"))
	runner.load_rule(rule)
	triggered[0] = 0
	var burning := _make_enemy(Vector2(0, -800))
	burning.health = 1.0
	var weak := Attack.from_step(runner.compiled.actions[0], 0)
	weak.damage = 0.0
	combat.hit(weak, burning)
	await create_timer(0.5).timeout
	_check(burning.is_dead and triggered[0] == 1, "화염으로 죽어도 처치 시 발동: %d" % triggered[0])

	# 조건으로 걸린 화염(source 없음)으로 죽으면 발동하지 않음 (A안)
	triggered[0] = 0
	var burning2 := _make_enemy(Vector2(0, -1600))
	burning2.health = 1.0
	burning2.killed_by_status.connect(combat._on_enemy_killed_by_status)
	burning2.apply_element(_t("fire"))
	await create_timer(0.5).timeout
	_check(burning2.is_dead and triggered[0] == 0, "조건으로 걸린 화염 처치는 발동 안 함")

	for n in [a, b, fresh, player, combat]:
		if is_instance_valid(n):
			n.queue_free()


func _test_shop() -> void:
	var state = root.get_node("RunState")
	state.reset()
	var shoot := _t("shoot")
	var pool: Array[BehaviorTile] = [shoot]
	var shop := Shop.new(state, pool)
	shop.open()
	_check(shop.offers.size() == Shop.OFFER_COUNT, "진열 4개")
	_check(shop.buy(0) == "화폐가 부족합니다.", "돈 없으면 구매 불가")
	state.add_coins(100)
	_check(shop.buy(0) == "" and state.coins == 100 - shoot.price, "구매 시 차감")
	_check(state.inventory == [shoot] and shop.offers[0] == null, "구매한 타일은 보관함으로")
	_check(shop.buy(0) == "이미 구매했습니다.", "같은 칸 재구매 불가")

	_check(shop.reroll() == "" and state.coins == 100 - shoot.price - 2 and shop.reroll_cost == 3, "새로고침 비용 2, 이후 3")

	shop.place(0, 2)
	_check(state.rule.get_tile(2) == shoot and state.inventory.is_empty(), "보관함 → 슬롯")
	state.add_to_inventory(_t("fire"))
	shop.place(0, 2)
	_check(state.rule.get_tile(2) == _t("fire") and state.inventory == [shoot], "슬롯에 있던 타일은 보관함으로")
	# 조건 연달아 배치는 상점에서 막힘
	var saved: Array[BehaviorTile] = state.rule.get_slots()
	var saved_inv: Array[BehaviorTile] = state.inventory.duplicate()
	var test_rule: Array[BehaviorTile] = [shoot, _t("on_hit"), _t("fire"), null, null]
	for i in 5:
		state.rule.set_tile(i, test_rule[i])
	state.inventory.clear()
	state.add_to_inventory(_t("on_kill"))
	_check(shop.place(0, 3) == "조건은 연달아 놓을 수 없습니다.", "조건 연달아 배치 막힘")
	_check(state.rule.is_slot_empty(3) and state.inventory.size() == 1, "막히면 아무것도 바뀌지 않음")
	state.rule.set_tile(3, _t("swing"))
	_check(shop.place(0, 4) == "", "사이에 순차 행동이 있으면 배치 가능")
	_check(shop.swap_slots(3, 4) == "조건은 연달아 놓을 수 없습니다.", "조건 연달아 되는 교환 막힘")
	_check(shop.unplace(3) == "조건은 연달아 놓을 수 없습니다.", "사이 행동 회수로 연달아 되면 막힘")
	_check(shop.sell_from_slot(3) == "조건은 연달아 놓을 수 없습니다.", "사이 행동 판매로 연달아 되면 막힘")
	for i in 5:
		state.rule.set_tile(i, saved[i])
	state.inventory.assign(saved_inv)
	shop.swap_slots(2, 0)
	_check(state.rule.get_tile(0) == _t("fire") and state.rule.is_slot_empty(2), "슬롯 순서 변경")
	shop.unplace(0)
	_check(state.rule.is_slot_empty(0) and state.inventory.size() == 2, "슬롯 → 보관함")
	var coins_before: int = state.coins
	shop.sell_from_inventory(0)
	_check(state.coins == coins_before + shoot.get_sell_price(), "판매는 절반 가격")

	for i in Shop.OFFER_COUNT:
		state.add_to_inventory(shoot)
	while not state.is_inventory_full():
		state.add_to_inventory(shoot)
	shop.open()
	_check(shop.buy(0) == "보관함이 가득 찼습니다.", "보관함 가득 차면 구매 불가")
	state.reset()


func _test_wave() -> void:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	root.add_child(player)
	var enemies := Node2D.new()
	var pickups := Node2D.new()
	root.add_child(enemies)
	root.add_child(pickups)
	var director := WaveDirector.new()
	root.add_child(director)
	director.setup(player, enemies, pickups)
	var cleared := [false]
	director.wave_cleared.connect(func(): cleared[0] = true)
	director.start_wave(2)
	_check(director.kill_target == 15, "2웨이브 목표 15")
	for i in director.kill_target:
		director._spawn_enemy()
	_check(enemies.get_child_count() == 15, "15마리 생성")
	_check(is_equal_approx((enemies.get_child(0) as Enemy).max_health, 15.0 * 1.15), "2웨이브 체력 15% 증가")
	for e: Enemy in enemies.get_children():
		e.take_damage(9999)
	await process_frame
	_check(cleared[0], "모두 처치하면 웨이브 종료")
	_check(pickups.get_child_count() == 15, "처치마다 화폐 드롭")
	for n in [player, enemies, pickups, director]:
		n.queue_free()
