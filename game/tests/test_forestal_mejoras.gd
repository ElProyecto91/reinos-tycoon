extends "res://tests/province_case.gd"
## Fases 2.4 a 2.6 (D-032): cadena forestal (carbonera, herramentero), mantenimiento en herramientas y
## mejoras de edificio al nivel 2. Todas las cifras son parámetros de juego provisionales.

const STORE := "res://scripts/sim/store.gd"


func _province(data, population: int = 100):
	data.rules["food_per_person"] = 0
	data.rules["calendar_start_day"] = 181      # verano: sin calefacción que moleste
	var p = new_province(data, population)
	p.store.seed_initial("coin", 60000)
	p.store.seed_initial("wood", 7800)
	return p


# --- 2.4 Cadena forestal -------------------------------------------------------------------------

func test_the_kiln_turns_wood_into_charcoal() -> void:
	var data = new_data()
	var p = _province(data)
	var kiln: int = p.add_building("charcoal_kiln")
	run_steps(p, 7)
	assert_eq(p.store.stock("charcoal"), 0, "antes de acabar el ciclo no hay carbón")
	assert_eq(p.store.stock("wood"), 7800 - 3000, "la madera se gasta al empezar")
	p.step()
	assert_eq(p.store.stock("charcoal"), 1500, "al octavo paso salen 1500 de carbón vegetal")
	assert_true(p.find_building(kiln)["status"] in ["running", "idle"], "sigue trabajando")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()


func test_the_kiln_without_wood_says_what_is_missing() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("coin", 60000)
	var kiln: int = p.add_building("charcoal_kiln")
	p.step()
	assert_eq(p.find_building(kiln)["status"], "missing_inputs", "sin madera no produce y lo dice")
	assert_eq(p.find_building(kiln)["missing"], {"wood": 3000}, "falta toda la madera del lote")
	done()


func test_the_toolsmith_needs_iron_and_charcoal() -> void:
	var data = new_data()
	var p = _province(data)
	p.store.seed_initial("iron", 1000)
	var t: int = p.add_building("toolsmith")
	p.step()
	assert_eq(p.find_building(t)["status"], "missing_inputs", "sin carbón no produce")
	assert_eq(p.find_building(t)["missing"], {"charcoal": 300}, "y dice que falta carbón")
	p.store.seed_initial("charcoal", 300)
	run_steps(p, 8)
	assert_eq(p.store.stock("tools"), 600, "con hierro y carbón salen 600 de herramientas")
	assert_eq(p.store.stock("iron"), 0, "gastó el hierro")
	assert_eq(p.store.stock("charcoal"), 0, "y el carbón")
	done()


func test_the_whole_forest_and_tools_chain_conserves_goods_for_a_season() -> void:
	var data = new_data()
	var p = _province(data, 200)
	p.store.seed_initial("tools", 1800)
	for id in ["granary", "woodcutter", "charcoal_kiln", "mine", "toolsmith"]:
		p.add_building(id)
	run_steps(p, 24 * 90)
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	assert_true(p.store.ledger("charcoal")["produced"] > 0, "se hizo carbón")
	assert_true(p.store.ledger("tools")["produced"] > 0, "se hicieron herramientas")
	for g in ["wood", "charcoal", "iron", "tools"]:
		var l: Dictionary = p.store.ledger(g)
		assert_eq(p.store.stock(g), l["initial"] + l["produced"] + l["imported"] - l["consumed"] - l["exported"] - l["lost"], "%s: existencias = libro" % g)
	done()


# --- 2.5 Mantenimiento en mercancías --------------------------------------------------------------

func test_mine_and_smithy_stop_without_tools_and_say_so() -> void:
	var data = new_data()
	var p = _province(data)
	var mine: int = p.add_building("mine")
	p.step()
	assert_eq(p.find_building(mine)["status"], "no_upkeep", "sin herramientas la mina se detiene")
	assert_eq(p.find_building(mine)["missing"], {"tools": 30}, "y dice que faltan 30 de herramientas")
	assert_eq(p.store.stock("iron"), 0, "no produce hierro")
	p.store.seed_initial("tools", 30)
	run_steps(p, 9)
	assert_eq(p.store.stock("iron"), 1500, "con herramientas trabaja")
	assert_eq(p.store.stock("tools"), 0, "y se gastaron 30 por ciclo")
	assert_eq(p.store.ledger("tools")["consumed"], 30, "queda anotado como consumido")
	done()


func test_smithy_upkeep_is_20_tools_per_cycle() -> void:
	var data = new_data()
	var p = _province(data)
	p.store.seed_initial("iron", 1500)
	p.store.seed_initial("firewood", 500)
	p.store.seed_initial("tools", 100)
	p.add_building("smithy")
	run_steps(p, 6)
	assert_eq(p.store.stock("tools"), 80, "gasta 20 de herramientas por ciclo")
	assert_eq(p.store.stock("weapons"), 1000, "y entrega las armas")
	done()


func test_farms_and_woodcutters_do_not_need_tools() -> void:
	var data = new_data()
	for id in ["farm", "woodcutter", "mill", "bakery", "house", "granary"]:
		assert_true(not data.buildings[id]["upkeep"].has("tools"), "%s no pide herramientas (la comida y la leña no dependen de ellas)" % id)
	done()


