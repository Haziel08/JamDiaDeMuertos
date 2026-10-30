extends Camera2D

#El juego se ve a 320 x 180, así que el nivel completo no cabe en pantalla:
#la cámara sigue al jugador y no se sale de los bordes del nivel.

@export var margen: int = 0

func _ready() -> void:
	#Los límites salen del tamaño del pasto + bordes del nivel
	var borde: TileMapLayer = $"../Borde"
	var area := borde.get_used_rect()
	var tam := borde.tile_set.tile_size
	var esquina := borde.to_global(borde.map_to_local(area.position)) - Vector2(tam) / 2.0
	limit_left = int(esquina.x) - margen
	limit_top = int(esquina.y) - margen
	limit_right = int(esquina.x) + area.size.x * tam.x + margen
	limit_bottom = int(esquina.y) + area.size.y * tam.y + margen
	seguir_jugador()
	reset_smoothing()

func _physics_process(_delta: float) -> void:
	seguir_jugador()

func seguir_jugador() -> void:
	var jugador = get_tree().get_first_node_in_group("jugador")
	if is_instance_valid(jugador):
		global_position = jugador.global_position
