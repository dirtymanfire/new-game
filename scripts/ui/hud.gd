extends CanvasLayer
## 전투 화면 HUD: 체력, 웨이브, 현재 행동 수칙과 경고를 표시합니다.

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _rule_bar: HBoxContainer = %RuleBar
@onready var _warning_label: Label = %WarningLabel
@onready var _coin_label: Label = %CoinLabel
@onready var _kill_label: Label = %KillLabel
@onready var _wave_clear_label: Label = %WaveClearLabel

var _clear_time_left := 0.0


func _ready() -> void:
	RunState.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(RunState.coins)
	_wave_clear_label.hide()


func _process(delta: float) -> void:
	if not _wave_clear_label.visible:
		return
	_clear_time_left = maxf(_clear_time_left - delta, 0.0)
	_wave_clear_label.text = "웨이브 클리어!  상점까지 %d" % ceili(_clear_time_left)


func show_wave_clear(seconds: float) -> void:
	_clear_time_left = seconds
	_wave_clear_label.show()


func hide_wave_clear() -> void:
	_wave_clear_label.hide()


func bind_player(player: Player) -> void:
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)


func bind_rule(rule: BehaviorRule, runner: RuleRunner) -> void:
	_rule_bar.bind(rule)
	runner.current_slot_changed.connect(_rule_bar.set_active_slot)


func show_warnings(warnings: Dictionary) -> void:
	_rule_bar.set_warnings(warnings)
	var lines: Array[String] = []
	var keys := warnings.keys()
	keys.sort()
	for slot_index in keys:
		var prefix := "수칙" if slot_index < 0 else "%d번 슬롯" % (slot_index + 1)
		lines.append("⚠ %s: %s" % [prefix, warnings[slot_index]])
	_warning_label.text = "\n".join(lines)


func set_wave(wave: int) -> void:
	_wave_label.text = "웨이브 %d" % wave


func set_kill_progress(kills: int, target: int) -> void:
	_kill_label.text = "처치 %d / %d" % [kills, target]


func _on_coins_changed(coins: int) -> void:
	_coin_label.text = "코인 %d" % coins


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "체력 %d / %d" % [ceili(current), ceili(maximum)]
