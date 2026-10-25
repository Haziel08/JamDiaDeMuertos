extends Area2D
## Alma en pena: aparece cerca del jugador, lo persigue atravesando todo
## y, si lo toca, lo empuja y se desvanece. Si no lo alcanza, se desvanece sola.

@export var speed: float = 34.0         # el jugador camina a 60: se le puede escapar
@export var lifetime: float = 11.0      # segundos antes de desvanecerse sola
@export var push_force: float = 220.0   # qué tan fuerte empuja al jugador

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _player: Node2D
var _alive_time: float = 0.0
var _leaving: bool = false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	body_entered.connect(_on_body_entered)
	# Aparece poco a poco, saliendo de la tierra.
	modulate = Color(1, 1, 1, 0.0)
	sprite.position.y += 6.0
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 0.95, 0.8)
	t.tween_property(sprite, "position:y", sprite.position.y - 6.0, 0.8)
	sprite.play("walk_down")


func _physics_process(delta: float) -> void:
	if _leaving or _player == null:
		return
	if GameState.in_dialogue:
		return  # mientras hay un diálogo, las almas esperan
	_alive_time += delta
	if _alive_time > lifetime:
		vanish()
		return
	var to_player := _player.global_position - global_position
	if to_player.length() > 2.0:
		var dir := to_player.normalized()
		global_position += dir * speed * delta
		_face(dir)
	# Parpadeo suave, como alma en pena.
	sprite.modulate.a = 0.8 + 0.2 * sin(_alive_time * 6.0)


func _face(dir: Vector2) -> void:
	## La animación de lado mira a la izquierda; para la derecha se voltea.
	var anim := "walk_side" if absf(dir.x) > absf(dir.y) else ("walk_down" if dir.y > 0 else "walk_up")
	sprite.flip_h = anim == "walk_side" and dir.x > 0
	if sprite.animation != anim:
		sprite.play(anim)


func _on_body_entered(body: Node2D) -> void:
	if _leaving or not body.is_in_group("player"):
		return
	if body.has_method("push_from"):
		body.push_from(global_position, push_force)
	_leaving = true
	sprite.flip_h = false
	sprite.play("attack")          # golpe y luego se deshace
	await sprite.animation_finished
	_leaving = false
	vanish()


func vanish() -> void:
	if _leaving:
		return
	_leaving = true
	set_deferred("monitoring", false)
	sprite.flip_h = false
	sprite.play("death")           # se desarma en huesos
	await sprite.animation_finished
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)
