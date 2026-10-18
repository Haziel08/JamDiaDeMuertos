extends Control
## Panel de créditos. Emite "closed" al cerrarse.

signal closed

@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(close)


func open() -> void:
	show()
	back_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Esc también cierra el panel
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
