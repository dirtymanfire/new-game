class_name TileCard
extends PanelContainer
## 타일 한 칸 UI. 행동 수칙 슬롯, 상점 진열, 보관함에서 함께 씁니다.
## drag_data를 지정하면 끌 수 있고, on_drop을 지정하면 다른 카드를 놓을 수 있습니다.

signal pressed

const WARNING_COLOR := Color("ff3b3b")
const ACTIVE_COLOR := Color.WHITE

var tile: BehaviorTile
var card_size := Vector2(140, 90)
## 끌기 시작할 때 넘길 데이터. null이면 끌 수 없습니다.
var drag_data = null
## func(data: Dictionary) -> void. 비어 있으면 놓을 수 없습니다.
var on_drop: Callable
var warning := ""
var active := false
var empty_text := "빈 슬롯"


func _ready() -> void:
	custom_minimum_size = card_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.bg_color = tile.get_kind_color() if tile else Color(1, 1, 1, 0.06)
	if warning != "":
		style.set_border_width_all(4)
		style.border_color = WARNING_COLOR
	elif active:
		style.set_border_width_all(4)
		style.border_color = ACTIVE_COLOR
	add_theme_stylebox_override("panel", style)

	var tips: Array[String] = []
	if tile:
		tips.append("%s (%s)" % [tile.display_name, tile.get_kind_name()])
		if tile.description != "":
			tips.append(tile.description)
	if warning != "":
		tips.append("⚠ " + warning)
	tooltip_text = "\n".join(tips)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	if tile and tile.icon:
		var icon := TextureRect.new()
		icon.texture = tile.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(48, 48)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = tile.display_name if tile else empty_text
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	if tile:
		var kind_label := Label.new()
		kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kind_label.text = tile.get_kind_name()
		kind_label.add_theme_font_size_override("font_size", 14)
		kind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(kind_label)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_data == null or tile == null:
		return null
	var preview := TileCard.new()
	preview.tile = tile
	preview.card_size = card_size
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	return drag_data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return on_drop.is_valid() and data is Dictionary


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	on_drop.call(data)
