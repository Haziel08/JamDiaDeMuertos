extends Control
## Menú principal: Jugar, Opciones, Créditos y Salir.

const MENU_MUSIC := preload("res://common/music/menu_theme.ogg")

@onready var main_panel: Control = %Center
@onready var play_button: BaseButton = %PlayButton
@onready var options_button: BaseButton = %OptionsButton
@onready var credits_button: BaseButton = %CreditsButton
@onready var quit_button: BaseButton = %QuitButton
@onready var title: TextureRect = %Title
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

	_float_title()
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


func _float_title() -> void:
	## El título sube y baja despacito, como si flotara.
	var base_y := title.position.y
	var t := create_tween().set_loops()
	t.tween_property(title, "position:y", base_y - 3.0, 1.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(title, "position:y", base_y, 1.4).set_trans(Tween.TRANS_SINE)


func _close_submenu(button_to_focus: BaseButton) -> void:
	main_panel.show()
	button_to_focus.grab_focus()