# --- 2.6 Mejoras ----------------------------------------------------------------------------------

func test_upgrade_cost_and_steps_follow_the_rules() -> void:
	var data = new_data()
	var p = _province(data)
	assert_eq(p.upgrade_cost("farm"), {"wood": 2000, "coin": 6000}, "mejorar cuesta el doble de construir (200 %)")
	assert_eq(p.upgrade_steps("farm"), 8, "y 150 % de pasos (5 → 8, redondeado hacia arriba)")
	done()


func test_upgrade_takes_resources_once_and_raises_level_after_the_work() -> void:
	var data = new_data()
	var p = _province(data)
	var farm: int = p.add_building("farm")
	var coin_before: int = p.store.stock("coin")
	var count_before: int = p.buildings.size()
	assert_true(p.start_upgrade(farm), "se puede mejorar: %s" % p.last_error)
	assert_eq(p.store.stock("coin"), coin_before - 6000, "se cobra la moneda")
	assert_eq(p.store.stock("wood"), 7800 - 2000, "y la madera")
	assert_eq(p.projects.size(), 1, "hay una obra")
	assert_eq(p.projects[0]["upgrade_uid"], farm, "que es la mejora de esa granja")
	assert_true(p.is_upgrading(farm), "se sabe que se está mejorando")
	assert_true(not p.start_upgrade(farm), "no se puede mejorar dos veces a la vez")
	assert_eq(p.store.stock("coin"), coin_before - 6000, "y no se cobró de nuevo")
	run_steps(p, 8)
	assert_eq(p.find_building(farm)["level"], 2, "tras las obras la granja es de nivel 2")
	assert_eq(p.projects.size(), 0, "la obra terminó")
	assert_eq(p.buildings.size(), count_before, "no se creó un edificio nuevo")
	assert_true(not p.is_upgrading(farm), "ya no se está mejorando")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()


func test_level_two_produces_150_percent_and_costs_150_percent_upkeep_once() -> void:
	var data = new_data()
	var p = _province(data)
	var farm: int = p.add_building("farm")
	p.start_upgrade(farm)
	run_steps(p, 8)
	assert_eq(p.find_building(farm)["level"], 2, "ya es de nivel 2")
	# Se vacía el trigo cada paso para que el almacén no se llene y se mida cada cosecha.
	var kind = load(STORE).CONSUMED
	p.store.remove("wheat", p.store.stock("wheat"), kind)
	var produced_before: int = p.store.ledger("wheat")["produced"]
	var spent_before: int = p.store.ledger("coin")["consumed"]
	for i in range(30):
		p.step()
		p.store.remove("wheat", p.store.stock("wheat"), kind)
	var produced: int = p.store.ledger("wheat")["produced"] - produced_before
	assert_true(produced >= 9000, "hubo al menos una cosecha")
	assert_eq(produced % 9000, 0, "cada cosecha del nivel 2 es de 9000 (150 %% de 6000); salió %d" % produced)
	var spent: int = p.store.ledger("coin")["consumed"] - spent_before
	assert_true(spent > 0 and spent % 900 == 0, "la moneda de mantenimiento se gasta de 900 en 900 (150 %% de 600): %d" % spent)
	assert_eq(p.upkeep_of(p.find_building(farm)), {"coin": 900}, "el mantenimiento calculado es 900")
	assert_true(not p.start_upgrade(farm), "una granja de nivel 2 no mejora más")
	assert_eq(p.last_error, "este edificio no se puede mejorar más", "y dice por qué")
	done()


func test_upgrade_is_rejected_without_resources_workers_or_a_valid_building() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	var farm: int = p.add_building("farm")
	assert_true(not p.start_upgrade(farm), "sin moneda ni madera no se mejora")
	assert_eq(p.last_error, "faltan recursos para mejorar", "motivo claro")
	assert_eq(p.projects.size(), 0, "no queda obra")
	p.store.seed_initial("coin", 60000)
	p.store.seed_initial("wood", 7800)
	var house: int = p.add_building("house")
	assert_true(not p.start_upgrade(house), "una vivienda no se mejora")
	assert_true(not p.start_upgrade(999), "un edificio que no existe tampoco")
	assert_eq(p.store.stock("coin"), 60000, "ninguno de los intentos cobró nada")
	data.rules["upgrade_cost_percent"] = 0
	assert_true(not p.start_upgrade(farm), "con la regla a 0 no hay mejoras")
	done()


func test_upgrade_does_not_need_a_free_building_slot_but_does_use_the_project_queue() -> void:
	var data = new_data()
	var p = _province(data, 400)
	var farm: int = p.add_building("farm")
	var cutter: int = p.add_building("woodcutter")
	while p.buildings.size() < data.rules["max_buildings"]:
		p.add_building("house")
	assert_true(not p.start_construction("house"), "el tope de edificios impide construir")
	assert_true(p.start_upgrade(farm), "pero se puede mejorar (no ocupa sitio): %s" % p.last_error)
	data.rules["max_projects"] = 1
	assert_true(not p.start_upgrade(cutter), "con la cola de obras llena no se mejora otro")
	assert_eq(p.last_error, "ya hay 1 obras en curso", "y dice por qué")
	done()


