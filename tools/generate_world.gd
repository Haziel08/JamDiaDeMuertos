extends SceneTree
## Genera el TileSet, el mapa completo (recámara → pasillo → pueblo) y las animaciones.
## Uso (desde la carpeta del proyecto):  godot --headless -s res://tools/generate_world.gd

const T := 16
const OX := 64          # el pueblo empieza en esta columna
const TOWN_W := 96
const W := OX + TOWN_W
const H := 44

enum { FLOOR, WATER, NATURE, HOUSE, ELEMENT, DETAIL, BOAT, ISLAND, WATER_ANIM, CAVE, WALL, WOOD, BED }

const SOURCES := {
	FLOOR: "res://common/art/ninja/tilesets/TilesetFloor.png",
	WATER: "res://common/art/ninja/tilesets/TilesetWater.png",
	NATURE: "res://common/art/ninja/tilesets/TilesetNature.png",
	HOUSE: "res://common/art/ninja/tilesets/TilesetHouse.png",
	ELEMENT: "res://common/art/ninja/tilesets/TilesetElement.png",
	DETAIL: "res://common/art/ninja/tilesets/TilesetFloorDetail.png",
	BOAT: "res://common/art/ninja/vehicles/Boat.png",
	ISLAND: "res://common/art/custom/tiles_isla.png",
	WATER_ANIM: "res://common/art/custom/agua_animada.png",
	CAVE: "res://common/art/custom/tiles_cueva.png",
	WALL: "res://common/art/ninja/interior/TilesetWallSimple.png",
	WOOD: "res://common/art/ninja/interior/TilesetInteriorFloor.png",
	BED: "res://common/art/ninja/interior/tileset_bed.png",
}

# Pasillo
const CORR_X0 := 14
const CORR_X1 := 59
const CORR_TOP := 20      # orilla de arriba (se camina)
const CORR_BOTTOM := 23   # acantilado de abajo (choca)

var rng := RandomNumberGenerator.new()
var ground: TileMapLayer
var deco: TileMapLayer
var walls: TileMapLayer
var above: TileMapLayer
var path := {}
var water := {}
var blocked := {}


func _init() -> void:
	rng.seed = 2026
	var tileset := build_tileset()
	ResourceSaver.save(tileset, "res://world/tilesets/town_tileset.tres")
	tileset = load("res://world/tilesets/town_tileset.tres")
	var map := build_map(tileset)
	var packed := PackedScene.new()
	packed.pack(map)
	ResourceSaver.save(packed, "res://world/map/town_map.tscn")
	build_sprite_frames()
	print("OK tileset + mapa + animaciones")
	quit()


# ================================================================== TileSet

func build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var square := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for id in SOURCES:
		var tex: Texture2D = load(SOURCES[id])
		var img := tex.get_image()
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(T, T)
		ts.add_source(src, id)
		if id == WATER_ANIM:
			# Un solo tile animado de 4 cuadros.
			src.create_tile(Vector2i(0, 0))
			src.set_tile_animation_frames_count(Vector2i(0, 0), 4)
			for f in 4:
				src.set_tile_animation_frame_duration(Vector2i(0, 0), f, 0.35)
			_add_collision(src, Vector2i(0, 0), square)
			continue
		for y in img.get_height() / T:
			for x in img.get_width() / T:
				if not _has_pixels(img, x, y):
					continue
				var c := Vector2i(x, y)
				src.create_tile(c)
				if _is_solid(id, c):
					_add_collision(src, c, square)
	return ts


func _add_collision(src: TileSetAtlasSource, c: Vector2i, square: PackedVector2Array) -> void:
	var data := src.get_tile_data(c, 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, square)


func _has_pixels(img: Image, tx: int, ty: int) -> bool:
	for y in T:
		for x in T:
			if img.get_pixel(tx * T + x, ty * T + y).a > 0.05:
				return true
	return false


