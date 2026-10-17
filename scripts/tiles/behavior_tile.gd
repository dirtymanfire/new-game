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

@export_group("배치 규칙 (변형 전용)")
## 행동 뒤에 놓아도 되는지. 끄면 행동 앞에만 놓을 수 있습니다 (예: 분열).
@export var allow_after_action: bool = true
## 조건 바로 뒤에 놓을 수 있는지. 켜면 맞은 적 위치에서 효과가 발동합니다 (예: 분열).
@export var usable_after_condition: bool = false

@export_group("수치 (임시값)")
## 피해량 (행동)
@export var damage: float = 0.0
## 투사체 속도 px/초 (사격, 분열 파편)
@export var speed: float = 0.0
## 사거리 px (사격, 분열 파편)
@export var attack_range: float = 0.0
## 크기 반경 px (사격: 탄 크기, 휘두르기·폭발: 범위)
@export var radius: float = 0.0
## 각도 (휘두르기: 부채꼴 각도, 분열: 퍼지는 각도)
@export var angle_degrees: float = 0.0
## 지속 시간 초 (속성)
@export var duration: float = 0.0
## 효과 세기 (화염·독: 초당 피해, 빙결: 1회당 둔화 비율, 유도: 초당 회전 라디안, 분열: 파편 피해 배율)
@export var potency: float = 0.0
## 개수 (관통: 관통 수, 분열: 발사 수, 독: 최대 중첩)
@export var count: int = 0
## 추가 지속 시간 초 (빙결: 완전 정지 시간)
@export var extra_duration: float = 0.0


func get_kind_name() -> String:
	return KIND_NAMES[kind]


func get_kind_color() -> Color:
	return KIND_COLORS[kind]
