extends Node
## 오토로드: 한 판(런) 동안 유지되는 상태 (행동 수칙, 웨이브, 화폐, 보관함).
## 사망하면 reset()으로 새 판을 시작합니다.

signal coins_changed(coins: int)
signal inventory_changed

## 보관함 칸 수 (임시값)
const INVENTORY_SIZE := 8

var rule: BehaviorRule
var wave := 1
var coins := 0
## 보관함. 빈 칸은 없고 앞에서부터 채웁니다.
var inventory: Array[BehaviorTile] = []


func _ready() -> void:
	reset()


func reset() -> void:
	rule = BehaviorRule.new()
	wave = 1
	coins = 0
	inventory.clear()
	coins_changed.emit(coins)
	inventory_changed.emit()


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


## 화폐가 충분하면 차감하고 true
func spend(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


func is_inventory_full() -> bool:
	return inventory.size() >= INVENTORY_SIZE


func add_to_inventory(tile: BehaviorTile) -> bool:
	if is_inventory_full():
		return false
	inventory.append(tile)
	inventory_changed.emit()
	return true


func take_from_inventory(index: int) -> BehaviorTile:
	var tile := inventory[index]
	inventory.remove_at(index)
	inventory_changed.emit()
	return tile
