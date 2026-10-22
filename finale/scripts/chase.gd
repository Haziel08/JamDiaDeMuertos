extends Node2D
## Persecución final: el puente de cempasúchil se derrumba detrás del jugador
## y llegan huesos desde la oscuridad. La Muerte NO aparece: se revela hasta el final.
## Caer o quedarse sin vidas reinicia solo esta escena.

const TILE := 16
const ALTAR_SCENE := "res://finale/altar.tscn"

@export_group("Puente")
@export var bridge_length_tiles: int = 140      ## largo del puente (~45-60 s)
@export var bridge_height_tiles: int = 5        ## ancho del puente en tiles
@export var floor_source_id: int = 0            ## fuente del atlas en el TileSet
@export var floor_atlas_coords: Vector2i = Vector2i(2, 0)  ## tile de cempasúchil

@export_group("Derrumbe")
@export var collapse_delay: float = 2.5         ## segundos antes de que empiece a caerse
@export var collapse_speed_start: float = 36.0  ## px/s al inicio
@export var collapse_speed_end: float = 50.0    ## px/s cerca del final

@export_group("Huesos")
@export var max_lives: int = 3
@export var attack_interval_start: float = 2.2  ## segundos entre ataques al inicio
@export var attack_interval_end: float = 1.0    ## segundos entre ataques al final
@export var warning_time: float = 0.6           ## aviso rojo antes de cada ataque
@export var bone_speed: float = 140.0
@export var hit_radius: float = 7.0

@export_group("Audio")
@export var chase_music: AudioStream
@export var hit_sound: AudioStream

@onready var bridge: TileMapLayer = $Bridge
@onready var player: CharacterBody2D = $Entities/Player

var lives: int
var collapse_x: float = 0.0
var _collapsed_columns: int = 0
var _time: float = 0.0
var _next_attack: float = 0.0
var _invulnerable: bool = false
var _over: bool = false
var _end_x: float = 0.0
var _bones: Array[Node2D] = []
var _hearts: Array[ColorRect] = []
var _hint: Label
var _hint_tween: Tween


func _ready() -> void:
	lives = max_lives
	_end_x = bridge_length_tiles * TILE
	_build_void()
	_build_bridge()
	_build_walls()
	_build_ui()
	player.global_position = Vector2(TILE * 4, _bridge_height() / 2.0 + 8.0)
	_setup_camera()
	_next_attack = collapse_delay + 1.0
	if chase_music:
		AudioManager.play_music(chase_music)
	_show_hint("¡Corre hacia la luz!", 2.5)


func _physics_process(delta: float) -> void:
	if _over:
		return
	_time += delta
	var progress := clampf(player.global_position.x / _end_x, 0.0, 1.0)

	# El puente se derrumba detrás del jugador.
	if _time > collapse_delay:
		collapse_x += lerpf(collapse_speed_start, collapse_speed_end, progress) * delta
		_update_collapse()
	if player.global_position.x < collapse_x - 2.0:
		_fall()
		return
	if player.global_position.x >= _end_x:
		_win()
		return

	_move_bones(delta)

	if _time >= _next_attack:
		_next_attack = _time + lerpf(attack_interval_start, attack_interval_end, progress)
		_launch_attack(progress)


# ---------------------------------------------------------------- Ataques

func _launch_attack(progress: float) -> void:
	var options := ["aimed"]
	if progress > 0.25:
		options.append("rain")
	if progress > 0.5:
		options.append("wall")
	match options.pick_random():
		"aimed": _attack_aimed()
		"rain": _attack_rain()
		"wall": _attack_wall()


func _attack_aimed() -> void:
	## Un hueso desde atrás, directo hacia donde está el jugador.
	var from := Vector2(player.global_position.x - 180.0, randf_range(-20.0, _bridge_height() + 20.0))
	var direction := (_player_center() - from).normalized()
	await _warn([[from, from + direction * 420.0]])
	if _over:
		return
	_spawn_bone(from, direction * bone_speed)


