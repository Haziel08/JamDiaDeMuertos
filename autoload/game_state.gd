extends Node
## Estado de la partida: qué minijuegos se completaron (cada uno da una luz).
## Uso: GameState.complete_minigame("minigame_1")

signal light_collected(minigame_id: String, total: int)
signal all_lights_collected

const TOTAL_LIGHTS := 4

var completed_minigames: Array[String] = []

# Dónde reaparece el jugador al volver al mapa desde un minijuego.
var world_return_position: Vector2 = Vector2.ZERO
var has_return_position: bool = false


func complete_minigame(minigame_id: String) -> void:
	if minigame_id in completed_minigames:
		return  # ya se había completado, no da otra luz
	completed_minigames.append(minigame_id)
	light_collected.emit(minigame_id, get_light_count())
	if has_all_lights():
		all_lights_collected.emit()


func is_minigame_completed(minigame_id: String) -> bool:
	return minigame_id in completed_minigames


func get_light_count() -> int:
	return completed_minigames.size()


func has_all_lights() -> bool:
	return get_light_count() >= TOTAL_LIGHTS


func save_return_position(position: Vector2) -> void:
	world_return_position = position
	has_return_position = true


func reset() -> void:
	## Llamar al iniciar una partida nueva desde el menú.
	completed_minigames.clear()
	has_return_position = false
