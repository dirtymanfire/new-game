class_name Attack
extends RefCounted
## 실행 중인 공격 하나의 정보. 행동 타일 + 붙은 속성/변형을 적용한 결과입니다.
## 같은 타일이 여러 개 붙어도 효과는 한 번만 적용됩니다 (강화는 별도 시스템으로 예정).

var step: RuleCompiler.ActionStep
var tile: BehaviorTile
## 0이면 조건을 발동할 수 있는 순차 행동, 1 이상이면 조건으로 발동된 공격
var depth: int
var damage: float
## 적용할 속성 타일 (중복 없음). 값은 쓰지 않습니다.
var elements: Dictionary = {}
var pierce := 0
## 동시에 나가는 발사 수 (분열을 행동 앞에 두었을 때)
var shot_count := 1
var spread_degrees := 0.0
var homing := 0.0


static func from_step(action_step: RuleCompiler.ActionStep, attack_depth: int) -> Attack:
	var attack := Attack.new()
	attack.step = action_step
	attack.tile = action_step.tile
	attack.depth = attack_depth
	attack.damage = action_step.tile.damage
	for element in action_step.elements:
		attack.elements[element] = true
	var applied := {}
	for modifier in action_step.modifiers:
		if applied.has(modifier.id):
			continue
		applied[modifier.id] = true
		match modifier.id:
			&"pierce":
				attack.pierce = modifier.count
			&"split":
				attack.shot_count = modifier.count
				attack.spread_degrees = modifier.angle_degrees
			&"homing":
				attack.homing = modifier.potency
	return attack


## 조건이 발동될 수 있는 공격인지 (무한 연쇄 방지 A안)
func can_trigger() -> bool:
	return depth == 0
