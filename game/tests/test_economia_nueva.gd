extends "res://tests/province_case.gd"
## Edificios y mercancías añadidos en la pieza G1 (olivar, almazara, aprisco, telar, mercado, mina,
## herrería): cada uno produce lo que dicen los datos y las cadenas se encadenan sin crear ni perder nada.
## Todas las cifras son parámetros de juego provisionales, no datos históricos.


func _provincia(data):
	var p = new_province(data, 100)
	p.store.seed_initial("bread", 18000)
	p.store.seed_initial("coin", 50000)
	p.store.seed_initial("wood", 9000)
	return p


func _ciclo(id: String, entradas: Dictionary, salidas: Dictionary) -> void:
	var data = new_data()
	var p = _provincia(data)
	for g in entradas.keys():
		p.store.seed_initial(g, entradas[g])
	var b: int = p.add_building(id)
	assert_true(b >= 0, "%s se puede añadir" % id)
	var pasos: int = int(data.buildings[id]["cycle_steps"])
	run_steps(p, pasos - 1)
	for g in salidas.keys():
		assert_eq(p.store.stock(g), 0 if not entradas.has(g) else int(entradas[g]), "%s: antes de acabar el ciclo no hay %s" % [id, g])
	p.step()
	for g in salidas.keys():
		var antes: int = int(entradas.get(g, 0))
		assert_eq(p.store.stock(g), antes + int(salidas[g]), "%s: al acabar el ciclo salen %d de %s" % [id, int(salidas[g]), g])
	for g in entradas.keys():
		if not salidas.has(g):
			assert_true(p.store.stock(g) < int(entradas[g]), "%s consume %s" % [id, g])
	assert_true(p.check_invariants().is_empty(), "%s: coherente: %s" % [id, str(p.check_invariants())])


func test_each_new_building_produces_what_its_data_says() -> void:
	_ciclo("olive_grove", {}, {"olives": 2000})
	_ciclo("olive_press", {"olives": 2000}, {"oil": 1200})
	_ciclo("sheepfold", {}, {"wool": 1500})
	_ciclo("loom", {"wool": 1500}, {"cloth": 1000})
	_ciclo("mine", {}, {"iron": 1500})
	_ciclo("smithy", {"iron": 1500, "firewood": 500}, {"weapons": 1000})
	done()


func test_the_market_turns_oil_and_cloth_into_coin() -> void:
	var data = new_data()
	var p = _provincia(data)
	p.store.seed_initial("oil", 600)
	p.store.seed_initial("cloth", 500)
	var antes: int = p.store.stock("coin")
	p.add_building("market")
	run_steps(p, 6)
	assert_eq(p.store.stock("oil"), 0, "gasta el aceite")
	assert_eq(p.store.stock("cloth"), 0, "y el paño")
	assert_true(p.store.stock("coin") > antes, "y entra moneda (%d → %d)" % [antes, p.store.stock("coin")])
	done()


func test_new_buildings_without_inputs_report_what_is_missing() -> void:
	var data = new_data()
	for id in ["olive_press", "loom", "market", "smithy"]:
		var p = _provincia(data)
		var b: int = p.add_building(id)
		p.step()
		assert_eq(p.find_building(b)["status"], "missing_inputs", "%s sin insumos lo dice" % id)
	done()


func test_the_whole_new_chain_runs_for_a_month_without_creating_or_losing_goods() -> void:
	var data = new_data()
	var p = new_province(data, 200)
	p.store.seed_initial("bread", 30000)
	p.store.seed_initial("coin", 90000)
	p.store.seed_initial("wood", 9000)
	p.store.seed_initial("firewood", 9000)
	for id in ["granary", "farm", "olive_grove", "olive_press", "sheepfold", "loom", "market", "mine", "smithy", "woodcutter"]:
		p.add_building(id)
	run_steps(p, 24 * 30)
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	assert_true(p.store.ledger("weapons")["produced"] > 0, "la herrería llegó a producir armas")
	assert_true(p.store.ledger("oil")["consumed"] > 0, "y el mercado a gastar aceite")
	done()


func test_every_batch_of_every_building_fits_in_the_base_storage() -> void:
	# Un edificio cuyo lote de entrada o salida no cabe en el tope de su mercancía nunca podría trabajar.
	var data = new_data()
	var p = new_province(data, 100)
	for id in data.buildings.keys():
		var b: Dictionary = data.buildings[id]
		for lote in [b["inputs"], b["outputs"]]:
			for g in lote.keys():
				if data.goods[g]["physical"]:
					assert_true(int(lote[g]) <= p.store.limit(g), "%s: el lote de %s (%d) cabe en el tope (%d)" % [id, g, int(lote[g]), p.store.limit(g)])
	done()
