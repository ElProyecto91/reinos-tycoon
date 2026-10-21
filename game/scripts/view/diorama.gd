extends Node3D
## Vista 3D de una provincia: un diorama de casillas hexagonales con edificios de poco polígono.
## Solo dibuja: no calcula nada del juego ni lo cambia (la simulación vive en scripts/sim).
## Modelos: "KayKit Medieval Hexagon Pack" (Kay Lousberg), licencia CC0; ver THIRD_PARTY_LICENSES.md.
##
## Medidas de las casillas (leídas de los archivos): hexágono con punta hacia delante y atrás,
## 2,0 de ancho entre lados planos, grosor 1,0 (la cara de arriba está a y = 0).
## Rejilla en coordenadas axiales (q, r): x = 2q + r, z = 1,732 r.
## Bordes de una casilla, contados en sentido contrario a las agujas del reloj mirando desde arriba:
## 0 = este, 1 = noreste, 2 = noroeste, 3 = oeste, 4 = suroeste, 5 = sureste.
## Girar un modelo 60° (rotation_degrees.y) mueve cada borde al siguiente (e -> e + 1).

const ROOT := "res://assets/kaykit/models/"
const ROW_H := 1.7320508
## Grosor de la capa de césped; debajo de ella cada casilla es un pilar de roca (acantilados).
const CAP := 0.2
const WATER_Y := -0.2

## Vecinos por borde (q, r).
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

# Modelos que usa la vista. Los edificios con color llevan "%s" para el bando (blue, green, red).
const MODELS := {
	"grass": "hex_grass",
	"water": "hex_water",
	"hills": "hills_A_trees",
	"hills_b": "hills_B_trees",
	"hills_c": "hills_C_trees",
	"mountain": "mountain_A_grass_trees",
	"mountain_b": "mountain_B_grass_trees",
	"mountain_c": "mountain_C_grass_trees",
	"trees_l": "trees_A_large",
	"trees_m": "trees_B_medium",
	"trees_s": "trees_A_small",
	"tree_a": "tree_single_A",
	"tree_b": "tree_single_B",
	"rock_a": "rock_single_A",
	"rock_b": "rock_single_C",
	"cloud": "cloud_big",
	"cloud_small": "cloud_small",
	"lily_a": "waterlily_A",
	"lily_b": "waterlily_B",
	"plant_a": "waterplant_A",
	"grain": "building_grain",
	"scaffold": "building_scaffolding",
	"stage_a": "building_stage_A",
	"stage_b": "building_stage_B",
	"dirt": "building_dirt",
	"wall": "wall_straight",
	"wall_gate": "wall_straight_gate",
	"wall_corner": "wall_corner_A_outside",
	"wall_corner_in": "wall_corner_A_inside",
	"fence": "fence_wood_straight",
	"crate": "crate_A_big",
	"crate_b": "crate_B_big",
	"barrel": "barrel",
	"sack": "sack",
	"wheelbarrow": "wheelbarrow",
	"lumber": "resource_lumber",
	"stone": "resource_stone",
	"tent": "tent",
	"flag": "flag_%s",
	"home_a": "building_home_A_%s",
	"home_b": "building_home_B_%s",
	"tavern": "building_tavern_%s",
	"church": "building_church_%s",
	"castle": "building_castle_%s",
	"market": "building_market_%s",
	"windmill": "building_windmill_%s",
	"watermill": "building_watermill_%s",
	"lumbermill": "building_lumbermill_%s",
	"well": "building_well_%s",
	"tower": "building_tower_A_%s",
	"tower_b": "building_tower_B_%s",
	"barracks": "building_barracks_%s",
	"blacksmith": "building_blacksmith_%s",
	"mine": "building_mine_%s",
}

