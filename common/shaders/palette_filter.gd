@tool
extends ColorRect
## Aplica el filtro de paleta a todo lo que se dibuja DEBAJO de este nodo.
## Ponlo dentro de un CanvasLayer con layer = 5 (encima del mapa, debajo del HUD).
## Cambia los colores, el modo y la intensidad desde el Inspector; se ve en vivo en el editor.

const SHADER := preload("res://common/shaders/palette_filter.gdshader")

## Colores de la paleta (máximo 16).
@export var colors: PackedColorArray = PackedColorArray([
	Color("202020"), Color("331c17"), Color("393939"), Color("563226"),
	Color("725956"), Color("ac6b26"), Color("bb7f57"), Color("f6cd26"),
]):
	set(value):
		colors = value
		_apply()

## Por brillo: todo el mapa queda en tonos de la paleta, como una foto antigua.
## Color más parecido: respeta más los colores originales (útil con 16 colores).
@export_enum("Color más parecido", "Por brillo") var mode: int = 1:
	set(value):
		mode = value
		_apply()

## 0 = sin filtro, 1 = solo colores de la paleta. 0.45 = atardecer que conserva los colores originales.
@export_range(0.0, 1.0, 0.05) var strength: float = 0.45:
	set(value):
		strength = value
		_apply()

## Solo para el modo "Por brillo": más alto = más diferencia entre claros y oscuros.
@export_range(0.5, 2.0, 0.05) var contrast: float = 1.15:
	set(value):
		contrast = value
		_apply()

## Intensidad de los colores: 1 = normal, más alto = más vivos (atardecer), 0 = blanco y negro.
@export_range(0.0, 2.0, 0.05) var saturation: float = 1.0:
	set(value):
		saturation = value
		_apply()


## Atardecer: 0 = luz normal, 1 = muy naranja. Arriba naranja y abajo lila.
@export_range(0.0, 1.0, 0.05) var sunset: float = 0.55:
	set(value):
		sunset = value
		_apply()

@export var sky_top: Color = Color(1.0, 0.55, 0.32):
	set(value):
		sky_top = value
		_apply()

@export var sky_bottom: Color = Color(0.55, 0.36, 0.62):
	set(value):
		sky_bottom = value
		_apply()

## Oscurece las esquinas de la pantalla (0 = nada).
@export_range(0.0, 1.0, 0.05) var vignette: float = 0.5:
	set(value):
		vignette = value
		_apply()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not material is ShaderMaterial:
		material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = SHADER
	_apply()


func _apply() -> void:
	if not is_node_ready() or not material is ShaderMaterial:
		return
	var palette: Array[Color] = []
	for i in 16:
		palette.append(colors[i] if i < colors.size() else Color.BLACK)
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("palette", palette)
	mat.set_shader_parameter("palette_size", clampi(colors.size(), 1, 16))
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("contrast", contrast)
	mat.set_shader_parameter("saturation", saturation)
	mat.set_shader_parameter("sunset", sunset)
	mat.set_shader_parameter("sky_top", sky_top)
	mat.set_shader_parameter("sky_bottom", sky_bottom)
	mat.set_shader_parameter("vignette", vignette)