func _attack_rain() -> void:
	## Tres huesos que caen desde arriba, delante del jugador.
	var segments := []
	var xs: Array[float] = []
	for i in 3:
		var x := player.global_position.x + randf_range(24.0, 150.0)
		xs.append(x)
		segments.append([Vector2(x, -8.0), Vector2(x, _bridge_height() + 8.0)])
	await _warn(segments)
	if _over:
		return
	for x in xs:
		_spawn_bone(Vector2(x, -110.0), Vector2(0.0, bone_speed))


func _attack_wall() -> void:
	## Una fila de huesos desde atrás que cubre el puente, con un hueco de 2 tiles.
	var gap := randi_range(0, bridge_height_tiles - 2)
	var left := player.global_position.x - 170.0
	var segments := []
	var ys: Array[float] = []
	for row in bridge_height_tiles:
		if row == gap or row == gap + 1:
			continue
		var y := row * TILE + TILE / 2.0
		ys.append(y)
		segments.append([Vector2(left + 12.0, y), Vector2(left + 40.0, y)])
	await _warn(segments)
	if _over:
		return
	for y in ys:
		_spawn_bone(Vector2(left, y), Vector2(bone_speed * 0.85, 0.0))


func _warn(segments: Array) -> void:
	## Dibuja líneas rojas de aviso y espera warning_time.
	var lines: Array[Line2D] = []
	for segment in segments:
		var line := Line2D.new()
		line.points = PackedVector2Array([segment[0], segment[1]])
		line.width = 1.0
		line.default_color = Color(0.85, 0.2, 0.25, 0.75)
		add_child(line)
		lines.append(line)
		var blink := create_tween().set_loops(3)
		blink.tween_property(line, "modulate:a", 0.2, warning_time / 6.0)
		blink.tween_property(line, "modulate:a", 1.0, warning_time / 6.0)
	await get_tree().create_timer(warning_time, false).timeout
	for line in lines:
		if is_instance_valid(line):
			line.queue_free()


func _spawn_bone(at: Vector2, velocity: Vector2) -> void:
	var bone := Node2D.new()
	bone.position = at
	bone.rotation = velocity.angle()
	bone.set_meta("velocity", velocity)
	bone.set_meta("life", 4.0)
	var visual := ColorRect.new()  # Hueso temporal; reemplazar por un Sprite2D con el arte.
	visual.color = Color("e8e2d0")
	visual.size = Vector2(12, 4)
	visual.position = Vector2(-6, -2)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bone.add_child(visual)
	$Entities.add_child(bone)
	_bones.append(bone)


func _move_bones(delta: float) -> void:
	var center := _player_center()
	for bone in _bones.duplicate():
		bone.position += bone.get_meta("velocity") * delta
		var life: float = bone.get_meta("life") - delta
		bone.set_meta("life", life)
		if life <= 0.0:
			_bones.erase(bone)
			bone.queue_free()
		elif bone.global_position.distance_to(center) < hit_radius:
			_bones.erase(bone)
			bone.queue_free()
			_hurt()


# ---------------------------------------------------------------- Vida, caída, victoria

func _hurt() -> void:
	if _invulnerable or _over:
		return
	lives -= 1
	_update_hearts()
	if hit_sound:
		AudioManager.play_sfx(hit_sound)
	if lives <= 0:
		_over = true
		player.can_move = false
		_restart("¡Te alcanzó!")
		return
	_invulnerable = true
	var blink := create_tween().set_loops(5)
	blink.tween_property(player, "modulate:a", 0.2, 0.1)
	blink.tween_property(player, "modulate:a", 1.0, 0.1)
	await blink.finished
	_invulnerable = false


func _fall() -> void:
	_over = true
	player.can_move = false
	var shrink := create_tween().set_parallel()
	shrink.tween_property(player, "scale", Vector2(0.2, 0.2), 0.5)
	shrink.tween_property(player, "modulate:a", 0.0, 0.5)
	await shrink.finished
	_restart("¡Caíste!")


func _restart(message: String) -> void:
	_show_hint(message, 1.2)
	await get_tree().create_timer(1.2, false).timeout
	SceneManager.change_scene(scene_file_path)  # reinicia solo la persecución