# Conexiones de cada casilla de río, camino y costa SIN girar (bordes, ver arriba). Salen de leer la
# geometría de los modelos y comprobarla a ojo con una hoja de contactos.
const RIVER_TILES := {
	"hex_river_A": [0, 3], "hex_river_A_curvy": [0, 3], "hex_river_B": [1, 3], "hex_river_C": [2, 3],
	"hex_river_D": [1, 3, 5], "hex_river_E": [0, 1, 3], "hex_river_F": [0, 3, 5], "hex_river_G": [2, 3, 4],
	"hex_river_H": [0, 2, 3, 4], "hex_river_I": [1, 2, 4, 5], "hex_river_J": [0, 3, 4, 5],
	"hex_river_K": [1, 2, 3, 4, 5], "hex_river_L": [0, 1, 2, 3, 4, 5],
}
const ROAD_TILES := {
	"hex_road_A": [0, 3], "hex_road_B": [1, 3], "hex_road_C": [2, 3], "hex_road_D": [1, 3, 5],
	"hex_road_E": [0, 1, 3], "hex_road_F": [0, 3, 5], "hex_road_G": [2, 3, 4], "hex_road_H": [0, 2, 3, 4],
	"hex_road_I": [1, 2, 4, 5], "hex_road_J": [0, 3, 4, 5], "hex_road_K": [1, 2, 3, 4, 5],
	"hex_road_L": [0, 1, 2, 3, 4, 5], "hex_road_M": [3],
}
## Casillas de orilla: los bordes que dan al agua.
const COAST_TILES := {
	"hex_coast_A": [5], "hex_coast_B": [4, 5], "hex_coast_C": [0, 4, 5], "hex_coast_D": [0, 1, 4, 5],
}
const CROSSING_TILES := {"hex_river_crossing_A": [0, 3], "hex_river_crossing_B": [0, 3]}
## Cada pieza de muralla recta se ve por una cara (la de fuera) hacia +z cuando no está girada.
const WALL_STRAIGHT := [0, 3]
const WALL_CORNER := [3, 1]

# Símbolos permitidos en las tres capas del diorama.
const TERRAIN_SYMBOLS := "w012"                    # agua, o suelo con 0, 1 o 2 niveles de altura
const PATH_SYMBOLS := ".rRcCmgb"                   # nada, río, camino, muralla, puerta, puente (ver _path_ground)
const THING_SYMBOLS := ".ThtsHMNQFWLCoOEYSDRxXyzKVZIUJlPG"  # ver _thing()

var faction := "blue"
## Pone una torre en cada esquina de la muralla.
var wall_towers := true
var _cache := {}
var _rock: StandardMaterial3D
var _cells := {}      # Vector2i -> {"t": terreno, "p": camino, "o": objeto, "h": altura}


## Posición en el mundo del centro de la casilla (q, r) a la altura y.
static func hex_to_world(q: int, r: int, y: float = 0.0) -> Vector3:
	return Vector3(2.0 * q + r, y, ROW_H * r)


## Convierte un diseño dado por coordenadas axiales en las tres capas de texto.
## cells: {Vector2i(q, r): {"t": terreno, "p": camino, "o": objeto}} (lo que falte vale "0", ".", ".").
static func layers_from_cells(radius: int, cells: Dictionary) -> Dictionary:
	var terrain: Array = []
	var paths: Array = []
	var things: Array = []
	for r in range(-radius, radius + 1):
		var t := ""
		var p := ""
		var o := ""
		for q in range(maxi(-radius, -radius - r), mini(radius, radius - r) + 1):
			var c: Dictionary = cells.get(Vector2i(q, r), {})
			t += str(c.get("t", "0"))
			p += str(c.get("p", "."))
			o += str(c.get("o", "."))
		terrain.append(t)
		paths.append(p)
		things.append(o)
	var errors: Array[String] = []
	for key in cells.keys():
		var q: int = key.x
		var r: int = key.y
		if maxi(maxi(absi(q), absi(r)), absi(q + r)) > radius:
			errors.append("la casilla (%d, %d) está fuera del radio %d" % [q, r, radius])
	return {"terrain": terrain, "paths": paths, "things": things, "errors": errors}