func test_upgrade_project_is_saved_and_loaded_and_bad_data_is_rejected() -> void:
	var data = new_data()
	var p = _province(data)
	var farm: int = p.add_building("farm")
	p.start_upgrade(farm)
	run_steps(p, 3)
	var saved: Dictionary = p.to_dict()
	var q = new_province(data, 100)
	assert_true(q.load_dict(saved), "carga a mitad de mejora: %s" % q.last_error)
	run_steps(p, 6)
	run_steps(q, 6)
	assert_eq(snapshot(q), snapshot(p), "y termina igual")
	assert_eq(q.find_building(farm)["level"], 2, "con el nivel 2")
	var old: Dictionary = saved.duplicate(true)
	for b in old["buildings"]:
		b.erase("level")
	for pr in old["projects"]:
		pr.erase("upgrade_uid")
	var r = new_province(data, 100)
	assert_true(r.load_dict(old), "un guardado anterior sin nivel ni mejoras carga: %s" % r.last_error)
	assert_eq(r.find_building(farm)["level"], 1, "y el nivel vale 1")
	var broken: Dictionary = saved.duplicate(true)
	broken["buildings"][0]["level"] = 3
	assert_true(not new_province(data, 100).load_dict(broken), "nivel por encima del máximo")
	broken = saved.duplicate(true)
	broken["buildings"][0]["level"] = 0
	assert_true(not new_province(data, 100).load_dict(broken), "nivel 0")
	broken = saved.duplicate(true)
	broken["projects"][0]["upgrade_uid"] = 77
	assert_true(not new_province(data, 100).load_dict(broken), "mejora de un edificio que no existe")
	broken = saved.duplicate(true)
	broken["projects"][0]["remaining"] = 99
	assert_true(not new_province(data, 100).load_dict(broken), "tiempo de obra de mejora fuera de rango")
	done()


func test_max_level_is_validated_in_the_data() -> void:
	var data = new_data()
	var base: Dictionary = {
		"id": "x", "name": "x", "category": "agricultural", "workers": 1, "build_workers": 1,
		"build_cost": {"wood": 1000}, "build_steps": 2, "inputs": {}, "outputs": {"wheat": 1000},
		"cycle_steps": 3, "upkeep": {}, "storage_capacity": 0, "housing": 0,
	}
	var ok_entry: Dictionary = base.duplicate(true)
	ok_entry["max_level"] = 2
	var d1 = new_data()
	assert_true(d1.build_buildings([ok_entry]), "max_level 2 es válido: %s" % "\n".join(d1.errors))
	assert_eq(d1.buildings["x"]["max_level"], 2, "se guarda")
	var d2 = new_data()
	assert_true(d2.build_buildings([base]), "sin max_level vale 1")
	assert_eq(d2.buildings["x"]["max_level"], 1, "nivel máximo 1 por defecto")
	for bad in [0, 4, 1.5, "2"]:
		var entry: Dictionary = base.duplicate(true)
		entry["max_level"] = bad
		var d3 = new_data()
		assert_true(not d3.build_buildings([entry]), "se rechaza max_level = %s" % str(bad))
	var passive: Dictionary = base.duplicate(true)
	passive["outputs"] = {}
	passive["max_level"] = 2
	var d4 = new_data()
	assert_true(not d4.build_buildings([passive]), "un edificio que no produce no puede tener mejoras")
	assert_true(data.buildings["house"]["max_level"] == 1 and data.buildings["farm"]["max_level"] == 2, "datos reales: la vivienda no mejora y la granja sí")
	done()


func test_every_map_province_starts_with_tools_so_a_new_mine_can_work() -> void:
	var data = new_data()
	var map = load("res://scripts/sim/game_map.gd").new()
	assert_true(map.load_defaults(data), "el mapa carga: %s" % "\n".join(map.errors))
	var created: Dictionary = map.new_world(data)
	assert_true(created["ok"], "partida nueva")
	var world = created["world"]
	for p in world.provinces:
		assert_eq(p.store.stock("tools"), 1800, "%s empieza con 1,8 de herramientas" % p.id)
	var p0 = world.provinces[0]
	var mine: int = p0.add_building("mine")
	run_steps(p0, 9)
	assert_eq(p0.find_building(mine)["status"] in ["running", "idle"], true, "la mina nueva trabaja con esa reserva (estado %s)" % p0.find_building(mine)["status"])
	assert_true(p0.store.ledger("iron")["produced"] > 0, "y produce hierro")
	done()


func test_loading_rejects_a_level_above_the_building_maximum_in_the_parser_itself() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.add_building("farm")
	var entry: Dictionary = p.to_dict()["buildings"][0].duplicate(true)
	assert_true(p._parse_saved_building(entry, {}, 99) != null, "con nivel 1 se acepta")
	entry["level"] = 9
	assert_true(p._parse_saved_building(entry, {}, 99) == null, "un nivel por encima del máximo se rechaza al leer el edificio")
	done()
