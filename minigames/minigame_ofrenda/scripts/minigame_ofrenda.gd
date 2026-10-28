extends Node2D
## Minijuego del panadero: atrapar la comida con la canasta antes de que toque el suelo.
## Dura lo que dura la canción y tiene 5 fases: cada fase cae más rápido y más seguido.
## 3 vidas: cada comida que se cae quita una. Si aguantas hasta el final de la canción, ganas.

const MINIGAME_ID := "minigame_ofrenda"
const MUSIC := preload("res://minigames/minigame_ofrenda/music/boneyard_bash.ogg")
const BACKGROUND := preload("res://minigames/minigame_ofrenda/sprites/fondo_piso.png")
const FOODS := preload("res://minigames/minigame_ofrenda/sprites/comidas.png")   # 5 comidas de 16×16
const BASKET := preload("res://minigames/minigame_ofrenda/sprites/canasta.png")
const HERO_FRAMES := preload("res://player/sprites/protagonista_frames.tres")
const HEART_FULL := preload("res://common/ui/corazon_lleno.png")
const HEART_EMPTY := preload("res://common/ui/corazon_vacio.png")
const STONE_BUTTON := preload("res://common/ui/stone_button.gd")
const PAUSE_ICON := preload("res://common/ui/botones/icono_pausa.png")
const PAUSE_ICON_PRESSED := preload("res://common/ui/botones/icono_pausa_presionado.png")

const GROUND_Y := 172.0      # donde están los pies del jugador
const FOOD_COUNT := 5

## Una fila por fase: velocidad de caída (px/s), segundos entre comidas,
## probabilidad de que caigan 2 juntas y cuánto se balancean de lado.
const PHASES := [
	{"speed": 42.0, "every": 1.35, "double": 0.0, "sway": 0.0},
	{"speed": 56.0, "every": 1.1, "double": 0.1, "sway": 0.0},
	{"speed": 70.0, "every": 0.9, "double": 0.2, "sway": 6.0},
	{"speed": 84.0, "every": 0.78, "double": 0.25, "sway": 8.0},
	{"speed": 100.0, "every": 0.65, "double": 0.35, "sway": 12.0},
]

@export var max_lives: int = 3
@export var player_speed: float = 140.0

var _lives: int
var _caught: int = 0
var _phase: int = -1
var _duration: float
var _elapsed: float = 0.0
var _next_food: float = 0.0
var _playing: bool = false
var _foods: Array[Dictionary] = []
var _last_x: float = 160.0   # dónde cayó la comida anterior (la siguiente siempre se alcanza)

var _player: Node2D
var _hero: AnimatedSprite2D
var _basket: Sprite2D
var _hearts: Array[TextureRect] = []
var _phase_label: Label
var _score_label: Label
var _bar_fill: ColorRect
var _hint: Label
var _hint_tween: Tween


func _ready() -> void:
	randomize()
	_lives = max_lives
	_duration = MUSIC.get_length()   # el juego dura lo mismo que la canción
	_build_scene()
	_build_ui()
	var music := MUSIC.duplicate() as AudioStreamOggVorbis
	music.loop = false
	AudioManager.play_music(music, 0.2)
	_show_hint("Mueve la canasta con las flechas o con A y D\n¡Que no se caiga la comida!", 2.6)
	await get_tree().create_timer(2.4, false).timeout
	_playing = true
	_set_phase(0)


func _process(delta: float) -> void:
	_update_foods(delta)
	if not _playing:
		_hero.play("idle_down")
		return
	_move_player(delta)
	_elapsed += delta
	var phase := mini(int(_elapsed / (_duration / PHASES.size())), PHASES.size() - 1)
	if phase != _phase:
		_set_phase(phase)
	_next_food -= delta
	if _next_food <= 0.0:
		var p: Dictionary = PHASES[_phase]
		var wait: float = p.every * randf_range(0.85, 1.2)
		_next_food = wait
		_spawn_food(wait)
		if randf() < p.double:
			_spawn_food(36.0 / p.speed, -36.0)   # una segunda, un poco más arriba
	_bar_fill.size.x = 98.0 * clampf(_elapsed / _duration, 0.0, 1.0)
	if _elapsed >= _duration:
		_win()


