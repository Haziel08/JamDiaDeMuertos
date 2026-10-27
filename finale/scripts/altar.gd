extends Node2D
## Final: la casa y el altar. La Muerte se revela y se reproduce ending.dialogue.
## Todo es temporal (rectángulos); reemplazar por el arte cuando esté listo.

const ENDING := preload("res://finale/dialogues/ending.dialogue")

@export var ending_music: AudioStream = preload("res://finale/music/sunbright.ogg")

var _death: ColorRect


func _ready() -> void:
	_build_placeholder_scene()
	if ending_music:
		var music: AudioStream = ending_music.duplicate()
		if music is AudioStreamOggVorbis:
			(music as AudioStreamOggVorbis).loop = true   # que no se corte si leen despacio
		AudioManager.play_music(music)
	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_dialogue_balloon(ENDING, "start")
	await DialogueManager.dialogue_ended
	await _show_the_end()
	SceneManager.go_to_main_menu()


func reveal_death() -> void:
	## Se llama desde ending.dialogue justo antes de que hable la Muerte.
	var fade := create_tween()
	fade.tween_property(_death, "modulate:a", 1.0, 1.5)
	await fade.finished


func _show_the_end() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var label := Label.new()
	label.text = "Fin\n\nGracias por jugar"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.modulate.a = 0.0
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.modulate.a = 0.0
	ui.add_child(dim)
	ui.add_child(label)
	var fade := create_tween().set_parallel()
	fade.tween_property(dim, "modulate:a", 1.0, 1.5)
	fade.tween_property(label, "modulate:a", 1.0, 1.5)
	await fade.finished
	await get_tree().create_timer(3.0).timeout


func _build_placeholder_scene() -> void:
	# Fondo y piso de la casa. Los personajes van arriba de y=88 para no quedar
	# tapados por la caja de diálogo, que ocupa la parte de abajo.
	_rect(Vector2(0, 0), Vector2(320, 180), Color("1b1030"))
	_rect(Vector2(0, 88), Vector2(320, 92), Color("2b1d3a"))
	# Altar con cempasúchil y velas
	_rect(Vector2(212, 44), Vector2(72, 44), Color("6b2e2a"))
	_rect(Vector2(208, 40), Vector2(80, 6), Color("f2a33a"))
	for x in [220, 244, 268]:
		_rect(Vector2(x, 32), Vector2(3, 8), Color("f2e2b0"))
		_rect(Vector2(x, 29), Vector2(3, 3), Color("ffcc55"))
	# Familia frente al altar
	_rect(Vector2(186, 64), Vector2(16, 24), Color("4a90d9"))  # adulto
	_rect(Vector2(166, 72), Vector2(12, 16), Color("7cb3e8"))  # hijo
	# El protagonista, translúcido: es un alma
	var ghost := _rect(Vector2(72, 72), Vector2(16, 16), Color("f2a33a"))
	ghost.modulate.a = 0.6
	# La Muerte: invisible hasta reveal_death()
	_death = _rect(Vector2(40, 60), Vector2(16, 28), Color("e8e2d0"))
	_death.modulate.a = 0.0


func _rect(at: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = at
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r
