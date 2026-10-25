extends Node2D
## Hace aparecer almas cerca del jugador (fuera de la pantalla) cada cierto tiempo.
## Va como hijo de Entities en world.tscn. Ajusta los números en el Inspector.

const ALMA := preload("res://world/enemies/Alma.tscn")

@export var enabled: bool = true
@export var max_alive: int = 2              # máximo de almas al mismo tiempo (nunca más de esto)
@export var min_wait: float = 6.0           # segundos entre una y otra
@export var max_wait: float = 11.0
@export var spawn_distance: float = 150.0   # qué tan lejos del jugador aparecen
@export var safe_radius: float = 120.0      # no aparecen cerca del punto de inicio

var _timer: float = 4.0
var _start_point: Vector2


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_start_point = player.global_position


func _process(delta: float) -> void:
	if not enabled or not GameState.intro_done or GameState.in_dialogue:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(min_wait, max_wait)
	if get_child_count() >= max_alive:
		return  # las que se están deshaciendo también cuentan: nunca hay más de max_alive
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.global_position.distance_to(_start_point) < safe_radius:
		return
	var alma := ALMA.instantiate()
	var angle := randf() * TAU
	var pos := player.global_position + Vector2.from_angle(angle) * spawn_distance
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:  # que no aparezca fuera del mapa
		pos.x = clampf(pos.x, cam.limit_left + 8, cam.limit_right - 8)
		pos.y = clampf(pos.y, cam.limit_top + 16, cam.limit_bottom - 8)
	alma.position = pos
	add_child(alma)
