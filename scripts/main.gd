extends Node2D
## 메인 전투 씬. 플레이어가 죽으면 새 판으로 다시 시작합니다.

@onready var _player: Player = $Player
@onready var _hud: CanvasLayer = $HUD


func _ready() -> void:
	_hud.bind_player(_player)
	_hud.bind_rule(RunState.rule)
	_player.died.connect(_on_player_died)


func _on_player_died() -> void:
	RunState.reset()
	get_tree().reload_current_scene.call_deferred()
