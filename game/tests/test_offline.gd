extends "res://tests/province_case.gd"
## Progreso offline (criterio A9) y marca de tiempo del guardado.
## Las cifras de tiempo vienen de rules.json: 60 s por paso y tope de 36 000 s (10 h).

const OFFLINE := "res://scripts/sim/offline.gd"
const WORLD := "res://scripts/sim/world.gd"
const SAVE_GAME := "res://scripts/sim/save_game.gd"
const T0 := 1800000000
const TEST_DIR := "user://pruebas_offline"


func _world(data):
	var world = load(WORLD).new(data)
	var a = world.add_province("prueba_a", "Provincia de prueba A", 100)
	for type_id in ["granary", "farm", "farm", "mill", "bakery", "woodcutter"]:
		a.add_building(type_id)
	a.store.seed_initial("bread", 30000)
	a.store.seed_initial("wheat", 6000)
	a.store.seed_initial("firewood", 5000)
	a.store.seed_initial("wood", 9000)
	a.store.seed_initial("coin", 20000)
	var b = world.add_province("prueba_b", "Provincia de prueba B", 60)
	b.add_building("farm")
	b.store.seed_initial("bread", 6000)
	b.store.seed_initial("coin", 5000)
	return world


func _snap(world) -> String:
	var parts: Array[String] = [str(world.step_count)]
	for province in world.provinces:
		parts.append(snapshot(province))
	return "\n".join(parts)


func test_negative_time_gives_no_reward() -> void:
	var data = new_data()
	var world = _world(data)
	var before := _snap(world)
	var result: Dictionary = load(OFFLINE).settle(world, T0, T0 - 3600)
	assert_eq(result["steps"], 0, "reloj atrasado: ningún paso")
	assert_eq(result["clock_problem"], "clock_went_back", "se avisa del reloj")
	assert_eq(result["elapsed_seconds"], 0, "ausencia contada 0")
	assert_eq(_snap(world), before, "el mundo no cambia")
	assert_eq(result["new_saved_at"], T0 - 3600, "la marca nueva es la hora actual")
	done()


func test_unknown_saved_time_gives_no_reward() -> void:
	var data = new_data()
	var world = _world(data)
	var before := _snap(world)
	for unknown in [0, -5]:
		var result: Dictionary = load(OFFLINE).settle(world, unknown, T0)
		assert_eq(result["steps"], 0, "hora desconocida (%d): ningún paso" % unknown)
		assert_eq(result["clock_problem"], "unknown_saved_time", "se avisa (%d)" % unknown)
	assert_eq(_snap(world), before, "el mundo no cambia")
	done()


func test_whole_steps_only_and_the_remainder_is_kept() -> void:
	var data = new_data()
	var offline = load(OFFLINE)
	var world = _world(data)
	var result: Dictionary = offline.settle(world, T0, T0 + 59)
	assert_eq(result["steps"], 0, "59 s no completan un paso")
	assert_eq(result["new_saved_at"], T0, "el resto se conserva: la marca no avanza")
	result = offline.settle(world, T0, T0 + 60)
	assert_eq(result["steps"], 1, "60 s = 1 paso")
	assert_eq(result["new_saved_at"], T0 + 60, "la marca avanza justo un paso")
	result = offline.settle(world, T0 + 60, T0 + 60 + 185)
	assert_eq(result["steps"], 3, "185 s = 3 pasos y 5 s sobrantes")
	assert_eq(result["new_saved_at"], T0 + 60 + 180, "los 5 s sobrantes se quedan para la próxima")
	assert_eq(world.step_count, 4, "se ejecutaron 1 + 3 pasos")
	done()


