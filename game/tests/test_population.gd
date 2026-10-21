extends "res://tests/province_case.gd"
## Población, mano de obra y consumo de alimento (tarea 1.3; criterios A4 y parte de A6).


func test_labor_force_is_half_of_population() -> void:
	var data = new_data()
	assert_eq(new_province(data, 100).labor_force(), 50, "100 habitantes")
	assert_eq(new_province(data, 101).labor_force(), 50, "101 habitantes (se redondea hacia abajo)")
	assert_eq(new_province(data, 10).labor_force(), 5, "10 habitantes")
	done()


func test_assigned_workers_never_exceed_available() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.auto_staff = false
	var f1: int = p.add_building("farm")
	var f2: int = p.add_building("farm")
	var f3: int = p.add_building("farm")
	assert_true(p.assign_workers(f1, 4), "primera asignación")
	assert_eq(p.available_workers(), 46, "quedan 46")
	assert_true(p.recruit(40), "reclutar 40")
	assert_eq(p.available_workers(), 6, "reclutar reduce los disponibles")
	assert_true(p.assign_workers(f2, 4), "segunda asignación")
	assert_eq(p.available_workers(), 2, "quedan 2")
	assert_true(not p.assign_workers(f3, 4), "no caben 4 más")
	assert_true(p.last_error != "", "queda el motivo")
	assert_eq(p.find_building(f3)["workers"], 0, "la asignación rechazada no cambia nada")
	assert_true(p.assign_workers(f3, 2), "sí caben 2")
	assert_eq(p.available_workers(), 0, "ninguno libre")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()


func test_assign_rejects_invalid_requests() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.auto_staff = false
	var farm: int = p.add_building("farm")
	assert_true(not p.assign_workers(999, 1), "edificio inexistente")
	assert_true(not p.assign_workers(farm, 5), "más de los que admite la granja")
	assert_true(not p.assign_workers(farm, -1), "cantidad negativa")
	assert_eq(p.find_building(farm)["workers"], 0, "nada cambió")
	done()


func test_assigning_fewer_workers_frees_them() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.auto_staff = false
	var farm: int = p.add_building("farm")
	p.assign_workers(farm, 4)
	assert_true(p.assign_workers(farm, 1), "bajar de 4 a 1")
	assert_eq(p.available_workers(), 49, "se liberan 3")
	done()


func test_recruiting_reduces_available_workers() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	assert_true(p.recruit(10), "reclutar 10")
	assert_eq(p.recruits, 10, "diez reclutas")
	assert_eq(p.labor_force(), 40, "la mano de obra baja")
	assert_eq(p.available_workers(), 40, "los disponibles bajan")
	assert_true(not p.recruit(41), "no se pueden reclutar más de los disponibles")
	assert_true(p.release_recruits(5), "licenciar 5")
	assert_eq(p.available_workers(), 45, "vuelven 5")
	assert_true(not p.release_recruits(100), "no se licencia a más de los que hay")
	assert_true(not p.recruit(-1), "cantidad negativa")
	done()


func test_labor_limit_is_enforced_when_population_falls() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.auto_staff = false
	var f1: int = p.add_building("farm")
	var f2: int = p.add_building("farm")
	var f3: int = p.add_building("farm")
	p.assign_workers(f1, 4)
	p.assign_workers(f2, 4)
	p.assign_workers(f3, 4)
	p.population = 20
	p.step()
	assert_eq(p.assigned_labor(), 10, "ya no hay más asignados que mano de obra")
	assert_eq(p.find_building(f1)["workers"], 4, "la primera granja conserva sus trabajadores")
	assert_eq(p.find_building(f3)["workers"], 2, "se quita primero a la última")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()


func test_auto_staff_fills_buildings_in_order() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	var f1: int = p.add_building("farm")
	var f2: int = p.add_building("farm")
	var m: int = p.add_building("mill")
	p.step()
	assert_eq(p.find_building(f1)["workers"], 4, "primera granja completa")
	assert_eq(p.find_building(f2)["workers"], 4, "segunda granja completa")
	assert_eq(p.find_building(m)["workers"], 2, "molino completo")
	assert_eq(p.available_workers(), 40, "quedan 40 libres")
	done()


