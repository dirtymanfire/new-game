extends HBoxContainer
## 행동 수칙 5슬롯을 화면에 표시합니다 (왼쪽 → 오른쪽 순서).
## 경고가 있는 슬롯은 빨간 테두리, 다음에 실행될 행동은 흰 테두리로 표시합니다.

var _rule: BehaviorRule
var _warnings: Dictionary = {}
var _active_slot := -1


func bind(rule: BehaviorRule) -> void:
	if _rule and _rule.changed.is_connected(_refresh):
		_rule.changed.disconnect(_refresh)
	_rule = rule
	_rule.changed.connect(_refresh)
	_refresh()


func set_warnings(warnings: Dictionary) -> void:
	_warnings = warnings
	_refresh()


func set_active_slot(slot_index: int) -> void:
	_active_slot = slot_index
	_refresh()


func _refresh() -> void:
	if _rule == null:
		return
	for child in get_children():
		child.queue_free()
	for i in BehaviorRule.SLOT_COUNT:
		var card := TileCard.new()
		card.tile = _rule.get_tile(i)
		card.warning = _warnings.get(i, "")
		card.active = i == _active_slot
		add_child(card)
