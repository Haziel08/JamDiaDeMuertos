extends Node2D
## Final: la casa y el altar. La Muerte se revela y se reproduce ending.dialogue.
## Casa con piso de madera, ofrenda, familia de espaldas y la Muerte.

const ENDING := preload("res://finale/dialogues/ending.dialogue")
const FLOOR := preload("res://finale/sprites/piso_madera.png")
const OFRENDA := preload("res://finale/sprites/ofrenda.png")
const ESPOSA := preload("res://finale/sprites/esposa.png")
const HIJO := preload("res://finale/sprites/hijo.png")
const DEATH := preload("res://finale/sprites/la_muerte.png")
const HERO_FRAMES := preload("res://player/sprites/protagonista_frames.tres")

@export var ending_music: AudioStream = preload("res://finale/music/sunbright.ogg")

var _death: Node2D


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
	## Casa de la familia: pared, piso de madera, la ofrenda, la familia de espaldas,
	## el protagonista (un alma, medio transparente) y la Muerte, que aparece con reveal_death().
	# Los personajes van arriba de y=106 para no quedar tapados por la caja de diálogo.
	_rect(Vector2(0, 0), Vector2(320, 96), Color("2a1a3d"))          # pared
	_rect(Vector2(0, 92), Vector2(320, 4), Color("1c1029"))          # zoclo
	var floor_rect := TextureRect.new()                              # piso de madera
	floor_rect.texture = FLOOR
	floor_rect.stretch_mode = TextureRect.STRETCH_TILE
	floor_rect.position = Vector2(0, 96)
	floor_rect.size = Vector2(320, 84)
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)
	_papel_picado()

	# Luz baja y cálida: la casa a oscuras, iluminada por las velas de la ofrenda
	var dark := CanvasModulate.new()
	dark.color = Color(0.62, 0.56, 0.72)
	add_child(dark)

	var ofrenda := _sprite(OFRENDA, Vector2(238, 98), Vector2(80, 64))
	for candle in [Vector2(-10, -22), Vector2(16, -5), Vector2(-20, 2)]:
		_candle_glow(ofrenda.position + candle)
	var warm := PointLight2D.new()
	warm.texture = _radial(128, Color(1.0, 0.75, 0.45))
	warm.texture_scale = 1.6
	warm.energy = 0.9
	warm.position = Vector2(238, 70)
	add_child(warm)

	# La familia, de espaldas, frente a la ofrenda
	var esposa := _sprite(ESPOSA, Vector2(226, 104), Vector2(16, 16), Rect2(16, 0, 16, 16))
	_sprite(HIJO, Vector2(250, 104), Vector2(16, 16), Rect2(16, 0, 16, 16))
	var sob := create_tween().set_loops()   # la esposa solloza un poquito
	sob.tween_interval(1.6)
	for i in 3:
		sob.tween_property(esposa, "position:y", 95.0, 0.08)
		sob.tween_property(esposa, "position:y", 96.0, 0.08)

	# El protagonista: un alma, medio transparente y flotando
	var ghost := AnimatedSprite2D.new()
	ghost.sprite_frames = HERO_FRAMES
	ghost.play("idle_right")
	ghost.position = Vector2(150, 100)
	ghost.modulate = Color(0.8, 0.9, 1.0, 0.65)
	_unshaded(ghost)
	add_child(ghost)
	var float_t := create_tween().set_loops()
	float_t.tween_property(ghost, "position:y", 97.0, 1.2).set_trans(Tween.TRANS_SINE)
	float_t.tween_property(ghost, "position:y", 100.0, 1.2).set_trans(Tween.TRANS_SINE)

	# La Muerte: invisible hasta reveal_death(), con la luz de su linterna
	_death = Node2D.new()
	_death.position = Vector2(84, 105)
	_death.modulate.a = 0.0
	add_child(_death)
	var body := Sprite2D.new()
	body.texture = DEATH
	body.centered = false
	body.position = Vector2(-16, -31)
	_death.add_child(body)
	var lantern := Sprite2D.new()
	lantern.texture = _radial(24, Color(1.0, 0.85, 0.4))
	lantern.position = Vector2(12, -15)
	_unshaded(lantern)
	_death.add_child(lantern)
	var hover := create_tween().set_loops()
	hover.tween_property(body, "position:y", -33.0, 1.5).set_trans(Tween.TRANS_SINE)
	hover.tween_property(body, "position:y", -31.0, 1.5).set_trans(Tween.TRANS_SINE)


func _papel_picado() -> void:
	## Tira de papel picado de lado a lado de la pared.
	var colors := [Color("e05a8a"), Color("f2a33a"), Color("8a5cd6"), Color("3fb67a"), Color("f6cd26")]
	_rect(Vector2(0, 6), Vector2(320, 1), Color("140c1e"))
	for i in 22:
		var flag := _rect(Vector2(4 + i * 14.5, 7), Vector2(10, 11), colors[i % colors.size()])
		flag.modulate.a = 0.9
		_rect(Vector2(4 + i * 14.5 + 3, 10), Vector2(4, 3), Color("2a1a3d"))   # recorte del papel
		_rect(Vector2(4 + i * 14.5 + 1, 16), Vector2(2, 2), Color("2a1a3d"))
		_rect(Vector2(4 + i * 14.5 + 7, 16), Vector2(2, 2), Color("2a1a3d"))


func _sprite(tex: Texture2D, feet: Vector2, size: Vector2, region := Rect2()) -> Sprite2D:
	## Coloca un dibujo con la base (los pies) en "feet".
	var s := Sprite2D.new()
	s.texture = tex
	if region.has_area():
		s.region_enabled = true
		s.region_rect = region
	s.position = feet - Vector2(0, size.y / 2.0)
	add_child(s)
	return s


func _candle_glow(at: Vector2) -> void:
	var glow := Sprite2D.new()
	glow.texture = _radial(16, Color(1.0, 0.8, 0.4))
	glow.position = at
	glow.modulate.a = 0.7
	_unshaded(glow)
	add_child(glow)
	var t := create_tween().set_loops()
	t.tween_property(glow, "scale", Vector2(1.15, 1.15), randf_range(0.15, 0.3))
	t.tween_property(glow, "scale", Vector2(0.9, 0.9), randf_range(0.15, 0.3))


func _unshaded(node: CanvasItem) -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	node.material = mat


func _radial(size: int, color: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex


func _rect(at: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = at
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r
