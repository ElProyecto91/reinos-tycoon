extends "res://tests/province_case.gd"
## Guardado y carga con versión de formato (tarea 1.7; criterio A8).

const SAVE_GAME := "res://scripts/sim/save_game.gd"
const WORLD := "res://scripts/sim/world.gd"
const TEST_DIR := "user://pruebas_guardado"
const VERSION := "0.0.test"


## Mundo de dos provincias a mitad de partida: obras en curso, un efecto activo y pérdidas.
func _busy_world(data):
	var world = load(WORLD).new(data)
	var a = world.add_province("prueba_a", "Provincia de prueba A", 100)
	for type_id in ["granary", "farm", "farm", "mill", "bakery", "woodcutter"]:
		a.add_building(type_id)
	a.store.seed_initial("bread", 30000)
	a.store.seed_initial("wheat", 6000)
	a.store.seed_initial("firewood", 5000)
	a.store.seed_initial("wood", 9000)
	a.store.seed_initial("coin", 20000)
	var b = world.add_province("prueba_b", "Provincia de prueba B", 60)
	b.add_building("farm")
	b.store.seed_initial("bread", 6000)
	b.store.seed_initial("coin", 5000)
	world.run_steps(30)
	a.start_construction("house")
	a.start_construction("granary")
	a.add_modifier("wheat", 50, 40)
	b.recruit(5)
	world.run_steps(3)
	return world


func _world_snapshot(world) -> String:
	var parts: Array[String] = [str(world.step_count)]
	for province in world.provinces:
		parts.append(snapshot(province))
	return "\n".join(parts)


func _clean() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_DIR + "/partida.json" + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_round_trip_gives_the_same_state() -> void:
	var data = new_data()
	var world = _busy_world(data)
	assert_true(world.provinces[0].projects.size() == 2, "la prueba parte de dos obras en curso")
	var text: String = load(SAVE_GAME).encode(world, VERSION)
	var result: Dictionary = load(SAVE_GAME).decode(new_data(), text)
	assert_true(result["ok"], "debe cargar: %s" % result["error"])
	assert_eq(_world_snapshot(result["world"]), _world_snapshot(world), "el estado cargado es idéntico")
	assert_eq(result["game_version"], VERSION, "se conserva la versión del juego")
	done()


func test_loaded_state_keeps_simulating_identically() -> void:
	var data = new_data()
	var world = _busy_world(data)
	var text: String = load(SAVE_GAME).encode(world, VERSION)
	var result: Dictionary = load(SAVE_GAME).decode(new_data(), text)
	assert_true(result["ok"], "debe cargar: %s" % result["error"])
	var loaded = result["world"]
	world.run_steps(300)
	loaded.run_steps(300)
	assert_eq(_world_snapshot(loaded), _world_snapshot(world), "tras 300 pasos más siguen iguales")
	assert_true(loaded.check_invariants().is_empty(), "coherente: %s" % str(loaded.check_invariants()))
	done()


func test_loaded_numbers_are_integers() -> void:
	var data = new_data()
	var world = _busy_world(data)
	var result: Dictionary = load(SAVE_GAME).decode(new_data(), load(SAVE_GAME).encode(world, VERSION))
	var province = result["world"].provinces[0]
	assert_eq(typeof(province.population), TYPE_INT, "población")
	assert_eq(typeof(province.unrest), TYPE_INT, "descontento")
	assert_eq(typeof(province.buildings[0]["workers"]), TYPE_INT, "trabajadores")
	assert_eq(typeof(province.projects[0]["remaining"]), TYPE_INT, "tiempo de obra")
	assert_eq(typeof(province.store.stock("wheat")), TYPE_INT, "existencias")
	assert_eq(typeof(province.store.ledger("wheat")["produced"]), TYPE_INT, "libro")
	done()


func test_truncated_text_is_rejected_with_a_message() -> void:
	var data = new_data()
	var text: String = load(SAVE_GAME).encode(_busy_world(data), VERSION)
	var result: Dictionary = load(SAVE_GAME).decode(new_data(), text.substr(0, text.length() / 2))
	assert_true(not result["ok"], "un archivo cortado no se carga")
	assert_true(result["error"] != "", "y explica por qué")
	assert_true(result["world"] == null, "sin mundo a medias")
	done()


