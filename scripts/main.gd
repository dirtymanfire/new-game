extends Node2D
## 메인 전투 씬. 플레이어가 죽으면 결과 화면을 띄우고 새 판을 시작합니다.

## 테스트용: 판 시작 시 이 타일들을 슬롯 1~5에 넣습니다. 비워 두면 빈 수칙으로 시작합니다.
## (시작 타일 구성은 기획 확정 전이라 게임 규칙이 아닌 개발용 설정입니다.)
@export var debug_start_tiles: Array[BehaviorTile] = []

@onready var _player: Player = $Player
@onready var _runner: RuleRunner = $Player/RuleRunner
@onready var _hud: CanvasLayer = $HUD
@onready var _result: CanvasLayer = $ResultScreen


func _ready() -> void:
	var rule := RunState.rule
	for i in mini(debug_start_tiles.size(), BehaviorRule.SLOT_COUNT):
		rule.set_tile(i, debug_start_tiles[i])

	_hud.bind_player(_player)
	_hud.bind_rule(rule, _runner)
	_hud.set_wave(RunState.wave)
	rule.changed.connect(_reload_rule)
	_reload_rule()
	_runner.action_performed.connect(_on_action_performed)
	_runner.start()

	_player.died.connect(_on_player_died)
	_result.restart_requested.connect(_on_restart_requested)


func _reload_rule() -> void:
	_runner.load_rule(RunState.rule)
	_hud.show_warnings(_runner.compiled.warnings)


func _on_action_performed(step: RuleCompiler.ActionStep, _origin: Vector2) -> void:
	# 공격 생성은 타일 수치 확정 후 구현합니다. 지금은 실행 순서만 확인할 수 있게 출력합니다.
	print("[수칙] %d번 슬롯 실행: %s" % [step.slot_index + 1, step.describe()])


func _on_player_died() -> void:
	get_tree().paused = true
	_result.open(RunState.wave)


func _on_restart_requested() -> void:
	get_tree().paused = false
	RunState.reset()
	get_tree().reload_current_scene()
