extends Control
## Panel de opciones: volumen y pantalla completa.
## Se puede reutilizar en el menú de pausa. Emite "closed" al cerrarse.

signal closed

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var back_button: Button = %BackButton


func _ready() -> void:
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume

	music_slider.value_changed.connect(Settings.set_music_volume)
	sfx_slider.value_changed.connect(Settings.set_sfx_volume)
	# Al soltar el slider de efectos, suena un clic para escuchar el volumen nuevo.
	sfx_slider.drag_ended.connect(func(_changed): AudioManager.play_sfx(AudioManager.UI_CLICK))
	fullscreen_check.toggled.connect(Settings.set_fullscreen)
	back_button.pressed.connect(close)


func open() -> void:
	# En el navegador el jugador puede salir de pantalla completa con Esc,
	# así que sincronizamos la casilla con el estado real de la ventana.
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.set_pressed_no_signal(is_fullscreen)
	show()
	music_slider.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
