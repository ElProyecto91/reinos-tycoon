extends "res://tests/province_case.gd"
## Mapa de provincias (tarea 1.8): validación, selección con el dedo y partida nueva.

const GAME_MAP := "res://scripts/sim/game_map.gd"
const OFFLINE := "res://scripts/sim/offline.gd"


func _new_map():
	return load(GAME_MAP).new()


func _square(x: int, y: int, half: int = 60) -> Array:
	return [[[x - half, y - half], [x + half, y - half], [x + half, y + half], [x - half, y + half]]]


func _province(id: String, x: int, y: int, neighbors: Array, extra: Dictionary = {}) -> Dictionary:
	var p := {
		"id": id, "name": "Provincia " + id, "x": x, "y": y, "neighbors": neighbors,
		"realm": "r", "look": "cordoba", "lon": -4.0, "lat": 38.0, "polygons": _square(x, y),
		"start": {"population": 50, "buildings": ["farm"], "stock": {"coin": 1000}},
	}
	for key in extra.keys():
		p[key] = extra[key]
	return p


func _raw(list: Array) -> Dictionary:
	return {
		"format_version": 2, "width": 1000, "height": 1000, "touch_slop": 20,
		"realms": {"r": {"name": "Reino", "label": "REINO", "note": "n", "color": [100, 140, 90], "outline": [], "label_x": 500, "label_y": 500, "label_room": 100}},
		"land": [], "foreign_land": [], "rivers": [], "labels": [], "projection": {"km_per_unit": 1.0},
		"provinces": list,
	}


func _errors_text(map) -> String:
	return "\n".join(map.errors)


func _expect_error(raw: Dictionary, fragment: String, label: String) -> void:
	var map = _new_map()
	var data = new_data()
	assert_true(not map.build(raw, data), "%s: se debe rechazar" % label)
	var found := false
	for e in map.errors:
		if fragment in e:
			found = true
	assert_true(found, "%s: mensaje con «%s»; obtenido: %s" % [label, fragment, _errors_text(map)])
	assert_true(map.provinces.is_empty(), "%s: no queda un mapa a medias" % label)


func test_default_map_loads_and_has_many_playable_provinces() -> void:
	var data = new_data()
	var map = _new_map()
	assert_true(map.load_defaults(data), "el mapa por defecto debe cargarse: %s" % _errors_text(map))
	assert_true(map.provinces.size() >= 30, "muchas provincias jugables: %d" % map.provinces.size())
	assert_true(map.provinces.size() <= map.MAX_PROVINCES, "dentro del máximo")
	assert_eq(map.find("toledo")["name"], "Toledo", "nombre histórico aproximado (docs/REGION_IBERIA_1000.md)")
	assert_eq(map.find("no_existe"), {}, "id desconocido: vacío")
	var used := {}
	for p in map.provinces:
		used[p["realm"]] = true
		assert_true(map.realms.has(p["realm"]), "%s tiene reino" % p["id"])
		assert_true(p["look"] in map.LOOKS, "%s tiene un aspecto 3D válido" % p["id"])
		assert_true(not p["rings"].is_empty(), "%s tiene territorio" % p["id"])
		for ring in p["rings"]:
			assert_true(not Geometry2D.triangulate_polygon(ring).is_empty(), "el territorio de %s se puede dibujar (triangular)" % p["id"])
	for id in map.realms.keys():
		assert_true(used.has(id), "el reino %s tiene alguna provincia" % id)
	assert_true(map.realms.size() >= 5, "varios reinos")
	assert_eq(map.provinces.size(), 47, "el mapa de la versión 0.3.0 tiene 47 provincias")
	for ring in map.land:
		assert_true(not Geometry2D.triangulate_polygon(ring).is_empty(), "una orilla se puede dibujar")
	done()


