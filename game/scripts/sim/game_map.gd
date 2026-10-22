extends RefCounted
## Mapa de provincias: posiciones, vecindades y estado inicial de cada una (tarea 1.8).
##
## Solo lógica y datos, sin pantalla: la interfaz (1.9) dibuja lo que este módulo dice.
## Formato 2 (mapa grande): cada provincia es un territorio con forma (anillos de puntos) que
## pertenece a un reino; seleccionar con el dedo es ver en qué territorio cae el toque.
## Las formas son una aproximación de juego, no fronteras históricas (ver docs/REGION_IBERIA_1000.md).

const WorldScript := preload("res://scripts/sim/world.gd")
const Fixed := preload("res://scripts/sim/fixed.gd")

const SUPPORTED_FORMAT_VERSION := 2
const DEFAULT_PATH := "res://data/map.json"
const MAX_PROVINCES := 60
const LOOKS := ["cordoba", "toledo", "zaragoza", "norte"]
const MAX_RING_POINTS := 4000
const MAX_BUILDINGS_PER_PROVINCE := 60

var width: int = 0
var height: int = 0
## Margen en unidades de mapa para tocar cerca de un territorio (el toque que cae en el mar junto a la costa elige la provincia más cercana).
var touch_slop: int = 0
## Provincias en el orden del archivo: {id, name, short, realm, look, x, y, lon, lat, rings: Array[PackedVector2Array], neighbors: Array, start: {population, buildings, stock}}
var provinces: Array = []
## Reinos: id -> {name, label, color: Color, note, outline: Array[PackedVector2Array], label_x, label_y, label_room}
var realms: Dictionary = {}
## Tierra (todas las orillas), tierra fuera de la partida, ríos [{name, points}] y proyección, para dibujar.
var land: Array = []
var foreign_land: Array = []
var rivers: Array = []
var projection: Dictionary = {}
## Rótulos sueltos [{text, x, y, kind: "mar" | "ajena"}]
var labels: Array = []
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
	var slop = Fixed.exact_int(raw.get("touch_slop", null))
	if w == null or w < 100 or w > 100000:
		errors.append("mapa: \"width\" debe ser un entero entre 100 y 100000")
	if h == null or h < 100 or h > 100000:
		errors.append("mapa: \"height\" debe ser un entero entre 100 y 100000")
	if slop == null or slop < 0 or slop > 500:
		errors.append("mapa: \"touch_slop\" debe ser un entero entre 0 y 500")
	var parsed_realms := _parse_realms(raw.get("realms", null), w if w != null else 0, h if h != null else 0)
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
	for p in loaded:
		if not parsed_realms.has(p["realm"]):
			errors.append("provincia \"%s\": reino desconocido (%s)" % [p["id"], p["realm"]])
	_check_neighbors(loaded, seen)
	_check_connected(loaded)
	var parsed_land := _parse_rings(raw.get("land", null), "tierra", w, h, true)
	var parsed_foreign := _parse_rings(raw.get("foreign_land", null), "tierra ajena", w, h, true)
	var parsed_rivers := _parse_rivers(raw.get("rivers", null), w, h)
	var parsed_labels: Array = []
	var raw_labels = raw.get("labels", [])
	if typeof(raw_labels) != TYPE_ARRAY:
		errors.append("mapa: \"labels\" debe ser una lista")
	else:
		for l in raw_labels:
			if typeof(l) != TYPE_DICTIONARY or typeof(l.get("text", null)) != TYPE_STRING or typeof(l.get("x", null)) not in [TYPE_FLOAT, TYPE_INT] or typeof(l.get("y", null)) not in [TYPE_FLOAT, TYPE_INT] or not (l.get("kind", "") in ["mar", "ajena"]):
				errors.append("mapa: rótulo no válido")
				break
			parsed_labels.append({"text": l["text"], "x": float(l["x"]), "y": float(l["y"]), "kind": l["kind"]})
	var proj = raw.get("projection", null)
	if typeof(proj) != TYPE_DICTIONARY or typeof(proj.get("km_per_unit", null)) not in [TYPE_FLOAT, TYPE_INT]:
		errors.append("mapa: falta \"projection\" con \"km_per_unit\"")
	if not errors.is_empty():
		return false
	width = w
	height = h
	touch_slop = slop
	provinces = loaded
	realms = parsed_realms
	land = parsed_land
	foreign_land = parsed_foreign
	rivers = parsed_rivers
	projection = proj
	labels = parsed_labels
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
	var realm = entry.get("realm", null)
	if typeof(realm) != TYPE_STRING or realm == "":
		errors.append("%s: falta el reino (\"realm\")" % where)
	var look = entry.get("look", null)
	if typeof(look) != TYPE_STRING or not (look in LOOKS):
		errors.append("%s: \"look\" debe ser uno de %s" % [where, ", ".join(LOOKS)])
	var rings := _parse_rings(entry.get("polygons", null), where, w, h, false)
	if rings.is_empty():
		errors.append("%s: falta el territorio (\"polygons\")" % where)
	var lon = entry.get("lon", null)
	var lat = entry.get("lat", null)
	if typeof(lon) not in [TYPE_FLOAT, TYPE_INT] or typeof(lat) not in [TYPE_FLOAT, TYPE_INT]:
		errors.append("%s: faltan \"lon\" y \"lat\" (la capital histórica)" % where)
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
	return {"id": id, "name": name, "short": short_name if short_name != "" else name, "realm": realm, "look": look, "x": x, "y": y,
		"lon": float(lon), "lat": float(lat), "rings": rings, "neighbors": neighbors, "start": start}


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


