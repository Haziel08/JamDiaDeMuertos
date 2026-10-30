extends Area2D

#Flor de cempasúchil que se puede recolectar.
#Por ahora es un cuadro amarillo; cuando haya sprite, se cambia el ColorRect por un Sprite2D.

func _on_area_entered(area: Area2D) -> void:
	#Solo la recoge el jugador (su Hurtbox)
	if area.name != "Hurtbox":
		return

	var jugador = area.get_parent()

	if not is_instance_valid(jugador):
		return

	jugador.recoger_flor()

	#Pequeña animación antes de desaparecer
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.15)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
