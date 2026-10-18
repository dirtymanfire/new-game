extends Node2D
## 메인 씬. 게임 흐름: 시작 타일 선택 → 웨이브 → 상점 → 웨이브 → … → 사망 시 결과 화면.

## 테스트용: 판 시작 시 이 타일들을 슬롯 1~5에 넣고 시작 타일 선택을 건너뜁니다.
## 비워 두면 시작 화면에서 행동 타일 하나를 고릅니다.
@export var debug_start_tiles: Array[BehaviorTile] = []
## 테스트용: 판 시작 시 지급할 코인
@export var debug_start_coins: int = 0

var _shop: Shop

@onready var _player: Player = $Player
@onready var _runner: RuleRunner = $Player/RuleRunner
@onready var _hud: CanvasLayer = $HUD
@onready var _result: CanvasLayer = $ResultScreen
@onready var _combat: CombatSystem = $Combat
@onready var _waves: WaveDirector = $WaveDirector
@onready var _enemies: Node2D = $Enemies
@onready var _pickups: Node2D = $Pickups
@onready var _shop_screen: CanvasLayer = $ShopScreen
@onready var _start_screen: CanvasLayer = $StartScreen


func _ready() -> void:
	var rule := RunState.rule
	_shop = Shop.new(RunState, TileLibrary.get_all())

	_hud.bind_player(_player)
	_hud.bind_rule(rule, _runner)
	rule.changed.connect(_reload_rule)
	_combat.setup(_player, _runner)
	_waves.setup(_player, _enemies, _pickups)
	_waves.progress_changed.connect(_hud.set_kill_progress)
	_waves.wave_cleared.connect(_on_wave_cleared)
	_waves.coins_collected.connect(RunState.add_coins)
	_player.died.connect(_on_player_died)
	_result.restart_requested.connect(_on_restart_requested)
	_shop_screen.next_wave_requested.connect(_on_next_wave)
	_start_screen.tile_chosen.connect(_on_start_tile_chosen)

	RunState.add_coins(debug_start_coins)
	if debug_start_tiles.is_empty():
		get_tree().paused = true
		_start_screen.open()
	else:
		for i in mini(debug_start_tiles.size(), BehaviorRule.SLOT_COUNT):
			rule.set_tile(i, debug_start_tiles[i])
		_start_wave()


func _start_wave() -> void:
	get_tree().paused = false
	_player.heal_full()
	_hud.set_wave(RunState.wave)
	_reload_rule()
	_runner.start()
	_waves.start_wave(RunState.wave)


func _reload_rule() -> void:
	_runner.load_rule(RunState.rule)
	_hud.show_warnings(_runner.compiled.warnings)


func _on_start_tile_chosen(tile: BehaviorTile) -> void:
	RunState.rule.set_tile(0, tile)
	_start_wave()


func _on_wave_cleared() -> void:
	_runner.stop()
	_clear_field()
	get_tree().paused = true
	_shop_screen.open(_shop, RunState.wave)


func _on_next_wave() -> void:
	RunState.wave += 1
	_start_wave()


## 웨이브 종료 시 남은 화폐는 자동으로 획득하고, 투사체와 효과는 지웁니다.
func _clear_field() -> void:
	for coin in _pickups.get_children():
		if coin is Coin:
			coin.collect()
	for node in _combat.get_children():
		node.queue_free()


func _on_player_died() -> void:
	get_tree().paused = true
	_result.open(RunState.wave)


func _on_restart_requested() -> void:
	get_tree().paused = false
	RunState.reset()
	get_tree().reload_current_scene()
