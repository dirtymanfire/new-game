extends Node
## 오토로드: 한 판(런) 동안 유지되는 상태.
## 사망하면 reset()으로 새 판을 시작합니다.

var rule: BehaviorRule
## 현재 웨이브 (웨이브 시스템은 기획 확정 후 구현)
var wave := 1


func _ready() -> void:
	reset()


func reset() -> void:
	# 시작 타일 구성은 미정이므로 빈 수칙으로 시작합니다.
	rule = BehaviorRule.new()
	wave = 1
