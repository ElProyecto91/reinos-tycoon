extends "res://tests/province_case.gd"
## Construcción con costes, mano de obra y tiempo (tarea 1.5; criterio A5).


func _builder_province(data, population: int = 100):
	var p = new_province(data, population)
	p.store.seed_initial("bread", 18000)
	p.store.seed_initial("wood", 9000)
	p.store.seed_initial("coin", 20000)
	return p


func test_construction_charges_the_cost_only_once() -> void:
	var data = new_data()
	var p = _builder_province(data)
	assert_true(p.start_construction("farm"), "debe poder empezar: %s" % p.last_error)
	assert_eq(p.store.stock("wood"), 8000, "se descuentan 1000 de madera")
	assert_eq(p.store.stock("coin"), 17000, "se descuentan 3000 de moneda")
	assert_eq(p.projects.size(), 1, "hay una obra")
	assert_eq(p.projects[0]["remaining"], 5, "tiempo restante visible: 5 pasos")
	run_steps(p, 4)
	assert_eq(p.projects[0]["remaining"], 1, "queda 1 paso")
	assert_eq(p.count_buildings("farm"), 0, "aún no está terminada")
	p.step()
	assert_eq(p.count_buildings("farm"), 1, "terminada al quinto paso")
	assert_eq(p.projects.size(), 0, "la obra desaparece de la lista")
	assert_eq(p.store.ledger("wood")["consumed"], 1000, "la madera se cobró una sola vez")
	assert_eq(p.store.ledger("coin")["consumed"], 3000, "la moneda se cobró una sola vez")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()


func test_building_limit_counts_finished_buildings_and_projects() -> void:
	# D-020: tope de edificios por provincia. Con recursos de sobra, el tope manda.
	var data = new_data()
	var limit: int = data.rules["max_buildings"]
	var p = new_province(data, 100)
	p.store.seed_initial("wood", 60000)
	p.store.seed_initial("coin", 60000)
	for i in range(limit - 1):
		p.add_building("house")
	assert_true(p.start_construction("house"), "con %d de %d todavía cabe uno más: %s" % [limit - 1, limit, p.last_error])
	assert_eq(p.buildings.size() + p.projects.size(), limit, "terminados + obras llegan al tope")
	var wood_before: int = p.store.stock("wood")
	var coin_before: int = p.store.stock("coin")
	assert_true(not p.start_construction("house"), "la obra en curso ya ocupa el último sitio")
	assert_true(p.last_error.contains("sitio"), "el motivo habla del sitio: %s" % p.last_error)
	assert_eq(p.projects.size(), 1, "no se añadió otra obra")
	assert_eq(p.store.stock("wood"), wood_before, "no se cobró madera")
	assert_eq(p.store.stock("coin"), coin_before, "no se cobró moneda")
	run_steps(p, 20)
	assert_eq(p.buildings.size(), limit, "la obra terminó y hay %d edificios" % limit)
	assert_true(not p.start_construction("farm"), "con el tope alcanzado no se construye nada más")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()


func test_construction_is_rejected_without_materials() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("wood", 500)
	p.store.seed_initial("coin", 20000)
	assert_true(not p.start_construction("farm"), "faltan 500 de madera")
	assert_true(p.last_error.contains("recursos"), "el motivo habla de recursos")
	assert_eq(p.projects.size(), 0, "no hay obra")
	assert_eq(p.store.stock("wood"), 500, "no se cobró nada")
	assert_eq(p.store.stock("coin"), 20000, "no se cobró nada")
	done()


func test_construction_is_rejected_without_coin() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("wood", 9000)
	p.store.seed_initial("coin", 2999)
	assert_true(not p.start_construction("farm"), "faltan 1 de moneda")
	assert_eq(p.store.stock("wood"), 9000, "la madera tampoco se cobra")
	done()


func test_construction_is_rejected_without_workers() -> void:
	var data = new_data()
	var p = _builder_province(data)
	assert_true(p.recruit(50), "reclutar a toda la mano de obra")
	assert_eq(p.available_workers(), 0, "no queda nadie")
	assert_true(not p.start_construction("house"), "sin mano de obra no se empieza")
	assert_true(p.last_error.contains("trabajadores"), "el motivo habla de trabajadores")
	assert_eq(p.store.stock("wood"), 9000, "no se cobró nada")
	assert_eq(p.projects.size(), 0, "no hay obra")
	done()


