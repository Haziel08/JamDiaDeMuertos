extends StaticBody2D
## NPC con el que se habla con la acción "interact" (E / Espacio).
## En el Inspector elige su archivo .dialogue y sus animaciones (Sprite Frames).
## Sin diálogo, es solo decoración.

@export var dialogue: DialogueResource
@export var start_cue: String = "start"
## Animaciones del NPC. Necesita al menos "idle_down"; si tiene idle_left/right/up, voltea al hablar.
@export var sprite_frames: SpriteFrames

@onready var prompt: Label = $Prompt
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _player_near: bool = false
var _player: Node2D
var _can_talk_at: int = 0  # evita reabrir el diálogo con la misma tecla que lo cerró


func _ready() -> void:
	prompt.hide()
	if sprite_frames:
		sprite.sprite_frames = sprite_frames
		sprite.play("idle_down")
		$Placeholder.hide()
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
		if _player:
			face_towards(_player.global_position)
		DialogueManager.show_dialogue_balloon(dialogue, start_cue)


func face_towards(point: Vector2) -> void:
	## Voltea hacia un punto (por ejemplo, el jugador) si tiene la animación.
	if sprite.sprite_frames == null:
		return
	var d := point - global_position
	var dir := ("right" if d.x > 0 else "left") if absf(d.x) > absf(d.y) else ("down" if d.y > 0 else "up")
	play_if_exists("idle_" + dir)


func play_if_exists(animation: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(animation):
		sprite.play(animation)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		_player = body
		prompt.visible = dialogue != null


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		prompt.hide()


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	_can_talk_at = Time.get_ticks_msec() + 300
	prompt.visible = _player_near and dialogue != null
