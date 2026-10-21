extends "res://tests/province_case.gd"
## Cierre de la fase 1 (tarea 1.10, parte [PC]): partidas largas con el mundo entero
## (las 5 provincias del mapa), con un jugador automático que construye y sufre malas
## cosechas, con guardados y cargas por el camino y con cierres y reaperturas de la
## aplicación con ausencias de todo tipo. Lo que se comprueba es que nada se corrompe,
## que guardar y cargar no cambia el rumbo de la partida y que la interfaz aguanta
## un año de juego a ×600. No comprueba que la economía esté equilibrada: los datos
## son de ejemplo (D-017).

const MAP := "res://scripts/sim/game_map.gd"
const SAVE := "res://scripts/sim/save_game.gd"
const SESSION := "res://scripts/sim/game_session.gd"
const MAIN_SCENE := "res://main.tscn"
const DIR := "user://pruebas_cierre"
const PATH := "user://pruebas_cierre/partida.json"
const T0 := 1800000000
const BUILD_ORDER: Array[String] = ["house", "granary", "farm", "mill", "bakery", "woodcutter"]
const TWO_YEARS := 17520


func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file_name in DirAccess.open(DIR).get_files():
		DirAccess.remove_absolute(DIR + "/" + file_name)


func _new_world(data):
	var map = load(MAP).new()
	var loaded: bool = map.load_defaults(data)
	assert_true(loaded, "el mapa por defecto se carga: %s" % "\n".join(map.errors))
	var created: Dictionary = map.new_world(data)
	assert_true(created["ok"], "partida nueva: %s" % created["error"])
	return created["world"]


## «Jugador» automático. Depende solo del estado del mundo (el contador de pasos), nunca
## del reloj ni del azar: así dos partidas iguales hacen lo mismo y se pueden comparar.
## Cada día intenta una obra en cada provincia (muchas veces no podrá: eso también cuenta)
## y cada 240 pasos una provincia sufre una mala cosecha de 40 pasos.
func _bot(world) -> void:
	var n: int = world.step_count
	if n % 24 == 0:
		var day: int = n / 24
		for i in range(world.provinces.size()):
			world.provinces[i].start_construction(BUILD_ORDER[(day + i) % BUILD_ORDER.size()])
	if n % 240 == 0:
		var target = world.provinces[(n / 240) % world.provinces.size()]
		target.add_modifier("wheat", 0, 40)


func _play(world, steps: int) -> void:
	for i in range(steps):
		_bot(world)
		world.step()


func _world_invalid_values(world, data) -> int:
	var bad := 0
	for p in world.provinces:
		bad += _invalid_values(p, data)
	if typeof(world.step_count) != TYPE_INT or world.step_count < 0:
		bad += 1
	return bad


func _building_total(world) -> int:
	var total := 0
	for p in world.provinces:
		total += p.buildings.size()
	return total


## Ids de las provincias cuyo estado difiere entre dos mundos. Se compara lo guardable
## (to_dict) y también lo que se lee directamente de los campos (snapshot): si solo se
## mirase to_dict, un campo que no se guarda pasaría desapercibido en ambos lados.
func _differing_provinces(a, b) -> Array[String]:
	var ids: Array[String] = []
	if a.provinces.size() != b.provinces.size():
		ids.append("(distinto número de provincias)")
		return ids
	for i in range(a.provinces.size()):
		if a.provinces[i].to_dict() != b.provinces[i].to_dict() or snapshot(a.provinces[i]) != snapshot(b.provinces[i]):
			ids.append(a.provinces[i].id)
	return ids


