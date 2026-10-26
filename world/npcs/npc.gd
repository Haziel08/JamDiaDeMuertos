extends StaticBody2D
## NPC con el que se habla con la acción "interact" (E / Espacio).
## En el Inspector elige su archivo .dialogue y sus animaciones (Sprite Frames).
## Sin diálogo, es solo decoración.

@export var dialogue: DialogueResource
@export var start_cue: String = "start"
## Animaciones del NPC. Necesita al menos "idle_down"; si tiene idle_left/right/up, voltea al hablar.
@export var sprite_frames: SpriteFrames
## Altura del dibujo (para pararlo en el suelo). 16 para sprites de 16×16, 24 para los de 24×24.
@export var sprite_height: float = 16.0
## Qué tan arriba sale la tecla "E" (desde los pies). 0 = automático según el dibujo.
@export var prompt_height: float = 0.0
## Qué tan cerca hay que estar para interactuar (en píxeles). 0 = el normal (14).
@export var interact_radius: float = 0.0

const KEY_E := preload("res://common/ui/tecla_e.png")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var prompt: Sprite2D   # tecla "E" flotando arriba de la cabeza
var _prompt_tween: Tween

var _player_near: bool = false
var _player: Node2D
var _can_talk_at: int = 0  # evita reabrir el diálogo con la misma tecla que lo cerró


func _ready() -> void:
	$Prompt.hide()   # la etiqueta vieja ya no se usa
	sprite.position.y = -sprite_height / 2.0
	$Placeholder.hide()   # el cuadro de color ya no se usa (sin arte = invisible, como las puertas)
	if sprite_frames:
		sprite.sprite_frames = sprite_frames
		sprite.play("idle_down")
	if interact_radius > 0.0:
		var shape_node := $InteractionArea/CollisionShape2D as CollisionShape2D
		var circle := CircleShape2D.new()   # copia propia para no cambiar a los demás NPCs
		circle.radius = interact_radius
		shape_node.shape = circle
	_create_prompt()
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
		_show_prompt(false)
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
		_show_prompt(dialogue != null)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		_show_prompt(false)


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	_can_talk_at = Time.get_ticks_msec() + 300
	_show_prompt(_player_near and dialogue != null)


func _create_prompt() -> void:
	prompt = Sprite2D.new()
	prompt.texture = KEY_E
	prompt.z_index = 10
	var h := prompt_height if prompt_height > 0.0 else sprite_height + 10.0
	prompt.position = Vector2(0, -h)
	prompt.visible = false
	add_child(prompt)


func _show_prompt(value: bool) -> void:
	## Muestra la tecla "E" con un saltito; mientras se ve, flota arriba y abajo (_process).
	if prompt == null or prompt.visible == value:
		return
	prompt.visible = value
	if not value:
		return
	if _prompt_tween:
		_prompt_tween.kill()
	prompt.scale = Vector2(0.4, 0.4)
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(prompt, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	if prompt and prompt.visible:
		var h := prompt_height if prompt_height > 0.0 else sprite_height + 10.0
		prompt.position.y = -h + round(sin(Time.get_ticks_msec() / 220.0) * 1.5)
