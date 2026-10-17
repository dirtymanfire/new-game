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
	var r := _compile("fire shoot pierce on_hit explosion")
	_check(r.warnings.is_empty(), "정상 배치는 경고 없음")
	_check(r.actions.size() == 1, "조건 전용 폭발은 순차 실행에서 빠짐")
	var shoot := r.actions[0]
	_check(shoot.elements == [_t("fire")] and shoot.modifiers == [_t("pierce")], "화염 앞, 관통 뒤")
	_check(shoot.triggers.size() == 1 and shoot.triggers[0].actions[0].tile == _t("explosion"), "적중 시 폭발")
	_check(shoot.triggers[0].actions[0].depth == 1, "조건 발동 행동은 깊이 1")

	r = _compile("fire frost shoot")
	_check(r.actions[0].elements.size() == 2, "행동 앞 속성 두 개 모두 적용")

	r = _compile("shoot fire")
	_check(r.warnings.has(1) and r.actions[0].elements.is_empty(), "행동 뒤 속성은 경고")

	r = _compile("fire pierce shoot")
	_check(r.warnings.has(0) and r.warnings.has(1), "속성과 행동 사이에 변형이 끼면 둘 다 경고")

	r = _compile("pierce shoot")
	_check(r.warnings.has(0), "변형 앞에 행동 없음")

	r = _compile("shoot on_hit")
	_check(r.warnings.has(1), "조건이 맨 끝")

	r = _compile("on_hit explosion")
	_check(r.warnings.has(0) and r.actions.size() == 1, "앞 행동 없는 조건은 무시, 뒤 폭발은 일반 행동")

	r = _compile("shoot on_hit explosion split")
	_check(r.warnings.has(3), "조건 뒤 폭발/분열 → 분열은 적용 안 됨(경고)")
	_check(r.actions[0].triggers[0].actions[0].modifiers.is_empty(), "조건 발동 폭발에 분열 없음")

	r = _compile("shoot on_hit explosion split", 2)
	_check(r.warnings.is_empty() and r.actions[0].triggers[0].actions[0].modifiers.size() == 1, "강화(2칸) 시 분열까지 적용")

	r = _compile("shoot on_hit fire")
	_check(r.warnings.is_empty() and r.actions[0].triggers[0].statuses == [_t("fire")], "적중 시 화염 = 상태이상")

	r = _compile("shoot on_hit explosion on_kill fire")
	_check(r.warnings.has(3), "A안: 조건 발동 행동은 다시 조건 발동 불가")

	r = _compile("shoot on_hit explosion on_kill fire", 1, -1)
	_check(not r.warnings.has(3), "무한 연쇄 업그레이드 시 허용")

	r = _compile("shoot on_hit on_kill explosion")
	_check(r.warnings.has(2), "조건 뒤 조건은 경고")

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
	runner._process(1.5)
	runner._process(1.5) # 3초 후 다음 행동
	runner._process(3.0) # 다시 처음으로
	_check(order == [0, 2, 0], "순차 실행 + 3초 쿨다운 + 반복 (결과: %s)" % [order])

	rule = BehaviorRule.new()
	for i in 5:
		rule.set_tile(i, _t(["shoot", "on_hit", "explosion", "_", "_"][i]) if i < 3 else null)
	runner.load_rule(rule)
	var triggered := []
	runner.triggered_action_performed.connect(func(step, origin): triggered.append([step.tile.id, origin]))
	var enemy := Node2D.new()
	enemy.position = Vector2(100, 50)
	root.add_child(enemy)
	runner.notify_hit(runner.compiled.actions[0], enemy)
	runner.notify_kill(runner.compiled.actions[0], enemy)
	_check(triggered.size() == 1 and triggered[0][1] == Vector2(100, 50), "적중 시 폭발은 적 위치에서 1회")
	runner.queue_free()
	enemy.queue_free()
