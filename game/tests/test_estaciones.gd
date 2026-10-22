extends "res://tests/province_case.gd"
## Fase 2.2 y 2.3 (D-032): cosechas por mes y necesidad de leña en invierno.
## Todas las cifras son parámetros de juego provisionales, no datos históricos.

const STORE := "res://scripts/sim/store.gd"
const NOVEMBER_30 := 333      # un día antes de diciembre


## Provincia con una granja, sin hambre, que empieza el día `day` del año.
func _farm_province(data, day: int):
	data.rules["calendar_start_day"] = day
	data.rules["food_per_person"] = 0
	var p = new_province(data, 100)
	p.add_building("farm")
	p.store.seed_initial("coin", 60000)
	return p


func _winter_province(data, firewood: int, day: int = 0):
	data.rules["calendar_start_day"] = day
	data.rules["food_per_person"] = 0
	var p = new_province(data, 100)
	p.store.seed_initial("firewood", firewood)
	return p


# --- 2.2 Cosechas por mes ----------------------------------------------------------------------

func test_real_seasons_file_has_twelve_months_averaging_100() -> void:
	var data = new_data_with_seasons()
	assert_true(data.seasons.has("wheat") and data.seasons.has("olives"), "el trigo y el olivo tienen estaciones")
	for good in data.seasons.keys():
		var list: Array = data.seasons[good]
		assert_eq(list.size(), 12, "%s: doce meses" % good)
		var total := 0
		for v in list:
			total += int(v)
		assert_eq(total, 1200, "%s: la media anual es exactamente 100 %%" % good)
	# El trigo se cosecha de mayo a julio y se siembra de septiembre a diciembre (H-10).
	var wheat: Array = data.seasons["wheat"]
	assert_true(wheat[5] > wheat[0] and wheat[5] > wheat[9], "junio (cosecha) rinde más que enero y octubre")
	assert_eq(data.season_percent("wheat", 5), wheat[5], "season_percent lee la tabla")
	assert_eq(data.season_percent("wood", 5), 100, "lo que no tiene estaciones vale 100")
	assert_eq(data.season_percent("wheat", 99), wheat[11], "un mes fuera de rango se acota")
	done()


func test_seasons_validation_rejects_bad_tables() -> void:
	var data = load(GAME_DATA).new()
	assert_true(data.load_defaults(), "base válida")
	var good_list := [100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100]
	assert_true(data.build_seasons({"wheat": good_list}), "tabla correcta")
	var cases := {
		"once meses": {"wheat": [100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100]},
		"mercancía desconocida": {"magia": good_list},
		"la moneda no es física": {"coin": good_list},
		"porcentaje negativo": {"wheat": [-1, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100]},
		"porcentaje enorme": {"wheat": [1001, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100]},
		"porcentaje decimal": {"wheat": [100.5, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100]},
		"no es una lista": {"wheat": 100},
	}
	for name in cases.keys():
		var other = load(GAME_DATA).new()
		other.load_defaults()
		other.errors.clear()
		assert_true(not other.build_seasons(cases[name]), "se rechaza: %s" % name)
		assert_true(not other.errors.is_empty(), "y dice por qué: %s" % name)
	done()


func test_farm_output_follows_the_month() -> void:
	var data = new_data_with_seasons()
	var winter = _farm_province(data, 0)
	run_steps(winter, 6)
	assert_eq(winter.store.stock("wheat"), 4800, "en enero la granja da el 80 % (4800 de 6000)")
	var data2 = new_data_with_seasons()
	var summer = _farm_province(data2, 181)
	run_steps(summer, 6)
	assert_eq(summer.store.stock("wheat"), 8700, "en julio da el 145 % (8700 de 6000)")
	var data3 = new_data()
	var flat = _farm_province(data3, 181)
	run_steps(flat, 6)
	assert_eq(flat.store.stock("wheat"), 6000, "sin estaciones da lo de siempre")
	done()


func test_a_year_of_one_farm_averages_close_to_normal_and_conserves_goods() -> void:
	var data = new_data_with_seasons()
	data.rules["heating_per_person"] = 0      # aquí se mide solo el trigo, no el frío
	var p = _farm_province(data, 181)
	var STORE_KIND = load(STORE).CONSUMED
	for i in range(8760):
		p.step()
		p.store.remove("wheat", p.store.stock("wheat"), STORE_KIND)   # vaciar el trigo para que nunca se llene
	var produced: int = p.store.ledger("wheat")["produced"]
	var flat_cycles := 8760 / 6
	var normal := flat_cycles * 6000
	assert_true(absi(produced - normal) * 100 <= normal * 2, "un año rinde el 100 %% ±2 %% (%d frente a %d)" % [produced, normal])
	assert_true(p.check_invariants().is_empty(), "coherente: %s" % str(p.check_invariants()))
	done()


func test_the_month_is_the_same_after_saving_and_loading() -> void:
	var data = new_data_with_seasons()
	var a = _farm_province(data, 181)
	run_steps(a, 301)      # a mitad de un día y de un ciclo
	var saved: Dictionary = a.to_dict()
	var b = new_province(data, 100)
	assert_true(b.load_dict(saved), "carga: %s" % b.last_error)
	run_steps(a, 1500)
	run_steps(b, 1500)
	assert_eq(snapshot(b), snapshot(a), "tras guardar y cargar la provincia sigue igual (estaciones incluidas)")
	assert_eq(b.current_season(), a.current_season(), "y la estación coincide")
	done()


func test_current_season_follows_the_start_day_and_the_step_counter() -> void:
	var data = new_data()
	data.rules["calendar_start_day"] = 181
	var p = new_province(data, 100)
	assert_eq(p.current_month(), 6, "la partida nueva empieza en julio")
	assert_eq(p.current_season(), "summer", "en verano")
	run_steps(p, 184 * 24)
	assert_eq(p.current_season(), "winter", "184 días después es 1 de enero: invierno")
	assert_eq(p.current_month(), 0, "enero")
	done()


# --- 2.3 Leña en invierno -----------------------------------------------------------------------

func test_winter_consumes_one_firewood_per_person_per_step() -> void:
	var data = new_data()
	var p = _winter_province(data, 7800)
	run_steps(p, 10)
	assert_eq(p.store.stock("firewood"), 7800 - 10 * 100, "100 personas gastan 100 milésimas de leña por paso")
	assert_eq(p.store.ledger("firewood")["consumed"], 1000, "y queda anotado como consumido")
	assert_eq(p.cold_shortage_percent, 0, "sin escasez")
	assert_true(not p.alerts.has("cold"), "sin aviso de frío")
	done()


func test_summer_needs_no_firewood() -> void:
	var data = new_data()
	var p = _winter_province(data, 7800, 181)
	run_steps(p, 50)
	assert_eq(p.store.stock("firewood"), 7800, "en verano no se gasta leña para calentarse")
	assert_true(not p.alerts.has("cold"), "ni hay aviso")
	done()


func test_heating_switches_on_when_december_begins() -> void:
	var data = new_data()
	var p = _winter_province(data, 7800, NOVEMBER_30)
	run_steps(p, 23)
	assert_eq(p.current_season(), "autumn", "aún es noviembre")
	assert_eq(p.store.stock("firewood"), 7800, "todavía no se calienta")
	p.step()
	assert_eq(p.current_season(), "winter", "el paso 24 es 1 de diciembre")
	assert_eq(p.store.stock("firewood"), 7700, "ya gasta leña")
	done()


func test_missing_firewood_is_gradual_and_nobody_starves_of_cold() -> void:
	var data = new_data()
	var p = _winter_province(data, 40)
	p.step()
	assert_eq(p.cold_shortage_percent, 60, "pedía 100 y había 40: faltó el 60 %")
	assert_true(p.alerts.has("cold"), "aviso de frío al primer paso")
	var warning: int = data.rules["cold_warning_steps"]
	var population_at_start: int = p.population
	p.store.remove("firewood", p.store.stock("firewood"), load(STORE).CONSUMED)
	run_steps(p, warning - 1)
	assert_eq(p.unrest, 0, "durante el aviso no sube el descontento")
	p.step()
	assert_eq(p.unrest, data.rules["cold_unrest_rise"], "pasado el aviso sube poco a poco (%d)" % p.unrest)
	var before: int = p.unrest
	p.step()
	assert_true(p.unrest > before, "y sigue subiendo mientras falte")
	for i in range(1000):      # sigue siendo invierno: enero y febrero duran 1416 pasos
		p.step()
		assert_true(p.unrest <= data.rules["cold_unrest_limit"], "el frío nunca pasa del tope (paso %d: %d)" % [i, p.unrest])
		if p.unrest > data.rules["cold_unrest_limit"]:
			break
	assert_eq(p.current_season(), "winter", "sigue siendo invierno")
	assert_true(not p.alerts.has("starvation"), "el frío no causa hambruna")
	assert_eq(p.hunger_steps, 0, "ni cuenta como hambre")
	assert_true(p.population >= population_at_start, "nadie muere de frío: la población no baja (%d → %d)" % [population_at_start, p.population])
	assert_eq(p.unrest, data.rules["cold_unrest_limit"], "el frío no pasa del tope de descontento (%d)" % p.unrest)
	assert_true(p.productivity_percent() >= 85, "y el trabajo se frena poco (%d %%)" % p.productivity_percent())
	done()


