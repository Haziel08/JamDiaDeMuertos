extends SceneTree
## Genera el TileSet, el mapa completo (claro → bosque y río → pueblo) y las animaciones.
## Uso (desde la carpeta del proyecto):  godot --headless -s res://tools/generate_world.gd

const T := 16
const OX := 64          # el pueblo empieza en esta columna
const TOWN_W := 96
const W := OX + TOWN_W
const H := 44

enum { FLOOR = 0, WATER = 1, NATURE = 2, HOUSE = 3, ELEMENT = 4, DETAIL = 5, BOAT = 6, ISLAND = 7,
		WATER_ANIM = 8, CAVE = 9, WATER_BASE = 13, BRIDGE = 14, SHORE = 15, BLOCK = 16 }

const SOURCES := {
	FLOOR: "res://common/art/ninja/tilesets/TilesetFloor.png",
	WATER: "res://common/art/ninja/tilesets/TilesetWater.png",
	NATURE: "res://common/art/ninja/tilesets/TilesetNature.png",
	HOUSE: "res://common/art/ninja/tilesets/TilesetHouse.png",
	ELEMENT: "res://common/art/ninja/tilesets/TilesetElement.png",
	DETAIL: "res://common/art/ninja/tilesets/TilesetFloorDetail.png",
	BOAT: "res://common/art/ninja/vehicles/Boat.png",
	ISLAND: "res://common/art/custom/tiles_isla_orilla.png",
	WATER_ANIM: "res://common/art/custom/agua_animada.png",
	CAVE: "res://common/art/custom/tiles_cueva.png",
	WATER_BASE: "res://common/art/custom/agua_animada.png",
	BRIDGE: "res://common/art/custom/puente_piedra.png",
	SHORE: "res://common/art/custom/orilla_lago.png",
	BLOCK: "res://common/art/custom/bloqueo.png",   # invisible: solo choca
}

# Zona de inicio (al aire libre) y camino hacia el pueblo
const CLEARING := Vector2(11, 21)     # centro del claro donde despierta el jugador
const PATH_TOP := 19                 # el camino del bosque va de la fila 19 a la 24
const PATH_BOTTOM := 24
const RIVER_X0 := 40                 # río (solo una parte del camino tiene agua)
const RIVER_X1 := 45
const BRIDGE_Y0 := 20                # puente de piedra: barandal 20, piso 21-22, barandal 23
const BRIDGE_Y1 := 23

var rng := RandomNumberGenerator.new()
var ground: TileMapLayer
var deco: TileMapLayer
var walls: TileMapLayer
var above: TileMapLayer
var path := {}
var water := {}
var blocked := {}
var west_used := {}   # celdas ocupadas por árboles en el bosque del inicio
var water_base: TileMapLayer


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
		if id == BLOCK:
			src.create_tile(Vector2i(0, 0))
			_add_collision(src, Vector2i(0, 0), square)
			continue
		if id == WATER_ANIM or id == WATER_BASE:
			# Un solo tile animado de 4 cuadros. WATER_ANIM choca; WATER_BASE es solo
			# el fondo que se ve debajo de las orillas y el puente.
			src.create_tile(Vector2i(0, 0))
			src.set_tile_animation_frames_count(Vector2i(0, 0), 4)
			for f in 4:
				src.set_tile_animation_frame_duration(Vector2i(0, 0), f, 0.35)
			if id == WATER_ANIM:
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
		HOUSE, ELEMENT, BOAT, SHORE:
			return true
		BRIDGE:
			return c.y != 1          # barandales chocan, el piso se camina
		ISLAND:
			return c.y == 2 or c.y >= 3 and c.x <= 7   # acantilados y agua
		CAVE:
			return c.y < 8           # oscuridad, rocas y árboles (el pasto claro no choca)
	return false                     # FLOOR, DETAIL


# ================================================================== Mapa

func build_map(ts: TileSet) -> Node2D:
	var root := Node2D.new()
	root.name = "TownMap"
	water_base = _layer(root, "WaterBase", ts)
	water_base.collision_enabled = false
	ground = _layer(root, "Ground", ts)
	deco = _layer(root, "Decoration", ts)
	deco.collision_enabled = false
	walls = _layer(root, "Walls", ts)
	above = _layer(root, "Above", ts)
	above.collision_enabled = false
	above.z_index = 1

	_build_west()
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


