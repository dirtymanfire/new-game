class_name Shop
extends RefCounted
## 상점 규칙: 진열, 구매, 새로고침, 판매, 보관함 ↔ 슬롯 배치.
## UI와 분리되어 있어 테스트할 수 있습니다. 실패하면 이유 문자열을, 성공하면 ""를 돌려줍니다.

## 한 번에 진열되는 타일 수 (임시값)
const OFFER_COUNT := 4
## 새로고침 기본 비용, 같은 상점에서 새로고침할 때마다 늘어나는 비용 (임시값)
const REROLL_BASE_COST := 2
const REROLL_COST_STEP := 1

## 진열 타일. 팔린 칸은 null
var offers: Array[BehaviorTile] = []
var reroll_cost := REROLL_BASE_COST

var _state: Node
var _pool: Array[BehaviorTile]


func _init(state: Node, pool: Array[BehaviorTile]) -> void:
	_state = state
	_pool = pool


## 새 상점을 엽니다 (웨이브 종료 시). 새로고침 비용이 초기화됩니다.
func open() -> void:
	reroll_cost = REROLL_BASE_COST
	_roll()


func reroll() -> String:
	if not _state.spend(reroll_cost):
		return "화폐가 부족합니다."
	reroll_cost += REROLL_COST_STEP
	_roll()
	return ""


func buy(offer_index: int) -> String:
	var tile := offers[offer_index]
	if tile == null:
		return "이미 구매했습니다."
	if _state.is_inventory_full():
		return "보관함이 가득 찼습니다."
	if not _state.spend(tile.price):
		return "화폐가 부족합니다."
	_state.add_to_inventory(tile)
	offers[offer_index] = null
	return ""


func sell_from_inventory(index: int) -> String:
	var tile: BehaviorTile = _state.take_from_inventory(index)
	_state.add_coins(tile.get_sell_price())
	return ""


func sell_from_slot(slot_index: int) -> String:
	var tile: BehaviorTile = _state.rule.get_tile(slot_index)
	if tile == null:
		return ""
	var reason := _forbidden_reason_without(slot_index)
	if reason != "":
		return reason
	_state.rule.clear_slot(slot_index)
	_state.add_coins(tile.get_sell_price())
	return ""


## 보관함 타일을 슬롯에 놓습니다. 슬롯에 타일이 있으면 보관함으로 돌아갑니다.
func place(inventory_index: int, slot_index: int) -> String:
	var slots: Array[BehaviorTile] = _state.rule.get_slots()
	slots[slot_index] = _state.inventory[inventory_index]
	var reason := _forbidden_reason(slots)
	if reason != "":
		return reason
	var tile: BehaviorTile = _state.take_from_inventory(inventory_index)
	var previous: BehaviorTile = _state.rule.get_tile(slot_index)
	_state.rule.set_tile(slot_index, tile)
	if previous:
		_state.add_to_inventory(previous)
	return ""


## 슬롯 타일을 보관함으로 돌려놓습니다.
func unplace(slot_index: int) -> String:
	var tile: BehaviorTile = _state.rule.get_tile(slot_index)
	if tile == null:
		return ""
	if _state.is_inventory_full():
		return "보관함이 가득 찼습니다."
	var reason := _forbidden_reason_without(slot_index)
	if reason != "":
		return reason
	_state.rule.clear_slot(slot_index)
	_state.add_to_inventory(tile)
	return ""


func swap_slots(a: int, b: int) -> String:
	var slots: Array[BehaviorTile] = _state.rule.get_slots()
	var temp := slots[a]
	slots[a] = slots[b]
	slots[b] = temp
	var reason := _forbidden_reason(slots)
	if reason != "":
		return reason
	_state.rule.swap(a, b)
	return ""


func _forbidden_reason_without(slot_index: int) -> String:
	var slots: Array[BehaviorTile] = _state.rule.get_slots()
	slots[slot_index] = null
	return _forbidden_reason(slots)


## 이 배치가 금지된 배치(예: 조건 연달아)면 이유를, 아니면 ""를 돌려줍니다.
## 이미 금지 상태인 수칙을 고치는 중이면, 금지 칸이 늘어날 때만 막습니다.
func _forbidden_reason(slots: Array[BehaviorTile]) -> String:
	var after := RuleCompiler.compile(slots)
	var before := RuleCompiler.compile(_state.rule.get_slots())
	if after.forbidden.size() > before.forbidden.size():
		return after.warnings[after.forbidden[0]]
	return ""


func _roll() -> void:
	offers.clear()
	for i in OFFER_COUNT:
		offers.append(_pool.pick_random())
