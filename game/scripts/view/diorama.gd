extends Node3D
## Vista 3D de una provincia: un diorama de casillas hexagonales con edificios de poco polígono.
## Solo dibuja: no calcula nada del juego ni lo cambia (la simulación vive en scripts/sim).
## Modelos: "KayKit Medieval Hexagon Pack" (Kay Lousberg), licencia CC0; ver THIRD_PARTY_LICENSES.md.
##
## Medidas de las casillas (leídas de los archivos): hexágono con punta hacia delante y atrás,
## 2,0 de ancho entre lados planos, grosor 1,0 (la cara de arriba está a y = 0).
## Rejilla en coordenadas axiales (q, r): x = 2q + r, z = 1,732 r.

const ROOT := "res://assets/kaykit/models/"
const ROW_H := 1.7320508

# Modelos que usa la vista. Los edificios con color llevan "%s" para el bando (blue, green, red).
const MODELS := {
	"grass": "hex_grass",
	"water": "hex_water",
	"hills": "hills_A_trees",
	"hills_b": "hills_B_trees",
	"mountain": "mountain_A_grass_trees",
	"mountain_b": "mountain_B_grass_trees",
	"mountain_c": "mountain_C_grass_trees",
	"trees_l": "trees_A_large",
	"trees_m": "trees_B_medium",
	"trees_s": "trees_A_small",
	"tree_a": "tree_single_A",
	"tree_b": "tree_single_B",
	"rock_a": "rock_single_A",
	"cloud": "cloud_big",
	"grain": "building_grain",
	"scaffold": "building_scaffolding",
	"stage_a": "building_stage_A",
	"stage_b": "building_stage_B",
	"dirt": "building_dirt",
	"wall": "wall_straight",
	"wall_gate": "wall_straight_gate",
	"wall_corner": "wall_corner_A_outside",
	"fence": "fence_wood_straight",
	"home_a": "building_home_A_%s",
	"home_b": "building_home_B_%s",
	"tavern": "building_tavern_%s",
	"church": "building_church_%s",
	"castle": "building_castle_%s",
	"market": "building_market_%s",
	"windmill": "building_windmill_%s",
	"lumbermill": "building_lumbermill_%s",
	"well": "building_well_%s",
	"tower": "building_tower_A_%s",
	"barracks": "building_barracks_%s",
}

var faction := "blue"
var _cache := {}


## Posición en el mundo del centro de la casilla (q, r) a la altura y.
static func hex_to_world(q: int, r: int, y: float = 0.0) -> Vector3:
	return Vector3(2.0 * q + r, y, ROW_H * r)


func model(key: String) -> PackedScene:
	if _cache.has(key):
		return _cache[key]
	var path: String = MODELS[key]
	if path.contains("%s"):
		path = path % faction
	var scene := load(ROOT + path + ".gltf") as PackedScene
	_cache[key] = scene
	return scene


## Pone un modelo; rot_deg gira sobre el eje vertical; devuelve el nodo (o null si falta el modelo).
func place(key: String, pos: Vector3, rot_deg: float = 0.0, scale_factor: float = 1.0) -> Node3D:
	var scene := model(key)
	if scene == null:
		push_error("Falta el modelo: " + key)
		return null
	var node := scene.instantiate() as Node3D
	node.position = pos
	node.rotation_degrees.y = rot_deg
	node.scale = Vector3.ONE * scale_factor
	add_child(node)
	return node


# Símbolos permitidos en las dos capas del diorama.
const TERRAIN_SYMBOLS := "w012"                    # agua, o suelo con 0, 1 o 2 niveles de altura
const THING_SYMBOLS := ".ThtsHMNQFWLCoOEYSDRxXyzK"  # ver _thing()


## Comprueba que las dos capas describen un hexágono grande de radio R: 2R+1 filas, y la fila
## con r = i - R tiene 2R+1-|r| casillas. Devuelve la lista de errores (vacía si todo está bien).
static func validate(terrain: Array, things: Array) -> Array[String]:
	var errors: Array[String] = []
	if terrain.size() % 2 == 0:
		errors.append("el número de filas debe ser impar (hexágono de radio R: 2R+1 filas); hay %d" % terrain.size())
		return errors
	if things.size() != terrain.size():
		errors.append("el terreno tiene %d filas y los objetos %d" % [terrain.size(), things.size()])
		return errors
	var radius := (terrain.size() - 1) / 2
	for i in terrain.size():
		var expected := 2 * radius + 1 - absi(i - radius)
		var t: String = terrain[i]
		var o: String = things[i]
		if t.length() != expected:
			errors.append("fila %d del terreno: debe tener %d casillas y tiene %d" % [i, expected, t.length()])
		if o.length() != expected:
			errors.append("fila %d de objetos: debe tener %d casillas y tiene %d" % [i, expected, o.length()])
		for c in t:
			if not TERRAIN_SYMBOLS.contains(c):
				errors.append("fila %d del terreno: símbolo «%s» desconocido" % [i, c])
		for c in o:
			if not THING_SYMBOLS.contains(c):
				errors.append("fila %d de objetos: símbolo «%s» desconocido" % [i, c])
	return errors


## Construye el diorama. terrain y things son listas de textos, una por fila (de arriba abajo,
## la primera tiene r = -R), cada una con las casillas q de menor a mayor.
## Si el diseño no es válido no construye nada y devuelve false.
func build(terrain: Array, things: Array) -> bool:
	var errors := validate(terrain, things)
	if not errors.is_empty():
		push_error("Diorama no válido: " + "; ".join(errors))
		return false
	var radius := (terrain.size() - 1) / 2
	for i in terrain.size():
		var r := i - radius
		var row: String = terrain[i]
		var objs: String = things[i]
		var q0 := maxi(-radius, -radius - r)
		for j in row.length():
			var q := q0 + j
			var c := row[j]
			_tile(q, r, c)
			_thing(q, r, objs[j], _height(c))
	return true


func _height(c: String) -> int:
	if c == "w":
		return 0
	return int(c) if c.is_valid_int() else 0


func _tile(q: int, r: int, c: String) -> void:
	if c == "w":
		place("water", hex_to_world(q, r))
		return
	var h := _height(c)
	for k in range(h + 1):
		place("grass", hex_to_world(q, r, float(k)))


func _rot(q: int, r: int) -> float:
	# Giro fijo según la casilla, para que no se repita igual todo (sin azar: siempre igual).
	return 60.0 * float(posmod(q * 7 + r * 13, 6))


func _thing(q: int, r: int, o: String, h: int) -> void:
	var p := hex_to_world(q, r, float(h))
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
		"L":
			place("lumbermill", p + Vector3(-0.3, 0, 0.2), 30.0)
			place("tree_a", p + Vector3(0.7, 0, -0.6))
			place("tree_b", p + Vector3(0.5, 0, 0.6))
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
			place("rock_a", p + Vector3(0.2, 0, 0.2), rot)
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
		_:
			push_warning("Símbolo desconocido en el diorama: " + o)
