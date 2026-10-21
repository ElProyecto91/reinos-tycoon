extends "res://tests/test_case.gd"
## Pruebas del almacén (tarea 1.2): capacidad, cantidades enteras y conservación.

const STORE := "res://scripts/sim/store.gd"


func _goods() -> Dictionary:
	return {
		"wheat": {"physical": true},
		"flour": {"physical": true},
		"coin": {"physical": false},
	}


func _new_store(capacity: int):
	return load(STORE).new(_goods(), capacity)


func test_new_store_is_empty_and_consistent() -> void:
	var store = _new_store(10000)
	assert_eq(store.stock("wheat"), 0, "sin existencias al empezar")
	assert_eq(store.used_space(), 0, "sin espacio usado")
	assert_eq(store.free_space(), 10000, "todo el espacio libre")
	assert_true(store.check_conservation().is_empty(), "un almacén nuevo es coherente")
	done()


func test_add_within_capacity() -> void:
	var store = _new_store(10000)
	assert_eq(store.add("wheat", 4000, "produced"), 4000, "cabe todo")
	assert_eq(store.stock("wheat"), 4000, "existencias tras producir")
	assert_eq(store.free_space(), 6000, "espacio libre")
	done()


func test_add_beyond_capacity_is_cut() -> void:
	var store = _new_store(5000)
	store.add("wheat", 4000, "produced")
	assert_eq(store.add("flour", 3000, "produced"), 1000, "solo cabe lo que queda")
	assert_eq(store.used_space(), 5000, "almacén lleno")
	assert_eq(store.add("wheat", 1, "produced"), 0, "lleno: no entra nada más")
	assert_true(store.check_conservation().is_empty(), "sigue siendo coherente")
	done()


func test_capacity_is_shared_between_goods() -> void:
	var store = _new_store(6000)
	store.add("wheat", 4000, "imported")
	store.add("flour", 4000, "imported")
	assert_eq(store.stock("flour"), 2000, "la harina solo ocupa el espacio restante")
	done()


func test_coin_does_not_use_space() -> void:
	var store = _new_store(1000)
	store.add("wheat", 1000, "produced")
	assert_eq(store.add("coin", 50000, "imported"), 50000, "la moneda siempre entra")
	assert_eq(store.used_space(), 1000, "la moneda no cuenta como espacio")
	assert_true(store.check_conservation().is_empty(), "coherente con moneda")
	done()


func test_remove_never_goes_negative() -> void:
	var store = _new_store(10000)
	store.add("wheat", 2000, "produced")
	assert_eq(store.remove("wheat", 5000, "consumed"), 2000, "solo se retira lo que hay")
	assert_eq(store.stock("wheat"), 0, "queda a cero, no negativo")
	assert_true(store.check_conservation().is_empty(), "coherente tras retirar de más")
	done()


func test_negative_amounts_are_rejected() -> void:
	var store = _new_store(10000)
	assert_eq(store.add("wheat", -100, "produced"), 0, "no se añade una cantidad negativa")
	assert_true(store.last_error != "", "queda el motivo")
	assert_eq(store.remove("wheat", -100, "consumed"), 0, "no se retira una cantidad negativa")
	assert_eq(store.stock("wheat"), 0, "las existencias no cambian")
	done()


func test_unknown_good_is_rejected() -> void:
	var store = _new_store(10000)
	assert_eq(store.add("oro", 100, "produced"), 0, "mercancía desconocida")
	assert_true(store.last_error.contains("oro"), "el motivo nombra la mercancía")
	assert_eq(store.remove("oro", 100, "consumed"), 0, "retirar mercancía desconocida")
	done()


func test_invalid_kinds_are_rejected() -> void:
	var store = _new_store(10000)
	assert_eq(store.add("wheat", 100, "consumed"), 0, "una entrada no puede ser de tipo salida")
	assert_eq(store.remove("wheat", 100, "produced"), 0, "una salida no puede ser de tipo entrada")
	assert_eq(store.stock("wheat"), 0, "sin cambios")
	done()


func test_ledger_matches_movements() -> void:
	var store = _new_store(20000)
	store.seed_initial("wheat", 1000)
	store.add("wheat", 3000, "produced")
	store.add("wheat", 500, "imported")
	store.remove("wheat", 1200, "consumed")
	store.remove("wheat", 300, "exported")
	store.remove("wheat", 100, "lost")
	var entry: Dictionary = store.ledger("wheat")
	assert_eq(entry["initial"], 1000, "iniciales")
	assert_eq(entry["produced"], 3000, "producido")
	assert_eq(entry["imported"], 500, "importado")
	assert_eq(entry["consumed"], 1200, "consumido")
	assert_eq(entry["exported"], 300, "exportado")
	assert_eq(entry["lost"], 100, "perdido")
	assert_eq(store.stock("wheat"), 2900, "1000+3000+500-1200-300-100")
	assert_true(store.check_conservation().is_empty(), "el libro cuadra con las existencias")
	done()


func test_conservation_detects_tampering() -> void:
	var store = _new_store(10000)
	store.add("wheat", 2000, "produced")
	store._stock["wheat"] += 7
	var problems: Array[String] = store.check_conservation()
	assert_eq(problems.size(), 1, "se detecta una existencia que no figura en el libro")
	assert_true(problems[0].contains("wheat"), "el aviso nombra la mercancía")
	done()


