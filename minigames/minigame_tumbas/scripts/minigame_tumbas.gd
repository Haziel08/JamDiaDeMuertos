extends Node2D
## Minijuego del panteonero: limpiar varias tumbas antes de que se acabe el tiempo.
## Los bichitos NO se lastiman: al hacerles clic se van volando o caminando a otro lado
## (los reubicamos). Las hojas secas y las telarañas sí se quitan.

const MINIGAME_ID := "minigame_tumbas"
const SPRITES := "res://minigames/minigame_tumbas/sprites/"
const MUSIC := preload("res://minigames/minigame_tumbas/music/a_bit_of_hope.ogg")
const GRASS := preload("res://minigames/minigame_tumbas/sprites/pasto_cementerio.png")
const TOMBS := preload("res://minigames/minigame_tumbas/sprites/lapidas.png")
const STONE_BUTTON := preload("res://common/ui/stone_button.gd")
const PAUSE_ICON := preload("res://common/ui/botones/icono_pausa.png")
const PAUSE_ICON_PRESSED := preload("res://common/ui/botones/icono_pausa_presionado.png")

## Cada tipo de cosa que puede aparecer en la tumba.
##   frames: cuadros de animación en la imagen · scale: tamaño en pantalla
##   kind: "fly" (vuela en su lugar), "crawl" (camina despacito), "leaf" u "web" (basura)
const ITEMS := [
	{"file": "mariposa_naranja", "frames": 4, "scale": 2, "kind": "fly", "fps": 8.0},
	{"file": "mariposa_amarilla", "frames": 4, "scale": 2, "kind": "fly", "fps": 8.0},
	{"file": "mariposa_morada", "frames": 4, "scale": 2, "kind": "fly", "fps": 8.0},
	{"file": "mariposa_azul", "frames": 4, "scale": 2, "kind": "fly", "fps": 8.0},
	{"file": "monarca", "frames": 1, "scale": 1, "kind": "fly", "fps": 0.0},
	{"file": "abeja", "frames": 1, "scale": 1, "kind": "fly", "fps": 0.0},
	{"file": "libelula", "frames": 1, "scale": 1, "kind": "fly", "fps": 0.0},
	{"file": "catarina_roja", "frames": 2, "scale": 2, "kind": "crawl", "fps": 6.0},
	{"file": "escarabajo_amarillo", "frames": 2, "scale": 2, "kind": "crawl", "fps": 6.0},
	{"file": "arana_negra", "frames": 2, "scale": 1, "kind": "crawl", "fps": 6.0},
	{"file": "arana_cafe", "frames": 2, "scale": 1, "kind": "crawl", "fps": 6.0},
	{"file": "hormiga", "frames": 1, "scale": 1, "kind": "crawl", "fps": 0.0},
	{"file": "oruga", "frames": 1, "scale": 1, "kind": "crawl", "fps": 0.0},
	{"file": "hojas", "frames": 3, "scale": 2, "kind": "leaf", "fps": 0.0},
	{"file": "hojas", "frames": 3, "scale": 2, "kind": "leaf", "fps": 0.0},
	{"file": "telarana", "frames": 1, "scale": 1, "kind": "web", "fps": 0.0},
]
const BUG_MESSAGES := ["¡A salvo!", "¡Adiós, bichito!", "¡A su nueva casa!", "¡Con cuidado!"]
const TRASH_MESSAGES := ["¡Limpio!", "¡Fuera!", "¡Listo!"]

@export var total_tombs: int = 10
@export var time_limit: float = 60.0
@export var items_min: int = 8
@export var items_max: int = 12
@export var tomb_scale: int = 3
@export var dirty_color: Color = Color(0.72, 0.64, 0.55)

var _time_left: float
var _playing: bool = false
var _tombs_done: int = 0
var _items: Array[Dictionary] = []
var _items_total: int = 0
var _used_tombs: Array[int] = []
var _tomb: Sprite2D
var _tomb_image: Image
var _tomb_cell: Rect2i
var _textures := {}