func model(key: String) -> PackedScene:
	var file: String = MODELS[key]
	if file.contains("%s"):
		file = file % faction
	return file_model(file)


func file_model(file: String) -> PackedScene:
	if _cache.has(file):
		return _cache[file]
	var scene := load(ROOT + file + ".gltf") as PackedScene
	_cache[file] = scene
	return scene


## Pone un modelo por su clave de MODELS; rot_deg gira sobre el eje vertical.
func place(key: String, pos: Vector3, rot_deg: float = 0.0, scale_factor: float = 1.0) -> Node3D:
	return _put(model(key), key, pos, rot_deg, scale_factor)


## Pone un modelo por el nombre de su archivo (casillas de río, camino, costa…).
func place_file(file: String, pos: Vector3, rot_deg: float = 0.0) -> Node3D:
	return _put(file_model(file), file, pos, rot_deg, 1.0)


func _put(scene: PackedScene, label: String, pos: Vector3, rot_deg: float, scale_factor: float) -> Node3D:
	if scene == null:
		push_error("Falta el modelo: " + label)
		return null
	var node := scene.instantiate() as Node3D
	node.position = pos
	node.rotation_degrees.y = rot_deg
	node.scale = Vector3.ONE * scale_factor
	add_child(node)
	return node


## Comprueba que las capas describen un hexágono grande de radio R: 2R+1 filas, y la fila
## con r = i - R tiene 2R+1-|r| casillas. paths puede ser una lista vacía (sin caminos ni ríos).
## Devuelve la lista de errores (vacía si todo está bien).
static func validate(terrain: Array, things: Array, paths: Array = []) -> Array[String]:
	var errors: Array[String] = []
	if terrain.size() % 2 == 0:
		errors.append("el número de filas debe ser impar (hexágono de radio R: 2R+1 filas); hay %d" % terrain.size())
		return errors
	if things.size() != terrain.size():
		errors.append("el terreno tiene %d filas y los objetos %d" % [terrain.size(), things.size()])
		return errors
	if not paths.is_empty() and paths.size() != terrain.size():
		errors.append("el terreno tiene %d filas y los caminos %d" % [terrain.size(), paths.size()])
		return errors
	var radius := (terrain.size() - 1) / 2
	for i in terrain.size():
		var expected := 2 * radius + 1 - absi(i - radius)
		var t: String = terrain[i]
		var o: String = things[i]
		var p: String = paths[i] if not paths.is_empty() else ".".repeat(expected)
		if t.length() != expected:
			errors.append("fila %d del terreno: debe tener %d casillas y tiene %d" % [i, expected, t.length()])
		if o.length() != expected:
			errors.append("fila %d de objetos: debe tener %d casillas y tiene %d" % [i, expected, o.length()])
		if p.length() != expected:
			errors.append("fila %d de caminos: debe tener %d casillas y tiene %d" % [i, expected, p.length()])
		for c in t:
			if not TERRAIN_SYMBOLS.contains(c):
				errors.append("fila %d del terreno: símbolo «%s» desconocido" % [i, c])
		for c in o:
			if not THING_SYMBOLS.contains(c):
				errors.append("fila %d de objetos: símbolo «%s» desconocido" % [i, c])
		for c in p:
			if not PATH_SYMBOLS.contains(c):
				errors.append("fila %d de caminos: símbolo «%s» desconocido" % [i, c])
	return errors


## Construye el diorama. terrain, things y paths son listas de textos, una por fila (de arriba abajo,
## la primera tiene r = -R), cada una con las casillas q de menor a mayor.
## Si el diseño no es válido no construye nada y devuelve false.
func build(terrain: Array, things: Array, paths: Array = []) -> bool:
	var errors := validate(terrain, things, paths)
	if not errors.is_empty():
		push_error("Diorama no válido: " + "; ".join(errors))
		return false
	var radius := (terrain.size() - 1) / 2
	_cells.clear()
	for i in terrain.size():
		var r := i - radius
		var q0 := maxi(-radius, -radius - r)
		var t: String = terrain[i]
		for j in t.length():
			_cells[Vector2i(q0 + j, r)] = {
				"t": t[j], "o": (things[i] as String)[j],
				"p": ((paths[i] as String)[j] if not paths.is_empty() else "."),
				"h": _height(t[j]),
			}
	for key in _cells.keys():
		_build_cell(key)
	return true