func test_auto_staff_is_limited_by_labor_force() -> void:
	var data = new_data()
	var p = new_province(data, 20)
	var f1: int = p.add_building("farm")
	var f2: int = p.add_building("farm")
	var f3: int = p.add_building("farm")
	p.step()
	assert_eq(p.find_building(f1)["workers"], 4, "primera")
	assert_eq(p.find_building(f2)["workers"], 4, "segunda")
	assert_eq(p.find_building(f3)["workers"], 2, "la tercera se queda con lo que sobra")
	assert_eq(p.available_workers(), 0, "ninguno libre")
	done()


func test_population_eats_every_step() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("bread", 10000)
	p.step()
	assert_eq(p.store.stock("bread"), 9333, "100 personas necesitan 1000 raciones: 667 de pan")
	assert_eq(p.store.ledger("bread")["consumed"], 667, "el consumo queda en el libro")
	assert_eq(p.food_shortage_percent, 0, "todos alimentados")
	run_steps(p, 9)
	assert_eq(p.store.ledger("bread")["consumed"], 6670, "667 por paso durante 10 pasos")
	assert_true(p.check_invariants().is_empty(), "coherente")
	done()


func test_bread_is_eaten_before_wheat() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("bread", 10000)
	p.store.seed_initial("wheat", 10000)
	p.step()
	assert_eq(p.store.stock("wheat"), 10000, "el trigo no se toca mientras haya pan")
	done()


func test_wheat_is_eaten_when_there_is_no_bread() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("wheat", 10000)
	p.step()
	assert_eq(p.store.stock("wheat"), 8750, "1000 raciones son 1250 de trigo")
	assert_eq(p.food_shortage_percent, 0, "alimentados")
	done()


func test_mixed_food_covers_the_gap() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("bread", 300)
	p.store.seed_initial("wheat", 10000)
	p.step()
	assert_eq(p.store.stock("bread"), 0, "se acaba el pan")
	assert_eq(p.store.stock("wheat"), 9312, "el trigo cubre las 550 raciones que faltaban")
	assert_eq(p.food_shortage_percent, 0, "alimentados")
	done()


func test_taxes_add_coin_each_step() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("bread", 10000)
	run_steps(p, 3)
	assert_eq(p.store.stock("coin"), 2400, "100 personas por 8 milésimas, 3 pasos")
	assert_eq(p.store.ledger("coin")["produced"], 2400, "el libro lo refleja")
	done()


func test_no_food_means_full_shortage() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.step()
	assert_eq(p.food_shortage_percent, 100, "sin alimento falta todo")
	assert_eq(p.hunger_steps, 1, "un paso de hambre")
	done()


func test_partial_shortage_is_measured() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("bread", 333)
	p.step()
	assert_eq(p.store.stock("bread"), 0, "se come todo el pan")
	assert_eq(p.food_shortage_percent, 51, "333 de pan dan 499 raciones de 1000: falta el 51 %")
	done()


func test_population_grows_slowly_when_fed_and_there_is_room() -> void:
	var data = new_data()
	var p = new_province(data, 80)
	p.store.seed_initial("bread", 18000)
	run_steps(p, 11)
	assert_eq(p.population, 80, "sin cambios antes del intervalo de crecimiento")
	p.step()
	assert_eq(p.population, 81, "al paso 12 crece un 2 %, mínimo 1")
	done()


func test_population_does_not_grow_beyond_housing() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("bread", 18000)
	run_steps(p, 24)
	assert_eq(p.population, 100, "la vivienda base admite 100")
	done()


func test_house_raises_housing_capacity() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	assert_eq(p.housing_capacity(), 100, "vivienda base")
	p.add_building("house")
	assert_eq(p.housing_capacity(), 120, "una casa suma 20")
	p.store.seed_initial("bread", 18000)
	run_steps(p, 12)
	assert_eq(p.population, 102, "con sitio y comida, crece un 2 %")
	done()
