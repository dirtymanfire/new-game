extends CanvasLayer
## 전투 화면 HUD: 체력, 웨이브, 현재 행동 수칙과 경고를 표시합니다.

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _rule_bar: HBoxContainer = %RuleBar
@onready var _warning_label: Label = %WarningLabel


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


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "체력 %d / %d" % [ceili(current), ceili(maximum)]