func test_cannot_shrink_capacity_below_used_space() -> void:
	var store = _new_store(10000)
	store.add("wheat", 6000, "produced")
	assert_true(not store.set_capacity(5000), "no se puede dejar la capacidad por debajo de lo usado")
	assert_eq(store.capacity, 10000, "la capacidad no cambia")
	assert_true(store.set_capacity(6000), "igual a lo usado sí")
	assert_true(store.set_capacity(20000), "ampliar sí")
	assert_eq(store.free_space(), 14000, "espacio tras ampliar")
	done()


func test_can_afford() -> void:
	var store = _new_store(10000)
	store.add("wheat", 2000, "produced")
	store.add("coin", 300, "imported")
	assert_true(store.can_afford({"wheat": 2000, "coin": 300}), "alcanza exactamente")
	assert_true(not store.can_afford({"wheat": 2001}), "falta una milésima")
	assert_true(not store.can_afford({"flour": 1}), "no hay nada de esa mercancía")
	assert_true(store.can_afford({}), "un coste vacío siempre se puede pagar")
	done()


func test_conservation_over_10000_pseudorandom_steps() -> void:
	# Criterio A1: 10 000 pasos de entradas y salidas variadas, con semilla fija
	# para que el resultado sea siempre el mismo.
	var store = _new_store(8000)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var goods: Array[String] = ["wheat", "flour", "coin"]
	var incoming: Array[String] = ["produced", "imported"]
	var outgoing: Array[String] = ["consumed", "exported", "lost"]
	var problems_seen := 0
	for step in range(10000):
		var good: String = goods[rng.randi_range(0, goods.size() - 1)]
		var amount := rng.randi_range(0, 2500)
		if rng.randi_range(0, 1) == 0:
			store.add(good, amount, incoming[rng.randi_range(0, 1)])
		else:
			store.remove(good, amount, outgoing[rng.randi_range(0, 2)])
		if step % 97 == 0 and not store.check_conservation().is_empty():
			problems_seen += 1
	assert_eq(problems_seen, 0, "ninguna comprobación intermedia falló")
	assert_true(store.check_conservation().is_empty(), "coherente al terminar los 10 000 pasos")
	assert_true(store.used_space() <= store.capacity, "nunca se superó la capacidad")
	for good in goods:
		assert_true(store.stock(good) >= 0, "existencias negativas de %s" % good)
	done()


func _shared_goods() -> Dictionary:
	return {
		"wheat": {"physical": true, "share": 50},
		"flour": {"physical": true, "share": 30},
		"coin": {"physical": false, "share": 0},
	}


func test_limit_is_share_of_capacity() -> void:
	var store = load(STORE).new(_shared_goods(), 10000)
	assert_eq(store.limit("wheat"), 5000, "50 % de 10000")
	assert_eq(store.limit("flour"), 3000, "30 % de 10000")
	assert_eq(store.limit("coin"), 0, "la moneda no tiene parte de almacén")
	done()


func test_good_cannot_exceed_its_share() -> void:
	var store = load(STORE).new(_shared_goods(), 10000)
	assert_eq(store.add("wheat", 8000, "produced"), 5000, "solo cabe su parte")
	assert_eq(store.add("wheat", 1, "produced"), 0, "su parte está llena")
	assert_eq(store.add("flour", 4000, "produced"), 3000, "la harina tiene su propia parte")
	assert_eq(store.free_space(), 2000, "queda sitio total, pero ninguna de las dos puede usarlo")
	assert_true(store.check_conservation().is_empty(), "coherente")
	done()


func test_share_grows_with_capacity() -> void:
	var store = load(STORE).new(_shared_goods(), 10000)
	store.add("wheat", 5000, "produced")
	store.set_capacity(20000)
	assert_eq(store.room("wheat"), 5000, "con más capacidad cabe más trigo")
	done()


func test_can_fit_checks_total_and_each_share() -> void:
	var store = load(STORE).new(_shared_goods(), 10000)
	assert_true(store.can_fit({"wheat": 5000, "flour": 3000}), "caben juntas")
	assert_true(not store.can_fit({"wheat": 5001}), "una supera su parte")
	assert_true(store.can_fit({"coin": 999999}), "la moneda no cuenta")
	store.add("wheat", 5000, "produced")
	store.add("flour", 3000, "produced")
	assert_true(not store.can_fit({"wheat": 1}), "trigo lleno")
	assert_true(store.can_fit({}), "nada siempre cabe")
	done()


func test_can_fit_counts_extra_free_space() -> void:
	var goods := {"a": {"physical": true, "share": 100}, "b": {"physical": true, "share": 100}}
	var store = load(STORE).new(goods, 1000)
	store.add("a", 1000, "produced")
	assert_true(not store.can_fit({"b": 400}), "sin sitio")
	assert_true(store.can_fit({"b": 400}, 400), "con 400 que se liberan sí")
	assert_true(not store.can_fit({"b": 400}, 399), "con 399 no")
	done()


func test_conservation_flags_stock_above_share() -> void:
	var store = load(STORE).new(_shared_goods(), 10000)
	store.add("wheat", 5000, "produced")
	store._stock["wheat"] += 1
	store._ledger["wheat"]["produced"] += 1
	var problems: Array[String] = store.check_conservation()
	assert_eq(problems.size(), 1, "solo se detecta pasarse de la parte, el libro cuadra")
	done()
