extends Node2D
## Persecución final: todo está oscuro y solo alumbran las luces que lleva el jugador.
## El puente de cempasúchil (con curvas) se derrumba detrás de él; algunos pedazos de
## adelante también se caen al azar, pero NUNCA el centro del camino: siempre hay paso.
## Caer al vacío reinicia solo esta escena. Llegar al portal dorado lleva al altar.

const TILE := 16
const ALTAR_SCENE := "res://finale/altar.tscn"
const FLOOR_TEXTURE := preload("res://finale/sprites/puente_cempasuchil.png")
const GATE_FRAMES := preload("res://world/npcs/sprites/porton_frames.tres")
const PETALS := preload("res://menus/main_menu/petalos.png")

# Tiles del atlas (ver finale/sprites/puente_cempasuchil.png)
const T_TL := Vector2i(0, 0); const T_T := Vector2i(1, 0); const T_TR := Vector2i(2, 0)
const T_L := Vector2i(0, 1); const T_C := Vector2i(1, 1); const T_R := Vector2i(2, 1)
const T_BL := Vector2i(0, 2); const T_B := Vector2i(1, 2); const T_BR := Vector2i(2, 2)
const T_VAR_A := Vector2i(3, 0); const T_VAR_B := Vector2i(3, 1); const T_CRACK := Vector2i(3, 2)
const T_IN_TL := Vector2i(0, 3); const T_IN_TR := Vector2i(1, 3)
const T_IN_BL := Vector2i(2, 3); const T_IN_BR := Vector2i(3, 3)

@export_group("Camino")
@export var path_steps: int = 170              ## largo del camino (pasos del centro)
@export var path_width: int = 3                ## ancho en tiles (impar)
@export var min_straight: int = 6
@export var max_straight: int = 13
@export var min_turn: int = 3
@export var max_turn: int = 7

@export_group("Derrumbe")
@export var collapse_delay: float = 2.5         ## segundos antes de que empiece
@export var collapse_speed_start: float = 3.05  ## tiles por segundo al inicio
@export var collapse_speed_end: float = 3.6     ## tiles por segundo al final (el jugador va a 3.75)
@export var random_drop_every: Vector2 = Vector2(0.7, 1.4)  ## segundos entre caídas al azar
@export var crack_warning: float = 0.8          ## segundos que se ve agrietado antes de caer
@export var linger_limit: float = 0.9           ## si te quedas parado más que esto en un tile, se agrieta
@export var linger_chance: float = 0.75         ## probabilidad de que ese tile se caiga (0 a 1)

@export_group("Luz")
@export var darkness: Color = Color(0.05, 0.04, 0.08)
@export var light_scale: float = 1.15           ## tamaño del círculo de luz del jugador

@export_group("Audio")
@export var chase_music: AudioStream = preload("res://finale/music/fight_or_flight.ogg")
@export var fall_sound: AudioStream

@onready var bridge: TileMapLayer = $Bridge
@onready var player: CharacterBody2D = $Entities/Player

var _cells := {}          # Vector2i -> índice a lo largo del camino
var _center := {}         # celdas del centro (nunca se caen al azar)
var _centerline: Array[Vector2i] = []
var _cracking := {}       # celdas que ya van a caer
var _front: float = 0.0   # todo lo que tenga índice menor que esto ya se cayó
var _time: float = 0.0
var _next_drop: float = 0.0
var _stand_cell := Vector2i(-99999, -99999)   # tile donde está parado ahora
var _stand_time: float = 0.0                  # cuánto tiempo lleva en ese tile
var _over: bool = false
var _hint: Label
var _progress: ColorRect
var _light: PointLight2D
var _motes: Array[Sprite2D] = []


func _ready() -> void:
	randomize()
	_build_tileset()
	_generate_path()
	_paint_all()
	_build_darkness()
	_build_goal()
	_build_petals()
	_build_ui()
	player.global_position = bridge.map_to_local(_centerline[1]) + Vector2(0, 6)
	player.reset_physics_interpolation()
	_setup_camera()
	_next_drop = collapse_delay + 2.0
	if chase_music:
		var music: AudioStream = chase_music.duplicate()
		if music is AudioStreamOggVorbis:
			(music as AudioStreamOggVorbis).loop = true
		AudioManager.play_music(music)
	_show_hint("¡Corre! El puente se está cayendo", 3.0)


