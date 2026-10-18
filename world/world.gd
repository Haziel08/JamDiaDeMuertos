extends Node2D
## Mundo abierto: ajusta la cámara al tamaño del mapa y
## coloca al jugador donde estaba al volver de un minijuego.

@onready var ground: TileMapLayer = $Ground
@onready var player: CharacterBody2D = $Entities/Player


func _ready() -> void:
	if GameState.has_return_position:
		player.global_position = GameState.world_return_position
	_set_camera_limits()


func _set_camera_limits() -> void:
	## La cámara no muestra nada fuera del suelo pintado.
	var camera: Camera2D = player.get_node("Camera2D")
	var used_rect := ground.get_used_rect()          # en tiles
	var tile_size := ground.tile_set.tile_size       # 16 × 16

	camera.limit_left = used_rect.position.x * tile_size.x
	camera.limit_top = used_rect.position.y * tile_size.y
	camera.limit_right = used_rect.end.x * tile_size.x
	camera.limit_bottom = used_rect.end.y * tile_size.y
	camera.reset_smoothing()  # evita que la cámara "viaje" al iniciar