func _height(c: String) -> int:
	if c == "w":
		return 0
	return int(c) if c.is_valid_int() else 0


# ---------------------------------------------------------------------------------------------
# Suelo

func _build_cell(key: Vector2i) -> void:
	var c: Dictionary = _cells[key]
	var q := key.x
	var r := key.y
	var h: int = c["h"]
	if c["t"] == "w":
		place_file("hex_water", hex_to_world(q, r))
		_thing(q, r, c["o"], WATER_Y)
		return
	var ground := _path_ground(key, c)
	_ground(ground[0], q, r, h, ground[1])
	_path_extra(key, c, h)
	_thing(q, r, c["o"], float(h))


## Elige la casilla de suelo: río, camino, orilla o césped. Devuelve [archivo, giro en grados].
func _path_ground(key: Vector2i, c: Dictionary) -> Array:
	var p: String = c["p"]
	match p:
		"r", "R":
			var mask := _connections(key, "rR", true, p == "R")
			if mask.size() >= 2:
				return _pick(RIVER_TILES, mask, key)
			return ["hex_grass", 0.0] if mask.is_empty() else ["hex_water", 0.0]
		"c", "C":
			return _pick(ROAD_TILES, _connections(key, "cCg", false, p == "C"), key)
		"g":
			# Camino bajo la puerta: sale por los bordes que no son los de la muralla.
			var wall := _connections(key, "mg", false, false)
			var mask: Array = []
			for e in _connections(key, "cC", false, false):
				if not wall.has(e):
					mask.append(e)
			if mask.is_empty():
				return ["hex_grass", 0.0]
			return _pick(ROAD_TILES, mask, key)
		"b":
			var mask := _connections(key, "rR", true, false)
			if mask.size() >= 2:
				return _pick(CROSSING_TILES, mask, key)
			return ["hex_grass", 0.0]
	# Orilla: césped con agua en uno o varios bordes seguidos.
	var water: Array = []
	for e in 6:
		var n: Vector2i = key + DIRS[e]
		if _cells.has(n) and _cells[n]["t"] == "w":
			water.append(e)
	if not water.is_empty():
		var picked := _pick(COAST_TILES, water, key)
		if picked[0] != "hex_grass":
			return picked
	return ["hex_grass", 0.0]


## Bordes de la casilla que se conectan con vecinas cuyo símbolo de camino está en kinds
## (o con agua del terreno si with_water). Si open_ends, un borde que da fuera del mapa
## continúa la línea recta de un borde ya conectado.
func _connections(key: Vector2i, kinds: String, with_water: bool, open_ends: bool) -> Array:
	var mask: Array = []
	for e in 6:
		var n: Vector2i = key + DIRS[e]
		if not _cells.has(n):
			continue
		var cell: Dictionary = _cells[n]
		if kinds.contains(cell["p"]) and cell["p"] != ".":
			mask.append(e)
		elif with_water and cell["t"] == "w":
			mask.append(e)
	if open_ends:
		for e in mask.duplicate():
			var opposite: int = (e + 3) % 6
			if not _cells.has(key + DIRS[opposite]) and not mask.has(opposite):
				mask.append(opposite)
	mask.sort()
	return mask


