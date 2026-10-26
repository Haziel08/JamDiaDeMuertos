extends Node2D
## Mundo abierto: mapa, cámara, intro, tutorial, diálogos, minijuegos, recompensas y portón final.

const INTRO := preload("res://world/npcs/dialogues/intro.dialogue")
const MEMORIES := preload("res://world/npcs/dialogues/memories.dialogue")

## Qué NPC entrega la luz de cada minijuego (usa el cue "reward" de su diálogo).
const REWARD_DIALOGUES := {
	"minigame_trajineras": preload("res://world/npcs/dialogues/mercader.dialogue"),
	"minigame_ofrenda": preload("res://world/npcs/dialogues/cocinero.dialogue"),
	"minigame_tumbas": preload("res://world/npcs/dialogues/panteonero.dialogue"),
}

@onready var ground: TileMapLayer = $Map/Ground
@onready var player: CharacterBody2D = $Entities/Player
@onready var guide: Node2D = $Entities/Guide
@onready var hud: CanvasLayer = $Hud

var _welcomed: bool = false  # ya se mostró "Bienvenido al pueblo"


func _ready() -> void:
	_place_at_markers()
	if GameState.has_return_position:
		player.global_position = GameState.world_return_position
	_set_camera_limits()

	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	if not GameState.intro_done:
		player.can_move = false
		player.sleeping = true   # despierta acostado en el pasto
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


func _process(_delta: float) -> void:
	# Al cruzar el puentecito hacia el pueblo aparece el aviso de bienvenida (una vez).
	if _welcomed:
		return
	var sign_marker := get_node_or_null("Map/Markers/Sign") as Node2D
	if sign_marker and player.global_position.x > sign_marker.global_position.x - 40.0:
		_welcomed = true
		hud.show_hint("Bienvenido a ???")
		await get_tree().create_timer(3.0, false).timeout
		if is_inside_tree():
			hud.hide_hint()


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
	## Se llama desde intro.dialogue: el jugador se levanta, el guía camina hasta él y se miran.
	player.sleeping = false
	var stand := create_tween()   # saltito al levantarse
	stand.tween_property(player.sprite, "position:y", -12.0, 0.15)
	stand.tween_property(player.sprite, "position:y", -8.0, 0.15)
	var target := player.global_position + Vector2(24, 0)
	var walk_dir := "left" if target.x < guide.global_position.x else "right"
	if guide.has_method("play_if_exists"):
		guide.call("play_if_exists", "walk_" + walk_dir)
	var tween := create_tween()
	tween.tween_property(guide, "global_position", target, 1.6)
	await tween.finished
	if guide.has_method("face_towards"):
		guide.call("face_towards", player.global_position)
	player.facing = Vector2.RIGHT   # el jugador voltea a ver al guía


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


func _place_at_markers() -> void:
	## Coloca a cada personaje en el Marker2D del mapa que se llama igual (Map/Markers).
	## Para mover a alguien, mueve su marcador en world/map/town_map.tscn.
	var markers := get_node_or_null("Map/Markers")
	if markers == null:
		return
	for marker in markers.get_children():
		var target := get_node_or_null(NodePath("Entities/" + marker.name)) as Node2D
		if target == null:
			continue
		target.global_position = marker.global_position
		target.reset_physics_interpolation()


func _set_camera_limits() -> void:
	## La cámara no muestra nada fuera del suelo pintado.
	## Usa posiciones globales, así funciona aunque el nodo Map no esté en (0, 0).
	var camera: Camera2D = player.get_node("Camera2D")
	var used_rect := ground.get_used_rect()
	var half_tile := Vector2(ground.tile_set.tile_size) / 2.0
	var top_left := ground.to_global(ground.map_to_local(used_rect.position) - half_tile)
	var bottom_right := ground.to_global(ground.map_to_local(used_rect.end) - half_tile)
	camera.limit_left = int(top_left.x)
	camera.limit_top = int(top_left.y)
	camera.limit_right = int(bottom_right.x)
	camera.limit_bottom = int(bottom_right.y)
	camera.reset_smoothing()
	_add_map_edges(top_left, bottom_right)


func _add_map_edges(top_left: Vector2, bottom_right: Vector2) -> void:
	## Paredes invisibles en las orillas del mapa: nadie se sale aunque haya un hueco entre árboles.
	var edges := StaticBody2D.new()
	edges.name = "MapEdges"
	var sides := [
		[Vector2.RIGHT, top_left.x], [Vector2.LEFT, -bottom_right.x],
		[Vector2.DOWN, top_left.y + 8.0], [Vector2.UP, -bottom_right.y],
	]
	for side in sides:
		var shape := WorldBoundaryShape2D.new()
		shape.normal = side[0]
		shape.distance = side[1]
		var col := CollisionShape2D.new()
		col.shape = shape
		edges.add_child(col)
	add_child(edges)
