extends AudioStreamPlayer

#Música del minijuego: se repite mientras se juega.

func _ready() -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	play()
