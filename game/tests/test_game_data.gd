extends "res://tests/test_case.gd"
## Pruebas de la carga y validación de datos (tarea 1.1).

const GAME_DATA := "res://scripts/sim/game_data.gd"
const GOODS_PATH := "res://data/goods.json"
const BUILDINGS_PATH := "res://data/buildings.json"


func _new_data():
	return load(GAME_DATA).new()


func _good(id: String) -> Dictionary:
	return {"id": id, "name": id, "category": "food", "unit": "unidad", "physical": true}


func _data_with_goods(ids: Array):
	var data = _new_data()
	var list: Array = []
	for id in ids:
		list.append(_good(id))
	data.build_goods(list)
	return data


func _building(id: String) -> Dictionary:
	return {
		"id": id, "name": id, "category": "agricultural", "workers": 1,
		"build_cost": {"wheat": 1000}, "build_steps": 2,
		"inputs": {}, "outputs": {"wheat": 1000}, "cycle_steps": 3, "upkeep": {},
		"storage_capacity": 0, "housing": 0,
	}


func _errors_text(data) -> String:
	return "\n".join(data.errors)


func test_real_files_load_without_errors() -> void:
	var data = _new_data()
	var ok: bool = data.load_files(GOODS_PATH, BUILDINGS_PATH)
	assert_true(ok, "los archivos reales deben cargarse: %s" % _errors_text(data))
	assert_eq(data.goods.size(), 6, "número de mercancías del prototipo")
	assert_eq(data.buildings.size(), 6, "número de edificios del prototipo")
	done()


func test_prototype_ids_are_stable() -> void:
	var data = _new_data()
	data.load_files(GOODS_PATH, BUILDINGS_PATH)
	for id in ["wheat", "flour", "bread", "wood", "firewood", "coin"]:
		assert_true(data.goods.has(id), "falta la mercancía \"%s\"" % id)
	for id in ["house", "granary", "farm", "mill", "bakery", "woodcutter"]:
		assert_true(data.buildings.has(id), "falta el edificio \"%s\"" % id)
	done()


func test_coin_is_not_physical_and_wheat_is() -> void:
	var data = _new_data()
	data.load_files(GOODS_PATH, BUILDINGS_PATH)
	assert_true(not data.is_physical("coin"), "la moneda no ocupa espacio")
	assert_true(data.is_physical("wheat"), "el trigo ocupa espacio")
	assert_true(not data.is_physical("no_existe"), "una mercancía desconocida no es física")
	done()


func test_real_buildings_have_integer_amounts() -> void:
	var data = _new_data()
	data.load_files(GOODS_PATH, BUILDINGS_PATH)
	var bakery: Dictionary = data.buildings["bakery"]
	assert_eq(typeof(bakery["outputs"]["bread"]), TYPE_INT, "las cantidades se guardan como enteros")
	assert_eq(bakery["inputs"]["flour"], 3000, "insumo de harina de la panadería")
	assert_eq(bakery["cycle_steps"], 4, "ciclo de la panadería")
	done()


func test_every_good_in_buildings_exists() -> void:
	var data = _new_data()
	data.load_files(GOODS_PATH, BUILDINGS_PATH)
	for building_id in data.buildings.keys():
		var building: Dictionary = data.buildings[building_id]
		for field in ["build_cost", "inputs", "outputs", "upkeep"]:
			for good_id in building[field].keys():
				assert_true(data.goods.has(good_id), "%s.%s usa una mercancía inexistente: %s" % [building_id, field, good_id])
	done()


func test_invalid_json_is_reported() -> void:
	var data = _new_data()
	var result = data.parse_json_text("{\"goods\": [", "prueba.json")
	assert_true(result == null, "un JSON roto no devuelve datos")
	assert_eq(data.errors.size(), 1, "se anota un error")
	assert_true(_errors_text(data).contains("prueba.json"), "el error nombra el archivo")
	done()


func test_missing_file_is_reported() -> void:
	var data = _new_data()
	var ok: bool = data.load_files("res://data/no_existe.json", BUILDINGS_PATH)
	assert_true(not ok, "un archivo ausente no se carga")
	assert_true(not data.errors.is_empty(), "queda un motivo anotado")
	done()


func test_wrong_format_version_is_rejected() -> void:
	var data = _new_data()
	var list: Array = data.extract_list({"format_version": 2, "goods": []}, "goods", "x.json")
	assert_eq(list.size(), 0, "no devuelve lista")
	assert_true(_errors_text(data).contains("format_version"), "el error menciona format_version")
	done()


func test_missing_list_is_rejected() -> void:
	var data = _new_data()
	data.extract_list({"format_version": 1}, "goods", "x.json")
	assert_true(_errors_text(data).contains("goods"), "el error menciona la lista ausente")
	done()


