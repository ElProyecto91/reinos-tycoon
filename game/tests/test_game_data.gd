extends "res://tests/test_case.gd"
## Pruebas de la carga y validación de datos (tarea 1.1).

const GAME_DATA := "res://scripts/sim/game_data.gd"
const GOODS_PATH := "res://data/goods.json"
const BUILDINGS_PATH := "res://data/buildings.json"
const RULES_PATH := "res://data/rules.json"


func _new_data():
	return load(GAME_DATA).new()


func _good(id: String) -> Dictionary:
	return {"id": id, "name": id, "category": "food", "unit": "unidad", "physical": true, "storage_share_percent": 20}


func _data_with_goods(ids: Array):
	var data = _new_data()
	var list: Array = []
	for id in ids:
		list.append(_good(id))
	data.build_goods(list)
	return data


func _building(id: String) -> Dictionary:
	return {
		"id": id, "name": id, "category": "agricultural", "workers": 1, "build_workers": 1,
		"build_cost": {"wheat": 1000}, "build_steps": 2,
		"inputs": {}, "outputs": {"wheat": 1000}, "cycle_steps": 3, "upkeep": {},
		"storage_capacity": 0, "housing": 0,
	}


func _errors_text(data) -> String:
	return "\n".join(data.errors)


func test_real_files_load_without_errors() -> void:
	var data = _new_data()
	var ok: bool = data.load_files(GOODS_PATH, BUILDINGS_PATH, RULES_PATH)
	assert_true(ok, "los archivos reales deben cargarse: %s" % _errors_text(data))
	assert_eq(data.goods.size(), 6, "número de mercancías del prototipo")
	assert_eq(data.buildings.size(), 6, "número de edificios del prototipo")
	assert_eq(data.rules["currency"], "coin", "la moneda de las reglas")
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


func _rules_data():
	var data = _new_data()
	var coin := {"id": "coin", "name": "Moneda", "category": "institutional", "unit": "moneda", "physical": false, "storage_share_percent": 0}
	data.build_goods([_good("wheat"), _good("bread"), coin])
	return data


func _valid_rules() -> Dictionary:
	return {
		"currency": "coin", "base_capacity": 60000, "base_housing": 100, "labor_percent": 50,
		"min_population": 10, "max_projects": 3, "tax_per_person": 8, "food_per_person": 10,
		"food_goods": [{"good": "bread", "value": 1500}, {"good": "wheat", "value": 800}],
		"hunger_warning_steps": 3, "starvation_steps": 24, "starvation_loss_percent": 2,
		"unrest_max": 1000, "unrest_rise": 25, "unrest_fall": 15, "unrest_slow_threshold": 300,
		"min_productivity_percent": 30, "growth_interval": 12, "growth_percent": 2,
		"growth_unrest_limit": 200, "step_seconds": 60, "offline_limit_seconds": 36000,
	}


func test_load_defaults_loads_everything() -> void:
	var data = _new_data()
	assert_true(data.load_defaults(), "load_defaults debe cargar los tres archivos: %s" % _errors_text(data))
	assert_true(not data.rules.is_empty(), "hay reglas")
	assert_eq(data.rules["food_goods"][0]["good"], "bread", "el pan es el alimento preferido")
	assert_eq(typeof(data.rules["labor_percent"]), TYPE_INT, "las reglas son enteros")
	done()


func test_valid_rules_are_accepted() -> void:
	var data = _rules_data()
	assert_true(data.build_rules(_valid_rules()), "reglas válidas: %s" % _errors_text(data))
	assert_eq(data.rules["food_goods"].size(), 2, "dos alimentos")
	done()


func test_missing_rule_is_rejected() -> void:
	var data = _rules_data()
	var rules := _valid_rules()
	rules.erase("labor_percent")
	assert_true(not data.build_rules(rules), "falta una regla")
	assert_true(_errors_text(data).contains("labor_percent"), "el error nombra la regla")
	done()


func test_rule_out_of_range_is_rejected() -> void:
	var data = _rules_data()
	var rules := _valid_rules()
	rules["labor_percent"] = 150
	assert_true(not data.build_rules(rules), "un porcentaje no puede pasar de 100")
	done()


func test_fractional_rule_is_rejected() -> void:
	var data = _rules_data()
	var rules := _valid_rules()
	rules["tax_per_person"] = 2.5
	assert_true(not data.build_rules(rules), "las reglas son enteros")
	done()


func test_unknown_rule_name_is_rejected() -> void:
	var data = _rules_data()
	var rules := _valid_rules()
	rules["labour_percent"] = 50
	assert_true(not data.build_rules(rules), "un nombre desconocido suele ser una errata")
	assert_true(_errors_text(data).contains("labour_percent"), "el error nombra la regla")
	done()


func test_currency_must_exist_and_not_be_physical() -> void:
	var data = _rules_data()
	var rules := _valid_rules()
	rules["currency"] = "wheat"
	assert_true(not data.build_rules(rules), "la moneda no puede ser física")
	rules["currency"] = "oro"
	assert_true(not data.build_rules(rules), "la moneda debe existir")
	done()


func test_food_goods_validation() -> void:
	var data = _rules_data()
	var rules := _valid_rules()
	rules["food_goods"] = []
	assert_true(not data.build_rules(rules), "la lista de alimentos no puede estar vacía")
	rules["food_goods"] = [{"good": "bread", "value": 1500}, {"good": "bread", "value": 900}]
	assert_true(not data.build_rules(rules), "alimento repetido")
	rules["food_goods"] = [{"good": "coin", "value": 1000}]
	assert_true(not data.build_rules(rules), "la moneda no se come")
	rules["food_goods"] = [{"good": "bread", "value": 0}]
	assert_true(not data.build_rules(rules), "el valor nutritivo debe ser positivo")
	done()


func test_unrest_threshold_must_be_below_max() -> void:
	var data = _rules_data()
	var rules := _valid_rules()
	rules["unrest_slow_threshold"] = 1000
	assert_true(not data.build_rules(rules), "el umbral debe ser menor que el máximo")
	done()


func test_building_requires_build_workers() -> void:
	var data = _data_with_goods(["wheat"])
	var building := _building("farm")
	building.erase("build_workers")
	assert_true(not data.build_buildings([building]), "build_workers es obligatorio")
	done()


func test_storage_share_is_required_and_in_range() -> void:
	var data = _new_data()
	var good := _good("wheat")
	good.erase("storage_share_percent")
	assert_true(not data.build_goods([good]), "falta storage_share_percent")
	good["storage_share_percent"] = 101
	assert_true(not data.build_goods([good]), "más de 100")
	good["storage_share_percent"] = -1
	assert_true(not data.build_goods([good]), "negativo")
	good["storage_share_percent"] = 12.5
	assert_true(not data.build_goods([good]), "decimal")
	done()


func test_storage_shares_cannot_add_more_than_100() -> void:
	var data = _new_data()
	var list: Array = []
	for id in ["a", "b", "c", "d", "e", "f"]:
		list.append(_good(id))
	assert_true(not data.build_goods(list), "6 mercancías al 20 % suman 120 %")
	assert_true(_errors_text(data).contains("120"), "el error dice la suma")
	done()


func test_non_physical_goods_do_not_count_for_shares() -> void:
	var data = _new_data()
	var coin := {"id": "coin", "name": "Moneda", "category": "institutional", "unit": "moneda", "physical": false, "storage_share_percent": 100}
	var list: Array = [_good("a"), _good("b"), _good("c"), _good("d"), _good("e"), coin]
	assert_true(data.build_goods(list), "cinco físicas al 20 %% más una moneda: %s" % _errors_text(data))
	done()


func test_real_goods_shares_add_up_to_at_most_100() -> void:
	var data = _new_data()
	data.load_defaults()
	var total := 0
	for good_id in data.goods.keys():
		if data.goods[good_id]["physical"]:
			total += data.goods[good_id]["share"]
	assert_true(total <= 100, "las partes de almacén de las mercancías reales suman %d" % total)
	assert_true(data.goods["wheat"]["share"] > 0, "el trigo tiene parte de almacén")
	done()