func test_historical_entities_of_the_default_map() -> void:
	var data = new_data()
	var map = _new_map()
	map.load_defaults(data)
	var esperado := {
		"cordoba": "califato", "toledo": "califato", "zaragoza": "califato", "sevilla": "califato", "coimbra": "califato",
		"leon": "leon", "galicia": "leon", "castilla": "castilla", "portugal": "portugal",
		"pamplona": "pamplona", "aragon": "pamplona", "barcelona": "catalanes", "ribagorza": "catalanes",
	}
	for id in esperado.keys():
		assert_eq(map.find(id)["realm"], esperado[id], "%s pertenece a %s" % [id, esperado[id]])
	var cordoba: Dictionary = map.find("cordoba")
	assert_true(absf(cordoba["lon"] - (-4.78)) < 0.05 and absf(cordoba["lat"] - 37.88) < 0.05, "Córdoba en su sitio")
	assert_true(map.find("barcelona")["x"] > map.find("cordoba")["x"] and map.find("leon")["y"] < map.find("cordoba")["y"], "el este está a la derecha y el norte arriba")
	assert_eq(map.realm_of("cordoba")["name"], "Califato de Córdoba", "nombre del reino")
	assert_eq(map.realm_of("no_existe"), {}, "desconocida: vacío")
	done()


func test_neighbors_are_mutual_in_the_default_map() -> void:
	var data = new_data()
	var map = _new_map()
	map.load_defaults(data)
	for p in map.provinces:
		assert_true(not map.neighbors_of(p["id"]).is_empty(), "%s tiene vecinas" % p["id"])
		for n in map.neighbors_of(p["id"]):
			assert_true(p["id"] in map.neighbors_of(n), "%s y %s son vecinas en los dos sentidos" % [p["id"], n])
	assert_true("castilla" in map.neighbors_of("leon") and "asturias" in map.neighbors_of("leon"), "León toca a Castilla y a Asturias")
	assert_true(not ("barcelona" in map.neighbors_of("cordoba")), "Córdoba no toca a Barcelona")
	assert_eq(map.neighbors_of("no_existe"), [], "desconocida: sin vecinos")
	done()


func test_touch_selects_the_territory_under_the_finger() -> void:
	var data = new_data()
	var map = _new_map()
	map.load_defaults(data)
	for p in map.provinces:
		assert_eq(map.province_at(p["x"], p["y"]), p["id"], "tocar la capital de %s" % p["id"])
	assert_eq(map.province_at(-500, 99999), "", "fuera del mapa: nada y sin fallar")
	assert_eq(map.province_at(0, 0), "", "esquina del mar: nada")
	# Mar abierto lejos de toda costa: nada. (El Atlántico, a la izquierda de Galicia.)
	assert_eq(map.province_at(5, 150), "", "mar abierto: nada")
	done()


func test_territories_never_overlap() -> void:
	var data = new_data()
	var map = _new_map()
	map.load_defaults(data)
	var step := 14
	var x := 0
	var covered := 0
	while x <= map.width:
		var y := 0
		while y <= map.height:
			var inside := 0
			for p in map.provinces:
				for ring in p["rings"]:
					if Geometry2D.is_point_in_polygon(Vector2(x, y), ring):
						inside += 1
			assert_true(inside <= 1, "punto (%d,%d) en %d territorios" % [x, y, inside])
			covered += inside
			y += step
		x += step
	assert_true(covered > 1500, "los territorios cubren buena parte del mapa (%d puntos)" % covered)
	done()


func test_slop_selects_the_nearest_territory_just_off_the_coast() -> void:
	var data = new_data()
	var map = _new_map()
	var raw := _raw([_province("a", 500, 500, [])])
	assert_true(map.build(raw, data), "mapa válido: %s" % _errors_text(map))
	assert_eq(map.province_at(500, 500), "a", "dentro")
	assert_eq(map.province_at(500 + 60 + 10, 500), "a", "a 10 unidades del borde: dentro del margen")
	assert_eq(map.province_at(500 + 60 + 30, 500), "", "a 30 unidades: fuera del margen")
	done()


func test_new_world_matches_the_map() -> void:
	var data = new_data()
	var map = _new_map()
	map.load_defaults(data)
	var result: Dictionary = map.new_world(data)
	assert_true(result["ok"], "la partida nueva se crea: %s" % result["error"])
	var world = result["world"]
	assert_eq(world.provinces.size(), map.provinces.size(), "una provincia del mundo por cada una del mapa")
	assert_eq(world.step_count, 0, "paso 0")
	for p in map.provinces:
		var province = world.find_province(p["id"])
		assert_true(province != null, "existe %s" % p["id"])
		assert_eq(province.population, p["start"]["population"], "población inicial de %s" % p["id"])
		assert_eq(province.buildings.size(), p["start"]["buildings"].size(), "edificios de %s" % p["id"])
		for good in p["start"]["stock"].keys():
			assert_eq(province.store.stock(good), p["start"]["stock"][good], "existencias de %s en %s" % [good, p["id"]])
	assert_eq(world.check_invariants(), [], "sin incoherencias")
	done()