## Busca entre las casillas la que, girada, tiene exactamente las conexiones de mask.
## Si hay varias (por ejemplo dos ríos rectos) elige una según la posición, sin azar.
func _pick(tiles: Dictionary, mask: Array, key: Vector2i) -> Array:
	var matches: Array = []
	for file in tiles.keys():
		var base: Array = tiles[file]
		if base.size() != mask.size():
			continue
		for k in 6:
			var rotated: Array = []
			for e in base:
				rotated.append((e + k) % 6)
			rotated.sort()
			if rotated == mask:
				matches.append([file, 60.0 * k])
				break
	if matches.is_empty():
		return ["hex_grass", 0.0]
	return matches[posmod(key.x * 5 + key.y * 3, matches.size())]


## Pone una pieza de suelo: una capa fina de césped sobre un pilar de roca hasta el fondo.
func _ground(file: String, q: int, r: int, h: int, rot: float) -> void:
	var piece := place_file(file, hex_to_world(q, r, float(h)), rot)
	if piece == null:
		return
	piece.scale.y = CAP
	var depth := float(h) - CAP + 1.0
	var pillar := place_file("hex_grass", hex_to_world(q, r, float(h) - CAP), 0.0)
	pillar.scale = Vector3(1.0, depth, 1.0)
	_set_material(pillar, _rock_material(q, r))


func _rock_material(q: int, r: int) -> StandardMaterial3D:
	if _rock == null:
		_rock = StandardMaterial3D.new()
		_rock.albedo_color = Color(0.46, 0.40, 0.34)
		_rock.roughness = 1.0
	# Un poco de variación según la casilla, sin azar.
	var shade := 0.92 + 0.08 * float(posmod(q * 3 + r * 7, 5)) / 4.0
	var mat := _rock.duplicate() as StandardMaterial3D
	mat.albedo_color = _rock.albedo_color * shade
	return mat


func _set_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_set_material(child, mat)


## Muralla, puente y otros elementos que van sobre el suelo de la casilla.
func _path_extra(key: Vector2i, c: Dictionary, h: int) -> void:
	var p: String = c["p"]
	if p != "m" and p != "g":
		return
	var pos := hex_to_world(key.x, key.y, float(h))
	var mask := _connections(key, "mg", false, false)
	var outward := _outward(key)
	var corner := false
	var rot := 0.0
	var file := "wall"
	if mask.size() == 2 and (mask[1] - mask[0]) in [2, 4]:
		corner = true
		file = "wall_corner"
		for k in 6:
			var rotated: Array = []
			for e in WALL_CORNER:
				rotated.append((e + k) % 6)
			rotated.sort()
			if rotated == mask:
				rot = 60.0 * k
				break
	else:
		if p == "g":
			file = "wall_gate"
		if mask.size() >= 1:
			rot = 60.0 * float(mask[0] % 3)
		# De las dos orientaciones posibles, la cara buena mira hacia fuera.
		var normal := Vector3(sin(deg_to_rad(rot)), 0.0, cos(deg_to_rad(rot)))
		if normal.dot(outward) < 0.0:
			rot += 180.0
	place(file, pos, rot)
	if corner and wall_towers:
		place("tower", pos + outward.normalized() * 0.25, 0.0)


## Dirección desde el centro de la muralla hacia la casilla (para saber qué lado es el de fuera).
func _outward(key: Vector2i) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for k in _cells.keys():
		if _cells[k]["p"] == "m" or _cells[k]["p"] == "g":
			sum += hex_to_world(k.x, k.y)
			n += 1
	if n == 0:
		return Vector3(0, 0, 1)
	var center := sum / float(n)
	var d := hex_to_world(key.x, key.y) - center
	d.y = 0.0
	return d if d.length() > 0.01 else Vector3(0, 0, 1)


# ---------------------------------------------------------------------------------------------
# Objetos

func _rot(q: int, r: int) -> float:
	# Giro fijo según la casilla, para que no se repita igual todo (sin azar: siempre igual).
	return 60.0 * float(posmod(q * 7 + r * 13, 6))


