extends TextureButton
## Botón de piedra: crece un poco al pasar el cursor (o al seleccionarlo con el teclado)
## y usa la imagen "presionado" al hacer clic.

@export var hover_scale: float = 1.1
@export var duration: float = 0.12

var _tween: Tween


func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	focus_entered.connect(_grow.bind(true))
	focus_exited.connect(_grow.bind(false))
	mouse_entered.connect(_grow.bind(true))
	mouse_exited.connect(func(): if not has_focus(): _grow(false))


func _grow(big: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var target := Vector2.ONE * (hover_scale if big else 1.0)
	_tween.tween_property(self, "scale", target, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
