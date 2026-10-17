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
	print("테스트 %s" % ("통과" if _failures == 0 else "실패 %d건" % _failures))
	quit(_failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("실패: " + message)


func _test_rule_slots() -> void:
	var rule := BehaviorRule.new()
	_check(rule.get_slots().size() == 5, "슬롯은 5개")
	_check(rule.is_slot_empty(0), "처음엔 빈 슬롯")
	var shoot := load("res://data/tiles/shoot.tres") as BehaviorTile
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
