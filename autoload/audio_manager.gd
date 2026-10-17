extends Node
## Reproduce música (con cambio suave entre canciones) y efectos de sonido.
## Uso: AudioManager.play_music(preload("res://common/music/menu.ogg"))
##      AudioManager.play_sfx(preload("res://common/sfx/click.wav"))

const SFX_PLAYER_COUNT := 8   # cuántos efectos pueden sonar al mismo tiempo
const SILENT_DB := -40.0

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue sonando aunque el juego esté en pausa

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	for i in SFX_PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)


func play_music(stream: AudioStream, fade_time: float = 0.5) -> void:
	if stream == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return  # ya está sonando esa canción

	if _music_player.playing:
		var fade_out := create_tween()
		fade_out.tween_property(_music_player, "volume_db", SILENT_DB, fade_time)
		await fade_out.finished

	_music_player.stream = stream
	_music_player.volume_db = SILENT_DB
	_music_player.play()
	create_tween().tween_property(_music_player, "volume_db", 0.0, fade_time)


func stop_music(fade_time: float = 0.5) -> void:
	if not _music_player.playing:
		return
	var fade_out := create_tween()
	fade_out.tween_property(_music_player, "volume_db", SILENT_DB, fade_time)
	await fade_out.finished
	_music_player.stop()


func play_sfx(stream: AudioStream, pitch_variation: float = 0.0) -> void:
	## pitch_variation: 0.1 hace que cada repetición suene un poco distinta (pasos, golpes).
	if stream == null:
		return
	var player := _get_free_sfx_player()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	return _sfx_players[0]  # todos ocupados: reutiliza el primero
