extends CanvasLayer

@onready var corazones: HBoxContainer = $Corazones

#Posición de corazones
func _ready() -> void:
	corazones.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	corazones.position = Vector2(5.0, 5.0)
