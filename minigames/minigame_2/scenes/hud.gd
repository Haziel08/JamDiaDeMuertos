extends CanvasLayer

@onready var corazones: HBoxContainer = $Corazones
@onready var contador_flores: HBoxContainer = $ContadorFlores
@onready var cantidad_flores: Label = $ContadorFlores/Cantidad

#El juego principal se ve a 320 x 180; esta ventana es de 1280 x 720 (4 veces más grande).
#Se escala el HUD x4 para que los corazones se vean igual que en el resto del juego.
const ESCALA_HUD: float = 4.0

#Posición de corazones (igual que en los otros minijuegos: arriba a la izquierda)
func _ready() -> void:
	corazones.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	corazones.scale = Vector2(ESCALA_HUD, ESCALA_HUD)
	corazones.position = Vector2(4.0, 4.0) * ESCALA_HUD

	#Contador de flores debajo de los corazones
	contador_flores.scale = Vector2(ESCALA_HUD, ESCALA_HUD)
	contador_flores.position = Vector2(4.0, 22.0) * ESCALA_HUD

func actualizar_flores(recogidas: int, total: int) -> void:
	cantidad_flores.text = str(recogidas) + "/" + str(total)
