class_name Enemy
extends Node2D
## 임시 적: 플레이어를 향해 직진하는 근접형. (적/웨이브 기획 확정 전 테스트용)
## 화염·독·빙결 상태이상을 받습니다.

signal died(enemy: Enemy)
## 지속 피해(화염·독)로 죽었을 때. source는 마지막으로 지속 피해를 건 공격이고,
## 조건으로 걸린 상태이상이면 null입니다.
signal killed_by_status(enemy: Enemy, source: Attack)

const BASE_COLOR := Color("c8475c")
const STATUS_COLORS := {
	&"fire": Color("ff8a3d"),
	&"poison": Color("7bd65a"),
	&"frost": Color("8fd3ff"),
}

## 일반적인 뱀서라이크 기준 임시값
@export var max_health: float = 15.0
@export var move_speed: float = 120.0
@export var contact_damage: float = 10.0
@export var radius: float = 16.0

var player: Player
var health: float
var is_dead := false

var _burn_dps := 0.0
var _burn_time := 0.0
var _poison_stacks := 0
var _poison_dps_per_stack := 0.0
var _poison_time := 0.0
## 0~1. 1이 되면 얼어붙습니다.
var _slow := 0.0
var _slow_time := 0.0
var _frozen_time := 0.0
var _flash_time := 0.0
## 마지막으로 화염·독을 건 공격 (조건으로 걸렸으면 null)
var _last_dot_source: Attack

@onready var _visual: ShapeVisual = $Visual


func _ready() -> void:
	health = max_health
	add_to_group(&"enemies")


func _physics_process(delta: float) -> void:
	_tick_statuses(delta)
	if is_dead:
		return
	if player and is_instance_valid(player):
		var speed_scale := 0.0 if _frozen_time > 0.0 else 1.0 - _slow
		var to_player := player.global_position - global_position
		if to_player.length() > 1.0:
			global_position += to_player.normalized() * move_speed * speed_scale * delta
		if to_player.length() < radius + player.radius:
			player.take_damage(contact_damage)
	_update_color(delta)


## 피해를 주고, 이 피해로 죽었으면 true를 돌려줍니다.
func take_damage(amount: float) -> bool:
	if is_dead:
		return false
	health -= amount
	_flash_time = 0.08
	if health <= 0.0:
		_die()
		return true
	return false


## 속성 상태이상을 겁니다. source는 그 상태이상을 건 공격이며, 조건으로 걸렸으면 null입니다.
func apply_element(element: BehaviorTile, source: Attack = null) -> void:
	if is_dead:
		return
	match element.id:
		&"fire":
			# 다시 걸면 지속 시간만 갱신 (중첩 없음)
			_burn_dps = element.potency
			_burn_time = element.duration
			_last_dot_source = source
		&"poison":
			_poison_dps_per_stack = element.potency
			# 걸 때마다 1중첩씩 쌓이고, 지속 시간이 갱신됩니다.
			_poison_stacks = mini(_poison_stacks + 1, element.count)
			_poison_time = element.duration
			_last_dot_source = source
		&"frost":
			if _frozen_time > 0.0:
				return
			_slow += element.potency
			_slow_time = element.duration
			if _slow >= 1.0:
				_slow = 0.0
				_frozen_time = element.extra_duration
		_:
			push_warning("처리되지 않은 속성입니다: %s" % element.id)


func _tick_statuses(delta: float) -> void:
	var dot := 0.0
	if _burn_time > 0.0:
		_burn_time -= delta
		dot += _burn_dps
	if _poison_time > 0.0:
		_poison_time -= delta
		dot += _poison_dps_per_stack * _poison_stacks
		if _poison_time <= 0.0:
			_poison_stacks = 0
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow = 0.0
	if _frozen_time > 0.0:
		_frozen_time -= delta
	if dot > 0.0 and take_damage(dot * delta):
		killed_by_status.emit(self, _last_dot_source)


func _update_color(delta: float) -> void:
	var color := BASE_COLOR
	if _frozen_time > 0.0 or _slow > 0.0:
		color = STATUS_COLORS[&"frost"]
	elif _poison_time > 0.0:
		color = STATUS_COLORS[&"poison"]
	elif _burn_time > 0.0:
		color = STATUS_COLORS[&"fire"]
	if _flash_time > 0.0:
		_flash_time -= delta
		color = Color.WHITE
	_visual.color = color


func _die() -> void:
	is_dead = true
	remove_from_group(&"enemies")
	died.emit(self)
	queue_free()