func _physics_process(delta: float) -> void:
	if _over:
		return
	_time += delta
	_animate_light()

	var player_cell := _standing_cell()
	if player_cell == Vector2i(-99999, -99999):
		_fall()
		return
	var player_index: int = _cells[player_cell]
	_check_linger(player_cell, delta)
	_progress.size.x = 100.0 * float(player_index) / float(_centerline.size() - 1)
	if player_index >= _centerline.size() - 3:
		_win()
		return

	if _time > collapse_delay:
		var progress := float(player_index) / _centerline.size()
		_front += lerpf(collapse_speed_start, collapse_speed_end, progress) * delta
		_collapse_up_to(_front)

	if _time >= _next_drop:
		_next_drop = _time + randf_range(random_drop_every.x, random_drop_every.y)
		_random_drop(player_index)


func _standing_cell() -> Vector2i:
	## Celda del puente donde está parado. Es un poco permisivo: si medio pie sigue
	## sobre las flores, no se cae.
	for offset in [Vector2.ZERO, Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4)]:
		var cell := bridge.local_to_map(bridge.to_local(player.global_position + offset))
		if _cells.has(cell):
			return cell
	return Vector2i(-99999, -99999)


# ---------------------------------------------------------------- Camino

func _generate_path() -> void:
	## Camino con curvas: tramos rectos hacia la derecha y vueltas hacia arriba o abajo.
	var p := Vector2i(0, 0)
	var y_limit := 9
	_centerline.append(p)
	# plataforma de inicio
	for i in 4:
		p.x += 1
		_centerline.append(p)
	var horizontal := true
	while _centerline.size() < path_steps:
		if horizontal:
			for i in randi_range(min_straight, max_straight):
				p.x += 1
				_centerline.append(p)
		else:
			var dir := 1 if randf() < 0.5 else -1
			if p.y + dir * min_turn > y_limit or p.y + dir * min_turn < -y_limit:
				dir = -dir
			for i in randi_range(min_turn, max_turn):
				if absi(p.y + dir) > y_limit:
					break
				p.y += dir
				_centerline.append(p)
		horizontal = not horizontal
	# tramo final recto hacia el portal
	for i in 6:
		p.x += 1
		_centerline.append(p)

	var half := path_width / 2
	for i in _centerline.size():
		var c := _centerline[i]
		_center[c] = true
		for dx in range(-half, half + 1):
			for dy in range(-half, half + 1):
				var cell := c + Vector2i(dx, dy)
				if not _cells.has(cell) or _cells[cell] > i:
					_cells[cell] = i
	# plataformas más anchas al inicio y al final
	for i in [0, _centerline.size() - 2]:
		var c := _centerline[i]
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var cell := c + Vector2i(dx, dy)
				if not _cells.has(cell):
					_cells[cell] = i


func _paint_all() -> void:
	bridge.clear()
	for cell in _cells:
		bridge.set_cell(cell, 0, _tile_for(cell))


func _tile_for(cell: Vector2i) -> Vector2i:
	## Escoge orilla, esquina o centro según qué vecinos siguen en pie.
	if _cracking.has(cell):
		return T_CRACK
	var n := _cells.has(cell + Vector2i.UP)
	var s := _cells.has(cell + Vector2i.DOWN)
	var w := _cells.has(cell + Vector2i.LEFT)
	var e := _cells.has(cell + Vector2i.RIGHT)
	if not n and not w: return T_TL
	if not n and not e: return T_TR
	if not s and not w: return T_BL
	if not s and not e: return T_BR
	if not n: return T_T
	if not s: return T_B
	if not w: return T_L
	if not e: return T_R
	if not _cells.has(cell + Vector2i(-1, -1)): return T_IN_TL
	if not _cells.has(cell + Vector2i(1, -1)): return T_IN_TR
	if not _cells.has(cell + Vector2i(-1, 1)): return T_IN_BL
	if not _cells.has(cell + Vector2i(1, 1)): return T_IN_BR
	var h := absi(cell.x * 73856093 ^ cell.y * 19349663) % 7
	return T_VAR_A if h == 0 else (T_VAR_B if h == 1 else T_C)


