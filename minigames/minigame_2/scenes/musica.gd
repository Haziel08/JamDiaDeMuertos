extends AudioStreamPlayer

#Música del minijuego: la pone el AudioManager del juego (así la música del mapa
#se apaga con fundido y no suenan dos canciones al mismo tiempo). Se repite sola.

func _ready() -> void:
	var cancion: AudioStream = stream.duplicate()
	if cancion is AudioStreamOggVorbis:
		(cancion as AudioStreamOggVorbis).loop = true
	AudioManager.play_music(cancion)
