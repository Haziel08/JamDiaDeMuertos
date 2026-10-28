extends Area2D

func _on_area_entered(area: Area2D) -> void:
	print("Área detectada: ", area.name)

	if area.name == "Hurtbox":
		var jugador = area.get_parent()
		jugador.recibir_dano()
		
		jugador.respawn()
