extends CanvasLayer
## HUD del mundo: contador de luces y botón de pausa.

@onready var lights_label: Label = %LightsLabel
@onready var pause_button: Button = %PauseButton


func _ready() -> void:
	_update_lights()
	GameState.light_collected.connect(_on_light_collected)
	pause_button.pressed.connect(_on_pause_pressed)


func _on_light_collected(_minigame_id: String, _total: int) -> void:
	_update_lights()


func _update_lights() -> void:
	lights_label.text = "Luces %d/%d" % [GameState.get_light_count(), GameState.TOTAL_LIGHTS]


func _on_pause_pressed() -> void:
	AudioManager.play_sfx(AudioManager.UI_CLICK)
	# Avisa a quien esté en el grupo "pause_menu" que abra la pausa.
	get_tree().call_group("pause_menu", "pause_game")
