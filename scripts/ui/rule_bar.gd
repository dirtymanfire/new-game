extends HBoxContainer
## 행동 수칙 5슬롯을 화면에 표시합니다 (왼쪽 → 오른쪽 순서).
## 경고가 있는 슬롯은 빨간 테두리, 다음에 실행될 행동은 흰 테두리로 표시합니다.

const SLOT_SIZE := Vector2(140, 90)
const WARNING_COLOR := Color("ff3b3b")
const ACTIVE_COLOR := Color.WHITE

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
		add_child(_make_slot(i, _rule.get_tile(i)))


func _make_slot(index: int, tile: BehaviorTile) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = SLOT_SIZE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.bg_color = tile.get_kind_color() if tile else Color(1, 1, 1, 0.06)
	if _warnings.has(index):
		style.set_border_width_all(4)
		style.border_color = WARNING_COLOR
		panel.tooltip_text = _warnings[index]
	elif index == _active_slot:
		style.set_border_width_all(4)
		style.border_color = ACTIVE_COLOR
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	if tile and tile.icon:
		var icon := TextureRect.new()
		icon.texture = tile.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(48, 48)
		box.add_child(icon)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = tile.display_name if tile else "빈 슬롯"
	box.add_child(name_label)

	if tile:
		var kind_label := Label.new()
		kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kind_label.text = tile.get_kind_name()
		kind_label.add_theme_font_size_override("font_size", 14)
		box.add_child(kind_label)
	return panel