func test_cold_never_pushes_unrest_above_its_limit_but_other_causes_can() -> void:
	var data = new_data()
	var p = _winter_province(data, 0)
	p.unrest = 900      # otra causa (por ejemplo soldados sin paga) ya lo subió
	run_steps(p, 100)
	assert_true(p.unrest < 900, "con frío el descontento ajeno baja hasta el tope en vez de quedarse")
	assert_eq(p.unrest, data.rules["cold_unrest_limit"], "y se queda en el tope del frío")
	done()


func test_firewood_arriving_ends_the_cold_and_unrest_recovers() -> void:
	var data = new_data()
	var p = _winter_province(data, 0)
	run_steps(p, 20)
	assert_true(p.unrest > 0 and p.alerts.has("cold"), "tras 20 pasos sin leña hay frío y descontento")
	p.store.seed_initial("firewood", 7800)
	p.step()
	assert_eq(p.cold_shortage_percent, 0, "con leña la escasez termina")
	assert_eq(p.cold_steps, 0, "y la racha se reinicia")
	assert_true(not p.alerts.has("cold"), "el aviso desaparece")
	run_steps(p, 20)
	assert_eq(p.unrest, 0, "el descontento baja hasta 0")
	done()


func test_heating_can_be_disabled_by_the_rules() -> void:
	var data = new_data()
	data.rules["heating_per_person"] = 0
	var p = _winter_province(data, 0)
	run_steps(p, 100)
	assert_eq(p.unrest, 0, "con la regla a 0 no hay necesidad de leña")
	assert_true(not p.alerts.has("cold"), "ni aviso")
	done()


func test_cold_state_is_saved_and_an_old_save_without_it_still_loads() -> void:
	var data = new_data()
	var p = _winter_province(data, 0)
	run_steps(p, 15)
	var saved: Dictionary = p.to_dict()
	assert_eq(saved["cold_steps"], 15, "la racha de frío se guarda")
	var q = new_province(data, 100)
	assert_true(q.load_dict(saved), "carga: %s" % q.last_error)
	assert_eq([q.cold_steps, q.cold_shortage_percent, q.unrest], [p.cold_steps, p.cold_shortage_percent, p.unrest], "y vuelve igual")
	var old: Dictionary = saved.duplicate(true)
	old.erase("cold_steps")
	old.erase("cold_shortage_percent")
	var r = new_province(data, 100)
	assert_true(r.load_dict(old), "un guardado anterior sin esos campos carga: %s" % r.last_error)
	assert_eq([r.cold_steps, r.cold_shortage_percent], [0, 0], "y vale 0")
	for bad in [-1, 101, 1.5, "x"]:
		var broken: Dictionary = saved.duplicate(true)
		broken["cold_shortage_percent"] = bad
		var s = new_province(data, 100)
		assert_true(not s.load_dict(broken), "se rechaza cold_shortage_percent = %s" % str(bad))
	done()


func test_a_cold_winter_with_a_woodcutter_stays_warm() -> void:
	var data = new_data()
	data.rules["calendar_start_day"] = 0
	data.rules["food_per_person"] = 0
	var p = new_province(data, 100)
	p.add_building("woodcutter")
	p.store.seed_initial("coin", 60000)
	p.store.seed_initial("tools", 0)
	run_steps(p, 24 * 90)
	assert_eq(p.cold_shortage_percent, 0, "un leñador abastece a 100 personas (250 por paso frente a 100)")
	assert_eq(p.unrest, 0, "sin descontento")
	done()
