extends CanvasLayer
## Menú de pausa: se abre y cierra con la acción "pause" (Esc o P).
## Pausa todo el juego excepto este menú.

@onready var main_panel: Control = %Center
@onready var resume_button: BaseButton = %ResumeButton
@onready var options_button: BaseButton = %OptionsButton
@onready var main_menu_button: BaseButton = %MainMenuButton
@onready var options_menu: Control = %OptionsMenu


func _ready() -> void:
	hide()
	options_menu.hide()

	resume_button.pressed.connect(resume_game)
	options_button.pressed.connect(_open_options)
	main_menu_button.pressed.connect(_go_to_main_menu)
	options_menu.closed.connect(_on_options_closed)

	AudioManager.add_button_sounds(self)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if visible:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	if GameState.in_dialogue:
		return
	get_tree().paused = true
	main_panel.show()
	options_menu.hide()
	show()
	resume_button.grab_focus()


func resume_game() -> void:
	hide()
	get_tree().paused = false


func _open_options() -> void:
	main_panel.hide()
	options_menu.open()


func _on_options_closed() -> void:
	main_panel.show()
	options_button.grab_focus()


func _go_to_main_menu() -> void:
	SceneManager.go_to_main_menu()  # SceneManager quita la pausa al cambiar de escena