func test_two_game_years_of_the_whole_world() -> void:
	var data = new_data()
	var world = _new_world(data)
	var start_buildings := _building_total(world)
	var invalid := 0
	var bad_checks := 0
	var lowest_population := 1000000000
	for i in range(TWO_YEARS):
		_bot(world)
		world.step()
		if i % 24 == 23:
			invalid += _world_invalid_values(world, data)
			for p in world.provinces:
				lowest_population = mini(lowest_population, p.population)
		if i % 97 == 0 and not world.check_invariants().is_empty():
			bad_checks += 1
	assert_eq(world.step_count, TWO_YEARS, "dos años son 17 520 pasos")
	assert_eq(invalid, 0, "ningún valor negativo ni no entero en todo el recorrido")
	assert_eq(bad_checks, 0, "ninguna comprobación de coherencia intermedia falló")
	assert_true(world.check_invariants().is_empty(), "coherente al final: %s" % str(world.check_invariants()))
	for p in world.provinces:
		for good_id in data.goods.keys():
			var l: Dictionary = p.store.ledger(good_id)
			var expected: int = l["initial"] + l["produced"] + l["imported"] - l["consumed"] - l["exported"] - l["lost"]
			assert_eq(p.store.stock(good_id), expected, "%s / %s: existencias = iniciales + producción + importaciones - consumo - exportaciones - pérdidas" % [p.id, good_id])
	assert_true(_building_total(world) > start_buildings, "el jugador automático llegó a construir (si no, la prueba no probaría nada)")
	var summary: Array[String] = []
	for p in world.provinces:
		summary.append("%s pob %d desc %d edif %d" % [p.id, p.population, p.unrest, p.buildings.size()])
	print("2 años: %s; población mínima vista %d" % [" | ".join(summary), lowest_population])
	done()


func test_saving_and_loading_never_changes_the_course_of_the_game() -> void:
	_clean()
	var data = new_data()
	var continuous = _new_world(data)
	var reloaded = _new_world(data)
	var save_script = load(SAVE)
	var trips := 0
	# Cobertura: cuántos de los guardados cayeron en un momento con cada cosa en marcha.
	var covered := {"obras": 0, "efectos": 0, "descontento": 0, "hambre": 0, "reclutas": 0}
	for i in range(1, 6001):
		_bot(continuous)
		continuous.step()
		_bot(reloaded)
		reloaded.step()
		if i % 97 != 0:
			continue
		for p in reloaded.provinces:
			if not p.projects.is_empty():
				covered["obras"] += 1
			if not p.modifiers.is_empty():
				covered["efectos"] += 1
			if p.unrest > 0:
				covered["descontento"] += 1
			if p.hunger_steps > 0:
				covered["hambre"] += 1
			if p.recruits > 0:
				covered["reclutas"] += 1
		var decoded: Dictionary
		if trips % 3 == 2:
			var error: String = save_script.write_file(reloaded, PATH, "0.0.test", T0 + i)
			assert_eq(error, "", "el guardado en archivo del paso %d no da error" % i)
			decoded = save_script.read_file(data, PATH)
		else:
			decoded = save_script.decode(data, save_script.encode(reloaded, "0.0.test", T0 + i))
		assert_true(decoded["ok"], "el paso %d se vuelve a cargar: %s" % [i, decoded["error"]])
		if not decoded["ok"]:
			break
		reloaded = decoded["world"]
		trips += 1
		assert_eq(_differing_provinces(continuous, reloaded), [], "tras cargar en el paso %d el estado es idéntico" % i)
	assert_eq(trips, 61, "se hicieron los 61 guardados y cargas (uno cada 97 pasos)")
	print("guardados en un momento con: %s" % str(covered))
	for key in ["obras", "efectos", "descontento", "hambre"]:
		assert_true(covered[key] > 0, "algún guardado cayó con %s en marcha (si no, la prueba no probaría nada)" % key)
	assert_eq(reloaded.step_count, continuous.step_count, "mismo número de pasos")
	assert_eq(_differing_provinces(continuous, reloaded), [], "tras 6000 pasos con 61 guardados y cargas el estado es idéntico al de la partida sin interrupciones")
	for i in range(continuous.provinces.size()):
		assert_eq(snapshot(reloaded.provinces[i]), snapshot(continuous.provinces[i]), "también coinciden los avisos y el resto del estado visible (%s)" % continuous.provinces[i].id)
	assert_true(reloaded.check_invariants().is_empty(), "coherente: %s" % str(reloaded.check_invariants()))
	done()


