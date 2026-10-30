extends CanvasLayer

@onready var corazones: HBoxContainer = $Corazones
@onready var contador_flores: HBoxContainer = $ContadorFlores
@onready var cantidad_flores: Label = $ContadorFlores/Cantidad

const BOTON_PIEDRA := preload("res://common/ui/stone_button.gd")
const ICONO_PAUSA := preload("res://common/ui/botones/icono_pausa.png")
const ICONO_PAUSA_PRESIONADO := preload("res://common/ui/botones/icono_pausa_presionado.png")

var mensaje: Label
var tween_mensaje: Tween

#Posición de corazones (igual que en los otros minijuegos: arriba a la izquierda).
#El juego se ve a 320 x 180, así que todo va a tamaño normal (sin escalar).
func _ready() -> void:
	corazones.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	corazones.position = Vector2(4.0, 4.0)

	#Contador de flores debajo de los corazones
	contador_flores.position = Vector2(4.0, 22.0)

	crear_boton_pausa()
	crear_mensaje()
	mostrar_mensaje("Salta con Espacio entre las trajineras\ny junta todas las flores", 3.0)

#Botón de pausa de piedra, arriba a la derecha (abre el menú de pausa del juego)
func crear_boton_pausa() -> void:
	var boton := TextureButton.new()
	boton.texture_normal = ICONO_PAUSA
	boton.texture_pressed = ICONO_PAUSA_PRESIONADO
	boton.set_script(BOTON_PIEDRA)
	boton.position = Vector2(320 - 38, 4)
	boton.focus_mode = Control.FOCUS_NONE
	boton.pressed.connect(func(): get_tree().call_group("pause_menu", "pause_game"))
	add_child(boton)

#Texto al centro de la pantalla que aparece y se desvanece
func crear_mensaje() -> void:
	mensaje = Label.new()
	mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mensaje.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mensaje.position.y = 40
	mensaje.add_theme_constant_override("outline_size", 4)
	mensaje.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.05))
	mensaje.modulate.a = 0.0
	add_child(mensaje)

func mostrar_mensaje(texto: String, segundos: float) -> void:
	mensaje.text = texto
	if tween_mensaje:
		tween_mensaje.kill()
	tween_mensaje = create_tween()
	tween_mensaje.tween_property(mensaje, "modulate:a", 1.0, 0.2)
	tween_mensaje.tween_interval(segundos)
	tween_mensaje.tween_property(mensaje, "modulate:a", 0.0, 0.4)

func actualizar_flores(recogidas: int, total: int) -> void:
	cantidad_flores.text = str(recogidas) + "/" + str(total)
