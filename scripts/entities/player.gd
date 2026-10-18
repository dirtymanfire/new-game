class_name Player
extends CharacterBody2D
## 플레이어: WASD 이동만 직접 조작하고, 공격은 행동 수칙에 따라 자동으로 실행합니다.

signal health_changed(current: float, maximum: float)
signal died

## 일반적인 뱀서라이크 기준 임시값
@export var max_health: float = 100.0
## 픽셀/초 (1920x1080 기준)
@export var move_speed: float = 300.0
## 피격 후 무적 시간(초). 적 여러 마리에 닿아도 연속으로 맞지 않게 합니다.
@export var invincible_time: float = 0.5
## 충돌 판정 반경
@export var radius: float = 20.0

var health: float
## 마지막 이동 방향. 휘두르기처럼 이동 방향을 기준으로 하는 행동에 사용합니다.
var facing := Vector2.RIGHT
var _invincible_left := 0.0


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	_invincible_left = maxf(_invincible_left - delta, 0.0)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	if direction != Vector2.ZERO:
		facing = direction.normalized()
	move_and_slide()


func take_damage(amount: float) -> void:
	if health <= 0.0 or _invincible_left > 0.0:
		return
	_invincible_left = invincible_time
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health == 0.0:
		died.emit()
