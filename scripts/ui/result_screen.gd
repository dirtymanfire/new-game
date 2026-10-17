extends CanvasLayer
## 사망 시 결과 화면: 도달한 웨이브를 보여 주고 새 판을 시작합니다.

signal restart_requested

@onready var _wave_label: Label = %ResultWaveLabel
@onready var _restart_button: Button = %RestartButton


func _ready() -> void:
	hide()
	_restart_button.pressed.connect(restart_requested.emit)


func open(wave: int) -> void:
	_wave_label.text = "도달 웨이브: %d" % wave
	show()
	_restart_button.grab_focus()