func _retile_around(cell: Vector2i) -> void:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := cell + Vector2i(dx, dy)
			if _cells.has(c):
				bridge.set_cell(c, 0, _tile_for(c))


# ---------------------------------------------------------------- Derrumbe

func _collapse_up_to(front: float) -> void:
	## Todo lo que quedó atrás del frente se agrieta y luego cae.
	for cell in _cells.keys():
		var index: int = _cells[cell]
		if index < front and not _cracking.has(cell):
			_crack_then_drop(cell, 0.25)
		elif index < front + 2.0 and not _cracking.has(cell) and randf() < 0.02:
			_crack_then_drop(cell, 0.6)


func _check_linger(cell: Vector2i, delta: float) -> void:
	## Si el jugador se queda mucho tiempo en el mismo tile, puede que se le caiga debajo.
	if cell != _stand_cell:
		_stand_cell = cell
		_stand_time = 0.0
		return
	_stand_time += delta
	if _stand_time >= linger_limit and not _cracking.has(cell) and _cells[cell] > 1:
		_stand_time = -9999.0   # solo se decide una vez por tile
		if randf() < linger_chance:
			_crack_then_drop(cell, 0.55)


func _random_drop(player_index: int) -> void:
	## Agujeros al azar más adelante, solo en las orillas (el centro siempre queda).
	var candidates: Array[Vector2i] = []
	for cell in _cells:
		var index: int = _cells[cell]
		if index > player_index + 5 and index < player_index + 22 and not _center.has(cell) \
				and not _cracking.has(cell) and index < _centerline.size() - 6:
			candidates.append(cell)
	if candidates.is_empty():
		return
	var first: Vector2i = candidates.pick_random()
	_crack_then_drop(first, crack_warning)
	# a veces cae un pedacito de 2
	for d in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var other: Vector2i = first + d
		if randf() < 0.35 and _cells.has(other) and not _center.has(other) and not _cracking.has(other):
			_crack_then_drop(other, crack_warning)
			break


func _crack_then_drop(cell: Vector2i, wait: float) -> void:
	_cracking[cell] = true
	bridge.set_cell(cell, 0, T_CRACK)
	await get_tree().create_timer(wait, false).timeout
	if _over or not _cells.has(cell):
		return
	_cells.erase(cell)
	_cracking.erase(cell)
	bridge.erase_cell(cell)
	_retile_around(cell)
	_spawn_falling_piece(cell)


func _spawn_falling_piece(cell: Vector2i) -> void:
	var piece := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	for f in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = FLOOR_TEXTURE
		atlas.region = Rect2(f * TILE, 4 * TILE, TILE, TILE)
		frames.add_frame("default", atlas)
	frames.set_animation_speed("default", 8.0)
	frames.set_animation_loop("default", false)
	piece.sprite_frames = frames
	piece.position = bridge.map_to_local(cell)
	piece.z_index = -1
	add_child(piece)
	piece.play()
	var drop := create_tween()
	drop.tween_property(piece, "position:y", piece.position.y + 20.0, 0.5).set_ease(Tween.EASE_IN)
	drop.tween_callback(piece.queue_free)
	if fall_sound and piece.position.distance_to(player.global_position) < 120.0:
		AudioManager.play_sfx(fall_sound, 0.1)


# ---------------------------------------------------------------- Final

func _fall() -> void:
	_over = true
	player.can_move = false
	var t := create_tween().set_parallel()
	t.tween_property(player, "scale", Vector2(0.2, 0.2), 0.6)
	t.tween_property(player, "position:y", player.position.y + 24.0, 0.6)
	t.tween_property(player, "modulate:a", 0.0, 0.6)
	t.tween_property(_light, "energy", 0.0, 0.6)
	_show_hint("Te caíste… inténtalo otra vez", 1.6)
	await get_tree().create_timer(1.6, false).timeout
	SceneManager.change_scene(scene_file_path)   # reinicia solo la persecución


func _win() -> void:
	_over = true
	player.can_move = false
	var t := create_tween()
	t.tween_property(_light, "texture_scale", light_scale * 4.0, 1.2)
	_show_hint("…", 1.0)
	await t.finished
	SceneManager.change_scene(ALTAR_SCENE)