func _win() -> void:
	_over = true
	player.can_move = false
	for bone in _bones:
		bone.queue_free()
	_bones.clear()
	SceneManager.change_scene(ALTAR_SCENE)


# ---------------------------------------------------------------- Construcción

func _build_void() -> void:
	var void_rect := ColorRect.new()  # el vacío bajo el puente
	void_rect.color = Color("0b0714")
	void_rect.position = Vector2(-400, -400)
	void_rect.size = Vector2(_end_x + 800, _bridge_height() + 800)
	void_rect.z_index = -10
	void_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(void_rect)

	var goal := ColorRect.new()  # la luz al final del puente
	goal.color = Color(0.95, 0.78, 0.3, 0.55)
	goal.position = Vector2(_end_x, -8)
	goal.size = Vector2(48, _bridge_height() + 16)
	goal.z_index = -5
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(goal)


func _build_bridge() -> void:
	bridge.clear()
	for x in bridge_length_tiles + 3:
		for y in bridge_height_tiles:
			bridge.set_cell(Vector2i(x, y), floor_source_id, floor_atlas_coords)


func _build_walls() -> void:
	## Bordes invisibles: arriba, abajo y atrás del puente.
	var walls := StaticBody2D.new()
	var length := _end_x + 128.0
	var rects := [
		Rect2(-64, -8, length, 8),                     # arriba
		Rect2(-64, _bridge_height(), length, 8),       # abajo
		Rect2(-8, -8, 8, _bridge_height() + 16),       # inicio
	]
	for r in rects:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = r.size
		shape.shape = box
		shape.position = r.position + r.size / 2.0
		walls.add_child(shape)
	add_child(walls)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	var hearts_box := HBoxContainer.new()
	hearts_box.position = Vector2(6, 6)
	hearts_box.add_theme_constant_override("separation", 3)
	ui.add_child(hearts_box)
	for i in max_lives:
		var heart := ColorRect.new()  # corazón temporal; reemplazar por un ícono
		heart.custom_minimum_size = Vector2(7, 7)
		hearts_box.add_child(heart)
		_hearts.append(heart)
	_update_hearts()

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y = 20
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.modulate.a = 0.0
	ui.add_child(_hint)


func _setup_camera() -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	var center_y := int(_bridge_height() / 2.0)
	camera.limit_left = -TILE * 2
	camera.limit_right = int(_end_x) + 64
	camera.limit_top = center_y - 90
	camera.limit_bottom = center_y + 90
	camera.reset_smoothing()


func _update_collapse() -> void:
	var target := mini(floori(collapse_x / TILE), bridge_length_tiles)
	while _collapsed_columns < target:
		for y in bridge_height_tiles:
			var cell := Vector2i(_collapsed_columns, y)
			_spawn_falling_tile(cell)
			bridge.erase_cell(cell)
		_collapsed_columns += 1


func _spawn_falling_tile(cell: Vector2i) -> void:
	var source := bridge.tile_set.get_source(floor_source_id) as TileSetAtlasSource
	if source == null:
		return
	var piece := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = source.texture
	atlas.region = source.get_tile_texture_region(floor_atlas_coords)
	piece.texture = atlas
	piece.position = bridge.map_to_local(cell)
	piece.z_index = -1
	add_child(piece)
	var drop := create_tween().set_parallel()
	drop.tween_property(piece, "position:y", piece.position.y + 24.0, 0.6)
	drop.tween_property(piece, "scale", Vector2(0.4, 0.4), 0.6)
	drop.tween_property(piece, "modulate:a", 0.0, 0.6)
	drop.chain().tween_callback(piece.queue_free)


func _update_hearts() -> void:
	for i in _hearts.size():
		_hearts[i].color = Color("d94a4a") if i < lives else Color("3b2a4a")


func _show_hint(text: String, seconds: float) -> void:
	_hint.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.2)
	_hint_tween.tween_interval(seconds)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.4)


func _bridge_height() -> float:
	return bridge_height_tiles * TILE


func _player_center() -> Vector2:
	return player.global_position + Vector2(0, -8)  # el origen del jugador está en sus pies
