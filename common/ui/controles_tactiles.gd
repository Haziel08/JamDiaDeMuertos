extends CanvasLayer
## Controles para celular: cruceta, botón E (interactuar) y botón de salto.
## Solo existen en pantallas táctiles (en la computadora no aparecen nunca).
## Se muestran solo en las escenas donde el jugador se mueve y se esconden
## durante los diálogos y la pausa.

const TEXTURAS := "res://common/ui/tactil/"

## Escenas (nombre del nodo raíz) donde aparecen los controles.
const ESCENAS_CON_CONTROLES := ["World", "Chase", "MinigameOfrenda", "MiniJuego2"]
## Escenas que además necesitan el botón de saltar.
const ESCENAS_CON_SALTO := ["MiniJuego2"]

## Escenas donde solo hace falta moverse a los lados (sin arriba/abajo).
const ESCENAS_SOLO_LADOS := ["MinigameOfrenda"]

var _salto: TouchScreenButton
var _interactuar: TouchScreenButton
var _arriba: TouchScreenButton
var _abajo: TouchScreenButton
var _botones: Array[TouchScreenButton] = []


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not DisplayServer.is_touchscreen_available():
		set_process(false)
		return   # computadora: no se crea nada
	_arriba = _boton("flecha_up", Vector2(26, 112), "move_up")
	_boton("flecha_left", Vector2(4, 134), "move_left")
	_boton("flecha_right", Vector2(48, 134), "move_right")
	_abajo = _boton("flecha_down", Vector2(26, 156), "move_down")
	_interactuar = _boton("boton_e", Vector2(290, 150), "interact")
	_salto = _boton("boton_salto", Vector2(260, 150), "jump")


func _process(_delta: float) -> void:
	var escena := get_tree().current_scene
	var nombre := String(escena.name) if escena else ""
	var mostrar: bool = nombre in ESCENAS_CON_CONTROLES and not get_tree().paused \
			and not GameState.in_dialogue
	visible = mostrar
	_salto.visible = nombre in ESCENAS_CON_SALTO
	_interactuar.visible = nombre == "World"
	_arriba.visible = not nombre in ESCENAS_SOLO_LADOS
	_abajo.visible = not nombre in ESCENAS_SOLO_LADOS
	if not mostrar:
		for accion in ["move_up", "move_down", "move_left", "move_right", "interact", "jump"]:
			Input.action_release(accion)   # que no se quede "pegada" una tecla


func _boton(textura: String, posicion: Vector2, accion: String) -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.texture_normal = load(TEXTURAS + textura + ".png")
	b.position = posicion
	b.action = accion
	b.passby_press = true   # se puede deslizar el dedo de una flecha a otra
	b.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	var forma := RectangleShape2D.new()   # zona de toque un poco más grande que el dibujo
	forma.size = b.texture_normal.get_size() + Vector2(6, 6)
	b.shape = forma
	b.shape_centered = true
	add_child(b)
	_botones.append(b)
	return b