func test_new_world_is_deterministic_and_independent() -> void:
	var data = new_data()
	var map = _new_map()
	map.load_defaults(data)
	var first = map.new_world(data)["world"]
	var second = map.new_world(data)["world"]
	first.run_steps(100)
	assert_eq(second.step_count, 0, "otra partida nueva no se ve afectada")
	second.run_steps(100)
	for i in range(first.provinces.size()):
		assert_eq(snapshot(first.provinces[i]), snapshot(second.provinces[i]), "misma partida, mismo resultado (%s)" % first.provinces[i].id)
	done()


func test_all_start_provinces_run_30_days_and_a_long_absence_cleanly() -> void:
	var data = new_data()
	var map = _new_map()
	map.load_defaults(data)
	var world = map.new_world(data)["world"]
	world.run_steps(720)
	assert_eq(world.check_invariants(), [], "30 días sin incoherencias")
	for province in world.provinces:
		assert_eq(province.store.check_conservation(), [], "conservación en %s" % province.id)
		assert_true(province.population >= data.rules["min_population"], "población válida en %s" % province.id)
	var away = map.new_world(data)["world"]
	load(OFFLINE).settle(away, 1800000000, 1800000000 + 30 * 24 * 3600)
	assert_eq(away.check_invariants(), [], "tras una ausencia larga, sin incoherencias")
	done()


func test_new_world_fails_cleanly_when_the_start_stock_does_not_fit() -> void:
	var data = new_data()
	var map = _new_map()
	var too_much := _raw([_province("a", 100, 100, [], {"start": {"population": 50, "buildings": [], "stock": {"wheat": 9999999}}})])
	assert_true(map.build(too_much, data), "el archivo es válido (la capacidad depende de los edificios)")
	var result: Dictionary = map.new_world(data)
	assert_true(not result["ok"], "no cabe: se rechaza")
	assert_eq(result["world"], null, "sin mundo a medias")
	assert_true("wheat" in result["error"], "el mensaje nombra la mercancía: %s" % result["error"])
	done()


func test_version_0_2_adds_tolosa_gascuna_and_the_two_sea_provinces_all_reachable() -> void:
	var data = new_data()
	var map = _new_map()
	assert_true(map.load_defaults(data), "el mapa carga")
	assert_eq(map.find("tolosa")["realm"], "tolosa", "Tolosa es un reino propio")
	assert_eq(map.find("gascuna")["realm"], "gascuna", "Gascuña es un reino propio")
	assert_true("barcelona" in map.find("baleares")["neighbors"], "Baleares se llega por mar desde Barcelona")
	assert_true("baleares" in map.find("barcelona")["neighbors"], "y la vecindad es mutua")
	assert_true("algeciras" in map.find("ceuta")["neighbors"], "Ceuta se llega por mar desde Algeciras")
	assert_true("algeciras" in map.find("ceuta")["neighbors"] and "ceuta" in map.find("algeciras")["neighbors"], "mutua también")
	# Todo el mapa es un solo grafo conectado: ninguna provincia queda aislada.
	var vistas := {"toledo": true}
	var cola: Array = ["toledo"]
	while not cola.is_empty():
		var id: String = cola.pop_back()
		for n in map.find(id)["neighbors"]:
			if not vistas.has(n):
				vistas[n] = true
				cola.append(n)
	assert_eq(vistas.size(), map.provinces.size(), "las 47 provincias están conectadas entre sí")
	for p in map.provinces:
		assert_eq(int(p["start"]["stock"].get("tools", -1)), 1800, "%s empieza con herramientas" % p["id"])
	done()


func test_valid_small_map_is_accepted() -> void:
	var data = new_data()
	var map = _new_map()
	var raw := _raw([_province("a", 100, 100, ["b"]), _province("b", 400, 100, ["a"])])
	assert_true(map.build(raw, data), "mapa pequeño válido: %s" % _errors_text(map))
	assert_eq(map.touch_slop, 20, "margen de toque")
	var single := _raw([_province("solo", 500, 500, [])])
	assert_true(_new_map().build(single, data), "una sola provincia sin vecinos es válida")
	done()


