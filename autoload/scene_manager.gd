extends CanvasLayer
## Cambia de escena con fundido a negro.
## Úsenlo SIEMPRE en lugar de get_tree().change_scene_to_file().
## Uso: SceneManager.go_to_world()
##      SceneManager.go_to_minigame("minigame_1")

const MAIN_MENU := "res://menus/main_menu/main_menu.tscn"
const WORLD := "res://world/world.tscn"
const FINALE := "res://finale/chase.tscn"

const FADE_TIME := 0.4

var _fade: ColorRect
var _is_changing := false


func _ready() -> void:
	layer = 100  # siempre encima de todo
	process_mode = Node.PROCESS_MODE_ALWAYS

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)


func go_to_main_menu() -> void:
	change_scene(MAIN_MENU)


func go_to_world() -> void:
	change_scene(WORLD)


func go_to_finale() -> void:
	change_scene(FINALE)


## Minijuegos que no siguen la convención de carpetas (ruta de su escena principal).
const MINIGAME_SCENES := {
	"minigame_trajineras": "res://minigames/minigame_2/scenes/mini_juego_2.tscn",
}


func go_to_minigame(minigame_id: String) -> void:
	## Convención: minigames/<id>/<id>.tscn  (ej. minigames/minigame_1/minigame_1.tscn)
	if MINIGAME_SCENES.has(minigame_id):
		change_scene(MINIGAME_SCENES[minigame_id])
		return
	change_scene("res://minigames/%s/%s.tscn" % [minigame_id, minigame_id])


func change_scene(path: String) -> void:
	if _is_changing:
		return  # evita doble cambio si presionan dos veces
	if not ResourceLoader.exists(path):
		push_error("La escena no existe: " + path)
		return

	_is_changing = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP  # bloquea clics durante la transición

	await _fade_to(1.0)
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await _fade_to(0.0)

	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_changing = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, FADE_TIME)
	await tween.finished