func test_limit_caps_the_reward_and_discards_the_excess() -> void:
	var data = new_data()
	var world = _world(data)
	var thirty_days := 30 * 24 * 3600
	var result: Dictionary = load(OFFLINE).settle(world, T0, T0 + thirty_days)
	assert_eq(result["steps"], 600, "tope de 10 h = 600 pasos")
	assert_true(result["capped"], "se marca como recortado")
	assert_eq(result["elapsed_seconds"], thirty_days, "se informa de la ausencia real")
	assert_eq(result["applied_seconds"], 36000, "solo cuentan 10 h")
	assert_eq(world.step_count, 600, "el mundo avanzó 600 pasos")
	assert_eq(result["new_saved_at"], T0 + thirty_days, "el exceso se descarta: la marca es la hora actual")
	var exact: Dictionary = load(OFFLINE).settle(_world(data), T0, T0 + 36000)
	assert_eq(exact["steps"], 600, "justo el tope")
	assert_true(not exact["capped"], "justo el tope no es recorte")
	done()


func test_offline_is_the_same_simulation_as_playing() -> void:
	var data = new_data()
	var offline_world = _world(data)
	var played_world = _world(data)
	load(OFFLINE).settle(offline_world, T0, T0 + 250 * 60)
	played_world.run_steps(250)
	assert_eq(_snap(offline_world), _snap(played_world), "250 pasos offline = 250 pasos jugados")
	done()


func test_splitting_the_absence_changes_nothing() -> void:
	var data = new_data()
	var offline = load(OFFLINE)
	var once = _world(data)
	offline.settle(once, T0, T0 + 5000)
	var in_pieces = _world(data)
	var stamp := T0
	for now in [T0 + 777, T0 + 1500, T0 + 1501, T0 + 3333, T0 + 5000]:
		var result: Dictionary = offline.settle(in_pieces, stamp, now)
		stamp = result["new_saved_at"]
	assert_eq(_snap(in_pieces), _snap(once), "cargar varias veces reparte el mismo tiempo, ni más ni menos")
	done()


func test_loading_again_with_the_same_time_does_not_duplicate() -> void:
	var data = new_data()
	var offline = load(OFFLINE)
	var world = _world(data)
	var first: Dictionary = offline.settle(world, T0, T0 + 7200)
	assert_eq(first["steps"], 120, "primera carga: 120 pasos")
	var after_first := _snap(world)
	var second: Dictionary = offline.settle(world, first["new_saved_at"], T0 + 7200)
	assert_eq(second["steps"], 0, "segunda carga con la misma hora: nada")
	assert_eq(_snap(world), after_first, "el estado no cambia")
	done()


func test_loading_the_same_save_file_twice_gives_the_same_world() -> void:
	var data = new_data()
	var save = load(SAVE_GAME)
	var offline = load(OFFLINE)
	var text: String = save.encode(_world(data), "0.0.test", T0)
	var first: Dictionary = save.decode(data, text)
	var second: Dictionary = save.decode(data, text)
	assert_true(first["ok"] and second["ok"], "ambos se cargan")
	assert_eq(first["saved_at"], T0, "la hora del guardado se conserva")
	offline.settle(first["world"], first["saved_at"], T0 + 3000)
	offline.settle(second["world"], second["saved_at"], T0 + 3000)
	assert_eq(_snap(first["world"]), _snap(second["world"]), "dos cargas del mismo archivo dan el mismo mundo, no el doble")
	assert_eq(first["world"].step_count, 50, "50 pasos, no 100")
	done()


func test_invariants_and_conservation_hold_after_a_capped_absence() -> void:
	var data = new_data()
	var world = _world(data)
	load(OFFLINE).settle(world, T0, T0 + 10 * 24 * 3600)
	assert_eq(world.check_invariants(), [], "sin incoherencias tras una ausencia larga")
	for province in world.provinces:
		assert_eq(province.store.check_conservation(), [], "conservación en %s" % province.id)
	done()


