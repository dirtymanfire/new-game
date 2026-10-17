class_name BehaviorRule
extends RefCounted
## 행동 수칙: 5개 고정 슬롯. 빈 슬롯(null)을 허용합니다.
## 슬롯 해석(실행 순서, 속성/변형/조건 적용)은 기획 확정 후 별도 해석기에서 처리합니다.

signal changed

const SLOT_COUNT := 5

var _slots: Array[BehaviorTile] = []


func _init() -> void:
	_slots.resize(SLOT_COUNT)


func get_tile(index: int) -> BehaviorTile:
	return _slots[index]


func set_tile(index: int, tile: BehaviorTile) -> void:
	_slots[index] = tile
	changed.emit()


func clear_slot(index: int) -> void:
	set_tile(index, null)


func swap(a: int, b: int) -> void:
	var temp := _slots[a]
	_slots[a] = _slots[b]
	_slots[b] = temp
	changed.emit()


func is_slot_empty(index: int) -> bool:
	return _slots[index] == null


## 슬롯 순서 그대로 복사본을 돌려줍니다 (빈 슬롯은 null).
func get_slots() -> Array[BehaviorTile]:
	return _slots.duplicate()