func test_forty_close_and_reopen_cycles_with_odd_absences() -> void:
	_clean()
	# Ausencias en segundos: cortas, justo en el límite de un paso, más allá del tope de
	# 10 h (36 000 s), cero y con el reloj hacia atrás.
	var gaps: Array[int] = [30, 90, 3600, 7200, 40000, 0, 59, 61, -500, 600, 36000, 36060, 1, 86400]
	var data = new_data()
	var reference = _new_world(data)
	var session = load(SESSION).new(PATH, "0.0.test")
	var now := T0
	assert_true(session.start(now), "primer arranque: %s" % "\n".join(session.errors))
	var expected_steps := 0
	var invalid := 0
	var offline_steps_total := 0
	for cycle in range(40):
		var online: int = 20 + (cycle * 37) % 181
		_play(session.world, online)
		_play(reference, online)
		expected_steps += online
		now += online
		assert_eq(session.save(now), "", "guarda en el ciclo %d" % cycle)
		var gap: int = gaps[cycle % gaps.size()]
		now += gap
		session = load(SESSION).new(PATH, "0.0.test")
		assert_true(session.start(now), "reabre en el ciclo %d: %s" % [cycle, "\n".join(session.errors)])
		var expected_offline := 0
		if gap >= 0:
			expected_offline = mini(gap, 36000) / 60
		reference.run_steps(expected_offline)
		expected_steps += expected_offline
		offline_steps_total += expected_offline
		assert_eq(session.last_report["steps"], expected_offline, "ciclo %d (ausencia de %d s): pasos aplicados" % [cycle, gap])
		assert_eq(session.world.step_count, expected_steps, "ciclo %d: el contador de pasos suma lo jugado y lo ausente, ni más ni menos" % cycle)
		assert_eq(session.notice, "", "ciclo %d: sin avisos de guardado dañado" % cycle)
		assert_eq(_differing_provinces(session.world, reference), [], "ciclo %d: cerrar y reabrir no cambia el rumbo de la partida" % cycle)
		invalid += _world_invalid_values(session.world, data)
		var problems: Array[String] = session.world.check_invariants()
		assert_true(problems.is_empty(), "ciclo %d coherente: %s" % [cycle, str(problems)])
	assert_eq(invalid, 0, "ningún valor inválido en los 40 ciclos")
	assert_true(offline_steps_total > 1000, "la prueba aplicó bastante tiempo ausente (%d pasos)" % offline_steps_total)
	print("40 ciclos: %d pasos en total, %d de ellos ausente" % [expected_steps, offline_steps_total])
	done()


## Pantalla principal lista, sin añadirla al árbol: _ready se llama a mano.
func _main():
	var main = load(MAIN_SCENE).instantiate()
	main.session = load(SESSION).new(PATH, "0.0.test")
	main.fixed_now = T0
	main._ready()
	main._map_view.size = Vector2(688, 500)
	return main


func test_a_year_of_play_through_the_real_screen_at_x600() -> void:
	_clean()
	var main = _main()
	var world = main.session.world
	var data = main.session.data
	main._on_speed_pressed(3)
	var presses := 0
	var provinces: Array = main.session.map.provinces
	for frame in range(1, 1501):
		main._process(1.0)
		if frame % 40 == 0:
			var turn: int = frame / 40
			main._on_province_selected(provinces[turn % provinces.size()]["id"])
			var button: Button = main._panel.build_button(BUILD_ORDER[turn % BUILD_ORDER.size()])
			if button != null and not button.disabled:
				button.pressed.emit()
				presses += 1
	assert_eq(world.step_count, 15000, "1500 s a ×600 con 60 s por paso: 15 000 pasos")
	assert_eq(main._time_label.text, main.session.time_text(), "el reloj de la pantalla coincide con el del mundo")
	assert_eq(_world_invalid_values(world, data), 0, "ningún valor inválido")
	assert_true(world.check_invariants().is_empty(), "coherente: %s" % str(world.check_invariants()))
	assert_true(presses > 0, "se pulsó algún botón de construir (%d veces)" % presses)
	assert_true(main._panel.current_province_id() != "", "la ficha muestra una provincia")
	# El autoguardado de la pantalla dejó un archivo que se puede cargar.
	var loaded: Dictionary = load(SAVE).read_file(data, PATH)
	assert_true(loaded["ok"], "el autoguardado se puede cargar: %s" % loaded["error"])
	if loaded["ok"]:
		assert_true(loaded["world"].step_count >= 15000 - 150, "el autoguardado es reciente (paso %d)" % loaded["world"].step_count)
		assert_eq(loaded["warning"], "", "sin avisos al cargar el autoguardado")
	main.free()
	done()


func test_touch_input_is_converted_to_mouse_events() -> void:
	# En Android, el dedo llega como toque; el mapa lee clics de ratón (D-018), que Godot
	# genera a partir del toque solo si este ajuste está activo (por defecto lo está).
	var emulate: bool = ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	assert_true(emulate, "el proyecto no desactiva la emulación de ratón desde el toque")
	done()
