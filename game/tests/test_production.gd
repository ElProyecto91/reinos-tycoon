extends "res://tests/province_case.gd"
## Edificios y producción con insumos (tarea 1.4; criterios A2 y A3).


func _fed_province(data, population: int = 100):
	var p = new_province(data, population)
	p.store.seed_initial("bread", 18000)
	return p


func test_farm_produces_after_a_full_cycle() -> void:
	var data = new_data()
	var p = _fed_province(data)
	p.add_building("farm")
	run_steps(p, 5)
	assert_eq(p.store.stock("wheat"), 0, "a los 5 pasos aún no hay trigo")
	p.step()
	assert_eq(p.store.stock("wheat"), 6000, "al sexto paso salen 6000")
	assert_eq(p.store.ledger("coin")["consumed"], 600, "mantenimiento pagado una vez al empezar el ciclo")
	done()


func test_farm_starts_the_next_cycle_at_once() -> void:
	var data = new_data()
	var p = _fed_province(data)
	p.add_building("farm")
	run_steps(p, 12)
	assert_eq(p.store.stock("wheat"), 12000, "dos ciclos en 12 pasos")
	assert_eq(p.store.ledger("coin")["consumed"], 1200, "dos pagos de mantenimiento")
	done()


func test_mill_without_wheat_reports_missing_inputs() -> void:
	var data = new_data()
	var p = _fed_province(data)
	var mill: int = p.add_building("mill")
	p.step()
	var b: Dictionary = p.find_building(mill)
	assert_eq(b["status"], "missing_inputs", "sin trigo no produce")
	assert_eq(b["missing"].size(), 1, "falta una sola mercancía")
	assert_eq(b["missing"].get("wheat", -1), 4000, "dice qué falta y cuánto")
	assert_eq(p.store.stock("flour"), 0, "no sale harina")
	done()


func test_mill_converts_wheat_into_flour() -> void:
	var data = new_data()
	var p = _fed_province(data)
	p.store.seed_initial("wheat", 8000)
	p.add_building("mill")
	run_steps(p, 4)
	assert_eq(p.store.stock("wheat"), 4000, "gasta 4000 de trigo al empezar")
	assert_eq(p.store.stock("flour"), 3000, "produce 3000 de harina a los 4 pasos")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()


func test_inputs_are_not_spent_when_the_cycle_cannot_start() -> void:
	var data = new_data()
	var p = _fed_province(data)
	p.store.seed_initial("wheat", 3999)
	p.add_building("mill")
	run_steps(p, 5)
	assert_eq(p.store.stock("wheat"), 3999, "con 3999 no empieza y no gasta nada")
	assert_eq(p.store.ledger("wheat")["consumed"], 0, "nada consumido")
	done()


func test_bakery_reports_missing_firewood() -> void:
	var data = new_data()
	var p = _fed_province(data)
	p.store.seed_initial("flour", 3000)
	var bakery: int = p.add_building("bakery")
	p.step()
	var b: Dictionary = p.find_building(bakery)
	assert_eq(b["status"], "missing_inputs", "falta leña")
	assert_eq(b["missing"].size(), 1, "falta una sola mercancía")
	assert_eq(b["missing"].get("firewood", -1), 500, "solo falta la leña")
	done()


func test_bakery_bakes_bread() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("bread", 6000)
	p.store.seed_initial("flour", 3000)
	p.store.seed_initial("firewood", 500)
	p.add_building("bakery")
	run_steps(p, 4)
	assert_eq(p.store.ledger("bread")["produced"], 4000, "4000 de pan a los 4 pasos")
	assert_eq(p.store.stock("flour"), 0, "gasta la harina")
	assert_eq(p.store.stock("firewood"), 0, "gasta la leña")
	done()


func test_full_chain_makes_bread() -> void:
	var data = new_data()
	var p = chain_province(data)
	run_steps(p, 100)
	assert_true(p.store.ledger("wheat")["produced"] > 0, "hay trigo")
	assert_true(p.store.ledger("flour")["produced"] > 0, "hay harina")
	assert_true(p.store.ledger("bread")["produced"] > 0, "hay pan")
	assert_eq(p.hunger_steps, 0, "la población come")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()


