# New Game

뱀서라이크 + 로그라이크 + 행동 프로그래밍. Godot 4.7.2 / GDScript / 2D 탑다운 / 1920×1080.

## 실행
Godot 4.7.2에서 `project.godot`을 열고 F5를 누릅니다. 이동은 WASD입니다.

## 확정 규칙 (현재 구현 범위)
- 플레이어는 이동만 직접 조작하고, 공격은 자동으로 합니다.
- 플레이어 능력치는 체력 100, 이동 속도 300px/s입니다. 뱀서라이크 일반값으로 넣은 임시값이고 `scenes/player.tscn` 인스펙터에서 바꿀 수 있습니다.
- 체력이 0이 되면 새 판으로 다시 시작합니다.
- 행동 수칙은 5슬롯 고정이며 빈 슬롯을 허용합니다.

## 구조
| 경로 | 내용 |
|---|---|
| `data/tiles/*.tres` | 타일 정의 (기획서 11종: 이름·종류만 있음). 새 타일은 파일만 추가하면 자동으로 불러옵니다. |
| `scripts/tiles/behavior_tile.gd` | 타일 리소스 (행동/속성/변형/조건, 아이콘) |
| `scripts/tiles/tile_library.gd` | 오토로드: 타일을 id로 조회 |
| `scripts/core/behavior_rule.gd` | 5슬롯 행동 수칙 데이터 |
| `scripts/core/run_state.gd` | 오토로드: 한 판 동안 유지되는 상태 |
| `scripts/visual/shape_visual.gd` | 임시 도형 표시. `texture`를 지정하면 이미지로 바뀝니다. |
| `scenes/` | 메인, 플레이어, HUD 씬 |

## 아트 교체
- 캐릭터: 해당 씬의 `Visual` 노드에서 `texture`를 지정합니다.
- 타일: `.tres`의 `icon`을 지정합니다.

## 테스트
```
godot --headless --path . -s res://tests/run_tests.gd
```