func _is_solid(id: int, c: Vector2i) -> bool:
	match id:
		WATER:
			return c.y < 12          # el muelle de madera (filas 12+) se camina
		NATURE:
			if c.y >= 10 and c.y <= 11 and c.x <= 11:
				return false         # arbustos chicos y flores
			if c.y == 18 and c.x >= 15:
				return false         # piedritas
			return true
		HOUSE, ELEMENT, BOAT, WALL, BED:
			return true
		ISLAND:
			return c.y == 2 or c.y >= 3 and c.x <= 7   # acantilados y agua
		CAVE:
			return c.y < 8           # oscuridad, rocas y árboles (el pasto claro no choca)
	return false                     # FLOOR, DETAIL, WOOD


# ================================================================== Mapa

func build_map(ts: TileSet) -> Node2D:
	var root := Node2D.new()
	root.name = "TownMap"
	ground = _layer(root, "Ground", ts)
	deco = _layer(root, "Decoration", ts)
	deco.collision_enabled = false
	walls = _layer(root, "Walls", ts)
	above = _layer(root, "Above", ts)
	above.collision_enabled = false
	above.z_index = 1

	_build_bedroom()
	_build_corridor()
	_build_town()
	_add_markers(root)
	return root


func _layer(root: Node, layer_name: String, ts: TileSet) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = layer_name
	l.tile_set = ts
	root.add_child(l)
	l.owner = root
	return l


# ---------------------------------------------------------------- Recámara

func _build_bedroom() -> void:
	# Oscuridad alrededor del cuarto (choca)
	for x in range(0, CORR_X0):
		for y in H:
			ground.set_cell(Vector2i(x, y), CAVE, Vector2i(4, 1))
	# Piso de madera (incluye la puerta)
	var wood := [Vector2i(5, 13), Vector2i(6, 13), Vector2i(7, 13), Vector2i(5, 14), Vector2i(6, 14)]
	for x in range(1, 13):
		for y in range(17, 27):
			ground.set_cell(Vector2i(x, y), WOOD, wood[rng.randi_range(0, wood.size() - 1)])
	for y in [21, 22]:
		ground.set_cell(Vector2i(13, y), WOOD, Vector2i(6, 13))
	# Paredes (marco café del pack Ninja Adventure)
	walls.set_cell(Vector2i(0, 16), WALL, Vector2i(0, 6))
	walls.set_cell(Vector2i(13, 16), WALL, Vector2i(4, 6))
	walls.set_cell(Vector2i(0, 27), WALL, Vector2i(0, 10))
	walls.set_cell(Vector2i(13, 27), WALL, Vector2i(4, 10))
	for x in range(1, 13):
		walls.set_cell(Vector2i(x, 16), WALL, Vector2i(3, 6))
		walls.set_cell(Vector2i(x, 27), WALL, Vector2i(3, 10))
	for y in range(17, 27):
		walls.set_cell(Vector2i(0, y), WALL, Vector2i(0, 7))
		if y == 21 or y == 22:
			continue                                   # puerta hacia el pasillo
		var right := Vector2i(4, 7)
		if y == 20: right = Vector2i(4, 8)             # remate arriba de la puerta
		if y == 23: right = Vector2i(4, 9)             # remate abajo de la puerta
		walls.set_cell(Vector2i(13, y), WALL, right)
	# Cama (sin colisión: el personaje despierta sobre ella)
	for dx in 2:
		for dy in 3:
			deco.set_cell(Vector2i(3 + dx, 17 + dy), BED, Vector2i(dx, dy))
	# Tapete redondo
	for dx in 2:
		for dy in 2:
			deco.set_cell(Vector2i(7 + dx, 21 + dy), WALL, Vector2i(2 + dx, 7 + dy))


# ---------------------------------------------------------------- Pasillo sobre el agua