func test_building_without_enough_workers_does_not_run() -> void:
	var data = new_data()
	var p = _fed_province(data)
	p.auto_staff = false
	var farm: int = p.add_building("farm")
	run_steps(p, 7)
	assert_eq(p.find_building(farm)["status"], "no_workers", "sin trabajadores")
	assert_eq(p.store.stock("wheat"), 0, "no produce")
	p.assign_workers(farm, 2)
	p.step()
	assert_eq(p.find_building(farm)["status"], "no_workers", "con la mitad tampoco")
	p.assign_workers(farm, 4)
	run_steps(p, 6)
	assert_eq(p.store.stock("wheat"), 6000, "con todos trabaja")
	done()


func test_disabled_building_does_not_run() -> void:
	var data = new_data()
	var p = _fed_province(data)
	var farm: int = p.add_building("farm")
	assert_true(p.set_enabled(farm, false), "desactivar")
	run_steps(p, 7)
	assert_eq(p.find_building(farm)["status"], "disabled", "desactivada")
	assert_eq(p.store.stock("wheat"), 0, "no produce")
	assert_true(not p.set_enabled(999, false), "edificio inexistente")
	p.set_enabled(farm, true)
	run_steps(p, 6)
	assert_eq(p.store.stock("wheat"), 6000, "al activarla produce")
	done()


func test_missing_upkeep_stops_the_building() -> void:
	var data = new_data()
	data.rules["tax_per_person"] = 0
	var p = _fed_province(data)
	var farm: int = p.add_building("farm")
	p.step()
	var b: Dictionary = p.find_building(farm)
	assert_eq(b["status"], "no_upkeep", "sin moneda para el mantenimiento")
	assert_eq(b["missing"].size(), 1, "falta una sola mercancía")
	assert_eq(b["missing"].get("coin", -1), 600, "faltan 600 de moneda")
	p.store.seed_initial("coin", 600)
	p.step()
	assert_eq(p.find_building(farm)["status"], "running", "con la moneda arranca")
	done()


func test_full_storage_stops_production_and_says_why() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	for good in ["wheat", "bread"]:
		p.store.seed_initial(good, 18000)
	p.store.seed_initial("flour", 6000)
	p.store.seed_initial("wood", 9000)
	p.store.seed_initial("firewood", 9000)
	assert_eq(p.store.free_space(), 0, "el almacén está lleno")
	var farm: int = p.add_building("farm")
	p.step()
	var b: Dictionary = p.find_building(farm)
	assert_eq(b["status"], "storage_full", "se detiene por almacén lleno")
	assert_true(not b["active"], "no gastó nada ni empezó el ciclo")
	assert_eq(p.store.stock("wheat"), 18000, "no se produce trigo")
	assert_true(p.alerts.has("storage_full"), "aviso de almacén lleno")
	assert_true(p.store.used_space() <= p.store.capacity, "nunca se supera la capacidad")
	done()


func test_one_good_at_its_limit_blocks_only_its_producers() -> void:
	var data = new_data()
	var p = _fed_province(data)
	p.store.seed_initial("wheat", 18000)
	var farm: int = p.add_building("farm")
	p.step()
	assert_eq(p.find_building(farm)["status"], "storage_full", "el trigo llegó a su parte de almacén")
	assert_true(p.store.free_space() > 0, "queda sitio libre para otras mercancías")
	done()


func test_finishing_waits_for_space_and_then_completes() -> void:
	var data = new_data()
	var p = _fed_province(data)
	var farm: int = p.add_building("farm")
	run_steps(p, 3)
	p.store.add("wheat", 18000, "imported")
	run_steps(p, 3)
	var b: Dictionary = p.find_building(farm)
	assert_eq(b["status"], "storage_full", "el ciclo terminó pero no cabe el resultado")
	assert_eq(p.store.stock("wheat"), 18000, "no se creó trigo de más")
	run_steps(p, 2)
	assert_eq(p.store.ledger("coin")["consumed"], 600, "el mantenimiento se pagó una sola vez")
	p.store.remove("wheat", 18000, "exported")
	p.step()
	assert_eq(p.store.stock("wheat"), 6000, "al haber sitio entrega el resultado")
	assert_eq(p.find_building(farm)["status"], "running", "vuelve a trabajar")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()


