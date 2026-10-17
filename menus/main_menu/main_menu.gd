extends Control
## Menú principal: Jugar, Opciones, Créditos y Salir.

@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# En el navegador no se puede cerrar el juego, así que se oculta "Salir".
	quit_button.visible = not OS.has_feature("web")

	# Permite moverse por el menú con flechas/Enter o con control.
	play_button.grab_focus()


func _on_play_pressed() -> void:
	GameState.reset()  # partida nueva: sin luces
	SceneManager.go_to_world()


func _on_options_pressed() -> void:
	print("Opciones: pendiente")  # lo conectamos en el siguiente paso


func _on_credits_pressed() -> void:
	print("Créditos: pendiente")  # lo conectamos en el siguiente paso


func _on_quit_pressed() -> void:
	get_tree().quit()