func _thing(q: int, r: int, o: String, y: float) -> void:
	var p := hex_to_world(q, r, y)
	var rot := _rot(q, r)
	match o:
		".":
			pass
		"T":
			place("trees_l", p, rot)
		"t":
			place("trees_m", p, rot)
		"s":
			place("trees_s", p, rot)
		"h":
			place("hills", p, rot)
		"H":
			place("hills_b", p, rot)
		"M":
			place("mountain", p, rot)
		"N":
			place("mountain_b", p, rot)
		"Q":
			place("mountain_c", p, rot)
		"F":
			place("grain", p, 0.0)
		"W":
			place("windmill", p, rot)
		"V":
			place("watermill", p, rot)
		"L":
			place("lumbermill", p + Vector3(-0.3, 0, 0.2), 30.0)
			place("tree_a", p + Vector3(0.7, 0, -0.6))
			place("tree_b", p + Vector3(0.5, 0, 0.6))
			place("lumber", p + Vector3(-0.1, 0, 0.8), 80.0, 1.3)
		"C":
			place("castle", p, 0.0)
		"o":
			place("home_a", p + Vector3(-0.55, 0, -0.4), 20.0)
			place("home_b", p + Vector3(0.6, 0, -0.3), -15.0)
			place("home_a", p + Vector3(0.0, 0, 0.6), 180.0)
		"O":
			place("home_b", p + Vector3(-0.6, 0, -0.5), 10.0)
			place("home_a", p + Vector3(0.6, 0, -0.5), -10.0)
			place("home_a", p + Vector3(-0.6, 0, 0.5), 170.0)
			place("home_b", p + Vector3(0.6, 0, 0.5), 200.0)
			place("well", p, 0.0)
		"E":
			place("market", p + Vector3(-0.5, 0, 0.0), 90.0)
			place("tavern", p + Vector3(0.6, 0, 0.0), -90.0)
		"Y":
			place("church", p, 0.0)
		"S":
			place("scaffold", p, rot)
		"D":
			place("dirt", p, 0.0)
			place("stage_a", p + Vector3(0.2, 0, 0.2), 40.0)
		"R":
			place("rock_a", p + Vector3(0.2, 0, 0.2), rot, 2.0)
			place("rock_b", p + Vector3(-0.5, 0, -0.3), rot, 2.0)
		"x":
			place("wall", p, 0.0)
		"X":
			place("wall_gate", p, 0.0)
		"y":
			place("wall", p, 60.0)
		"z":
			place("wall", p, 120.0)
		"K":
			place("tower", p, 0.0)
		"Z":
			place("blacksmith", p, 20.0)
		"I":
			place("barracks", p, 0.0)
		"U":
			place("mine", p, 0.0)
		"J":
			# Puesto con mercancías: cajas, barriles, sacos y una carretilla.
			place("crate", p + Vector3(-0.5, 0, -0.3), 20.0, 1.8)
			place("barrel", p + Vector3(0.4, 0, -0.5), 0.0, 1.8)
			place("sack", p + Vector3(0.6, 0, 0.3), 40.0, 1.8)
			place("wheelbarrow", p + Vector3(-0.4, 0, 0.5), 200.0, 1.8)
		"l":
			place("lily_a", p + Vector3(-0.3, 0, 0.2), 0.0, 3.0)
			place("lily_b", p + Vector3(0.4, 0, -0.3), 90.0, 3.0)
		"P":
			place("tent", p + Vector3(-0.4, 0, -0.2), 30.0, 1.8)
			place("tent", p + Vector3(0.5, 0, 0.3), -40.0, 1.8)
			place("flag", p + Vector3(0.0, 0, -0.6), 0.0, 2.5)
		"G":
			# Corral: cercado de madera con un árbol dentro.
			for k in 6:
				var a := deg_to_rad(60.0 * k + 30.0)
				place("fence", p + Vector3(cos(a), 0, -sin(a)) * 0.82, 60.0 * k + 30.0 + 90.0, 0.78)
			place("tree_a", p, rot)
		_:
			push_warning("Símbolo desconocido en el diorama: " + o)
