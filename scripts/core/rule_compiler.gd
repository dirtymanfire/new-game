class_name RuleCompiler
extends RefCounted
## 행동 수칙 5슬롯을 왼쪽 → 오른쪽으로 해석해 실행 가능한 형태(CompiledRule)로 바꿉니다.
##
## 해석 규칙 (확정):
## - 속성은 행동 바로 앞에 붙습니다. 행동 앞에 연속된 속성은 모두 적용됩니다.
## - 변형은 행동 앞 또는 뒤에 붙습니다. 연속된 변형은 모두 적용됩니다.
##   단, allow_after_action이 꺼진 변형(분열)은 행동 뒤에 오면 경고합니다.
## - 조건은 바로 앞 행동에만 적용되고, 뒤의 타일 trigger_reach개를 발동합니다.
##   · 뒤가 행동이면: 그 행동은 조건 전용이 되어 순차 실행에서 빠집니다. 쿨다운 없이 발동합니다.
##   · 뒤가 속성이면: 적중/처치한 적에게 그 상태이상을 겁니다.
##   · 뒤가 usable_after_condition이 켜진 변형(분열)이면: 맞은 적 위치에서 그 효과가 발동합니다.
## - 조건으로 발동된 행동은 max_chain_depth를 넘어 다시 조건을 발동하지 않습니다 (무한 연쇄 방지 A안).
## - 잘못된 배치는 허용하되 경고하고, 해당 타일은 효과 없이 무시합니다.
## - 빈 슬롯은 없는 것처럼 건너뜁니다.

## 조건 타일이 뒤에서 발동시키는 타일 수. 업그레이드로 2가 될 예정입니다.
const DEFAULT_TRIGGER_REACH := 1
## 조건 연쇄 깊이. 1이면 조건으로 발동된 행동은 다시 조건을 발동하지 않습니다. -1이면 무한.
const DEFAULT_MAX_CHAIN_DEPTH := 1


## 순차 실행되거나 조건으로 발동되는 행동 하나.
class ActionStep:
	extends RefCounted
	var tile: BehaviorTile
	var slot_index: int
	## 0: 순차 실행되는 행동, 1 이상: 조건으로 발동된 행동
	var depth: int = 0
	var elements: Array[BehaviorTile] = []
	var modifiers: Array[BehaviorTile] = []
	var triggers: Array[TriggerStep] = []

	func describe() -> String:
		var parts: Array[String] = []
		for e in elements:
			parts.append(e.display_name)
		parts.append(tile.display_name)
		for m in modifiers:
			parts.append(m.display_name)
		return " ".join(parts)


## 조건 타일 하나와 그 조건이 발동시키는 내용.
class TriggerStep:
	extends RefCounted
	var condition: BehaviorTile
	var slot_index: int
	## 조건 발동 시 실행할 행동 (조건 전용)
	var actions: Array[ActionStep] = []
	## 조건 발동 시 대상 적에게 걸 상태이상
	var statuses: Array[BehaviorTile] = []
	## 조건 발동 시 대상 적 위치에서 발동할 변형 (예: 맞은 후 분열)
	var modifiers: Array[BehaviorTile] = []


class CompiledRule:
	extends RefCounted
	## 순차 실행 순서대로 정렬된 행동
	var actions: Array[ActionStep] = []
	## 슬롯 번호 -> 경고 메시지. 슬롯과 무관한 경고는 -1
	var warnings: Dictionary = {}

	func add_warning(slot_index: int, message: String) -> void:
		if not warnings.has(slot_index):
			warnings[slot_index] = message


