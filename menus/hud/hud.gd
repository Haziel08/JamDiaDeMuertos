extends CanvasLayer
## HUD del mundo: contador de luces y botón de pausa.

@onready var lights_label: Label = %LightsLabel
@onready var pause_button: BaseButton = %PauseButton
@onready var hint_label: Label = %HintLabel

var _hint_tween: Tween


func _ready() -> void:
	_update_lights()
	GameState.light_collected.connect(_on_light_collected)
	pause_button.pressed.connect(_on_pause_pressed)
	hint_label.modulate.a = 0.0


func _on_light_collected(_minigame_id: String, _total: int) -> void:
	_update_lights()


func _update_lights() -> void:
	lights_label.text = "Luces %d/%d" % [GameState.get_light_count(), GameState.TOTAL_LIGHTS]


func _on_pause_pressed() -> void:
	AudioManager.play_sfx(AudioManager.UI_CLICK)
	# Avisa a quien esté en el grupo "pause_menu" que abra la pausa.
	get_tree().call_group("pause_menu", "pause_game")

func show_hint(text: String) -> void:
	## Muestra un aviso arriba de la pantalla (ej. controles).
	hint_label.text = text
	_fade_hint(1.0)


func hide_hint() -> void:
	_fade_hint(0.0)


func _fade_hint(alpha: float) -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(hint_label, "modulate:a", alpha, 0.3)
