extends Area2D

func _on_area_entered(area: Area2D) -> void:
	if area.name != "Hurtbox":
		return

	var jugador = area.get_parent()

	#No hacer nada si el jugador ya no existe
	if not is_instance_valid(jugador):
		return
	#El salto y el aterrizaje se gestionan desde el jugador
	if jugador.saltando or jugador.sobre_barco:
		return
	jugador.recibir_dano()