## Anillos de puntos [[x, y], ...] dentro del mapa. Con `allow_empty` una lista vacía vale.
func _parse_rings(raw: Variant, where: String, w: int, h: int, allow_empty: bool) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		if not allow_empty:
			errors.append("%s: los anillos deben ser una lista" % where)
		return out
	for ring in raw:
		if typeof(ring) != TYPE_ARRAY or ring.size() < 3 or ring.size() > MAX_RING_POINTS:
			errors.append("%s: un anillo debe tener entre 3 y %d puntos" % [where, MAX_RING_POINTS])
			return []
		var points := PackedVector2Array()
		for pt in ring:
			if typeof(pt) != TYPE_ARRAY or pt.size() != 2 or typeof(pt[0]) not in [TYPE_FLOAT, TYPE_INT] or typeof(pt[1]) not in [TYPE_FLOAT, TYPE_INT]:
				errors.append("%s: punto no válido en un anillo" % where)
				return []
			if pt[0] < -1.0 or pt[0] > w + 1.0 or pt[1] < -1.0 or pt[1] > h + 1.0:
				errors.append("%s: un punto cae fuera del mapa" % where)
				return []
			points.append(Vector2(float(pt[0]), float(pt[1])))
		out.append(points)
	return out


func _parse_rivers(raw: Variant, w: int, h: int) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		errors.append("mapa: \"rivers\" debe ser una lista")
		return out
	for r in raw:
		if typeof(r) != TYPE_DICTIONARY or typeof(r.get("name", null)) != TYPE_STRING:
			errors.append("mapa: un río no tiene nombre")
			return []
		var rings := _parse_rings([r.get("points", null)], "río " + str(r.get("name", "")), w, h, false)
		if rings.is_empty():
			return []
		out.append({"name": r["name"], "points": rings[0]})
	return out


func _parse_realms(raw: Variant, w: int, h: int) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY or raw.is_empty():
		errors.append("mapa: \"realms\" debe ser un objeto no vacío")
		return out
	for id in raw.keys():
		var r = raw[id]
		var where := "reino \"%s\"" % str(id)
		if typeof(r) != TYPE_DICTIONARY:
			errors.append("%s: debe ser un objeto" % where)
			continue
		var color = r.get("color", null)
		var ok_color: bool = typeof(color) == TYPE_ARRAY and color.size() == 3
		if ok_color:
			for c in color:
				if typeof(c) not in [TYPE_FLOAT, TYPE_INT] or c < 0 or c > 255:
					ok_color = false
		if not ok_color:
			errors.append("%s: \"color\" debe ser [r, g, b] de 0 a 255" % where)
			continue
		for key in ["name", "label", "note"]:
			if typeof(r.get(key, null)) != TYPE_STRING or r[key] == "":
				errors.append("%s: falta \"%s\"" % [where, key])
		out[str(id)] = {
			"name": str(r.get("name", "")), "label": str(r.get("label", "")), "note": str(r.get("note", "")),
			"color": Color8(int(color[0]), int(color[1]), int(color[2])),
			"outline": _parse_rings(r.get("outline", null), where, w, h, true),
			"label_x": float(r.get("label_x", 0.0)), "label_y": float(r.get("label_y", 0.0)), "label_room": float(r.get("label_room", 0.0)),
		}
	return out


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


## Provincia tocada en el punto (x, y) en unidades de mapa, o "" si cae lejos de todo territorio.
## Dentro de un territorio gana ese territorio; en el mar o fuera, la provincia con la orilla a menos de `touch_slop`.
func province_at(x: float, y: float) -> String:
	var point := Vector2(x, y)
	for p in provinces:
		for ring in p["rings"]:
			if Geometry2D.is_point_in_polygon(point, ring):
				return p["id"]
	if touch_slop <= 0:
		return ""
	var best := ""
	var best_distance := float(touch_slop)
	for p in provinces:
		for ring in p["rings"]:
			for i in range(ring.size()):
				var closest := Geometry2D.get_closest_point_to_segment(point, ring[i], ring[(i + 1) % ring.size()])
				var d := point.distance_to(closest)
				if d < best_distance:
					best_distance = d
					best = p["id"]
	return best


func realm_of(province_id: String) -> Dictionary:
	var p := find(province_id)
	return {} if p.is_empty() or not realms.has(p["realm"]) else realms[p["realm"]]


## Crea el mundo de una partida nueva. Devuelve {ok, world, error}. Falla (sin devolver un
## mundo a medias) si alguna existencia inicial no cabe en el almacén de su provincia.
## Red de comercio del mapa: id -> {realm, neighbors} (ver trade.gd).
func trade_links() -> Dictionary:
	var links := {}
	for p in provinces:
		links[p["id"]] = {"realm": p["realm"], "neighbors": p["neighbors"].duplicate()}
	return links


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
	world.set_network(trade_links())
	var problems := world.check_invariants()
	if not problems.is_empty():
		return {"ok": false, "world": null, "error": "estado inicial incoherente: %s" % problems[0]}
	return {"ok": true, "world": world, "error": ""}
