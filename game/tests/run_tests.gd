extends SceneTree
## Ejecutor de pruebas nativo, sin bibliotecas externas.
##
## Uso (sin ventana):
##   godot --headless --path game -s res://tests/run_tests.gd
##
## Con "-- --selftest-fail" añade una prueba que falla a propósito, para comprobar
## que el ejecutor detecta fallos. Devuelve 0 si todo pasa y 1 si algo falla
## o si no se ejecutó ninguna prueba.

const TEST_FILES: Array[String] = [
	"res://tests/test_smoke.gd",
	"res://tests/test_game_data.gd",
	"res://tests/test_store.gd",
	"res://tests/test_population.gd",
	"res://tests/test_production.gd",
	"res://tests/test_construction.gd",
	"res://tests/test_scarcity.gd",
	"res://tests/test_long_run.gd",
]
const SELFTEST_FILE := "res://tests/selftest_fail.gd"


func _init() -> void:
	var files: Array[String] = []
	files.append_array(TEST_FILES)
	if "--selftest-fail" in OS.get_cmdline_user_args():
		files.append(SELFTEST_FILE)

	var total := 0
	var failed := 0
	for path in files:
		var script = load(path)
		if script == null:
			# Un archivo que no compila cuenta como fallo, no como "cero pruebas".
			total += 1
			failed += 1
			printerr("FALLO %s: no se pudo cargar el archivo (error de sintaxis o ruta)" % path.get_file())
			continue
		var test_case = script.new()
		for method in test_case.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			test_case.failures.clear()
			test_case.finished = false
			test_case.call(method_name)
			if test_case.failures.is_empty() and test_case.finished:
				print("OK    %s::%s" % [path.get_file(), method_name])
			elif test_case.failures.is_empty():
				failed += 1
				printerr("FALLO %s::%s: la prueba no llegó al final (error de ejecución; ver SCRIPT ERROR en el registro)" % [path.get_file(), method_name])
			else:
				failed += 1
				for failure in test_case.failures:
					printerr("FALLO %s::%s: %s" % [path.get_file(), method_name, failure])

	print("Pruebas: %d, fallos: %d" % [total, failed])
	if total == 0:
		printerr("No se ejecutó ninguna prueba.")
	quit(1 if (failed > 0 or total == 0) else 0)
