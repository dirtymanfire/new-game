class_name RuleRunner
extends Node
## 컴파일된 행동 수칙을 순차 실행합니다.
## 순차 행동을 왼쪽부터 하나씩 실행하고, 실행할 때마다 쿨다운만큼 기다렸다가 다음 행동으로 넘어갑니다.
## 마지막 행동 다음에는 처음으로 돌아갑니다.
##
## 실제 공격 생성은 CombatSystem이 이 노드의 신호를 받아 처리합니다.

## 순차 행동이 실행될 때. origin은 플레이어 위치입니다.
signal action_performed(step: RuleCompiler.ActionStep, origin: Vector2)
## 조건으로 행동이 발동될 때. origin은 조건을 일으킨 적 위치입니다. 쿨다운이 없습니다.
signal triggered_action_performed(step: RuleCompiler.ActionStep, origin: Vector2, target: Node2D)
## 조건으로 변형이 발동될 때 (예: 맞은 후 분열). source_step은 조건을 일으킨 행동입니다.
signal triggered_modifier_performed(modifier: BehaviorTile, source_step: RuleCompiler.ActionStep, target: Node2D)
## 조건으로 적에게 상태이상을 걸 때
signal status_applied(element: BehaviorTile, target: Node2D)
## 실행 위치가 바뀔 때 (HUD 강조용). 슬롯 번호, 행동이 없으면 -1
signal current_slot_changed(slot_index: int)

## 행동 하나를 실행한 뒤 다음 행동까지 기다리는 시간(초)
@export var base_cooldown: float = 3.0
## 웨이브 시작 시 첫 행동을 바로 실행할지 (false면 쿨다운 후 실행)
@export var fire_immediately_on_start: bool = true

var compiled: RuleCompiler.CompiledRule
var _index := 0
var _time_left := 0.0
var _running := false


func load_rule(rule: BehaviorRule) -> void:
	compiled = RuleCompiler.compile(rule.get_slots())
	_index = 0
	_time_left = 0.0 if fire_immediately_on_start else base_cooldown
	_emit_current_slot()


func start() -> void:
	_running = true


func stop() -> void:
	_running = false


func _process(delta: float) -> void:
	if not _running or compiled == null or compiled.actions.is_empty():
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	var step := compiled.actions[_index]
	action_performed.emit(step, _get_origin())
	_index = (_index + 1) % compiled.actions.size()
	_time_left += base_cooldown
	_emit_current_slot()


## 공격이 적에게 적중했을 때 공격 쪽에서 호출합니다.
func notify_hit(step: RuleCompiler.ActionStep, target: Node2D) -> void:
	_fire_triggers(step, &"on_hit", target)


## 공격이 적을 처치했을 때 공격 쪽에서 호출합니다.
func notify_kill(step: RuleCompiler.ActionStep, target: Node2D) -> void:
	_fire_triggers(step, &"on_kill", target)


func _fire_triggers(step: RuleCompiler.ActionStep, condition_id: StringName, target: Node2D) -> void:
	for trigger in step.triggers:
		if trigger.condition.id != condition_id:
			continue
		for element in trigger.statuses:
			status_applied.emit(element, target)
		for modifier in trigger.modifiers:
			triggered_modifier_performed.emit(modifier, step, target)
		for action in trigger.actions:
			triggered_action_performed.emit(action, target.global_position, target)


func _get_origin() -> Vector2:
	var owner_node := get_parent() as Node2D
	return owner_node.global_position if owner_node else Vector2.ZERO


func _emit_current_slot() -> void:
	if compiled == null or compiled.actions.is_empty():
		current_slot_changed.emit(-1)
	else:
		current_slot_changed.emit(compiled.actions[_index].slot_index)
