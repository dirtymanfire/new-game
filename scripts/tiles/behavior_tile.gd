class_name BehaviorTile
extends Resource
## 행동 수칙 슬롯에 들어가는 타일 하나의 정의.
## 타일 효과(피해량, 지속 시간 등)는 기획 확정 후 추가합니다.

enum Kind {
	ACTION, ## 행동: 공격 생성 (사격, 휘두르기, 폭발)
	ELEMENT, ## 속성: 원소 및 상태이상 (화염, 빙결, 독)
	MODIFIER, ## 변형: 공격 메커니즘 변경 (관통, 분열, 유도)
	CONDITION, ## 조건: 특정 상황에 행동 발동 (적중 시, 처치 시)
}

const KIND_NAMES := {
	Kind.ACTION: "행동",
	Kind.ELEMENT: "속성",
	Kind.MODIFIER: "변형",
	Kind.CONDITION: "조건",
}

## 아이콘이 없을 때 사용할 임시 색상
const KIND_COLORS := {
	Kind.ACTION: Color("e05a47"),
	Kind.ELEMENT: Color("e0a847"),
	Kind.MODIFIER: Color("4797e0"),
	Kind.CONDITION: Color("9b5de5"),
}

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.ACTION
## 비워 두면 종류별 임시 색상으로 표시됩니다.
@export var icon: Texture2D
@export_multiline var description: String = ""


func get_kind_name() -> String:
	return KIND_NAMES[kind]


func get_kind_color() -> Color:
	return KIND_COLORS[kind]