func _build_corridor() -> void:
	for x in range(CORR_X0, OX):
		for y in H:
			ground.set_cell(Vector2i(x, y), WATER_ANIM, Vector2i(0, 0))
	var grass_details := [Vector2i(8, 1), Vector2i(9, 1), Vector2i(12, 3), Vector2i(13, 3), Vector2i(14, 3), Vector2i(13, 4)]
	for x in range(CORR_X0, CORR_X1 + 1):
		var is_end := x == CORR_X1
		ground.set_cell(Vector2i(x, CORR_TOP), ISLAND, Vector2i(7, 0) if is_end else Vector2i(6, 0))
		for y in range(CORR_TOP + 1, CORR_BOTTOM):
			var tile := Vector2i(6, 1)
			if rng.randf() < 0.18:
				tile = grass_details[rng.randi_range(0, grass_details.size() - 1)]
			ground.set_cell(Vector2i(x, y), ISLAND, tile)
		ground.set_cell(Vector2i(x, CORR_BOTTOM), ISLAND, Vector2i(7, 2) if is_end else Vector2i(6, 2))
	# Puente de madera hacia el pueblo
	for x in range(CORR_X1 + 1, OX):
		for y in [21, 22]:
			ground.set_cell(Vector2i(x, y), WATER, Vector2i(1, 13))
	# Árboles naranjas a lo largo del pasillo
	for x in [18, 27, 44, 53]:           # orilla de arriba: el tronco choca, la copa queda sobre el agua
		_cave_tree(Vector2i(x, CORR_TOP - 2), x % 2 == 0)
	for x in [22, 39, 48]:               # orilla de abajo: la copa tapa al jugador al pasar
		_cave_tree(Vector2i(x, CORR_BOTTOM - 2), x % 2 == 1)


func _cave_tree(origin: Vector2i, light: bool) -> void:
	var from := Vector2i(8, 2) if light else Vector2i(10, 2)
	for dx in 2:
		for dy in 3:
			var cell := origin + Vector2i(dx, dy)
			var atlas := from + Vector2i(dx, dy)
			if dy < 2:
				above.set_cell(cell, CAVE, atlas)
			else:
				walls.set_cell(cell, CAVE, atlas)


# ---------------------------------------------------------------- Pueblo

func _v(x: int, y: int) -> Vector2i:
	return Vector2i(OX + x, y)


