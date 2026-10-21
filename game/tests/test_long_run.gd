extends "res://tests/province_case.gd"
## Simulaciones largas (criterios A1 y A10) y determinismo.


## Perturbaciones repetibles: una mala cosecha cada 500 pasos.
func _perturb(p, step_index: int) -> void:
	if step_index % 500 == 0:
		p.add_modifier("wheat", 0, 40)


func test_conservation_holds_for_10000_steps() -> void:
	# Criterio A1.
	var data = new_data()
	var p = chain_province(data, 100)
	var bad_checks := 0
	for i in range(10000):
		_perturb(p, i)
		p.step()
		if i % 97 == 0 and not p.check_invariants().is_empty():
			bad_checks += 1
	assert_eq(bad_checks, 0, "ninguna comprobación intermedia falló")
	assert_true(p.check_invariants().is_empty(), "coherente al final: %s" % str(p.check_invariants()))
	for good_id in data.goods.keys():
		var l: Dictionary = p.store.ledger(good_id)
		var expected: int = l["initial"] + l["produced"] + l["imported"] - l["consumed"] - l["exported"] - l["lost"]
		assert_eq(p.store.stock(good_id), expected, "%s: existencias = iniciales + producción + importaciones - consumo - exportaciones - pérdidas" % good_id)
	print("10000 pasos: población %d, descontento %d, hambre %d, pan producido %d, trigo producido %d" % [p.population, p.unrest, p.hunger_steps, p.store.ledger("bread")["produced"], p.store.ledger("wheat")["produced"]])
	done()


func test_thirty_days_have_no_invalid_values() -> void:
	# Criterio A10: 30 días de 24 pasos, con obras por el camino.
	var data = new_data()
	var p = chain_province(data, 100)
	var invalid := 0
	var started := 0
	var turn := 0
	var kinds: Array[String] = ["house", "granary", "farm"]
	for i in range(720):
		if i % 48 == 0:
			if p.start_construction(kinds[turn % 3]):
				started += 1
			turn += 1
		p.step()
		invalid += _invalid_values(p, data)
	print("30 días: obras empezadas %d, edificios %d, población %d" % [started, p.buildings.size(), p.population])
	assert_eq(invalid, 0, "ningún valor negativo ni no entero en 720 pasos")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	assert_eq(p.step_count, 720, "30 días son 720 pasos")
	done()


func test_same_start_gives_identical_results() -> void:
	var data_a = new_data()
	var data_b = new_data()
	var a = chain_province(data_a, 100)
	var b = chain_province(data_b, 100)
	for i in range(1500):
		_perturb(a, i)
		_perturb(b, i)
		a.step()
		b.step()
	assert_eq(snapshot(a), snapshot(b), "dos simulaciones iguales dan el mismo estado")
	done()


func test_different_start_gives_different_results() -> void:
	# Comprueba que snapshot() distingue estados de verdad (no devuelve siempre lo mismo).
	var data_a = new_data()
	var data_b = new_data()
	var a = chain_province(data_a, 100)
	var b = chain_province(data_b, 100)
	b.add_modifier("wheat", 0, 40)
	run_steps(a, 300)
	run_steps(b, 300)
	assert_true(snapshot(a) != snapshot(b), "una mala cosecha deja huella en el estado")
	done()


func test_invalid_values_detector_catches_bad_state() -> void:
	# Comprueba que el detector de valores inválidos detecta de verdad.
	var data = new_data()
	var p = chain_province(data, 100)
	assert_eq(_invalid_values(p, data), 0, "un estado nuevo es válido")
	p.unrest = -1
	assert_true(_invalid_values(p, data) > 0, "un descontento negativo se detecta")
	p.unrest = 0
	p.store._stock["wheat"] = 12.5
	assert_true(_invalid_values(p, data) > 0, "una existencia decimal se detecta")
	done()
