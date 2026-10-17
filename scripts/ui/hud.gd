extends CanvasLayer
## 전투 화면 HUD: 체력과 현재 행동 수칙을 표시합니다.

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _rule_bar: HBoxContainer = %RuleBar


func bind_player(player: Player) -> void:
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)


func bind_rule(rule: BehaviorRule) -> void:
	_rule_bar.bind(rule)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "체력 %d / %d" % [ceili(current), ceili(maximum)]