func test_duplicate_good_id_is_rejected() -> void:
	var data = _new_data()
	var ok: bool = data.build_goods([_good("wheat"), _good("wheat")])
	assert_true(not ok, "un id repetido no es válido")
	assert_true(_errors_text(data).contains("repetido"), "el error dice que está repetido")
	done()


func test_invalid_id_format_is_rejected() -> void:
	var data = _new_data()
	var ok: bool = data.build_goods([_good("Trigo"), _good("2trigo"), _good("trigo-1")])
	assert_true(not ok, "ids con mayúsculas, número inicial o guion no son válidos")
	assert_eq(data.goods.size(), 0, "ninguna entra")
	done()


func test_unknown_category_is_rejected() -> void:
	var data = _new_data()
	var good := _good("wheat")
	good["category"] = "magia"
	assert_true(not data.build_goods([good]), "categoría desconocida")
	done()


func test_physical_must_be_boolean() -> void:
	var data = _new_data()
	var good := _good("wheat")
	good["physical"] = "si"
	assert_true(not data.build_goods([good]), "physical debe ser booleano")
	done()


func test_valid_building_is_accepted() -> void:
	var data = _data_with_goods(["wheat"])
	var ok: bool = data.build_buildings([_building("farm")])
	assert_true(ok, "edificio válido: %s" % _errors_text(data))
	assert_true(data.buildings.has("farm"), "queda registrado")
	done()


func test_unknown_good_in_building_is_rejected() -> void:
	var data = _data_with_goods(["wheat"])
	var building := _building("farm")
	building["outputs"] = {"oro": 1000}
	assert_true(not data.build_buildings([building]), "mercancía desconocida")
	assert_true(_errors_text(data).contains("oro"), "el error nombra la mercancía")
	done()


func test_non_positive_amount_is_rejected() -> void:
	var data = _data_with_goods(["wheat"])
	var building := _building("farm")
	building["outputs"] = {"wheat": 0}
	assert_true(not data.build_buildings([building]), "cantidad cero no válida")
	building["outputs"] = {"wheat": -5}
	assert_true(not data.build_buildings([building]), "cantidad negativa no válida")
	done()


func test_fractional_amount_is_rejected() -> void:
	var data = _data_with_goods(["wheat"])
	var building := _building("farm")
	building["outputs"] = {"wheat": 1.5}
	assert_true(not data.build_buildings([building]), "las cantidades deben ser enteros (milésimas)")
	done()


func test_whole_float_amount_is_accepted_as_integer() -> void:
	var data = _data_with_goods(["wheat"])
	var building := _building("farm")
	building["outputs"] = {"wheat": 2000.0}
	assert_true(data.build_buildings([building]), "JSON entrega 2000 como número decimal entero")
	assert_eq(typeof(data.buildings["farm"]["outputs"]["wheat"]), TYPE_INT, "se normaliza a entero")
	done()


func test_inputs_without_outputs_is_rejected() -> void:
	var data = _data_with_goods(["wheat"])
	var building := _building("mill")
	building["inputs"] = {"wheat": 1000}
	building["outputs"] = {}
	assert_true(not data.build_buildings([building]), "consumir sin producir no es válido")
	done()


func test_empty_build_cost_is_rejected() -> void:
	var data = _data_with_goods(["wheat"])
	var building := _building("farm")
	building["build_cost"] = {}
	assert_true(not data.build_buildings([building]), "construir debe costar algo")
	done()


func test_cycle_steps_must_be_positive() -> void:
	var data = _data_with_goods(["wheat"])
	var building := _building("farm")
	building["cycle_steps"] = 0
	assert_true(not data.build_buildings([building]), "un ciclo de 0 pasos no es válido")
	done()


func test_negative_workers_rejected() -> void:
	var data = _data_with_goods(["wheat"])
	var building := _building("farm")
	building["workers"] = -1
	assert_true(not data.build_buildings([building]), "trabajadores negativos")
	done()


func test_duplicate_building_id_is_rejected() -> void:
	var data = _data_with_goods(["wheat"])
	assert_true(not data.build_buildings([_building("farm"), _building("farm")]), "id de edificio repetido")
	done()


func test_errors_are_cleared_on_new_load() -> void:
	var data = _new_data()
	data.load_files("res://data/no_existe.json", BUILDINGS_PATH)
	assert_true(not data.errors.is_empty(), "primer intento falla")
	var ok: bool = data.load_files(GOODS_PATH, BUILDINGS_PATH)
	assert_true(ok, "segundo intento con archivos buenos funciona")
	assert_true(data.errors.is_empty(), "los errores anteriores se descartan")
	done()
