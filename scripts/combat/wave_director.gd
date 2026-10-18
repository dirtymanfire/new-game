class_name WaveDirector
extends Node
## 웨이브 진행: 웨이브마다 정해진 수의 적을 화면 밖에서 생성하고, 모두 처치하면 웨이브가 끝납니다.
## 적이 죽은 자리에 화폐를 떨어뜨립니다. 모든 수치는 임시값입니다.

signal progress_changed(kills: int, target: int)
signal wave_cleared
## 플레이어가 화폐를 주웠을 때
signal coins_collected(amount: int)

const ENEMY_SCENE_PATH := "res://scenes/enemy.tscn"
const COIN_SCENE_PATH := "res://scenes/coin.tscn"

## 1웨이브 처치 목표, 웨이브마다 늘어나는 수
@export var base_kill_target: int = 10
@export var kill_target_per_wave: int = 5
## 생성 간격(초). 웨이브마다 줄어들고 최소값 아래로는 내려가지 않습니다.
@export var base_spawn_interval: float = 1.5
@export var spawn_interval_step: float = 0.1
@export var min_spawn_interval: float = 0.3
## 웨이브마다 적 체력 증가 비율 (0.15 = 15%)
@export var health_growth_per_wave: float = 0.15
## 플레이어로부터의 생성 거리 (1920x1080 화면 바깥)
@export var spawn_distance: float = 1150.0
## 적 1마리당 떨어지는 화폐
@export var coins_per_kill: int = 1

var kill_target := 0
var kills := 0

var _player: Player
var _enemy_parent: Node
var _pickup_parent: Node
var _wave := 1
var _spawned := 0
var _spawn_interval := 1.0
var _time_left := 0.0
var _running := false
var _enemy_scene: PackedScene
var _coin_scene: PackedScene


func setup(player: Player, enemy_parent: Node, pickup_parent: Node) -> void:
	_player = player
	_enemy_parent = enemy_parent
	_pickup_parent = pickup_parent
	_enemy_scene = load(ENEMY_SCENE_PATH)
	_coin_scene = load(COIN_SCENE_PATH)


func start_wave(wave: int) -> void:
	_wave = wave
	kill_target = base_kill_target + kill_target_per_wave * (wave - 1)
	kills = 0
	_spawned = 0
	_spawn_interval = maxf(base_spawn_interval - spawn_interval_step * (wave - 1), min_spawn_interval)
	_time_left = 0.0
	_running = true
	progress_changed.emit(kills, kill_target)


func _process(delta: float) -> void:
	if not _running or _spawned >= kill_target:
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left += _spawn_interval
	_spawn_enemy()


func _spawn_enemy() -> void:
	var enemy := _enemy_scene.instantiate() as Enemy
	enemy.player = _player
	enemy.max_health *= 1.0 + health_growth_per_wave * (_wave - 1)
	enemy.died.connect(_on_enemy_died)
	_enemy_parent.add_child(enemy)
	enemy.global_position = _player.global_position + Vector2.from_angle(randf() * TAU) * spawn_distance
	_spawned += 1


func _on_enemy_died(enemy: Enemy) -> void:
	if not _running:
		return
	var coin := _coin_scene.instantiate() as Coin
	coin.value = coins_per_kill
	coin.player = _player
	coin.collected.connect(coins_collected.emit)
	_pickup_parent.add_child.call_deferred(coin)
	coin.position = enemy.global_position
	kills += 1
	progress_changed.emit(kills, kill_target)
	if kills >= kill_target:
		_running = false
		# 마지막 화폐가 추가된 뒤에 웨이브 종료를 처리합니다.
		wave_cleared.emit.call_deferred()
