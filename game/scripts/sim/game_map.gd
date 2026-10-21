extends RefCounted
## Mapa de provincias: posiciones, vecindades y estado inicial de cada una (tarea 1.8).
##
## Solo lógica y datos, sin pantalla: la interfaz (1.9) dibuja lo que este módulo dice.
## Las coordenadas son enteros en unidades de mapa. Seleccionar con el dedo usa un radio
## de toque: las provincias deben estar separadas al menos el doble del radio para que
## un toque nunca sea ambiguo.

const WorldScript := preload("res://scripts/sim/world.gd")
const Fixed := preload("res://scripts/sim/fixed.gd")

const SUPPORTED_FORMAT_VERSION := 1
const DEFAULT_PATH := "res://data/map.json"
const MAX_PROVINCES := 20
const MAX_BUILDINGS_PER_PROVINCE := 60

var width: int = 0
var height: int = 0
var touch_radius: int = 0
## Provincias en el orden del archivo: {id, name, short (nombre para el mapa; si falta, el nombre), x, y, neighbors: Array, start: {population, buildings, stock}}
var provinces: Array = []
var errors: Array[String] = []

var _id_regex := RegEx.new()


func _init() -> void:
	_id_regex.compile("^[a-z][a-z0-9_]*$")


func load_defaults(data) -> bool:
	return load_file(DEFAULT_PATH, data)


func load_file(path: String, data) -> bool:
	errors = []
	provinces = []
	if not FileAccess.file_exists(path):
		errors.append("no existe el archivo del mapa: %s" % path)
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s: JSON no válido en la línea %d" % [path.get_file(), json.get_error_line()])
		return false
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("%s: debe contener un objeto" % path.get_file())
		return false
	return build(json.data, data)


## Valida y carga el mapa. `data` son los datos de juego ya cargados (edificios, mercancías).
func build(raw: Dictionary, data) -> bool:
	errors = []
	provinces = []
	var version = Fixed.exact_int(raw.get("format_version", null))
	if version != SUPPORTED_FORMAT_VERSION:
		errors.append("mapa: versión de formato no soportada (%s)" % str(raw.get("format_version", null)))
		return false
	var w = Fixed.exact_int(raw.get("width", null))
	var h = Fixed.exact_int(raw.get("height", null))
	var r = Fixed.exact_int(raw.get("touch_radius", null))
	if w == null or w < 100 or w > 100000:
		errors.append("mapa: \"width\" debe ser un entero entre 100 y 100000")
	if h == null or h < 100 or h > 100000:
		errors.append("mapa: \"height\" debe ser un entero entre 100 y 100000")
	if r == null or r < 10 or r > 10000:
		errors.append("mapa: \"touch_radius\" debe ser un entero entre 10 y 10000")
	var list = raw.get("provinces", null)
	if typeof(list) != TYPE_ARRAY or list.is_empty():
		errors.append("mapa: \"provinces\" debe ser una lista no vacía")
		return false
	if list.size() > MAX_PROVINCES:
		errors.append("mapa: como máximo %d provincias (hay %d)" % [MAX_PROVINCES, list.size()])
		return false
	if not errors.is_empty():
		return false
	var loaded: Array = []
	var seen := {}
	for i in range(list.size()):
		var entry = list[i]
		var where := "provincia #%d" % (i + 1)
		var province := _parse_province(entry, where, w, h, data)
		if province.is_empty():
			continue
		if seen.has(province["id"]):
			errors.append("%s: id repetido (%s)" % [where, province["id"]])
			continue
		seen[province["id"]] = true
		loaded.append(province)
	if not errors.is_empty():
		return false
	_check_neighbors(loaded, seen)
	_check_separation(loaded, r)
	_check_connected(loaded)
	if not errors.is_empty():
		return false
	width = w
	height = h
	touch_radius = r
	provinces = loaded
	return true


func _parse_province(entry: Variant, where: String, w: int, h: int, data) -> Dictionary:
	var before := errors.size()
	if typeof(entry) != TYPE_DICTIONARY:
		errors.append("%s: debe ser un objeto" % where)
		return {}
	var id = entry.get("id", null)
	if typeof(id) != TYPE_STRING or not _id_regex.search(id):
		errors.append("%s: \"id\" debe ser texto en minúsculas, dígitos y _ (empieza por letra)" % where)
		return {}
	where = "provincia \"%s\"" % id
	var name = entry.get("name", null)
	if typeof(name) != TYPE_STRING or name.strip_edges() == "":
		errors.append("%s: falta el nombre" % where)
	var short_name: String = ""
	var raw_short = entry.get("short", null)
	if raw_short != null:
		if typeof(raw_short) != TYPE_STRING or raw_short.strip_edges() == "" or raw_short.length() > 20:
			errors.append("%s: \"short\" debe ser un texto de 1 a 20 caracteres" % where)
		else:
			short_name = raw_short
	var x = Fixed.exact_int(entry.get("x", null))
	var y = Fixed.exact_int(entry.get("y", null))
	if x == null or x < 0 or x > w or y == null or y < 0 or y > h:
		errors.append("%s: la posición debe estar dentro del mapa (x 0–%d, y 0–%d)" % [where, w, h])
	var neighbors: Array = []
	var raw_neighbors = entry.get("neighbors", null)
	if typeof(raw_neighbors) != TYPE_ARRAY:
		errors.append("%s: \"neighbors\" debe ser una lista (puede estar vacía solo si hay una provincia)" % where)
	else:
		for n in raw_neighbors:
			if typeof(n) != TYPE_STRING:
				errors.append("%s: los vecinos deben ser ids de texto" % where)
			elif n in neighbors:
				errors.append("%s: vecino repetido (%s)" % [where, n])
			else:
				neighbors.append(n)
	var start := _parse_start(entry.get("start", null), where, data)
	if errors.size() > before:
		return {}
	return {"id": id, "name": name, "short": short_name if short_name != "" else name, "x": x, "y": y, "neighbors": neighbors, "start": start}


