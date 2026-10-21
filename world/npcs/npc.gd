extends StaticBody2D
## NPC con el que se habla con la acción "interact" (E / Espacio).
## En el Inspector elige su archivo .dialogue. Sin diálogo, es solo decoración.

@export var dialogue: DialogueResource
@export var start_cue: String = "start"

@onready var prompt: Label = $Prompt

var _player_near: bool = false
var _can_talk_at: int = 0  # evita reabrir el diálogo con la misma tecla que lo cerró


func _ready() -> void:
	prompt.hide()
	$InteractionArea.body_entered.connect(_on_body_entered)
	$InteractionArea.body_exited.connect(_on_body_exited)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_near or dialogue == null or GameState.in_dialogue:
		return
	if Time.get_ticks_msec() < _can_talk_at:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		prompt.hide()
		DialogueManager.show_dialogue_balloon(dialogue, start_cue)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		prompt.visible = dialogue != null


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		prompt.hide()


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	_can_talk_at = Time.get_ticks_msec() + 300
	prompt.visible = _player_near and dialogue != null
