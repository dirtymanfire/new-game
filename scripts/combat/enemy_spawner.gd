extends Node
## 임시 적 생성기: 화면 밖에서 일정 간격으로 추적형 적을 만듭니다.
## (웨이브 기획 확정 전 테스트용)

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

@export var spawn_interval: float = 1.0
## 플레이어로부터의 생성 거리 (1920x1080 화면 바깥)
@export var spawn_distance: float = 1150.0
@export var max_enemies: int = 150

var _player: Player
var _parent: Node
var _time_left := 0.0


func setup(player: Player, parent: Node) -> void:
	_player = player
	_parent = parent


func _process(delta: float) -> void:
	if _player == null:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left += spawn_interval
	if get_tree().get_node_count_in_group(&"enemies") >= max_enemies:
		return
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.player = _player
	_parent.add_child(enemy)
	enemy.global_position = _player.global_position + Vector2.from_angle(randf() * TAU) * spawn_distance
