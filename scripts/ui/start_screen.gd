extends CanvasLayer
## 게임 시작 화면: 첫 행동 타일을 하나 고르면 1번 슬롯에 놓고 웨이브를 시작합니다.

signal tile_chosen(tile: BehaviorTile)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	hide()


func open() -> void:
	for child in get_children():
		child.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 30)
	center.add_child(box)

	var title := Label.new()
	title.text = "시작 행동 타일을 고르세요"
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for tile in TileLibrary.get_all():
		if tile.kind != BehaviorTile.Kind.ACTION:
			continue
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(280, 0)
		var card := TileCard.new()
		card.tile = tile
		card.card_size = Vector2(280, 140)
		card.pressed.connect(_choose.bind(tile))
		col.add_child(card)
		var desc := Label.new()
		desc.text = tile.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(280, 0)
		col.add_child(desc)
		var button := Button.new()
		button.text = "선택"
		button.custom_minimum_size = Vector2(0, 56)
		button.pressed.connect(_choose.bind(tile))
		col.add_child(button)
		row.add_child(col)
	show()


func _choose(tile: BehaviorTile) -> void:
	hide()
	tile_chosen.emit(tile)