# ---------------------------------------------------------------- Claro, bosque y río

func _is_open(c: Vector2i) -> bool:
	## Celdas por donde se camina en la zona de inicio: el claro y el camino al pueblo.
	var d := (Vector2(c) - CLEARING) / Vector2(7.5, 5.0)
	if d.length() <= 1.0:
		return true
	return c.x >= 15 and c.x < OX and c.y >= PATH_TOP and c.y <= PATH_BOTTOM


func _near_open(c: Vector2i) -> bool:
	## La copa de los árboles junto al camino deja pasar por detrás; las demás chocan.
	for d in [Vector2i.DOWN, Vector2i.DOWN * 2, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if _is_open(c + d):
			return true
	return false


func _is_river(x: int) -> bool:
	return x >= RIVER_X0 - 1 and x <= RIVER_X1 + 1     # incluye las dos orillas


func _build_west() -> void:
	var grass_details := [Vector2i(8, 1), Vector2i(9, 1), Vector2i(12, 3), Vector2i(13, 3), Vector2i(14, 3), Vector2i(13, 4)]
	for x in OX:
		for y in H:
			var c := Vector2i(x, y)
			if x >= RIVER_X0 and x <= RIVER_X1:
				ground.set_cell(c, WATER_ANIM, Vector2i(0, 0))          # el río choca
			elif x == RIVER_X0 - 1 or x == RIVER_X1 + 1:
				water_base.set_cell(c, WATER_BASE, Vector2i(0, 0))
				ground.set_cell(c, ISLAND, Vector2i(7, 1) if x < RIVER_X0 else Vector2i(5, 1))
			else:
				var tile := Vector2i(6, 1)
				if rng.randf() < 0.14:
					tile = grass_details[rng.randi_range(0, grass_details.size() - 1)]
				ground.set_cell(c, ISLAND, tile)

	# Puente de piedra: barandal arriba, dos filas de piso y barandal abajo.
	for x in range(RIVER_X0 - 1, RIVER_X1 + 2):
		var col := 0 if x == RIVER_X0 - 1 else (2 if x == RIVER_X1 + 1 else 1)
		for y in range(BRIDGE_Y0, BRIDGE_Y1 + 1):
			var row := 0 if y == BRIDGE_Y0 else (2 if y == BRIDGE_Y1 else 1)
			water_base.set_cell(Vector2i(x, y), WATER_BASE, Vector2i(0, 0))
			if row == 1:
				ground.set_cell(Vector2i(x, y), BRIDGE, Vector2i(col, row))
			else:
				walls.set_cell(Vector2i(x, y), BRIDGE, Vector2i(col, row))

	_plant_west_forest()

	# Flores de cempasúchil alrededor de donde despierta el jugador
	for p in [[8, 19], [14, 19], [7, 22], [15, 23], [10, 24], [13, 18], [6, 20], [16, 21]]:
		deco.set_cell(Vector2i(p[0], p[1]), ISLAND, [Vector2i(12, 3), Vector2i(13, 3), Vector2i(14, 3)][rng.randi_range(0, 2)])
	# Piedras sueltas a la orilla del camino
	for p in [[20, 19], [29, 24], [34, 19], [52, 24], [58, 19], [5, 23]]:
		walls.set_cell(Vector2i(p[0], p[1]), CAVE, [Vector2i(8, 0), Vector2i(9, 0), Vector2i(8, 1), Vector2i(9, 1)][rng.randi_range(0, 3)])
		west_used[Vector2i(p[0], p[1])] = true


func _plant_west_forest() -> void:
	## Bosque espeso alrededor del claro y del camino. Ningún árbol se encima con otro.
	var kinds := ["light", "dark", "light", "dark", "autumn", "dead"]
	for y in range(0, H - 1):
		for x in range(0, OX):
			var at_edge := x < 2 or y < 2 or y > H - 5
			if not at_edge and rng.randf() < 0.12:
				continue          # algún hueco para que no se vea como cuadrícula (nunca en las orillas)
			var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
			var size := Vector2i(3, 3) if kind == "autumn" else (Vector2i(2, 2) if kind == "dead" else Vector2i(2, 3))
			var o := Vector2i(x, y)
			if o.y + size.y > H or o.x + size.x > OX:
				continue
			if _west_free(o, size):
				_west_tree(o, kind, size)
	# Tapa cualquier hueco que quede en la orilla izquierda con piedras (chocan).
	var rocks := [Vector2i(8, 0), Vector2i(9, 0), Vector2i(8, 1), Vector2i(9, 1)]
	for y in H:
		for x in 4:
			var c := Vector2i(x, y)
			if not west_used.has(c) and not _is_open(c):
				walls.set_cell(c, CAVE, rocks[rng.randi_range(0, 3)])
				west_used[c] = true


func _west_free(o: Vector2i, size: Vector2i) -> bool:
	for dx in size.x:
		for dy in size.y:
			var c := o + Vector2i(dx, dy)
			if west_used.has(c) or _is_open(c) or _is_river(c.x):
				return false
	return true


func _west_tree(o: Vector2i, kind: String, size: Vector2i) -> void:
	var src := CAVE
	var from := Vector2i(8, 2)
	match kind:
		"dark": from = Vector2i(10, 2)
		"autumn":
			src = NATURE
			from = Vector2i(9, 18)
		"dead":
			src = NATURE
			from = Vector2i(4, 0)
	for dx in size.x:
		for dy in size.y:
			var cell := o + Vector2i(dx, dy)
			west_used[cell] = true
			if dy < size.y - 1:
				above.set_cell(cell, src, from + Vector2i(dx, dy))     # copa: tapa al jugador
				if not _near_open(cell):
					walls.set_cell(cell, BLOCK, Vector2i(0, 0))        # dentro del bosque no se puede pasar
			else:
				walls.set_cell(cell, src, from + Vector2i(dx, dy))     # tronco: choca


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
				# Misma agua animada que el río; la orilla del pack Ninja va encima.
				water_base.set_cell(c, WATER_BASE, Vector2i(0, 0))
				var t := _water_tile(c)
				if t == Vector2i(1, 7):
					ground.set_cell(c, WATER_ANIM, Vector2i(0, 0))
				else:
					ground.set_cell(c, SHORE, t - Vector2i(0, 6))
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
		"big": [Vector2i(3, 18), Vector2i(3, 3)],
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
		"Player": Vector2(CLEARING.x * T + 8, CLEARING.y * T + 12),   # dormido en el claro
		"Guide": Vector2(19 * T + 8, 22 * T + 14),                      # llega por el camino
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

	# Alma (enemigo): esqueleto de Dark Fantasy Monsters (jfranci_px), tiras de 4 cuadros de 16×16.
	#   El de lado mira a la izquierda; para la derecha el script lo voltea (flip_h).
	sf = SpriteFrames.new()
	sf.remove_animation("default")
	var strips := {
		"walk_down": ["movefront", 7.0, true], "walk_up": ["moveback", 7.0, true],
		"walk_side": ["moveside", 7.0, true], "attack": ["attackfront", 12.0, false],
		"death": ["deathfront", 8.0, false],
	}
	for anim in strips:
		var tex: Texture2D = load("res://world/enemies/sprites/esqueleto_%s.png" % strips[anim][0])
		_anim(sf, tex, anim, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], 16, Vector2i.ZERO, strips[anim][1])
		sf.set_animation_loop(anim, strips[anim][2])
	ResourceSaver.save(sf, "res://world/enemies/alma_frames.tres")

	# NPCs del pueblo (pack Ninja Adventure, CC0): columnas abajo, arriba, izquierda, derecha.
	for npc in ["dona_clara", "panadero", "panteonero"]:
		var tex: Texture2D = load("res://world/npcs/sprites/%s.png" % npc)
		sf = SpriteFrames.new()
		sf.remove_animation("default")
		var order := ["down", "up", "left", "right"]
		for i in 4:
			_anim(sf, tex, "idle_" + order[i], [Vector2i(i, 0)], 16, Vector2i.ZERO, 1.0)
			_anim(sf, tex, "walk_" + order[i], [Vector2i(i, 0), Vector2i(i, 1), Vector2i(i, 2), Vector2i(i, 3)], 16, Vector2i.ZERO, 8.0)
		ResourceSaver.save(sf, "res://world/npcs/sprites/%s_frames.tres" % npc)

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