func test_tampered_content_is_detected_by_the_checksum() -> void:
	var data = new_data()
	var text: String = load(SAVE_GAME).encode(_busy_world(data), VERSION)
	var tampered := text.replace("\\\"population\\\":100", "\\\"population\\\":999")
	assert_true(tampered != text, "la prueba debe haber cambiado algo")
	var result: Dictionary = load(SAVE_GAME).decode(new_data(), tampered)
	assert_true(not result["ok"], "un guardado alterado no se carga")
	assert_true(result["error"].contains("suma de control"), "el motivo es la suma de control: %s" % result["error"])
	done()


func test_newer_format_version_is_rejected_with_a_message() -> void:
	var data = new_data()
	var world = _busy_world(data)
	var text: String = load(SAVE_GAME).encode(world, VERSION)
	var newer := text.replace("\"format_version\": 1", "\"format_version\": 99")
	assert_true(newer != text, "la prueba debe haber cambiado la versión")
	var result: Dictionary = load(SAVE_GAME).decode(new_data(), newer)
	assert_true(not result["ok"], "una versión futura no se carga")
	assert_true(result["error"].contains("más nueva"), "el motivo habla de versión más nueva: %s" % result["error"])
	done()


func test_invalid_format_version_is_rejected() -> void:
	var data = new_data()
	var text: String = load(SAVE_GAME).encode(_busy_world(data), VERSION)
	var older := text.replace("\"format_version\": 1", "\"format_version\": 0")
	var result: Dictionary = load(SAVE_GAME).decode(new_data(), older)
	assert_true(not result["ok"], "la versión 0 no existe")
	assert_true(result["error"].contains("versión"), "el motivo habla de versión: %s" % result["error"])
	done()


func test_garbage_is_rejected_without_crashing() -> void:
	var data = new_data()
	for text in ["", "no es json", "[]", "{}", "{\"format_version\": 1}", "null", "123"]:
		var result: Dictionary = load(SAVE_GAME).decode(data, text)
		assert_true(not result["ok"], "texto basura rechazado: '%s'" % text)
		assert_true(result["error"] != "", "con motivo: '%s'" % text)
	done()


## Alteraciones del estado (con la suma de control calculada después, o sea, correcta).
const MUTATIONS: Array[String] = [
	"existencias negativas", "mercancía desconocida", "existencias decimales", "libro que no cuadra",
	"edificio desconocido", "demasiados trabajadores", "uid repetido", "población cero",
	"descontento excesivo", "capacidad incoherente", "falta la lista de obras", "obra sin tiempo",
	"provincia repetida", "sin provincias", "paso negativo", "aviso desconocido",
]


func _mutate(d: Dictionary, kind: String) -> void:
	var province: Dictionary = d["provinces"][0]
	match kind:
		"existencias negativas":
			province["store"]["stock"]["wheat"] = -5
		"mercancía desconocida":
			province["store"]["stock"]["oro"] = 5
		"existencias decimales":
			province["store"]["stock"]["wheat"] = 1.5
		"libro que no cuadra":
			province["store"]["stock"]["wheat"] += 7
		"edificio desconocido":
			province["buildings"][1]["type"] = "castillo"
		"demasiados trabajadores":
			province["buildings"][1]["workers"] = 99
		"uid repetido":
			province["buildings"][1]["uid"] = province["buildings"][0]["uid"]
		"población cero":
			province["population"] = 0
		"descontento excesivo":
			province["unrest"] = 5000
		"capacidad incoherente":
			province["store"]["capacity"] = 1
		"falta la lista de obras":
			province.erase("projects")
		"obra sin tiempo":
			province["projects"][0]["remaining"] = 0
		"provincia repetida":
			d["provinces"].append(province.duplicate(true))
		"sin provincias":
			d["provinces"] = []
		"paso negativo":
			d["step_count"] = -1
		"aviso desconocido":
			province["alerts"] = ["no_existe"]


func test_invalid_contents_are_rejected_even_with_a_valid_checksum() -> void:
	for kind in MUTATIONS:
		var data = new_data()
		var payload: Dictionary = _busy_world(data).to_dict()
		_mutate(payload, kind)
		var text: String = load(SAVE_GAME).pack(payload, VERSION)
		var result: Dictionary = load(SAVE_GAME).decode(new_data(), text)
		assert_true(not result["ok"], "debe rechazar: %s" % kind)
		assert_true(result["error"] != "", "y dar un motivo: %s" % kind)
	done()


