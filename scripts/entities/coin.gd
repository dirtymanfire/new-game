class_name Coin
extends Node2D
## 적이 떨어뜨리는 화폐. 플레이어가 가까이 오면 끌려가서 획득됩니다.

signal collected(value: int)

## 끌려가기 시작하는 거리, 끌려가는 속도, 획득 거리 (임시값)
@export var magnet_radius: float = 150.0
@export var magnet_speed: float = 600.0
@export var collect_radius: float = 24.0

var value := 1
var player: Player
var _attracted := false


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist < magnet_radius:
		_attracted = true
	if _attracted:
		global_position += to_player.normalized() * minf(magnet_speed * delta, dist)
	if dist < collect_radius:
		collect()


func collect() -> void:
	if is_queued_for_deletion():
		return
	collected.emit(value)
	queue_free()
