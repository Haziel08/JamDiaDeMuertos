extends CharacterBody2D
## Jugador del mundo abierto: movimiento en 4 direcciones (sin diagonales).
## Otros scripts pueden bloquear el movimiento con player.can_move = false
## (por ejemplo durante diálogos o cinemáticas).

## 60 = exactamente 1 píxel por frame de física: movimiento nítido en pixel art.
@export var speed: float = 60.0

const DIRECTIONS := {
	"move_left": Vector2.LEFT,
	"move_right": Vector2.RIGHT,
	"move_up": Vector2.UP,
	"move_down": Vector2.DOWN,
}

var can_move: bool = true
var facing: Vector2 = Vector2.DOWN  # última dirección a la que miró

var _held_directions: Array[Vector2] = []  # teclas presionadas, en orden

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	var direction := _get_input_direction() if can_move else Vector2.ZERO

	velocity = direction * speed
	move_and_slide()

	if direction != Vector2.ZERO:
		facing = direction
	_update_animation(direction != Vector2.ZERO)


func _get_input_direction() -> Vector2:
	## Devuelve solo UNA dirección: la de la última tecla presionada.
	for action in DIRECTIONS:
		var dir: Vector2 = DIRECTIONS[action]
		if Input.is_action_pressed(action):
			if dir not in _held_directions:
				_held_directions.append(dir)
		else:
			_held_directions.erase(dir)

	if _held_directions.is_empty():
		return Vector2.ZERO
	return _held_directions.back()


func _update_animation(is_moving: bool) -> void:
	if sprite.sprite_frames == null:
		return  # todavía no hay arte

	# Nombres esperados: idle_down, idle_up, idle_left, idle_right,
	#                    walk_down, walk_up, walk_left, walk_right
	var animation := ("walk_" if is_moving else "idle_") + _direction_name(facing)
	if sprite.sprite_frames.has_animation(animation):
		sprite.play(animation)


func _direction_name(direction: Vector2) -> String:
	if direction.x < 0:
		return "left"
	if direction.x > 0:
		return "right"
	return "up" if direction.y < 0 else "down"