func test_productivity_percent_follows_unrest() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.unrest = 0
	assert_eq(p.productivity_percent(), 100, "sin descontento")
	p.unrest = 300
	assert_eq(p.productivity_percent(), 100, "en el umbral")
	p.unrest = 301
	assert_eq(p.productivity_percent(), 100, "una milésima por encima apenas se nota")
	p.unrest = 400
	assert_eq(p.productivity_percent(), 93, "400: 100 - floor(100 * 50 / 700)")
	p.unrest = 650
	assert_eq(p.productivity_percent(), 75, "650: 100 - floor(350 * 50 / 700)")
	p.unrest = 1000
	assert_eq(p.productivity_percent(), 50, "máximo descontento: la mitad de velocidad")
	done()


func test_unrest_slows_work_without_wasting_inputs() -> void:
	var data = new_data()
	data.rules["unrest_fall"] = 0
	var p = _fed_province(data)
	p.unrest = 1000
	p.add_building("farm")
	run_steps(p, 11)
	assert_eq(p.store.stock("wheat"), 0, "a la mitad de velocidad 11 pasos no bastan para un ciclo de 6")
	p.step()
	assert_eq(p.store.stock("wheat"), 6000, "el ciclo tarda el doble (12 pasos) pero rinde lo mismo")
	done()


func test_bad_harvest_modifier_scales_wheat_and_expires() -> void:
	var data = new_data()
	var p = _fed_province(data)
	p.add_modifier("wheat", 50, 7)
	p.add_building("farm")
	run_steps(p, 12)
	assert_eq(p.store.stock("wheat"), 9000, "3000 con la mala cosecha y 6000 después")
	assert_true(p.modifiers.is_empty(), "el efecto caducó")
	done()


func test_granary_adds_storage_capacity() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	assert_eq(p.store.capacity, 60000, "capacidad base")
	p.add_building("granary")
	assert_eq(p.store.capacity, 100000, "el granero suma 40000")
	assert_eq(p.store.limit("wheat"), 30000, "las partes se calculan sobre la capacidad nueva")
	done()


func test_passive_buildings_stay_idle() -> void:
	var data = new_data()
	var p = _fed_province(data)
	var house: int = p.add_building("house")
	var granary: int = p.add_building("granary")
	p.step()
	assert_eq(p.find_building(house)["status"], "idle", "la vivienda no produce")
	assert_eq(p.find_building(granary)["status"], "idle", "el granero no produce")
	done()


func test_surplus_coproduct_is_wasted_but_the_rest_is_delivered() -> void:
	var data = new_data()
	var p = _fed_province(data)
	p.store.seed_initial("wood", 9000)
	var cutter: int = p.add_building("woodcutter")
	run_steps(p, 6)
	assert_eq(p.store.ledger("firewood")["produced"], 1500, "la leña se entrega aunque la madera no quepa")
	assert_eq(p.store.stock("wood"), 9000, "la madera sigue en su tope")
	assert_eq(p.wasted.get("wood", 0), 3000, "la madera que no cabía se anota como desperdicio")
	assert_eq(p.store.ledger("wood")["produced"], 0, "lo desperdiciado nunca entró en el libro del almacén")
	assert_true(p.alerts.has("waste"), "aviso de desperdicio")
	assert_eq(p.find_building(cutter)["status"], "running", "el leñador sigue trabajando")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()


func test_nothing_is_delivered_when_every_output_is_blocked() -> void:
	var data = new_data()
	var p = _fed_province(data)
	p.store.seed_initial("wood", 9000)
	p.store.seed_initial("firewood", 9000)
	var cutter: int = p.add_building("woodcutter")
	run_steps(p, 3)
	var b: Dictionary = p.find_building(cutter)
	assert_eq(b["status"], "storage_full", "sin sitio para nada, se detiene")
	assert_true(not b["active"], "no empezó el ciclo")
	assert_eq(p.store.ledger("coin")["consumed"], 0, "no pagó mantenimiento por un ciclo que no empezó")
	assert_true(p.wasted.is_empty(), "y no desperdicia nada")
	done()