func test_invalid_maps_are_rejected_with_clear_messages() -> void:
	var a := _province("a", 100, 100, ["b"])
	var b := _province("b", 400, 100, ["a"])
	_expect_error(_raw([]), "lista no vacía", "sin provincias")
	var viejo := _raw([a])
	viejo["format_version"] = 1
	_expect_error(viejo, "versión de formato", "versión desconocida")
	_expect_error(_raw([a, _province("a", 700, 700, [])]), "id repetido", "id repetido")
	_expect_error(_raw([_province("A!", 100, 100, [])]), "\"id\"", "id con caracteres no válidos")
	_expect_error(_raw([_province("a", 100, 100, ["b"]), _province("b", 400, 100, [])]), "mutua", "vecindad no mutua")
	_expect_error(_raw([_province("a", 100, 100, ["a"])]), "de sí misma", "vecina de sí misma")
	_expect_error(_raw([_province("a", 100, 100, ["zzz"])]), "vecino desconocido", "vecino inexistente")
	_expect_error(_raw([_province("a", 100, 100, ["b", "b"]), b]), "repetido", "vecino repetido")
	_expect_error(_raw([_province("a", 100, 100, [], {"realm": "otro"})]), "reino desconocido", "reino inexistente")
	_expect_error(_raw([_province("a", 100, 100, [], {"look": "marte"})]), "look", "aspecto 3D desconocido")
	_expect_error(_raw([_province("a", 100, 100, [], {"polygons": []})]), "territorio", "sin territorio")
	_expect_error(_raw([_province("a", 100, 100, [], {"polygons": [[[0, 0], [10, 0]]]})]), "3 y", "anillo con dos puntos")
	_expect_error(_raw([_province("a", 100, 100, [], {"polygons": [[[0, 0], [10, 0], [5, 99999]]]})]), "fuera del mapa", "territorio fuera del mapa")
	_expect_error(_raw([_province("a", 100, 100, [], {"lon": null})]), "lon", "sin coordenadas históricas")
	_expect_error(_raw([a, b, _province("c", 800, 800, [])]), "aisladas", "provincia aislada")
	_expect_error(_raw([_province("a", 5000, 100, [])]), "dentro del mapa", "fuera del mapa")
	_expect_error(_raw([_province("a", 100, 100, [], {"name": "  "})]), "nombre", "sin nombre")
	_expect_error(_raw([_province("a", 100, 100, [], {"start": {"population": 1, "buildings": [], "stock": {}}})]), "population", "población bajo el mínimo")
	_expect_error(_raw([_province("a", 100, 100, [], {"start": {"population": 50, "buildings": ["castillo"], "stock": {}}})]), "edificio desconocido", "edificio inexistente")
	_expect_error(_raw([_province("a", 100, 100, [], {"start": {"population": 50, "buildings": [], "stock": {"oro": 5}}})]), "mercancía desconocida", "mercancía inexistente")
	_expect_error(_raw([_province("a", 100, 100, [], {"start": {"population": 50, "buildings": [], "stock": {"coin": -1}}})]), "cantidad no válida", "cantidad negativa")
	_expect_error(_raw([_province("a", 100, 100, [], {"start": {"population": 50, "buildings": [], "stock": {"coin": 1.5}}})]), "cantidad no válida", "cantidad con decimales")
	var many: Array = []
	for i in range(61):
		many.append(_province("p%d" % i, 20 + (i % 10) * 90, 20 + (i / 10) * 90, [], {"polygons": _square(20 + (i % 10) * 90, 20 + (i / 10) * 90, 20)}))
	_expect_error(_raw(many), "como máximo 60", "más de 60 provincias")
	done()


func test_garbage_files_fail_cleanly() -> void:
	var data = new_data()
	var map = _new_map()
	assert_true(not map.load_file("res://data/no_existe.json", data), "archivo inexistente")
	assert_true("no existe" in _errors_text(map), "mensaje: %s" % _errors_text(map))
	for text in ["", "no es json", "[]", "42"]:
		var path := "user://mapa_basura.json"
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		var other = _new_map()
		assert_true(not other.load_file(path, data), "basura rechazada: «%s»" % text)
		assert_true(not other.errors.is_empty(), "con mensaje: «%s»" % text)
		DirAccess.remove_absolute(path)
	done()
