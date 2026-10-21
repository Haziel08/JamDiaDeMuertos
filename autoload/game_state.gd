extends Node
## Estado de la partida: luces, NPCs conocidos, intro y minijuego pendiente.
## Uso: GameState.complete_minigame("minigame_trajineras")

signal light_collected(minigame_id: String, total: int)
signal all_lights_collected

const TOTAL_LIGHTS := 3

var completed_minigames: Array[String] = []
var pending_finale: bool = false        # el jugador aceptó cruzar el portón

# Dónde reaparece el jugador al volver al mapa desde un minijuego.
var world_return_position: Vector2 = Vector2.ZERO
var has_return_position: bool = false

# --- Historia y diálogos ---
var intro_done: bool = false            # ya se vio la escena inicial
var met_npcs: Array[String] = []        # NPCs con los que ya se habló una vez
var in_dialogue: bool = false           # hay un diálogo en pantalla
var pending_minigame: String = ""       # minijuego aceptado; se abre al cerrar el diálogo
var pending_reward: String = ""         # minijuego recién ganado; su NPC entrega la luz


func complete_minigame(minigame_id: String) -> void:
	if minigame_id in completed_minigames:
		return  # ya se había completado, no da otra luz
	completed_minigames.append(minigame_id)
	pending_reward = minigame_id
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


# --- Funciones que se llaman desde los archivos .dialogue ---

func has_met(npc_id: String) -> bool:
	return npc_id in met_npcs


func mark_met(npc_id: String) -> void:
	if npc_id not in met_npcs:
		met_npcs.append(npc_id)


func request_minigame(minigame_id: String) -> void:
	## El mundo abre este minijuego en cuanto termine el diálogo.
	pending_minigame = minigame_id

func request_finale() -> void:
	## Se llama desde gate.dialogue al aceptar cruzar el portón.
	pending_finale = true

func reset() -> void:
	## Llamar al iniciar una partida nueva desde el menú.
	completed_minigames.clear()
	has_return_position = false
	intro_done = false
	met_npcs.clear()
	in_dialogue = false
	pending_minigame = ""
	pending_reward = ""
	pending_finale = false
