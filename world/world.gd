extends Node2D
## Mundo abierto: cámara, intro, tutorial, diálogos, minijuegos, recompensas y portón final.

const INTRO := preload("res://world/npcs/dialogues/intro.dialogue")
const MEMORIES := preload("res://world/npcs/dialogues/memories.dialogue")

## Qué NPC entrega la luz de cada minijuego (usa el cue "reward" de su diálogo).
const REWARD_DIALOGUES := {
	"minigame_trajineras": preload("res://world/npcs/dialogues/mercader.dialogue"),
	"minigame_ofrenda": preload("res://world/npcs/dialogues/cocinero.dialogue"),
	"minigame_tumbas": preload("res://world/npcs/dialogues/panteonero.dialogue"),
}

@onready var ground: TileMapLayer = $Ground
@onready var player: CharacterBody2D = $Entities/Player
@onready var guide: Node2D = $Entities/Guide
@onready var hud: CanvasLayer = $Hud


func _ready() -> void:
	if GameState.has_return_position:
		player.global_position = GameState.world_return_position
	_set_camera_limits()

	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	if not GameState.intro_done:
		player.can_move = false
	await get_tree().create_timer(0.5).timeout  # deja terminar el fundido

	if not GameState.intro_done:
		DialogueManager.show_dialogue_balloon(INTRO, "start")
		await DialogueManager.dialogue_ended
		_show_controls_tutorial()
	elif GameState.pending_reward != "":
		_play_reward()


func _unhandled_input(event: InputEvent) -> void:
	# SOLO PARA PRUEBAS: F1 da las 3 luces. No funciona en la versión exportada sin debug.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		for minigame_id in ["minigame_trajineras", "minigame_ofrenda", "minigame_tumbas"]:
			GameState.complete_minigame(minigame_id)
		GameState.pending_reward = ""
		print("[Prueba] Luces: ", GameState.get_light_count())


func _show_controls_tutorial() -> void:
	## Pequeños avisos de controles después de la intro.
	hud.show_hint("Muévete con WASD o las flechas")
	while is_inside_tree() and player.velocity == Vector2.ZERO:
		await get_tree().process_frame
	if not await _wait(1.5): return
	hud.show_hint("Acércate a alguien y presiona E")
	if not await _wait(4.0): return
	hud.show_hint("P: pausa")
	if not await _wait(2.5): return
	hud.hide_hint()


func _wait(seconds: float) -> bool:
	## Espera y avisa si el mundo sigue existiendo (por si salieron al menú).
	if not is_inside_tree():
		return false
	await get_tree().create_timer(seconds, false).timeout
	return is_inside_tree()


func guide_approach() -> void:
	## Se llama desde intro.dialogue: el guía camina hacia el jugador.
	var target := player.global_position + Vector2(24, 0)
	var tween := create_tween()
	tween.tween_property(guide, "global_position", target, 1.2)
	await tween.finished


func _play_reward() -> void:
	## Al volver de un minijuego ganado: el NPC entrega la luz y luego viene el recuerdo.
	var minigame_id := GameState.pending_reward
	GameState.pending_reward = ""
	if REWARD_DIALOGUES.has(minigame_id):
		DialogueManager.show_dialogue_balloon(REWARD_DIALOGUES[minigame_id], "reward")
		await DialogueManager.dialogue_ended
		await get_tree().process_frame
	var lights := GameState.get_light_count()
	if lights >= 1 and lights <= 3:
		DialogueManager.show_dialogue_balloon(MEMORIES, "light_%d" % lights)


func _on_dialogue_started(_resource: DialogueResource) -> void:
	GameState.in_dialogue = true
	player.can_move = false


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	GameState.in_dialogue = false
	player.can_move = true

	if GameState.pending_minigame != "":
		var minigame_id := GameState.pending_minigame
		GameState.pending_minigame = ""
		GameState.save_return_position(player.global_position)
		SceneManager.go_to_minigame(minigame_id)
	elif GameState.pending_finale:
		GameState.pending_finale = false
		SceneManager.go_to_finale()


func _set_camera_limits() -> void:
	## La cámara no muestra nada fuera del suelo pintado.
	var camera: Camera2D = player.get_node("Camera2D")
	var used_rect := ground.get_used_rect()
	var tile_size := ground.tile_set.tile_size
	camera.limit_left = used_rect.position.x * tile_size.x
	camera.limit_top = used_rect.position.y * tile_size.y
	camera.limit_right = used_rect.end.x * tile_size.x
	camera.limit_bottom = used_rect.end.y * tile_size.y
	camera.reset_smoothing()