# ---------------------------------------------------------------- Construcción

func _build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = FLOOR_TEXTURE
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	for y in 4:
		for x in 4:
			src.create_tile(Vector2i(x, y))
	bridge.tile_set = ts


func _build_darkness() -> void:
	var void_rect := ColorRect.new()   # el vacío debajo del puente
	void_rect.color = Color(0.03, 0.02, 0.05)
	void_rect.position = Vector2(-2000, -2000)
	void_rect.size = Vector2(8000, 4000)
	void_rect.z_index = -100
	void_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(void_rect)
	var dark := CanvasModulate.new()
	dark.color = darkness
	add_child(dark)
	# Luz del jugador: las luces que juntó lo rodean y alumbran un pedazo del camino.
	_light = PointLight2D.new()
	_light.texture = _radial_texture(128, Color(1.0, 0.86, 0.6))
	_light.texture_scale = light_scale
	_light.energy = 1.25
	_light.position = Vector2(0, -8)
	player.add_child(_light)
	for i in 3:
		var mote := Sprite2D.new()
		mote.texture = _radial_texture(6, Color(1.0, 0.85, 0.4))
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # brillan aunque esté oscuro
		mote.material = mat
		player.add_child(mote)
		_motes.append(mote)


func _animate_light() -> void:
	var t := _time
	_light.energy = 1.2 + 0.08 * sin(t * 7.0) + 0.05 * sin(t * 13.0)   # parpadeo de vela
	for i in _motes.size():
		var a := t * 2.2 + i * TAU / 3.0
		_motes[i].position = Vector2(cos(a) * 11.0, -10.0 + sin(a) * 5.0)
		_motes[i].z_index = 1 if sin(a) > 0.0 else -1


func _build_goal() -> void:
	## Portal dorado al final del camino, con su propia luz.
	var end := _centerline[_centerline.size() - 1]
	var gate := AnimatedSprite2D.new()
	gate.sprite_frames = GATE_FRAMES
	gate.position = bridge.map_to_local(end) + Vector2(0, -20)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	gate.material = mat
	add_child(gate)
	gate.play("open")
	var glow := PointLight2D.new()
	glow.texture = _radial_texture(128, Color(1.0, 0.75, 0.35))
	glow.texture_scale = 1.6
	glow.energy = 1.4
	glow.position = gate.position
	add_child(glow)


func _build_petals() -> void:
	## Pétalos que flotan cerca del jugador (se ven solo dentro de la luz).
	var p := CPUParticles2D.new()
	p.texture = PETALS
	var mat := CanvasItemMaterial.new()
	mat.particles_animation = true
	mat.particles_anim_h_frames = 3
	mat.particles_anim_v_frames = 1
	p.material = mat
	p.amount = 24
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(170, 100)
	p.gravity = Vector2(-6, 6)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 8.0
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	p.angle_max = 360.0
	p.anim_offset_max = 1.0
	p.local_coords = false
	player.add_child(p)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.2, 0.11, 0.09, 0.8)
	bar_bg.position = Vector2(110, 8)
	bar_bg.size = Vector2(100, 3)
	ui.add_child(bar_bg)
	_progress = ColorRect.new()
	_progress.color = Color("f6cd26")
	_progress.position = Vector2(110, 8)
	_progress.size = Vector2(0, 3)
	ui.add_child(_progress)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y = 16
	_hint.modulate.a = 0.0
	ui.add_child(_hint)


func _setup_camera() -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	var used := bridge.get_used_rect()
	camera.limit_left = used.position.x * TILE - 96
	camera.limit_right = used.end.x * TILE + 96
	camera.limit_top = used.position.y * TILE - 96
	camera.limit_bottom = used.end.y * TILE + 96
	camera.reset_smoothing()


func _show_hint(text: String, seconds: float) -> void:
	_hint.text = text
	var t := create_tween()
	t.tween_property(_hint, "modulate:a", 1.0, 0.2)
	t.tween_interval(seconds)
	t.tween_property(_hint, "modulate:a", 0.0, 0.4)


func _radial_texture(size: int, color: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	g.add_point(0.45, Color(color.r, color.g, color.b, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex
