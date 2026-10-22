extends "res://tests/province_case.gd"
## Explicación del descontento en la ficha: las causas que se enseñan tienen que ser las que de verdad lo suben.
## Province.unrest_causes() usa los mismos umbrales que la simulación; el texto nombra remedios que existen en el juego.

const TEXTS := "res://scripts/ui/texts.gd"


func _winter(data):
	data.rules["calendar_start_day"] = 0
	data.rules["food_per_person"] = 0
	var p = new_province(data, 100)
	return p


func test_a_calm_province_has_no_causes() -> void:
	var data = new_data()
	var p = chain_province(data, 100)
	p.step()
	assert_eq(p.unrest_causes(), [], "sin problemas no hay causas")
	done()


func test_hunger_is_a_cause_only_after_the_warning_steps() -> void:
	var data = new_data()
	var p = new_province(data, 100)       # sin comida
	var warning: int = data.rules["hunger_warning_steps"]
	for i in range(warning):
		p.step()
		assert_eq(p.unrest_causes(), [], "paso %d: todavía en aviso, no sube" % (i + 1))
		assert_eq(p.unrest, 0, "y el descontento no ha subido")
	p.step()
	assert_eq(p.unrest_causes(), ["hunger"], "pasado el aviso, hambre")
	assert_true(p.unrest > 0, "y de verdad sube")
	done()


func test_unpaid_soldiers_are_a_cause() -> void:
	var data = new_data()
	data.rules["tax_per_person"] = 0
	var p = new_province(data, 100)
	p.store.seed_initial("bread", 100000)
	p.recruits = 5
	p.step()
	assert_true(p.soldiers_unpaid, "preparación: no cobran")
	assert_true(p.unrest_causes().has("unpaid"), "causa: soldados sin paga")
	p.recruits = 0
	p.step()
	assert_true(not p.unrest_causes().has("unpaid"), "sin soldados, ya no")
	done()


func test_cold_is_a_cause_below_its_cap_and_not_at_it() -> void:
	var data = new_data()
	var p = _winter(data)
	p.store.seed_initial("bread", 0)
	run_steps(p, 20)
	assert_true(p.unrest > 0, "preparación: sube con frío")
	assert_true(p.unrest_causes().has("cold"), "causa: frío (%d)" % p.unrest)
	run_steps(p, 200)
	assert_eq(p.unrest, data.rules["cold_unrest_limit"], "llega al tope del frío")
	assert_true(not p.unrest_causes().has("cold"), "en el tope ya no sube: no se acusa al frío de seguir subiéndolo")
	p.store.seed_initial("firewood", 100000)
	p.step()
	assert_eq(p.unrest_causes(), [], "con leña, sin causa")
	done()


func test_every_rise_has_a_cause_in_the_scenarios_that_raise_it() -> void:
	## Coherencia: si el descontento sube en un paso y no está en el tope del frío, hay alguna causa explicada.
	var data = new_data()
	var p = new_province(data, 100)
	for i in 60:
		var before: int = p.unrest
		p.step()
		if p.unrest > before:
			assert_true(not p.unrest_causes().is_empty(), "paso %d: subió %d → %d sin causa" % [i, before, p.unrest])
	done()


func test_the_text_names_each_cause_and_its_remedy_with_things_that_exist() -> void:
	var data = new_data()
	var T = load(TEXTS)
	var r: Dictionary = data.rules
	var hunger: String = T.unrest_explanation(["hunger"], 250, r)
	assert_true("HAMBRE" in hunger and "Granjas" in hunger, "hambre → granjas: " + hunger)
	assert_true(data.buildings.has("farm") and data.buildings["farm"]["name"] == "Granja", "el edificio citado existe")
	var cold: String = T.unrest_explanation(["cold"], 250, r)
	assert_true("FRÍO" in cold and "Leñador" in cold, "frío → leñador: " + cold)
	assert_eq(data.buildings["woodcutter"]["name"], "Leñador", "el leñador existe con ese nombre")
	var unpaid: String = T.unrest_explanation(["unpaid"], 250, r)
	assert_true("SOLDADOS" in unpaid and "Licencia" in unpaid, "soldados → licenciar: " + unpaid)
	var idle: String = T.unrest_explanation([], 600, r)
	assert_true("1,5 %" in idle and "60 %" in idle, "sin causa: baja solo y la conquista empieza en el valor real: " + idle)
	var calm: String = T.unrest_explanation([], 0, r)
	assert_true("Sin problemas" in calm, "a 0 se dice que no hay problema: " + calm)
	for text in [hunger, cold, unpaid, idle, calm]:
		assert_true("30 %" in text and "20 %" in text, "siempre dice los umbrales reales (30 % y 20 %): " + text)
	done()