func _rect(dict: Dictionary, x0: int, y0: int, x1: int, y1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			dict[_v(x, y)] = true


func _build_town() -> void:
	_rect(path, 0, 21, 91, 22)     # camino principal: puente → pueblo → portón
	_rect(path, 40, 17, 51, 26)    # plaza
	_rect(path, 33, 13, 34, 20)    # hacia el lago (trajineras)
	_rect(path, 45, 15, 46, 16)    # casa del centro
	_rect(path, 61, 13, 62, 20)    # panadería
	_rect(path, 53, 16, 54, 20)    # casa del este
	_rect(path, 45, 27, 46, 31)    # hacia el cementerio
	_rect(path, 39, 32, 52, 33)    # pasillo del cementerio
	_rect(water, 25, 4, 38, 12)    # lago de las trajineras

	for x in TOWN_W:
		for y in H:
			var c := _v(x, y)
			if water.has(c):
				ground.set_cell(c, WATER, _water_tile(c))
			elif path.has(c):
				ground.set_cell(c, FLOOR, _path_tile(c))
			else:
				ground.set_cell(c, FLOOR, _grass_tile())

	_place_buildings()
	_place_trees()
	_place_decoration()


func _grass_tile() -> Vector2i:
	if rng.randf() < 0.82:
		return Vector2i(0, 12)
	var variants := [Vector2i(1, 12), Vector2i(2, 12), Vector2i(3, 12), Vector2i(4, 12), Vector2i(2, 11), Vector2i(3, 11)]
	return variants[rng.randi_range(0, variants.size() - 1)]


func _path_tile(c: Vector2i) -> Vector2i:
	# Si el camino toca el borde izquierdo del pueblo, se continúa como si siguiera.
	var n := path.has(c + Vector2i.UP)
	var s := path.has(c + Vector2i.DOWN)
	var w := path.has(c + Vector2i.LEFT) or c.x == OX
	var e := path.has(c + Vector2i.RIGHT)
	if n and s and w and e:
		if not path.has(c + Vector2i(1, 1)): return Vector2i(5, 8)
		if not path.has(c + Vector2i(-1, 1)) and c.x != OX: return Vector2i(6, 8)
		if not path.has(c + Vector2i(1, -1)): return Vector2i(5, 9)
		if not path.has(c + Vector2i(-1, -1)) and c.x != OX: return Vector2i(6, 9)
		return Vector2i(1, 8)
	if not n and not w: return Vector2i(0, 7)
	if not n and not e: return Vector2i(2, 7)
	if not s and not w: return Vector2i(0, 9)
	if not s and not e: return Vector2i(2, 9)
	if not n: return Vector2i(1, 7)
	if not s: return Vector2i(1, 9)
	if not w: return Vector2i(0, 8)
	if not e: return Vector2i(2, 8)
	return Vector2i(1, 8)


func _water_tile(c: Vector2i) -> Vector2i:
	var n := water.has(c + Vector2i.UP)
	var s := water.has(c + Vector2i.DOWN)
	var w := water.has(c + Vector2i.LEFT)
	var e := water.has(c + Vector2i.RIGHT)
	if not n and not w: return Vector2i(0, 6)
	if not n and not e: return Vector2i(2, 6)
	if not s and not w: return Vector2i(0, 8)
	if not s and not e: return Vector2i(2, 8)
	if not n: return Vector2i(1, 6)
	if not s: return Vector2i(1, 8)
	if not w: return Vector2i(0, 7)
	if not e: return Vector2i(2, 7)
	return Vector2i(1, 7)


func _stamp(layer: TileMapLayer, source: int, origin: Vector2i, atlas_from: Vector2i, size: Vector2i, mark_blocked := true) -> void:
	for dx in size.x:
		for dy in size.y:
			var cell := origin + Vector2i(dx, dy)
			layer.set_cell(cell, source, atlas_from + Vector2i(dx, dy))
			if mark_blocked:
				blocked[cell] = true


func _place_buildings() -> void:
	_stamp(walls, HOUSE, _v(44, 12), Vector2i(4, 0), Vector2i(4, 3))
	_stamp(walls, HOUSE, _v(52, 13), Vector2i(0, 0), Vector2i(4, 3))
	_stamp(walls, HOUSE, _v(27, 25), Vector2i(12, 0), Vector2i(4, 3))
	_stamp(walls, HOUSE, _v(66, 25), Vector2i(8, 0), Vector2i(4, 3))
	_stamp(walls, HOUSE, _v(60, 10), Vector2i(16, 0), Vector2i(3, 3))   # panadería
	_stamp(walls, BOAT, _v(27, 6), Vector2i(0, 0), Vector2i(5, 2))       # trajineras
	_stamp(walls, BOAT, _v(31, 9), Vector2i(0, 0), Vector2i(5, 2))
	var stones := [Vector2i(4, 2), Vector2i(3, 2), Vector2i(5, 2)]
	for row in [35, 38]:
		for col in range(39, 53, 3):
			var c := _v(col, row)
			walls.set_cell(c, ELEMENT, stones[rng.randi_range(0, 2)])
			blocked[c] = true
	_stamp(above, HOUSE, _v(89, 19), Vector2i(0, 5), Vector2i(3, 2), false)   # torii del portón
	_stamp(walls, HOUSE, _v(86, 19), Vector2i(28, 20), Vector2i(1, 2))
	_stamp(walls, HOUSE, _v(86, 23), Vector2i(28, 20), Vector2i(1, 2))
	_rect(blocked, 84, 17, 91, 26)
	_rect(blocked, 0, 18, 8, 25)      # entrada del pueblo (cartel de bienvenida)


func _free(c: Vector2i, size: Vector2i, margin := 1) -> bool:
	for dx in range(-margin, size.x + margin):
		for dy in range(-margin, size.y + margin):
			var cell := c + Vector2i(dx, dy)
			if cell.x < OX or path.has(cell) or water.has(cell) or blocked.has(cell):
				return false
	return true


func _tree(c: Vector2i, kind: String, margin := 1, solid := false) -> bool:
	var specs := {
		"dead": [Vector2i(4, 0), Vector2i(2, 2)],
		"pine": [Vector2i(2, 0), Vector2i(2, 2)],
		"round": [Vector2i(0, 0), Vector2i(2, 2)],
		"autumn": [Vector2i(9, 18), Vector2i(3, 3)],
		"big": [Vector2i(4, 18), Vector2i(2, 3)],
	}
	var from: Vector2i = specs[kind][0]
	var size: Vector2i = specs[kind][1]
	if not _free(c, size, margin):
		return false
	for dx in size.x:
		for dy in size.y:
			var cell := c + Vector2i(dx, dy)
			var atlas := from + Vector2i(dx, dy)
			if dy < size.y - 1 and not solid:
				above.set_cell(cell, NATURE, atlas)
			else:
				walls.set_cell(cell, NATURE, atlas)
			blocked[cell] = true
	return true


func _place_trees() -> void:
	# Borde del pueblo (sólido). A la izquierda queda un hueco para el puente.
	for x in range(0, TOWN_W, 2):
		_tree(_v(x, 0), "pine" if x % 4 == 0 else "dead", 0, true)
		_tree(_v(x, H - 2), "pine" if x % 4 == 2 else "dead", 0, true)
	for y in range(2, H - 2, 2):
		if y < 20 or y > 22:
			_tree(_v(0, y), "dead" if y % 4 == 0 else "pine", 0, true)
		_tree(_v(TOWN_W - 2, y), "dead" if y % 4 == 2 else "pine", 0, true)
	# Arboleda a la entrada (más ligera que antes)
	for i in 70:
		var c := _v(rng.randi_range(2, 20), rng.randi_range(2, H - 4))
		if abs(c.y - 21) < 4:
			continue
		_tree(c, "dead" if rng.randf() < 0.65 else "pine", 0)
	var town_trees := [
		[41, 6, "autumn"], [50, 5, "round"], [56, 6, "autumn"], [68, 8, "big"], [74, 13, "autumn"],
		[70, 17, "round"], [24, 15, "round"], [36, 28, "autumn"], [57, 28, "big"], [78, 27, "round"],
		[80, 9, "autumn"], [62, 33, "dead"], [34, 36, "dead"], [76, 34, "autumn"], [25, 33, "round"],
	]
	for t in town_trees:
		_tree(_v(t[0], t[1]), t[2])
	for i in 60:
		_tree(_v(rng.randi_range(70, TOWN_W - 4), rng.randi_range(3, H - 5)), ["round", "autumn", "dead"][rng.randi_range(0, 2)])


func _place_decoration() -> void:
	for x in TOWN_W:
		for y in H:
			var c := _v(x, y)
			if water.has(c) or blocked.has(c):
				continue
			if path.has(c):
				if rng.randf() < 0.12:
					deco.set_cell(c, DETAIL, Vector2i(1, 0))
				continue
			var r := rng.randf()
			var in_town := x >= 23 and x <= 84
			if in_town and r < 0.05:
				deco.set_cell(c, DETAIL, Vector2i(4, 0))
			elif in_town and r < 0.07:
				deco.set_cell(c, DETAIL, Vector2i(2, 0))
			elif r < 0.10:
				deco.set_cell(c, DETAIL, [Vector2i(2, 2), Vector2i(3, 2)][rng.randi_range(0, 1)])
	for p in [[41, 34], [47, 37], [50, 34], [43, 39], [52, 39]]:
		deco.set_cell(_v(p[0], p[1]), DETAIL, Vector2i(13, 0))
	for p in [[44, 36], [49, 39], [40, 37]]:
		deco.set_cell(_v(p[0], p[1]), DETAIL, Vector2i(14, 0))


# ---------------------------------------------------------------- Marcadores

func _add_markers(root: Node2D) -> void:
	var markers := Node2D.new()
	markers.name = "Markers"
	root.add_child(markers)
	markers.owner = root
	var spots := {
		"Player": Vector2(4 * T, 17 * T + 14),           # en la almohada de la cama
		"Guide": Vector2(11 * T + 8, 22 * T + 14),       # junto a la puerta del cuarto
		"Skeleton": Vector2(34 * T + 8, 21 * T + 14),    # a la mitad del pasillo
		"Sign": Vector2((OX + 4) * T + 8, 20 * T + 14),  # entrada del pueblo
		"Mercader": Vector2((OX + 36) * T + 8, 14 * T + 14),
		"Cocinero": Vector2((OX + 64) * T + 8, 14 * T + 14),
		"Panteonero": Vector2((OX + 48) * T + 8, 32 * T + 14),
		"Gate": Vector2((OX + 90) * T + 8, 22 * T + 14),
	}
	for marker_name in spots:
		var m := Marker2D.new()
		m.name = marker_name
		m.position = spots[marker_name]
		markers.add_child(m)
		m.owner = root


# ================================================================== Animaciones

func build_sprite_frames() -> void:
	# Protagonista: hoja de 6×4 cuadros de 16×16.
	#   columna 0 = abajo, columna 1 = arriba (4 cuadros hacia abajo)
	#   fila 0, columnas 2-5 = derecha · fila 1, columnas 2-5 = izquierda
	var hero: Texture2D = load("res://player/sprites/protagonista.png")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_anim(sf, hero, "idle_down", [Vector2i(0, 0)], 16, Vector2i.ZERO, 1.0)
	_anim(sf, hero, "idle_up", [Vector2i(1, 0)], 16, Vector2i.ZERO, 1.0)
	_anim(sf, hero, "idle_right", [Vector2i(2, 0)], 16, Vector2i.ZERO, 1.0)
	_anim(sf, hero, "idle_left", [Vector2i(2, 1)], 16, Vector2i.ZERO, 1.0)
	_anim(sf, hero, "walk_down", [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)], 16, Vector2i.ZERO, 8.0)
	_anim(sf, hero, "walk_up", [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)], 16, Vector2i.ZERO, 8.0)
	_anim(sf, hero, "walk_right", [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)], 16, Vector2i.ZERO, 8.0)
	_anim(sf, hero, "walk_left", [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)], 16, Vector2i.ZERO, 8.0)
	ResourceSaver.save(sf, "res://player/sprites/protagonista_frames.tres")

	# Guía (mago): cuadros de 48×48, 4 por fila.
	#   filas 0-3 = quieto (abajo, arriba, izquierda, derecha) · filas 4-7 = caminar
	var wiz: Texture2D = load("res://world/npcs/sprites/guia_mago.png")
	sf = SpriteFrames.new()
	sf.remove_animation("default")
	var dirs := ["down", "up", "left", "right"]
	for i in 4:
		_anim(sf, wiz, "idle_" + dirs[i], _row(i), 48, Vector2i.ZERO, 5.0)
		_anim(sf, wiz, "walk_" + dirs[i], _row(4 + i), 48, Vector2i.ZERO, 8.0)
	ResourceSaver.save(sf, "res://world/npcs/sprites/guia_frames.tres")

	# Esqueleto: 4×4 cuadros de 16×16; columna 1 = de frente.
	var skel: Texture2D = load("res://world/npcs/sprites/esqueleto.png")
	sf = SpriteFrames.new()
	sf.remove_animation("default")
	_anim(sf, skel, "idle_down", [Vector2i(1, 0), Vector2i(1, 2)], 16, Vector2i.ZERO, 2.0)
	ResourceSaver.save(sf, "res://world/npcs/sprites/esqueleto_frames.tres")

	# Cartel de bienvenida: poste del TilesetElement (16×32), recorrido para que la base quede en los pies.
	var element: Texture2D = load("res://common/art/ninja/tilesets/TilesetElement.png")
	sf = SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("idle_down")
	var at := AtlasTexture.new()
	at.atlas = element
	at.region = Rect2(6 * 16, 3 * 16, 16, 32)
	at.margin = Rect2(0, 0, 0, 16)
	sf.add_frame("idle_down", at)
	ResourceSaver.save(sf, "res://world/npcs/sprites/cartel_frames.tres")


func _row(r: int) -> Array:
	return [Vector2i(0, r), Vector2i(1, r), Vector2i(2, r), Vector2i(3, r)]


func _anim(sf: SpriteFrames, tex: Texture2D, anim: String, cells: Array, size: int, _unused: Vector2i, fps: float) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, true)
	for c in cells:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(c.x * size, c.y * size, size, size)
		sf.add_frame(anim, at)