# ---------------------------------------------------------------- Jugador

func _move_player(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	_player.position.x = clampf(_player.position.x + dir * player_speed * delta, 18.0, 302.0)
	if dir < 0.0:
		_hero.play("walk_left")
	elif dir > 0.0:
		_hero.play("walk_right")
	else:
		_hero.play("idle_down")
	# la canasta se mece un poquito al caminar
	_basket.rotation = lerpf(_basket.rotation, dir * 0.08, 0.2)


# ---------------------------------------------------------------- Comida

func _spawn_food(time_since_last: float, extra_y: float = 0.0) -> void:
	## Nunca pone la comida tan lejos que sea imposible llegar a tiempo.
	var reach := player_speed * time_since_last * 0.7
	var x := clampf(_last_x + randf_range(-reach, reach), 20.0, 300.0)
	_last_x = x
	var sprite := Sprite2D.new()
	sprite.texture = FOODS
	sprite.hframes = FOOD_COUNT
	sprite.frame = randi() % FOOD_COUNT
	sprite.position = Vector2(x, -10.0 + extra_y)
	add_child(sprite)
	var p: Dictionary = PHASES[_phase]
	_foods.append({
		"sprite": sprite, "speed": p.speed * randf_range(0.9, 1.1), "sway": p.sway,
		"base_x": sprite.position.x, "t": randf() * TAU, "spin": randf_range(-2.0, 2.0), "alive": true,
	})


func _update_foods(delta: float) -> void:
	var basket_top := _player.position.y - 30.0
	for food in _foods:
		if not food.alive:
			continue
		var sprite: Sprite2D = food.sprite
		food.t += delta
		var prev_y := sprite.position.y
		sprite.position.y += food.speed * delta
		sprite.position.x = clampf(food.base_x + sin(food.t * 2.5) * food.sway, 10.0, 310.0)
		sprite.rotation += food.spin * delta
		if not _playing:
			continue
		if sprite.position.y >= basket_top - 8.0 \
				and absf(sprite.position.x - _player.position.x) <= 26.0:
			_catch(food)
		elif sprite.position.y >= GROUND_Y - 4.0:
			_drop(food)
	_foods = _foods.filter(func(f): return f.alive)


func _catch(food: Dictionary) -> void:
	food.alive = false
	_caught += 1
	_score_label.text = "Comida %d" % _caught
	AudioManager.play_sfx(AudioManager.UI_CLICK, 0.2)
	var sprite: Sprite2D = food.sprite
	var t := create_tween().set_parallel()
	t.tween_property(sprite, "position", Vector2(_player.position.x, _player.position.y - 28.0), 0.1)
	t.tween_property(sprite, "scale", Vector2(0.3, 0.3), 0.15)
	t.chain().tween_callback(sprite.queue_free)
	var bounce := create_tween()   # la canasta "recibe" la comida
	bounce.tween_property(_basket, "position:y", -26.0, 0.06)
	bounce.tween_property(_basket, "position:y", -28.0, 0.1)


func _drop(food: Dictionary) -> void:
	## Se cayó al suelo: se aplasta, se desvanece y quita una vida.
	food.alive = false
	var sprite: Sprite2D = food.sprite
	sprite.rotation = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(sprite, "scale", Vector2(1.4, 0.5), 0.12)
	t.tween_property(sprite, "modulate:a", 0.0, 0.6).set_delay(0.3)
	t.chain().tween_callback(sprite.queue_free)
	_lose_life()


func _lose_life() -> void:
	_lives -= 1
	_update_hearts()
	var shake := create_tween()
	for i in 4:
		shake.tween_property(self, "position:x", 2.0 if i % 2 == 0 else -2.0, 0.04)
	shake.tween_property(self, "position:x", 0.0, 0.04)
	if _lives <= 0:
		_lose()


func _set_phase(phase: int) -> void:
	_phase = phase
	_phase_label.text = "Fase %d/%d" % [phase + 1, PHASES.size()]
	_show_hint("Fase %d" % (phase + 1) if phase > 0 else "¡Fase 1!", 1.0)


# ---------------------------------------------------------------- Final

func _win() -> void:
	_playing = false
	_show_hint("¡Lo lograste! Atrapaste %d comidas" % _caught, 2.5)
	await get_tree().create_timer(2.6, false).timeout
	GameState.complete_minigame(MINIGAME_ID)
	_back_to_map()


func _lose() -> void:
	_playing = false
	AudioManager.stop_music(1.0)
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
	for text in ["¡Se cayó demasiada comida!", "Llegaste a la fase %d y atrapaste %d" % [_phase + 1, _caught]]:
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

func _build_scene() -> void:
	var bg := Sprite2D.new()
	bg.texture = BACKGROUND
	bg.centered = false
	bg.z_index = -10
	add_child(bg)
	_player = Node2D.new()
	_player.position = Vector2(160, GROUND_Y)
	add_child(_player)
	_hero = AnimatedSprite2D.new()
	_hero.sprite_frames = HERO_FRAMES
	_hero.position = Vector2(0, -8)
	_hero.play("idle_down")
	_player.add_child(_hero)
	_basket = Sprite2D.new()   # la canasta va arriba de la cabeza
	_basket.texture = BASKET
	_basket.position = Vector2(0, -28)
	_player.add_child(_basket)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var hearts := HBoxContainer.new()   # vidas arriba a la izquierda
	hearts.position = Vector2(4, 4)
	hearts.add_theme_constant_override("separation", 2)
	ui.add_child(hearts)
	for i in max_lives:
		var heart := TextureRect.new()
		heart.texture = HEART_FULL
		hearts.add_child(heart)
		_hearts.append(heart)
	_score_label = Label.new()
	_score_label.text = "Comida 0"
	_score_label.position = Vector2(6, 22)
	ui.add_child(_score_label)

	_phase_label = Label.new()
	_phase_label.position = Vector2(110, 14)
	_phase_label.size = Vector2(100, 12)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(_phase_label)
	var bar_bg := ColorRect.new()   # avance de la canción
	bar_bg.color = Color(0.13, 0.1, 0.08, 0.85)
	bar_bg.position = Vector2(110, 8)
	bar_bg.size = Vector2(100, 5)
	ui.add_child(bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color("f6cd26")
	_bar_fill.position = Vector2(111, 9)
	_bar_fill.size = Vector2(0, 3)
	ui.add_child(_bar_fill)

	var pause := TextureButton.new()
	pause.texture_normal = PAUSE_ICON
	pause.texture_pressed = PAUSE_ICON_PRESSED
	pause.set_script(STONE_BUTTON)
	pause.position = Vector2(320 - 38, 4)
	pause.focus_mode = Control.FOCUS_NONE
	pause.pressed.connect(func(): get_tree().call_group("pause_menu", "pause_game"))
	ui.add_child(pause)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y = 60
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.05))
	_hint.modulate.a = 0.0
	ui.add_child(_hint)


func _update_hearts() -> void:
	for i in _hearts.size():
		_hearts[i].texture = HEART_FULL if i < _lives else HEART_EMPTY


func _stone_button(name_prefix: String) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load("res://common/ui/botones/%s.png" % name_prefix)
	b.texture_pressed = load("res://common/ui/botones/%s_presionado.png" % name_prefix)
	b.set_script(STONE_BUTTON)
	return b


func _show_hint(text: String, seconds: float) -> void:
	_hint.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.2)
	_hint_tween.tween_interval(seconds)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.4)