static func compile(
	slots: Array[BehaviorTile],
	trigger_reach: int = DEFAULT_TRIGGER_REACH,
	max_chain_depth: int = DEFAULT_MAX_CHAIN_DEPTH,
) -> CompiledRule:
	var result := CompiledRule.new()

	var tokens: Array[Dictionary] = []
	for i in slots.size():
		if slots[i] != null:
			tokens.append({ "index": i, "tile": slots[i] })

	## 다음 행동 앞에 붙을 속성/변형. {index, tile, reason(행동이 안 나오면 띄울 경고)}
	var pending_prefix: Array[Dictionary] = []
	## 다음 변형/조건이 붙을 행동. 다른 타일이 끼어들면 null이 됩니다.
	var attach_target: ActionStep = null
	## attach_target 뒤에 조건이 이미 나와서 변형이 더 붙을 수 없는 상태
	var modifiers_closed := false

	var t := 0
	while t < tokens.size():
		var index: int = tokens[t].index
		var tile: BehaviorTile = tokens[t].tile
		t += 1

		match tile.kind:
			BehaviorTile.Kind.ELEMENT:
				pending_prefix.append({ "index": index, "tile": tile, "reason": "속성 뒤에 행동이 없습니다." })
				attach_target = null

			BehaviorTile.Kind.ACTION:
				var step := ActionStep.new()
				step.tile = tile
				step.slot_index = index
				for p in pending_prefix:
					if p.tile.kind == BehaviorTile.Kind.ELEMENT:
						step.elements.append(p.tile)
					else:
						step.modifiers.append(p.tile)
				pending_prefix.clear()
				result.actions.append(step)
				attach_target = step
				modifiers_closed = false

			BehaviorTile.Kind.MODIFIER:
				if attach_target and not modifiers_closed and pending_prefix.is_empty():
					if tile.allow_after_action:
						attach_target.modifiers.append(tile)
					else:
						result.add_warning(index, "%s은(는) 행동 앞에 놓아야 합니다." % tile.display_name)
				else:
					var reason := "변형 앞뒤에 행동이 없습니다."
					if modifiers_closed and pending_prefix.is_empty():
						reason = "조건으로 발동되는 행동에는 뒤의 변형이 적용되지 않습니다."
					pending_prefix.append({ "index": index, "tile": tile, "reason": reason })
					attach_target = null

			BehaviorTile.Kind.CONDITION:
				_orphan_prefix(result, pending_prefix)
				if attach_target == null:
					result.add_warning(index, "조건 앞에 행동이 없습니다.")
					continue
				if max_chain_depth >= 0 and attach_target.depth >= max_chain_depth:
					result.add_warning(index, "조건으로 발동된 행동은 다시 조건을 발동할 수 없습니다.")
					attach_target = null
					continue
				if t >= tokens.size():
					result.add_warning(index, "조건 뒤에 발동할 타일이 없습니다.")
					attach_target = null
					continue

				var trigger := TriggerStep.new()
				trigger.condition = tile
				trigger.slot_index = index
				attach_target.triggers.append(trigger)
				var owner := attach_target
				var last_payload_action: ActionStep = null
				var consumed := 0
				while consumed < trigger_reach and t < tokens.size():
					var p_index: int = tokens[t].index
					var p_tile: BehaviorTile = tokens[t].tile
					t += 1
					consumed += 1
					match p_tile.kind:
						BehaviorTile.Kind.ACTION:
							var triggered := ActionStep.new()
							triggered.tile = p_tile
							triggered.slot_index = p_index
							triggered.depth = owner.depth + 1
							trigger.actions.append(triggered)
							last_payload_action = triggered
						BehaviorTile.Kind.ELEMENT:
							trigger.statuses.append(p_tile)
						BehaviorTile.Kind.MODIFIER:
							if last_payload_action and p_tile.allow_after_action:
								last_payload_action.modifiers.append(p_tile)
							elif last_payload_action == null and p_tile.usable_after_condition:
								trigger.modifiers.append(p_tile)
							else:
								result.add_warning(p_index, "%s은(는) 조건 뒤에 올 수 없습니다." % p_tile.display_name)
						BehaviorTile.Kind.CONDITION:
							result.add_warning(p_index, "조건 뒤에 조건이 올 수 없습니다.")

				# 조건으로 발동된 행동 뒤의 타일은 그 행동에 붙지 않고 경고 대상이 됩니다.
				attach_target = last_payload_action
				modifiers_closed = true

	_orphan_prefix(result, pending_prefix)
	if result.actions.is_empty():
		result.add_warning(-1, "행동 수칙에 순차 실행할 행동이 없습니다.")
	return result


static func _orphan_prefix(result: CompiledRule, pending_prefix: Array[Dictionary]) -> void:
	for p in pending_prefix:
		result.add_warning(p.index, p.reason)
	pending_prefix.clear()