var _timer_label: Label
var _tombs_label: Label
var _bar_fill: ColorRect
var _hint: Label
var _hint_tween: Tween
var _ui: CanvasLayer


func _ready() -> void:
	randomize()
	for item in ITEMS:
		if not _textures.has(item.file):
			_textures[item.file] = load(SPRITES + item.file + ".png")
	_tomb_image = TOMBS.get_image()
	_build_background()
	_build_ui()
	var music := MUSIC.duplicate() as AudioStreamOggVorbis
	music.loop = true
	AudioManager.play_music(music)
	_time_left = time_limit
	_update_ui()
	_next_tomb(true)
	_show_hint("Haz clic en los bichitos para reubicarlos\ny quita hojas y telarañas", 3.0)
	await get_tree().create_timer(2.2, false).timeout
	_playing = true


func _process(delta: float) -> void:
	_animate_items(delta)
	if not _playing:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_update_ui()
	if _time_left <= 0.0:
		_lose()


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local := make_input_local(event) as InputEventMouseButton
		var item := _item_at(local.position)
		if not item.is_empty():
			get_viewport().set_input_as_handled()
			_clean(item)


# ---------------------------------------------------------------- Tumbas

func _next_tomb(first: bool = false) -> void:
	## Saca una lápida distinta a las anteriores y le pone bichitos y basura al azar.
	var count := (TOMBS.get_width() / 32) * (TOMBS.get_height() / 48)
	var index := randi() % count
	while index in _used_tombs and _used_tombs.size() < count:
		index = randi() % count
	_used_tombs.append(index)
	_tomb_cell = Rect2i((index % 7) * 32, (index / 7) * 48, 32, 48)

	var atlas := AtlasTexture.new()
	atlas.atlas = TOMBS
	atlas.region = Rect2(_tomb_cell)
	_tomb = Sprite2D.new()
	_tomb.texture = atlas
	_tomb.centered = false
	_tomb.scale = Vector2.ONE * tomb_scale
	_tomb.modulate = dirty_color
	var target := Vector2(160 - 16 * tomb_scale, 172 - 48 * tomb_scale)
	_tomb.position = target if first else target + Vector2(0, -200)
	add_child(_tomb)
	if not first:
		var t := create_tween()
		t.tween_property(_tomb, "position", target, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await t.finished

	var amount := randi_range(items_min, items_max)
	_items_total = amount
	for i in amount:
		_spawn_item(ITEMS.pick_random(), i * 0.07)


func _spawn_item(def: Dictionary, delay: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _textures[def.file]
	sprite.hframes = def.frames
	sprite.frame = randi() % def.frames if def.kind == "leaf" else 0
	sprite.scale = Vector2.ZERO
	sprite.position = _random_spot(def.kind)
	if def.kind == "leaf":
		sprite.rotation = randf() * TAU
	add_child(sprite)
	var item := {
		"sprite": sprite, "def": def, "alive": true, "t": randf() * 10.0,
		"home": sprite.position, "target": sprite.position, "next_move": randf_range(0.5, 1.5),
		"radius": 6.0 * def.scale if def.scale == 2 else 9.0,
	}
	_items.append(item)
	var pop := create_tween()
	pop.tween_interval(delay)
	pop.tween_property(sprite, "scale", Vector2.ONE * def.scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _random_spot(kind: String) -> Vector2:
	## Un punto encima de la lápida (o, a veces, en el pasto junto a ella).
	if kind != "web" and randf() < 0.18:
		return _tomb.position + Vector2(randf_range(-24, 32 * tomb_scale + 24), 48 * tomb_scale - randf_range(0, 10))
	for attempt in 60:
		var px := Vector2i(randi_range(3, 28), randi_range(3, 44))
		if _tomb_image.get_pixelv(_tomb_cell.position + px).a > 0.5:
			return _tomb.position + Vector2(px) * tomb_scale
	return _tomb.position + Vector2(16, 30) * tomb_scale


func _clean(item: Dictionary) -> void:
	item.alive = false
	var sprite: Sprite2D = item.sprite
	var kind: String = item.def.kind
	AudioManager.play_sfx(AudioManager.UI_CLICK, 0.2)
	if kind == "leaf" or kind == "web":
		_float_text(sprite.position, TRASH_MESSAGES.pick_random())
	else:
		_float_text(sprite.position, BUG_MESSAGES.pick_random())
	var t := create_tween().set_parallel()
	match kind:
		"fly":   # se va volando hacia arriba, sin prisa
			var to := Vector2(sprite.position.x + randf_range(-120, 120), -30)
			t.tween_property(sprite, "position", to, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		"crawl":   # sale caminando rapidito hacia la orilla más cercana
			var side := -40.0 if sprite.position.x < 160 else 360.0
			var to := Vector2(side, sprite.position.y + randf_range(-20, 20))
			sprite.rotation = (to - sprite.position).angle() + PI / 2.0 if item.def.scale == 1 else 0.0
			sprite.flip_h = to.x > sprite.position.x and item.def.scale == 2
			t.tween_property(sprite, "position", to, 1.0)
		"leaf":   # el viento se la lleva
			t.tween_property(sprite, "position", sprite.position + Vector2(randf_range(30, 60), randf_range(-30, 10)), 0.5)
			t.tween_property(sprite, "rotation", sprite.rotation + randf_range(3, 6), 0.5)
			t.tween_property(sprite, "modulate:a", 0.0, 0.5)
		"web":
			t.tween_property(sprite, "scale", Vector2.ZERO, 0.25)
	t.chain().tween_callback(sprite.queue_free)

	var left := _items_left()
	_tomb.modulate = dirty_color.lerp(Color.WHITE, 1.0 - float(left) / _items_total)
	_update_ui()
	if left == 0:
		_tomb_finished()


func _tomb_finished() -> void:
	_tombs_done += 1
	_items = _items.filter(func(i): return i.alive)
	_sparkle(_tomb.position + Vector2(16, 24) * tomb_scale)
	var shine := create_tween()
	shine.tween_property(_tomb, "modulate", Color(1.6, 1.5, 1.2), 0.12)
	shine.tween_property(_tomb, "modulate", Color.WHITE, 0.25)
	_update_ui()
	if _tombs_done >= total_tombs:
		_win()
		return
	_show_hint("¡Tumba limpia!", 0.9)
	var old := _tomb
	await get_tree().create_timer(0.5, false).timeout
	var out := create_tween()
	out.tween_property(old, "position:y", 260.0, 0.35).set_ease(Tween.EASE_IN)
	out.tween_callback(old.queue_free)
	_next_tomb()


func _items_left() -> int:
	var n := 0
	for item in _items:
		if item.alive:
			n += 1
	return n


func _item_at(point: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for item in _items:
		if not item.alive:
			continue
		var d: float = item.sprite.position.distance_to(point)
		if d < item.radius + 3.0 and d < best_d:
			best = item
			best_d = d
	return best


func _animate_items(delta: float) -> void:
	for item in _items:
		if not item.alive:
			continue
		var sprite: Sprite2D = item.sprite
		var def: Dictionary = item.def
		item.t += delta
		if def.fps > 0.0:
			sprite.frame = int(item.t * def.fps) % def.frames
		match def.kind:
			"fly":
				sprite.position = item.home + Vector2(sin(item.t * 1.7) * 2.0, sin(item.t * 3.1) * 2.0)
				if def.frames == 1:   # aletea: se aplasta de lado
					sprite.scale.x = def.scale * (0.75 + 0.25 * absf(sin(item.t * 12.0)))
			"crawl":
				item.next_move -= delta
				if item.next_move <= 0.0:
					item.next_move = randf_range(0.8, 2.0)
					item.target = item.home + Vector2(randf_range(-10, 10), randf_range(-10, 10))
				var dir: Vector2 = item.target - sprite.position
				if dir.length() > 0.5:
					sprite.position += dir.normalized() * 7.0 * delta
					if def.scale == 1:
						sprite.rotation = lerp_angle(sprite.rotation, dir.angle() + PI / 2.0, 0.15)
					else:
						sprite.flip_h = dir.x > 0


# ---------------------------------------------------------------- Final

func _win() -> void:
	_playing = false
	_show_hint("¡Todas las tumbas quedaron limpias!", 2.5)
	await get_tree().create_timer(2.5, false).timeout
	GameState.complete_minigame(MINIGAME_ID)
	_back_to_map()


func _lose() -> void:
	_playing = false
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	dim.add_child(box)
	for text in ["¡Se acabó el tiempo!", "Limpiaste %d de %d tumbas" % [_tombs_done, total_tombs]]:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var retry := _stone_button("reintentar")
	retry.pressed.connect(func(): SceneManager.change_scene(scene_file_path))
	row.add_child(retry)
	var back := _stone_button("menu")
	back.pressed.connect(_back_to_map)
	row.add_child(back)
	AudioManager.add_button_sounds(layer)
	retry.grab_focus()


func _back_to_map() -> void:
	## Regresa al mapa abierto, donde se quedó el jugador.
	AudioManager.stop_music()
	SceneManager.go_to_world()


# ---------------------------------------------------------------- Construcción

func _build_background() -> void:
	var bg := Sprite2D.new()
	bg.texture = GRASS
	bg.centered = false
	bg.scale = Vector2(2, 2)
	bg.z_index = -10
	add_child(bg)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_tombs_label = Label.new()
	_tombs_label.position = Vector2(8, 4)
	_ui.add_child(_tombs_label)
	_timer_label = Label.new()
	_timer_label.position = Vector2(8, 16)
	_ui.add_child(_timer_label)

	var bar_bg := ColorRect.new()   # barra de avance total
	bar_bg.color = Color(0.13, 0.1, 0.08, 0.85)
	bar_bg.position = Vector2(110, 10)
	bar_bg.size = Vector2(100, 5)
	_ui.add_child(bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color("f6cd26")
	_bar_fill.position = Vector2(111, 11)
	_bar_fill.size = Vector2(0, 3)
	_ui.add_child(_bar_fill)

	var pause := TextureButton.new()
	pause.texture_normal = PAUSE_ICON
	pause.texture_pressed = PAUSE_ICON_PRESSED
	pause.set_script(STONE_BUTTON)
	pause.position = Vector2(320 - 38, 4)
	pause.focus_mode = Control.FOCUS_NONE
	pause.pressed.connect(func(): get_tree().call_group("pause_menu", "pause_game"))
	_ui.add_child(pause)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y = 34
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.05))
	_hint.modulate.a = 0.0
	_ui.add_child(_hint)


func _update_ui() -> void:
	var seconds := ceili(_time_left)
	_timer_label.text = "Tiempo %d:%02d" % [seconds / 60, seconds % 60]
	_timer_label.modulate = Color(1, 0.45, 0.4) if _time_left < 10.0 else Color.WHITE
	_tombs_label.text = "Tumbas %d/%d" % [_tombs_done, total_tombs]
	var current := 0.0
	if _items_total > 0 and _tombs_done < total_tombs:
		current = 1.0 - float(_items_left()) / _items_total
	_bar_fill.size.x = 98.0 * clampf((_tombs_done + current) / total_tombs, 0.0, 1.0)


func _stone_button(name_prefix: String) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load("res://common/ui/botones/%s.png" % name_prefix)
	b.texture_pressed = load("res://common/ui/botones/%s_presionado.png" % name_prefix)
	b.set_script(STONE_BUTTON)
	return b


func _float_text(at: Vector2, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = at + Vector2(-30, -16)
	label.size = Vector2(60, 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.05))
	label.z_index = 20
	add_child(label)
	var t := create_tween().set_parallel()
	t.tween_property(label, "position:y", label.position.y - 14, 0.8)
	t.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	t.chain().tween_callback(label.queue_free)


func _sparkle(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.amount = 24
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(40, 60)
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 30.0
	p.gravity = Vector2(0, 20)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color("f6cd26")
	p.z_index = 15
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _show_hint(text: String, seconds: float) -> void:
	_hint.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.2)
	_hint_tween.tween_interval(seconds)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.4)
