extends "res://tests/province_case.gd"
## Mapa de provincias (tarea 1.8): validación, selección con el dedo y partida nueva.

const GAME_MAP := "res://scripts/sim/game_map.gd"
const OFFLINE := "res://scripts/sim/offline.gd"


func _new_map():
	return load(GAME_MAP).new()


func _province(id: String, x: int, y: int, neighbors: Array, extra: Dictionary = {}) -> Dictionary:
	var p := {
		"id": id, "name": "Provincia " + id, "x": x, "y": y, "neighbors": neighbors,
		"start": {"population": 50, "buildings": ["farm"], "stock": {"coin": 1000}},
	}
	for key in extra.keys():
		p[key] = extra[key]
	return p


func _raw(list: Array) -> Dictionary:
	return {"format_version": 1, "width": 1000, "height": 1000, "touch_radius": 100, "provinces": list}


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


func test_default_map_loads_and_has_the_prototype_provinces() -> void:
	var data = new_data()
	var map = _new_map()
	assert_true(map.load_defaults(data), "el mapa por defecto debe cargarse: %s" % _errors_text(map))
	assert_eq(map.provinces.size(), 5, "5 provincias (prototipo)")
	assert_true(map.provinces.size() <= 20, "dentro del máximo del MVP")
	assert_eq(map.find("prueba_a")["name"], "Provincia de prueba A", "nombre de ejemplo, sin pretensión histórica")
	assert_eq(typeof(map.find("prueba_a")["x"]), TYPE_INT, "coordenadas enteras")
	assert_eq(map.find("no_existe"), {}, "id desconocido: vacío")
	done()


func test_neighbors_are_mutual_in_the_default_map() -> void:
	var data = new_data()
	var map = _new_map()
	map.load_defaults(data)
	for p in map.provinces:
		for n in map.neighbors_of(p["id"]):
			assert_true(p["id"] in map.neighbors_of(n), "%s y %s son vecinas en los dos sentidos" % [p["id"], n])
	assert_eq(map.neighbors_of("prueba_e"), ["prueba_d"], "E solo toca a D")
	assert_eq(map.neighbors_of("no_existe"), [], "desconocida: sin vecinos")
	done()


func test_touch_selects_the_nearest_province_within_the_radius() -> void:
	var data = new_data()
	var map = _new_map()
	map.load_defaults(data)
	var a: Dictionary = map.find("prueba_a")
	assert_eq(map.province_at(a["x"], a["y"]), "prueba_a", "tocar el centro")
	assert_eq(map.province_at(a["x"] + 80, a["y"] - 70), "prueba_a", "tocar cerca del centro")
	assert_eq(map.province_at(a["x"] + map.touch_radius, a["y"]), "prueba_a", "justo en el borde del radio")
	assert_eq(map.province_at(a["x"] + map.touch_radius + 1, a["y"]), "", "un punto más allá: nada")
	assert_eq(map.province_at(0, 0), "", "esquina vacía del mapa")
	assert_eq(map.province_at(-500, 99999), "", "fuera del mapa: nada y sin fallar")
	done()


func test_every_province_can_be_selected_and_zones_never_overlap() -> void:
	var data = new_data()
	var map = _new_map()
	map.load_defaults(data)
	for p in map.provinces:
		assert_eq(map.province_at(p["x"], p["y"]), p["id"], "se puede seleccionar %s" % p["id"])
	# Barrido de toda la cuadrícula: ningún punto cae en la zona de dos provincias a la vez.
	var step := 25
	var x := 0
	while x <= map.width:
		var y := 0
		while y <= map.height:
			var inside := 0
			for p in map.provinces:
				var dx: int = p["x"] - x
				var dy: int = p["y"] - y
				if dx * dx + dy * dy <= map.touch_radius * map.touch_radius:
					inside += 1
			assert_true(inside <= 1, "punto (%d,%d) en %d zonas de toque" % [x, y, inside])
			y += step
		x += step
	done()


func test_new_world_matches_the_map() -> void:
	var data = new_data()
	var map = _new_map()
	map.load_defaults(data)
	var result: Dictionary = map.new_world(data)
	assert_true(result["ok"], "la partida nueva se crea: %s" % result["error"])
	var world = result["world"]
	assert_eq(world.provinces.size(), 5, "5 provincias en el mundo")
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


func test_valid_small_map_is_accepted() -> void:
	var data = new_data()
	var map = _new_map()
	var raw := _raw([_province("a", 100, 100, ["b"]), _province("b", 400, 100, ["a"])])
	assert_true(map.build(raw, data), "mapa pequeño válido: %s" % _errors_text(map))
	assert_eq(map.touch_radius, 100, "radio de toque")
	var single := _raw([_province("solo", 500, 500, [])])
	assert_true(_new_map().build(single, data), "una sola provincia sin vecinos es válida")
	done()


func test_invalid_maps_are_rejected_with_clear_messages() -> void:
	var a := _province("a", 100, 100, ["b"])
	var b := _province("b", 400, 100, ["a"])
	_expect_error(_raw([]), "lista no vacía", "sin provincias")
	_expect_error({"format_version": 2, "width": 1000, "height": 1000, "touch_radius": 100, "provinces": [a]}, "versión de formato", "versión desconocida")
	_expect_error(_raw([a, _province("a", 700, 700, [])]), "id repetido", "id repetido")
	_expect_error(_raw([_province("A!", 100, 100, [])]), "\"id\"", "id con caracteres no válidos")
	_expect_error(_raw([_province("a", 100, 100, ["b"]), _province("b", 400, 100, [])]), "mutua", "vecindad no mutua")
	_expect_error(_raw([_province("a", 100, 100, ["a"])]), "de sí misma", "vecina de sí misma")
	_expect_error(_raw([_province("a", 100, 100, ["zzz"])]), "vecino desconocido", "vecino inexistente")
	_expect_error(_raw([_province("a", 100, 100, ["b", "b"]), b]), "repetido", "vecino repetido")
	_expect_error(_raw([a, _province("b", 150, 120, ["a"])]), "demasiado juntas", "zonas de toque solapadas")
	_expect_error(_raw([a, b, _province("c", 800, 800, [])]), "aisladas", "provincia aislada")
	_expect_error(_raw([_province("a", 5000, 100, [])]), "dentro del mapa", "fuera del mapa")
	_expect_error(_raw([_province("a", 100, 100, [], {"name": "  "})]), "nombre", "sin nombre")
	_expect_error(_raw([_province("a", 100, 100, [], {"start": {"population": 1, "buildings": [], "stock": {}}})]), "population", "población bajo el mínimo")
	_expect_error(_raw([_province("a", 100, 100, [], {"start": {"population": 50, "buildings": ["castillo"], "stock": {}}})]), "edificio desconocido", "edificio inexistente")
	_expect_error(_raw([_province("a", 100, 100, [], {"start": {"population": 50, "buildings": [], "stock": {"oro": 5}}})]), "mercancía desconocida", "mercancía inexistente")
	_expect_error(_raw([_province("a", 100, 100, [], {"start": {"population": 50, "buildings": [], "stock": {"coin": -1}}})]), "cantidad no válida", "cantidad negativa")
	_expect_error(_raw([_province("a", 100, 100, [], {"start": {"population": 50, "buildings": [], "stock": {"coin": 1.5}}})]), "cantidad no válida", "cantidad con decimales")
	var many: Array = []
	for i in range(21):
		many.append(_province("p%d" % i, 100 + (i % 5) * 220, 100 + (i / 5) * 220, []))
	_expect_error(_raw(many), "como máximo 20", "más de 20 provincias")
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
