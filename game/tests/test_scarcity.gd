extends "res://tests/province_case.gd"
## Escasez gradual y recuperación (tarea 1.6; criterios A6 y A7).


func test_first_steps_without_food_only_warn() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	for i in range(1, 4):
		p.step()
		assert_eq(p.unrest, 0, "paso %d: aún no hay descontento" % i)
		assert_eq(p.hunger_steps, i, "paso %d: cuenta de hambre" % i)
		assert_true(p.alerts.has("hunger_warning"), "paso %d: hay aviso" % i)
		assert_eq(p.population, 100, "paso %d: nadie muere" % i)
	done()


func test_unrest_rises_gradually_after_the_warning() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	run_steps(p, 3)
	p.step()
	assert_eq(p.unrest, 25, "primer paso con descontento: +25")
	assert_true(p.alerts.has("unrest"), "aviso de descontento")
	p.step()
	assert_eq(p.unrest, 50, "segundo: +25")
	done()


func test_starvation_starts_only_after_a_long_shortage() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	run_steps(p, 23)
	assert_eq(p.population, 100, "tras 23 pasos de hambre nadie ha muerto")
	p.step()
	assert_eq(p.population, 98, "al paso 24 se pierde el 2 %")
	assert_true(p.alerts.has("starvation"), "aviso de hambruna")
	done()


func test_population_never_collapses_in_one_step() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	var worst_loss := 0
	var problems := 0
	for i in range(600):
		var before: int = p.population
		p.step()
		var loss: int = before - p.population
		worst_loss = maxi(worst_loss, loss)
		assert_true(loss >= 0, "paso %d: la población no crece sin comida" % (i + 1))
		assert_true(p.population >= 10, "paso %d: nunca por debajo del mínimo" % (i + 1))
		if not p.check_invariants().is_empty():
			problems += 1
	assert_true(worst_loss <= 2, "la mayor pérdida en un paso fue %d (máximo 2 con 100 habitantes)" % worst_loss)
	assert_eq(p.population, 10, "tras 600 pasos sin comida queda el mínimo, no cero")
	assert_eq(p.unrest, 1000, "el descontento llega a su tope y no pasa de él")
	assert_eq(problems, 0, "ningún paso dejó el estado incoherente")
	done()


func test_unrest_and_hunger_recover_when_food_returns() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	run_steps(p, 10)
	assert_eq(p.unrest, 175, "7 pasos de descontento de 25")
	p.store.add("bread", 18000, "imported")
	p.step()
	assert_eq(p.hunger_steps, 0, "el hambre se corta en cuanto hay comida")
	assert_eq(p.unrest, 160, "el descontento baja 15 por paso")
	assert_true(p.alerts.is_empty(), "sin avisos")
	assert_eq(p.food_shortage_percent, 0, "alimentados")
	run_steps(p, 11)
	assert_eq(p.unrest, 0, "tras 12 pasos con comida, sin descontento")
	done()


func test_partial_shortage_raises_unrest_less() -> void:
	var data = new_data()
	data.rules["hunger_warning_steps"] = 0
	var p = new_province(data, 100)
	p.store.seed_initial("bread", 333)
	p.step()
	assert_eq(p.food_shortage_percent, 51, "falta el 51 %")
	assert_eq(p.unrest, 12, "25 * 51 / 100 = 12")
	done()


func test_bad_harvest_causes_scarcity_and_the_province_recovers() -> void:
	# Criterio A7. Cosecha de trigo nula durante 100 pasos; las reservas de pan
	# duran unos 50, así que hay escasez, y después la producción vuelve.
	var data = new_data()
	var p = chain_province(data, 100)
	p.add_modifier("wheat", 0, 100)
	var max_hunger := 0
	var max_unrest := 0
	var min_population: int = p.population
	var worst_loss := 0
	var problems := 0
	var recovered_at := -1
	for i in range(1, 801):
		var before: int = p.population
		p.step()
		max_hunger = maxi(max_hunger, p.hunger_steps)
		max_unrest = maxi(max_unrest, p.unrest)
		min_population = mini(min_population, p.population)
		worst_loss = maxi(worst_loss, before - p.population)
		if not p.check_invariants().is_empty():
			problems += 1
		if recovered_at < 0 and i > 100 and p.hunger_steps == 0 and p.unrest == 0:
			recovered_at = i
		if i % 25 == 0:
			var states := ""
			for b in p.buildings:
				states += str(b["status"]).substr(0, 4) + " "
			print("  t=%d pob=%d desc=%d hambre=%d falta=%d%% prod=%d%% pan=%d trigo=%d harina=%d lena=%d mon=%d | %s" % [i, p.population, p.unrest, p.hunger_steps, p.food_shortage_percent, p.productivity_percent(), p.store.stock("bread"), p.store.stock("wheat"), p.store.stock("flour"), p.store.stock("firewood"), p.store.stock("coin"), states])
	print("crisis: hambre máx. %d pasos, descontento máx. %d, población mín. %d, final %d, recuperada en el paso %d" % [max_hunger, max_unrest, min_population, p.population, recovered_at])
	assert_true(max_hunger > 0, "la mala cosecha produjo escasez")
	assert_true(max_unrest > 0, "y descontento")
	assert_true(min_population >= 10, "la población nunca bajó del mínimo (%d)" % min_population)
	assert_true(worst_loss <= 2, "ninguna pérdida de población superior al 2 %% en un paso (%d)" % worst_loss)
	assert_true(recovered_at > 0, "la provincia llegó a recuperarse del todo")
	assert_eq(p.hunger_steps, 0, "al final no hay hambre")
	assert_eq(p.unrest, 0, "al final no hay descontento")
	assert_eq(problems, 0, "el estado fue coherente durante toda la crisis")
	done()


func test_reserves_cover_a_short_harvest_failure() -> void:
	# Con 20 pasos sin cosecha las reservas bastan: ni hambre ni descontento.
	var data = new_data()
	var p = chain_province(data, 100)
	p.add_modifier("wheat", 0, 20)
	var max_hunger := 0
	for i in range(300):
		p.step()
		max_hunger = maxi(max_hunger, p.hunger_steps)
	assert_eq(max_hunger, 0, "con reservas no hay ni un paso de hambre")
	assert_eq(p.unrest, 0, "sin descontento")
	assert_eq(p.population, 100, "sin pérdidas")
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()