func _parse_start(raw: Variant, where: String, data) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("%s: falta \"start\" (estado inicial)" % where)
		return {}
	var population = Fixed.exact_int(raw.get("population", null))
	var min_population: int = data.rules.get("min_population", 1)
	if population == null or population < min_population or population > 1000000:
		errors.append("%s: \"population\" debe ser un entero entre %d y 1000000" % [where, min_population])
	var buildings: Array = []
	var raw_buildings = raw.get("buildings", null)
	if typeof(raw_buildings) != TYPE_ARRAY:
		errors.append("%s: \"buildings\" debe ser una lista de ids de edificio" % where)
	elif raw_buildings.size() > MAX_BUILDINGS_PER_PROVINCE:
		errors.append("%s: como máximo %d edificios iniciales" % [where, MAX_BUILDINGS_PER_PROVINCE])
	else:
		for b in raw_buildings:
			if typeof(b) != TYPE_STRING or not data.buildings.has(b):
				errors.append("%s: edificio desconocido (%s)" % [where, str(b)])
			else:
				buildings.append(b)
	var stock := {}
	var raw_stock = raw.get("stock", null)
	if typeof(raw_stock) != TYPE_DICTIONARY:
		errors.append("%s: \"stock\" debe ser un objeto mercancía → cantidad" % where)
	else:
		for good in raw_stock.keys():
			var amount = Fixed.exact_int(raw_stock[good])
			if not data.goods.has(good):
				errors.append("%s: mercancía desconocida en el stock (%s)" % [where, str(good)])
			elif amount == null or amount < 0:
				errors.append("%s: cantidad no válida de %s (entero ≥ 0 en milésimas)" % [where, str(good)])
			else:
				stock[good] = amount
	return {"population": population, "buildings": buildings, "stock": stock}


func _check_neighbors(loaded: Array, ids: Dictionary) -> void:
	var by_id := {}
	for p in loaded:
		by_id[p["id"]] = p
	for p in loaded:
		for n in p["neighbors"]:
			if n == p["id"]:
				errors.append("provincia \"%s\": no puede ser vecina de sí misma" % p["id"])
			elif not ids.has(n):
				errors.append("provincia \"%s\": vecino desconocido (%s)" % [p["id"], n])
			elif not (p["id"] in by_id[n]["neighbors"]):
				errors.append("provincia \"%s\": %s figura como vecino, pero %s no la nombra a ella (la vecindad debe ser mutua)" % [p["id"], n, n])


func _check_separation(loaded: Array, r: int) -> void:
	for i in range(loaded.size()):
		for j in range(i + 1, loaded.size()):
			var dx: int = loaded[i]["x"] - loaded[j]["x"]
			var dy: int = loaded[i]["y"] - loaded[j]["y"]
			if dx * dx + dy * dy < 4 * r * r:
				errors.append("provincias \"%s\" y \"%s\": demasiado juntas; las zonas de toque (radio %d) se solaparían" % [loaded[i]["id"], loaded[j]["id"], r])


func _check_connected(loaded: Array) -> void:
	if loaded.size() <= 1:
		return
	var by_id := {}
	for p in loaded:
		by_id[p["id"]] = p
	var reached := {loaded[0]["id"]: true}
	var pending: Array = [loaded[0]["id"]]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		for n in by_id[current]["neighbors"]:
			if by_id.has(n) and not reached.has(n):
				reached[n] = true
				pending.append(n)
	if reached.size() != loaded.size():
		errors.append("mapa: hay provincias aisladas; todas deben estar conectadas entre sí")


func find(province_id: String) -> Dictionary:
	for p in provinces:
		if p["id"] == province_id:
			return p
	return {}


func neighbors_of(province_id: String) -> Array:
	var p := find(province_id)
	return [] if p.is_empty() else p["neighbors"].duplicate()


## Provincia tocada en el punto (x, y) en unidades de mapa, o "" si el toque cae fuera de
## toda zona de toque. Con la separación validada puede haber como mucho una.
func province_at(x: int, y: int) -> String:
	var best := ""
	var best_distance := -1
	for p in provinces:
		var dx: int = p["x"] - x
		var dy: int = p["y"] - y
		var d := dx * dx + dy * dy
		if d <= touch_radius * touch_radius and (best_distance < 0 or d < best_distance):
			best = p["id"]
			best_distance = d
	return best


## Crea el mundo de una partida nueva. Devuelve {ok, world, error}. Falla (sin devolver un
## mundo a medias) si alguna existencia inicial no cabe en el almacén de su provincia.
func new_world(data) -> Dictionary:
	var world = WorldScript.new(data)
	for p in provinces:
		var province = world.add_province(p["id"], p["name"], p["start"]["population"])
		for type_id in p["start"]["buildings"]:
			province.add_building(type_id)
		var goods: Array = p["start"]["stock"].keys()
		goods.sort()
		for good in goods:
			var wanted: int = p["start"]["stock"][good]
			var accepted: int = province.store.seed_initial(good, wanted)
			if accepted != wanted:
				return {"ok": false, "world": null, "error": "provincia \"%s\": solo caben %d de %d de %s en el almacén inicial" % [p["id"], accepted, wanted, good]}
	var problems := world.check_invariants()
	if not problems.is_empty():
		return {"ok": false, "world": null, "error": "estado inicial incoherente: %s" % problems[0]}
	return {"ok": true, "world": world, "error": ""}