func test_construction_takes_workers_from_buildings_when_staffing_is_automatic() -> void:
	var data = new_data()
	var p = _builder_province(data, 20)
	var f1: int = p.add_building("farm")
	var f2: int = p.add_building("farm")
	var f3: int = p.add_building("farm")
	p.step()
	assert_eq(p.available_workers(), 0, "toda la mano de obra está empleada")
	assert_true(p.start_construction("house"), "la obra tiene prioridad: %s" % p.last_error)
	assert_eq(p.find_building(f3)["workers"], 1, "se quita un trabajador a la última granja")
	assert_eq(p.find_building(f1)["workers"], 4, "las primeras no se tocan")
	assert_eq(p.find_building(f2)["workers"], 4, "las primeras no se tocan")
	assert_eq(p.assigned_labor(), 10, "nunca más asignados que mano de obra")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()


func test_construction_does_not_take_workers_when_staffing_is_manual() -> void:
	var data = new_data()
	var p = _builder_province(data, 20)
	p.auto_staff = false
	var f1: int = p.add_building("farm")
	var f2: int = p.add_building("farm")
	var f3: int = p.add_building("farm")
	p.assign_workers(f1, 4)
	p.assign_workers(f2, 4)
	p.assign_workers(f3, 2)
	assert_true(not p.start_construction("house"), "en manual no se quitan trabajadores")
	assert_eq(p.store.stock("wood"), 9000, "no se cobró nada")
	done()


func test_builders_are_released_when_the_work_ends() -> void:
	var data = new_data()
	var p = _builder_province(data)
	p.start_construction("farm")
	assert_eq(p.assigned_labor(), 2, "dos obreros en la obra")
	run_steps(p, 5)
	assert_eq(p.assigned_labor(), 0, "al terminar se liberan; la granja nueva aún no tiene gente")
	p.step()
	assert_eq(p.assigned_labor(), 4, "al paso siguiente la granja recibe sus 4 trabajadores")
	done()


func test_granary_construction_increases_capacity() -> void:
	var data = new_data()
	var p = _builder_province(data)
	assert_true(p.start_construction("granary"), "empezar el granero: %s" % p.last_error)
	run_steps(p, 5)
	assert_eq(p.store.capacity, 60000, "aún no está")
	p.step()
	assert_eq(p.store.capacity, 100000, "terminado: +40000")
	done()


func test_project_queue_has_a_limit() -> void:
	var data = new_data()
	var p = _builder_province(data)
	for i in range(3):
		assert_true(p.start_construction("house"), "obra %d: %s" % [i + 1, p.last_error])
	assert_true(not p.start_construction("house"), "la cuarta no cabe en la cola")
	assert_true(p.last_error.contains("obras"), "el motivo habla de obras")
	assert_eq(p.projects.size(), 3, "tres obras")
	assert_eq(p.store.stock("wood"), 4500, "solo se cobraron tres casas")
	done()


func test_second_project_is_not_partially_charged() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("wood", 1500)
	p.store.seed_initial("coin", 20000)
	assert_true(p.start_construction("house"), "la primera casa se paga")
	assert_true(not p.start_construction("house"), "para la segunda no queda madera")
	assert_eq(p.store.stock("wood"), 0, "se gastó solo la de la primera")
	assert_eq(p.store.stock("coin"), 18000, "y solo la moneda de la primera")
	assert_eq(p.projects.size(), 1, "una obra")
	done()


func test_unknown_building_type_is_rejected() -> void:
	var data = new_data()
	var p = _builder_province(data)
	assert_true(not p.start_construction("castillo"), "tipo inexistente")
	assert_true(p.last_error.contains("castillo"), "el motivo nombra el tipo")
	done()


func test_new_building_works_after_construction() -> void:
	var data = new_data()
	var p = _builder_province(data)
	p.start_construction("farm")
	run_steps(p, 5 + 6 + 1)
	assert_eq(p.store.stock("wheat"), 6000, "la granja nueva produjo su primera cosecha")
	done()
