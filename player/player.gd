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
var sleeping: bool = false  # al inicio: dormido en el pasto (animación "sleep")
var facing: Vector2 = Vector2.DOWN  # última dirección a la que miró

var _held_directions: Array[Vector2] = []  # teclas presionadas, en orden
var _knockback: Vector2 = Vector2.ZERO     # empujón (por ejemplo, cuando te toca un alma)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	var direction := _get_input_direction() if can_move else Vector2.ZERO

	velocity = direction * speed + _knockback
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)

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
	if sleeping and sprite.sprite_frames.has_animation("sleep"):
		sprite.play("sleep")
		return

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


func push_from(from: Vector2, force: float) -> void:
	## Empuja al jugador lejos de un punto y lo hace parpadear.
	var away := global_position - from
	if away.length() < 0.1:
		away = -facing
	_knockback = away.normalized() * force
	var t := create_tween()
	for i in 3:
		t.tween_property(sprite, "modulate", Color(0.6, 0.6, 1.0, 0.4), 0.08)
		t.tween_property(sprite, "modulate", Color.WHITE, 0.08)
