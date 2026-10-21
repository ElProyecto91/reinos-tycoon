extends "res://tests/province_case.gd"
## Sesión de juego: arranque, guardado, reanudación y archivos dañados.

const SESSION := "res://scripts/sim/game_session.gd"
const DIR := "user://pruebas_sesion"
const PATH := "user://pruebas_sesion/partida.json"
const T0 := 1800000000


func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var dir := DirAccess.open(DIR)
	for file_name in dir.get_files():
		DirAccess.remove_absolute(DIR + "/" + file_name)


func _session():
	return load(SESSION).new(PATH, "0.0.test")


func test_first_start_creates_a_new_game() -> void:
	_clean()
	var s = _session()
	assert_true(s.start(T0), "arranca: %s" % "\n".join(s.errors))
	assert_eq(s.world.provinces.size(), 5, "partida nueva con las 5 provincias")
	assert_eq(s.world.step_count, 0, "paso 0")
	assert_eq(s.notice, "", "sin avisos")
	assert_eq(s.last_report, {}, "sin ausencia que contar")
	assert_eq(s.stamp, T0, "marca = ahora")
	done()


func test_save_then_start_restores_and_applies_the_absence() -> void:
	_clean()
	var s = _session()
	s.start(T0)
	s.world.run_steps(10)
	assert_eq(s.save(T0 + 600), "", "guarda")
	assert_eq(s.stamp, T0 + 600, "la marca avanza al guardar")
	# La referencia usa otra ruta: con la misma leería el guardado recién creado.
	var reference = load(SESSION).new(DIR + "/referencia.json", "0.0.test")
	reference.start(T0)
	reference.world.run_steps(10)
	var later = _session()
	assert_true(later.start(T0 + 600 + 7200), "arranca con guardado")
	assert_eq(later.last_report["steps"], 120, "2 h de ausencia = 120 pasos")
	reference.world.run_steps(120)
	for i in range(later.world.provinces.size()):
		assert_eq(snapshot(later.world.provinces[i]), snapshot(reference.world.provinces[i]), "mismo resultado que jugar (%s)" % later.world.provinces[i].id)
	assert_eq(later.world.step_count, 130, "10 jugados + 120 ausentes")
	done()


func test_resume_applies_the_pause_once() -> void:
	_clean()
	var s = _session()
	s.start(T0)
	s.save(T0 + 100)
	var report: Dictionary = s.resume(T0 + 100 + 3600)
	assert_eq(report["steps"], 60, "1 h de pausa = 60 pasos")
	var again: Dictionary = s.resume(T0 + 100 + 3600)
	assert_eq(again["steps"], 0, "reanudar otra vez con la misma hora no añade nada")
	assert_eq(s.world.step_count, 60, "60 pasos en total")
	done()


func test_resume_with_clock_set_back_gives_nothing() -> void:
	_clean()
	var s = _session()
	s.start(T0)
	s.save(T0 + 1000)
	var report: Dictionary = s.resume(T0 + 10)
	assert_eq(report["steps"], 0, "reloj atrasado: sin pasos")
	assert_eq(report["clock_problem"], "clock_went_back", "se avisa")
	assert_eq(s.world.step_count, 0, "el mundo no avanzó")
	done()


func test_broken_save_is_set_aside_not_deleted() -> void:
	_clean()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{\"esto está cortado")
	file.close()
	var s = _session()
	assert_true(s.start(T0), "arranca igualmente")
	assert_eq(s.world.step_count, 0, "partida nueva")
	assert_true("No se pudo leer" in s.notice, "avisa: %s" % s.notice)
	assert_true(not FileAccess.file_exists(PATH), "el archivo dañado ya no ocupa el sitio del guardado")
	var kept := false
	for file_name in DirAccess.open(DIR).get_files():
		if file_name.begins_with("partida.json.danada-"):
			kept = true
			assert_eq(FileAccess.get_file_as_string(DIR + "/" + file_name), "{\"esto está cortado", "se conserva el contenido tal cual")
	assert_true(kept, "hay una copia apartada del archivo dañado")
	done()


func test_damaged_main_falls_back_to_backup_with_a_notice() -> void:
	_clean()
	var s = _session()
	s.start(T0)
	s.world.run_steps(5)
	s.save(T0 + 10)
	s.world.run_steps(5)
	s.save(T0 + 20)
	var broken := FileAccess.open(PATH, FileAccess.WRITE)
	broken.store_string("basura")
	broken.close()
	var again = _session()
	assert_true(again.start(T0 + 20), "arranca con la copia")
	assert_eq(again.world.step_count, 5, "es el guardado anterior (paso 5)")
	assert_true(again.notice != "", "avisa de que usó la copia")
	done()


func test_new_game_replaces_the_world() -> void:
	_clean()
	var s = _session()
	s.start(T0)
	s.world.run_steps(50)
	assert_true(s.new_game(T0 + 99), "partida nueva")
	assert_eq(s.world.step_count, 0, "paso 0 otra vez")
	assert_eq(s.stamp, T0 + 99, "marca actualizada")
	done()


func test_time_text() -> void:
	_clean()
	var s = _session()
	s.start(T0)
	assert_eq(s.time_text(), "Día 1, 00:00", "inicio")
	s.world.run_steps(24 + 5)
	assert_eq(s.time_text(), "Día 2, 05:00", "día 2, hora 5")
	done()
