extends Control
## Menú principal: Jugar, Opciones, Créditos y Salir.

const MENU_MUSIC := preload("res://common/music/menu_theme.ogg")

@onready var main_panel: Control = %Center
@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton
@onready var options_menu: Control = %OptionsMenu
@onready var credits_menu: Control = %CreditsMenu


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_open_submenu.bind(options_menu))
	credits_button.pressed.connect(_open_submenu.bind(credits_menu))
	quit_button.pressed.connect(_on_quit_pressed)

	# Al cerrar un panel, regresa el foco al botón que lo abrió.
	options_menu.closed.connect(_close_submenu.bind(options_button))
	credits_menu.closed.connect(_close_submenu.bind(credits_button))

	options_menu.hide()
	credits_menu.hide()

	# En el navegador no se puede cerrar el juego, así que se oculta "Salir".
	quit_button.visible = not OS.has_feature("web")

	play_button.grab_focus()
	AudioManager.add_button_sounds(self)  # después de grab_focus, para que no suene al abrir
	AudioManager.play_music(MENU_MUSIC)


func _on_play_pressed() -> void:
	GameState.reset()  # partida nueva: sin luces
	SceneManager.go_to_world()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _open_submenu(submenu: Control) -> void:
	main_panel.hide()
	submenu.open()


func _close_submenu(button_to_focus: Button) -> void:
	main_panel.show()
	button_to_focus.grab_focus()