func test_summary_reports_what_happened() -> void:
	var data = new_data()
	var world = _world(data)
	var a = world.find_province("prueba_a")
	assert_true(a.start_construction("house"), "obra de vivienda iniciada: %s" % a.last_error)
	var stock_before := {}
	for good in data.goods.keys():
		stock_before[good] = a.store.stock(good)
	var houses_before := 0
	for b in a.buildings:
		if b["type"] == "house":
			houses_before += 1
	var result: Dictionary = load(OFFLINE).settle(world, T0, T0 + 120 * 60)
	assert_eq(result["steps"], 120, "120 pasos")
	assert_eq(result["provinces"].size(), 2, "una entrada por provincia")
	var entry: Dictionary = result["provinces"][0]
	assert_eq(entry["id"], "prueba_a", "orden de provincias")
	assert_eq(entry["name"], "Provincia de prueba A", "nombre")
	assert_eq(entry["population_before"], 100, "población antes")
	assert_eq(entry["population_after"], a.population, "población después")
	for good in data.goods.keys():
		var expected: int = a.store.stock(good) - stock_before[good]
		assert_eq(entry["stock_delta"].get(good, 0), expected, "variación de %s" % good)
	var houses_after: int = entry["buildings_after"].get("house", 0)
	assert_eq(houses_after, houses_before + 1, "la vivienda en obra quedó terminada y consta en el resumen")
	assert_eq(entry["buildings_before"].get("house", 0), houses_before, "viviendas antes")
	done()


func test_summary_reports_the_worst_moment_of_a_famine() -> void:
	var data = new_data()
	var world = load(WORLD).new(data)
	var p = world.add_province("hambre", "Provincia sin comida", 100)
	p.store.seed_initial("coin", 1000)
	var result: Dictionary = load(OFFLINE).settle(world, T0, T0 + 60 * 60)
	var entry: Dictionary = result["provinces"][0]
	assert_true(entry["worst_hunger_steps"] >= 24, "se informa del peor hambre aunque ya haya pasado o siga: %d" % entry["worst_hunger_steps"])
	assert_true(entry["worst_unrest"] > 0, "y del peor descontento")
	assert_true(entry["population_after"] < entry["population_before"], "la población bajó")
	assert_true(entry["population_after"] >= data.rules["min_population"], "sin bajar del mínimo")
	assert_eq(entry["alerts"], ["starvation"], "y el aviso final de hambruna")
	assert_eq(entry["worst_unrest"], data.rules["unrest_max"], "descontento al máximo")
	done()


func test_new_rules_are_validated() -> void:
	var reference = new_data()
	var raw: Dictionary = {}
	for key in reference.rules.keys():
		raw[key] = reference.rules[key]
	assert_true(new_data().build_rules(raw.duplicate(true)), "las reglas normales se aceptan")
	for case in [["step_seconds", 0], ["step_seconds", 86401], ["offline_limit_seconds", -1], ["offline_limit_seconds", 172801], ["step_seconds", 1.5]]:
		var probe = new_data()
		var rules: Dictionary = raw.duplicate(true)
		rules[case[0]] = case[1]
		assert_true(not probe.build_rules(rules), "se rechaza %s = %s" % [case[0], str(case[1])])
	done()


func test_save_time_is_stored_and_bad_values_become_unknown() -> void:
	var data = new_data()
	var save = load(SAVE_GAME)
	var world = _world(data)
	var payload: Dictionary = world.to_dict()
	var good: Dictionary = save.decode(data, save.pack(payload, "x", T0))
	assert_eq(good["saved_at"], T0, "se conserva")
	var old_format: Dictionary = save.decode(data, save.encode(world, "x"))
	assert_eq(old_format["saved_at"], 0, "un guardado sin hora da 0 = desconocida")
	for bad in ["\"ayer\"", "-5", "12.5", "null", "[]"]:
		var text: String = save.pack(payload, "x", T0).replace("\"saved_at\": %d" % T0, "\"saved_at\": %s" % bad)
		var result: Dictionary = save.decode(data, text)
		assert_true(result["ok"], "un valor raro en la hora no impide cargar (%s)" % bad)
		assert_eq(result["saved_at"], 0, "y se trata como desconocida (%s)" % bad)
	done()


func test_save_time_survives_the_file_round_trip() -> void:
	var data = new_data()
	var save = load(SAVE_GAME)
	var path: String = TEST_DIR + "/partida.json"
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	var error: String = save.write_file(_world(data), path, "x", T0)
	assert_eq(error, "", "se guarda")
	var result: Dictionary = save.read_file(data, path)
	assert_true(result["ok"], "se lee")
	assert_eq(result["saved_at"], T0, "la hora hace el viaje de ida y vuelta")
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	done()
