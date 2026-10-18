extends CanvasLayer
## 웨이브 사이 상점 화면.
## - 진열 타일 구매 → 보관함
## - 보관함 → 슬롯으로 끌어 배치 (슬롯에 있던 타일은 보관함으로)
## - 슬롯 ↔ 슬롯 끌어 순서 변경, 슬롯 → 보관함 끌어 회수
## - 판매 칸에 끌어 판매 (구매가의 절반)

signal next_wave_requested

const CARD_SIZE := Vector2(150, 96)
const SECTION_FONT_SIZE := 26

var _shop: Shop
var _wave := 1
var _message := ""
var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	hide()


func open(shop: Shop, cleared_wave: int) -> void:
	_shop = shop
	_wave = cleared_wave
	_message = ""
	_shop.open()
	if not RunState.coins_changed.is_connected(_on_state_changed):
		RunState.coins_changed.connect(_on_state_changed)
		RunState.inventory_changed.connect(_on_state_changed)
	if not RunState.rule.changed.is_connected(_rebuild):
		RunState.rule.changed.connect(_rebuild)
	show()
	_rebuild()


func close() -> void:
	hide()
	RunState.coins_changed.disconnect(_on_state_changed)
	RunState.inventory_changed.disconnect(_on_state_changed)
	RunState.rule.changed.disconnect(_rebuild)


func _on_state_changed(_value = null) -> void:
	_rebuild()


func _rebuild() -> void:
	if not visible:
		return
	if _root:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	_root.add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	margin.add_child(page)

	page.add_child(_build_header())
	page.add_child(_section_label("판매 중"))
	page.add_child(_build_offers())
	page.add_child(_section_label("행동 수칙"))
	page.add_child(_build_rule_slots())
	page.add_child(_build_warnings())
	page.add_child(_section_label("보관함 (%d / %d)" % [RunState.inventory.size(), RunState.INVENTORY_SIZE]))
	page.add_child(_build_inventory())
	page.add_child(_build_footer())


func _build_header() -> Control:
	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = "웨이브 %d 클리어 — 상점" % _wave
	title.add_theme_font_size_override("font_size", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var coins := Label.new()
	coins.text = "코인 %d" % RunState.coins
	coins.add_theme_font_size_override("font_size", 36)
	coins.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
	row.add_child(coins)
	return row


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	return label


func _build_offers() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	for i in _shop.offers.size():
		var tile := _shop.offers[i]
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(260, 0)
		var card := TileCard.new()
		card.card_size = CARD_SIZE
		card.tile = tile
		card.empty_text = "판매 완료"
		col.add_child(card)
		var desc := Label.new()
		if tile:
			desc.text = tile.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(260, 60)
		desc.add_theme_font_size_override("font_size", 15)
		col.add_child(desc)
		var buy := Button.new()
		if tile:
			buy.text = "구매 · %d" % tile.price
			buy.disabled = RunState.coins < tile.price
		else:
			buy.text = "구매 완료"
			buy.disabled = true
		buy.pressed.connect(_act.bind(_shop.buy.bind(i)))
		col.add_child(buy)
		row.add_child(col)

	var reroll := Button.new()
	reroll.text = "새로고침 · %d" % _shop.reroll_cost
	reroll.disabled = RunState.coins < _shop.reroll_cost
	reroll.custom_minimum_size = Vector2(200, 60)
	reroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reroll.pressed.connect(_act.bind(_shop.reroll))
	row.add_child(reroll)
	return row


func _build_rule_slots() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var warnings := RuleCompiler.compile(RunState.rule.get_slots()).warnings
	for i in BehaviorRule.SLOT_COUNT:
		var card := TileCard.new()
		card.card_size = CARD_SIZE
		card.tile = RunState.rule.get_tile(i)
		card.warning = warnings.get(i, "")
		card.drag_data = { "source": "slot", "index": i }
		card.on_drop = _drop_on_slot.bind(i)
		row.add_child(card)
	return row


func _build_warnings() -> Control:
	var label := Label.new()
	var warnings := RuleCompiler.compile(RunState.rule.get_slots()).warnings
	var lines: Array[String] = []
	var keys := warnings.keys()
	keys.sort()
	for slot_index in keys:
		var prefix := "수칙" if slot_index < 0 else "%d번 슬롯" % (slot_index + 1)
		lines.append("⚠ %s: %s" % [prefix, warnings[slot_index]])
	label.text = "\n".join(lines)
	label.add_theme_color_override("font_color", Color(1, 0.36, 0.36))
	label.custom_minimum_size = Vector2(0, 50)
	return label


func _build_inventory() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in RunState.INVENTORY_SIZE:
		var card := TileCard.new()
		card.card_size = CARD_SIZE
		card.empty_text = ""
		if i < RunState.inventory.size():
			card.tile = RunState.inventory[i]
			card.drag_data = { "source": "inventory", "index": i }
		card.on_drop = _drop_on_inventory
		row.add_child(card)

	var sell := TileCard.new()
	sell.card_size = Vector2(200, CARD_SIZE.y)
	sell.empty_text = "여기로 끌어\n판매 (절반 가격)"
	sell.on_drop = _drop_on_sell
	row.add_child(sell)
	return row


func _build_footer() -> Control:
	var row := HBoxContainer.new()
	var help := Label.new()
	help.text = "보관함 → 슬롯: 배치 · 슬롯 ↔ 슬롯: 순서 변경 · 슬롯 → 보관함: 회수 · 판매 칸: 판매"
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(help)
	var message := Label.new()
	message.text = _message
	message.add_theme_color_override("font_color", Color(1, 0.6, 0.3))
	row.add_child(message)
	var next := Button.new()
	next.text = "다음 웨이브 ▶"
	next.custom_minimum_size = Vector2(260, 64)
	next.add_theme_font_size_override("font_size", 26)
	next.pressed.connect(_on_next_pressed)
	row.add_child(next)
	return row


func _drop_on_slot(data: Dictionary, slot_index: int) -> void:
	match data.source:
		"inventory":
			_act(_shop.place.bind(data.index, slot_index))
		"slot":
			_act(_shop.swap_slots.bind(data.index, slot_index))


func _drop_on_inventory(data: Dictionary) -> void:
	if data.source == "slot":
		_act(_shop.unplace.bind(data.index))


func _drop_on_sell(data: Dictionary) -> void:
	match data.source:
		"inventory":
			_act(_shop.sell_from_inventory.bind(data.index))
		"slot":
			_act(_shop.sell_from_slot.bind(data.index))


## 상점 동작을 실행하고, 실패 이유가 있으면 표시합니다.
func _act(action: Callable) -> void:
	_message = action.call()
	_rebuild.call_deferred()


func _on_next_pressed() -> void:
	close()
	next_wave_requested.emit()
