extends "res://tests/province_case.gd"
## Interfaz táctil (tarea 1.9): textos, toque en el mapa y pantalla principal.
## Sin ventana: las pruebas llaman a los métodos de la interfaz con eventos de entrada
## fabricados; el dibujo real se revisa con capturas y en el móvil (A11).

const TEXTS := "res://scripts/ui/texts.gd"
const MAIN_SCENE := "res://main.tscn"
const SESSION := "res://scripts/sim/game_session.gd"
const PROVINCE_SCRIPT := "res://scripts/sim/province.gd"
const DIR := "user://pruebas_ui"
const PATH := "user://pruebas_ui/partida.json"
const T0 := 1800000000


func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file_name in DirAccess.open(DIR).get_files():
		DirAccess.remove_absolute(DIR + "/" + file_name)


## Pantalla principal lista, sin añadirla al árbol: _ready se llama a mano.
func _main(now: int = T0):
	var main = load(MAIN_SCENE).instantiate()
	main.session = load(SESSION).new(PATH, "0.0.test")
	main.fixed_now = now
	main._ready()
	main._map_view.size = Vector2(688, 500)
	return main


func _tap(view, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	view._gui_input(event)


func test_amount_is_exact_and_trimmed() -> void:
	var texts = load(TEXTS)
	assert_eq(texts.amount(0), "0", "cero")
	assert_eq(texts.amount(1000), "1", "entero")
	assert_eq(texts.amount(12500), "12,5", "un decimal")
	assert_eq(texts.amount(50), "0,05", "no se redondea a cero")
	assert_eq(texts.amount(5), "0,005", "milésimas")
	assert_eq(texts.amount(1234), "1,234", "tres decimales")
	assert_eq(texts.amount(-250), "-0,25", "negativo")
	assert_eq(texts.amount(100000), "100", "cien")
	assert_eq(texts.signed_amount(3000), "+3", "con signo")
	assert_eq(texts.signed_amount(-1500), "-1,5", "negativo con signo")
	assert_eq(texts.signed_amount(0), "0", "cero sin signo")
	done()


func test_duration_text() -> void:
	var texts = load(TEXTS)
	assert_eq(texts.duration(30), "menos de 1 min", "30 s")
	assert_eq(texts.duration(90), "1 min", "90 s")
	assert_eq(texts.duration(7500), "2 h 05 min", "2 h 5 min")
	assert_eq(texts.duration(36000), "10 h 00 min", "10 h")
	assert_eq(texts.duration(90000), "1 d 1 h", "más de un día")
	done()


func test_every_status_and_alert_has_a_text_and_a_severity() -> void:
	var texts = load(TEXTS)
	var province = load(PROVINCE_SCRIPT)
	for status in province.STATUSES:
		assert_true(texts.STATUS_TEXT.has(status), "texto para el estado %s" % status)
	for code in province.ALERTS:
		assert_true(texts.ALERT_TEXT.has(code), "texto para el aviso %s" % code)
		assert_true(texts.ALERT_SEVERITY.has(code), "gravedad para el aviso %s" % code)
	assert_eq(texts.alert_severity([]), 0, "sin avisos")
	assert_eq(texts.alert_severity(["storage_full", "waste"]), 0, "avisos informativos no marcan el mapa")
	assert_eq(texts.alert_severity(["storage_full", "starvation"]), 2, "manda el más grave")
	done()


func test_offline_text_covers_the_cases() -> void:
	var texts = load(TEXTS)
	var data = new_data()
	var back: String = texts.offline_text(data, {"clock_problem": "clock_went_back"})
	assert_true("anterior" in back and "no se ha sumado tiempo" in back, "reloj atrasado: %s" % back)
	var unknown: String = texts.offline_text(data, {"clock_problem": "unknown_saved_time"})
	assert_true("se conocía la hora" in unknown, "hora desconocida: %s" % unknown)
	var report := {
		"clock_problem": "", "elapsed_seconds": 7500, "steps": 125, "capped": true,
		"provinces": [{
			"id": "a", "name": "Provincia X", "population_before": 100, "population_after": 90,
			"buildings_before": {"house": 1}, "buildings_after": {"house": 3, "farm": 1},
			"stock_delta": {"bread": -1500, "coin": 107200, "wheat": 50}, "worst_hunger_steps": 30,
			"worst_unrest": 500, "alerts": ["starvation", "storage_full"],
		}],
	}
	var text: String = texts.offline_text(data, report)
	assert_true("2 h 05 min" in text, "tiempo: %s" % text)
	assert_true("125 pasos" in text, "pasos")
	assert_true("límite" in text, "se avisa del tope")
	assert_true("Población: 100 → 90" in text, "población")
	assert_true("Pan -1,5" in text and "Moneda +107,2" in text and "Trigo +0,05" in text, "variaciones exactas: %s" % text)
	assert_true("2 Vivienda" in text and "1 Granja" in text, "terminadas")
	assert_true("hambre" in text and "30 pasos" in text, "hambre")
	assert_true("Hambruna" in text, "aviso grave")
	assert_true(not ("Almacén lleno" in text), "el aviso informativo no entra en el resumen")
	done()


func test_tapping_each_province_selects_it() -> void:
	_clean()
	var main = _main()
	var view = main._map_view
	var map = main.session.map
	var seen: Array[String] = []
	view.province_selected.connect(func(id: String) -> void: seen.append(id))
	for p in map.provinces:
		_tap(view, view.map_to_view(p["x"], p["y"]))
		assert_eq(view.selected_id, p["id"], "tocar el centro de %s" % p["id"])
		assert_eq(main._panel.current_province_id(), p["id"], "la ficha muestra %s" % p["id"])
	assert_eq(seen.size(), map.provinces.size(), "una señal por toque")
	# Un toque en zona vacía no cambia la selección
	var before: String = view.selected_id
	_tap(view, Vector2(5, 5))
	assert_eq(view.selected_id, before, "tocar el vacío no cambia nada")
	assert_eq(seen.size(), map.provinces.size(), "ni emite señal")
	main.free()
	done()


func test_tap_near_the_edge_of_the_touch_zone_still_selects() -> void:
	_clean()
	var main = _main()
	var view = main._map_view
	var a: Dictionary = main.session.map.find("prueba_a")
	var edge: Vector2 = view.map_to_view(a["x"], a["y"]) + Vector2(main.session.map.touch_radius * view.view_scale() * 0.95, 0)
	_tap(view, edge)
	assert_eq(view.selected_id, "prueba_a", "cerca del borde de la zona de toque")
	var outside: Vector2 = view.map_to_view(a["x"], a["y"]) + Vector2(main.session.map.touch_radius * view.view_scale() * 1.2, 0)
	view.selected_id = ""
	_tap(view, outside)
	assert_eq(view.selected_id, "", "fuera de la zona")
	main.free()
	done()


func test_touch_zone_is_large_enough_for_a_finger() -> void:
	_clean()
	var main = _main()
	# Base de 720 px de ancho = 1080 px físicos en el móvil de prueba (×1,5); 48 dp ≈ 132 px
	# físicos ≈ 88 px base. El diámetro de la zona de toque debe llegar a eso.
	var diameter: float = 2.0 * main.session.map.touch_radius * main._map_view.view_scale()
	assert_true(diameter >= 88.0, "zona de toque de %.0f px base (mínimo 88)" % diameter)
	main.free()
	done()


func test_building_buttons_build_and_report() -> void:
	_clean()
	var main = _main()
	var province = main.session.world.find_province("prueba_d")
	main._on_province_selected("prueba_d")
	var projects_before: int = province.projects.size()
	var button: Button = main._panel.build_button("house")
	assert_true(button != null and not button.disabled, "se puede construir una vivienda con recursos")
	assert_true("Construir Vivienda" in button.text, "texto del botón: %s" % button.text)
	assert_true(button.custom_minimum_size.y >= 88.0, "botón grande para el dedo")
	button.pressed.emit()
	assert_eq(province.projects.size(), projects_before + 1, "la obra se inició")
	assert_true("Obra iniciada" in main._panel.feedback_text(), "mensaje: %s" % main._panel.feedback_text())
	# Sin recursos: el botón se desactiva y explica por qué
	province.store.remove("coin", province.store.stock("coin"), "consumed")
	main._panel.refresh()
	assert_true(button.disabled, "sin moneda, desactivado")
	assert_true("faltan recursos" in button.text, "dice por qué: %s" % button.text)
	button.pressed.emit()
	assert_true("No se pudo construir" in main._panel.feedback_text(), "si se fuerza, no construye y avisa")
	main.free()
	done()


func test_projects_limit_disables_the_buttons() -> void:
	_clean()
	var main = _main()
	var province = main.session.world.find_province("prueba_d")
	province.store.seed_initial("wood", 20000)
	province.store.seed_initial("coin", 50000)
	main._on_province_selected("prueba_d")
	for i in range(main.session.data.rules["max_projects"]):
		province.start_construction("house")
	main._panel.refresh()
	assert_true(main._panel.build_button("house").disabled, "con las obras al máximo no se puede construir más")
	assert_true("obras al máximo" in main._panel.build_button("house").text, "lo explica")
	main.free()
	done()


func test_speed_controls_time() -> void:
	_clean()
	var main = _main()
	var world = main.session.world
	main._on_speed_pressed(0)
	main._process(1000.0)
	assert_eq(world.step_count, 0, "en pausa no avanza")
	main._on_speed_pressed(2)
	main._process(1.0)
	assert_eq(world.step_count, 1, "×60 con 60 s por paso: un paso por segundo")
	main._process(10.0)
	assert_eq(world.step_count, 11, "10 s = 10 pasos")
	main._on_speed_pressed(1)
	main._process(59.0)
	assert_eq(world.step_count, 11, "×1: 59 s no completan un paso")
	main._process(1.0)
	assert_eq(world.step_count, 12, "×1: a los 60 s, un paso")
	main._on_speed_pressed(3)
	main._process(100000.0)
	assert_eq(world.step_count, 12 + 30, "un fotograma no puede dar más de 30 pasos")
	assert_eq(main._time_label.text, main.session.time_text(), "el reloj de la pantalla se actualiza")
	main.free()
	done()


func test_autosave_writes_the_file_with_the_time() -> void:
	_clean()
	var main = _main(T0 + 5)
	main._on_speed_pressed(0)
	assert_true(not FileAccess.file_exists(PATH), "todavía no hay guardado")
	main._process(14.0)
	assert_true(not FileAccess.file_exists(PATH), "a los 14 s aún no")
	main._process(1.5)
	assert_true(FileAccess.file_exists(PATH), "a los 15 s se guarda solo")
	var loaded: Dictionary = load("res://scripts/sim/save_game.gd").read_file(main.session.data, PATH)
	assert_true(loaded["ok"], "se puede leer")
	assert_eq(loaded["saved_at"], T0 + 5, "con la hora")
	main.free()
	done()


func test_pause_saves_and_resume_applies_the_absence_with_a_summary() -> void:
	_clean()
	var main = _main(T0)
	main._on_speed_pressed(0)
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_true(FileAccess.file_exists(PATH), "al pausar la aplicación se guarda")
	assert_true(not main.has_modal(), "sin ventanas")
	main.fixed_now = T0 + 3 * 3600
	main.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(main.session.world.step_count, 180, "3 h de pausa = 180 pasos")
	assert_true(main.has_modal(), "al volver se muestra el resumen")
	main.free()
	done()


func test_start_with_a_save_shows_the_summary_and_a_fresh_start_does_not() -> void:
	_clean()
	var first = _main(T0)
	assert_true(not first.has_modal(), "partida nueva: sin resumen")
	first.session.save(T0)
	first.free()
	var again = _main(T0 + 600)
	assert_eq(again.session.world.step_count, 10, "10 min = 10 pasos")
	assert_true(again.has_modal(), "partida cargada con ausencia: resumen")
	again.free()
	done()


func test_new_game_flow_resets_the_world() -> void:
	_clean()
	var main = _main()
	main._on_speed_pressed(0)
	main.session.world.run_steps(50)
	main._confirm_new_game()
	assert_eq(main.session.world.step_count, 0, "paso 0")
	assert_eq(main._map_view.world, main.session.world, "el mapa usa el mundo nuevo")
	assert_eq(main._panel.current_province_id(), "", "sin provincia seleccionada")
	main.free()
	done()


func test_broken_save_shows_a_notice_and_still_plays() -> void:
	_clean()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("roto")
	file.close()
	var main = _main()
	assert_true(main.has_modal(), "avisa del guardado dañado")
	assert_eq(main.session.world.step_count, 0, "partida nueva jugable")
	main.free()
	done()


func test_speed_text_formats_milliseconds_per_step() -> void:
	var texts = load(TEXTS)
	var text: String = texts.speed_text({"steps": 600, "provinces": 5, "microseconds": 300000})
	assert_true("600 pasos de 5 provincias en 300 ms" in text, "total: %s" % text)
	assert_true("0,50 ms" in text, "por paso: %s" % text)
	assert_true("12,34 ms" in texts.speed_text({"steps": 100, "provinces": 5, "microseconds": 1234000}), "12,34 ms por paso")
	assert_eq(texts.speed_text({"steps": 0, "provinces": 0, "microseconds": 0}), "No se pudo medir.", "sin datos")
	done()


func test_menu_offers_the_speed_measurement() -> void:
	_clean()
	var main = _main()
	main._on_measure_pressed()
	assert_true(main.has_modal(), "se muestra el resultado")
	main.free()
	done()