func test_valid_payload_through_pack_is_accepted() -> void:
	# Comprueba que el ayudante de la prueba anterior no rechaza todo por error.
	var data = new_data()
	var payload: Dictionary = _busy_world(data).to_dict()
	var result: Dictionary = load(SAVE_GAME).decode(new_data(), load(SAVE_GAME).pack(payload, VERSION))
	assert_true(result["ok"], "un estado sin tocar debe cargar: %s" % result["error"])
	done()


func test_file_round_trip() -> void:
	_clean()
	var data = new_data()
	var world = _busy_world(data)
	var path := TEST_DIR + "/partida.json"
	var error: String = load(SAVE_GAME).write_file(world, path, VERSION)
	assert_eq(error, "", "guardar sin errores")
	var result: Dictionary = load(SAVE_GAME).read_file(new_data(), path)
	assert_true(result["ok"], "leer: %s" % result["error"])
	assert_true(not result["used_backup"], "no hizo falta la copia")
	assert_eq(_world_snapshot(result["world"]), _world_snapshot(world), "idéntico tras pasar por archivo")
	assert_true(not FileAccess.file_exists(path + ".tmp"), "no queda archivo temporal")
	_clean()
	done()


func test_missing_file_gives_a_message() -> void:
	_clean()
	var result: Dictionary = load(SAVE_GAME).read_file(new_data(), TEST_DIR + "/partida.json")
	assert_true(not result["ok"], "sin archivo no hay partida")
	assert_true(result["error"] != "", "con motivo")
	done()


func test_interrupted_write_does_not_destroy_a_valid_save() -> void:
	# Criterio A8: un archivo incompleto no destruye un guardado válido.
	_clean()
	var data = new_data()
	var world = _busy_world(data)
	var path := TEST_DIR + "/partida.json"
	assert_eq(load(SAVE_GAME).write_file(world, path, VERSION), "", "primer guardado")
	var before := _world_snapshot(world)
	# Se simula un corte: queda un temporal a medias.
	var text: String = load(SAVE_GAME).encode(world, VERSION)
	var broken := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	broken.store_string(text.substr(0, text.length() / 3))
	broken.close()
	var result: Dictionary = load(SAVE_GAME).read_file(new_data(), path)
	assert_true(result["ok"], "el guardado válido sigue cargando: %s" % result["error"])
	assert_eq(_world_snapshot(result["world"]), before, "y es el mismo estado")
	# Un guardado posterior limpia el temporal y funciona.
	world.run_steps(10)
	assert_eq(load(SAVE_GAME).write_file(world, path, VERSION), "", "guardar otra vez con un temporal viejo")
	_clean()
	done()


func test_corrupted_main_file_falls_back_to_the_previous_save() -> void:
	_clean()
	var data = new_data()
	var world = _busy_world(data)
	var path := TEST_DIR + "/partida.json"
	assert_eq(load(SAVE_GAME).write_file(world, path, VERSION), "", "primer guardado")
	var first := _world_snapshot(world)
	world.run_steps(20)
	assert_eq(load(SAVE_GAME).write_file(world, path, VERSION), "", "segundo guardado")
	var good: Dictionary = load(SAVE_GAME).read_file(new_data(), path)
	assert_true(good["ok"] and not good["used_backup"], "el segundo guardado carga")
	assert_true(FileAccess.file_exists(path + ".bak"), "el primero quedó como copia")
	# Se corrompe el principal.
	var damaged := FileAccess.open(path, FileAccess.WRITE)
	damaged.store_string("{ esto está roto")
	damaged.close()
	var result: Dictionary = load(SAVE_GAME).read_file(new_data(), path)
	assert_true(result["ok"], "se carga la copia anterior: %s" % result["error"])
	assert_true(result["used_backup"], "y se avisa de que se usó la copia")
	assert_true(result["warning"] != "", "con un mensaje")
	assert_eq(_world_snapshot(result["world"]), first, "es el primer guardado")
	_clean()
	done()


func test_both_files_broken_gives_a_clear_error() -> void:
	_clean()
	var path := TEST_DIR + "/partida.json"
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	for suffix in ["", ".bak"]:
		var file := FileAccess.open(path + suffix, FileAccess.WRITE)
		file.store_string("basura")
		file.close()
	var result: Dictionary = load(SAVE_GAME).read_file(new_data(), path)
	assert_true(not result["ok"], "no hay nada que cargar")
	assert_true(result["error"] != "", "con motivo")
	_clean()
	done()
