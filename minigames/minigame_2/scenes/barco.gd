extends AnimatableBody2D

@export var velocidad: float = 35.0

# 1 = baja
# -1 = sube
@export_range(-1, 1, 2) var direccion: int = 1

# Límites verticales del recorrido, en coordenadas globales
@export var limite_superior_y: float = -150.0
@export var limite_inferior_y: float = 170.0

# Separación adicional para que aparezca fuera del borde
@export var margen_reaparicion: float = 40.0


func _physics_process(delta: float) -> void:
	# Mover la trajinera
	global_position.y += velocidad * direccion * delta

	# Si sube y alcanza el borde superior
	if direccion == -1 and global_position.y <= limite_superior_y:
		comprobar_jugador_a_bordo()

		# Reaparece por debajo del agua
		global_position.y = limite_inferior_y + margen_reaparicion
		reset_physics_interpolation()

	# Si baja y alcanza el borde inferior
	elif direccion == 1 and global_position.y >= limite_inferior_y:
		comprobar_jugador_a_bordo()

		# Reaparece por encima del agua
		global_position.y = limite_superior_y - margen_reaparicion
		reset_physics_interpolation()


func comprobar_jugador_a_bordo() -> void:
	var jugador = get_tree().get_first_node_in_group("jugador")

	if jugador == null:
		return

	if jugador.barco_actual == self:
		print("¡La trajinera llegó al borde con el jugador a bordo!")
		jugador.caer_de_borde()
