extends RefCounted
## Carga y validación de los datos de juego (mercancías y edificios).
##
## Las cantidades son enteros en milésimas de unidad (1 unidad = 1000), para que
## la economía sea exacta y la conservación de recursos se pueda comprobar sin
## errores de redondeo. Los valores de los archivos de datos son parámetros de
## juego provisionales, no datos históricos.

const SUPPORTED_FORMAT_VERSION := 1
const GOODS_CATEGORIES: Array[String] = ["food", "forestry", "manufactured", "materials", "institutional"]
const BUILDING_CATEGORIES: Array[String] = ["residential", "agricultural", "storage", "forestry", "industrial", "pastoral", "mining", "commercial", "military"]

const DEFAULT_GOODS_PATH := "res://data/goods.json"
const DEFAULT_BUILDINGS_PATH := "res://data/buildings.json"
const DEFAULT_RULES_PATH := "res://data/rules.json"

## Reglas numéricas (entero obligatorio): nombre -> [mínimo, máximo]
const RULE_INTS := {
	"base_capacity": [0, 100000000],
	"base_housing": [0, 1000000],
	"labor_percent": [0, 100],
	"min_population": [1, 1000000],
	"max_projects": [1, 100],
	"max_buildings": [1, 1000],
	"tax_per_person": [0, 1000000],
	"food_per_person": [0, 1000000],
	"hunger_warning_steps": [0, 1000000],
	"starvation_steps": [1, 1000000],
	"starvation_loss_percent": [0, 100],
	"unrest_max": [1, 1000000],
	"unrest_rise": [0, 1000000],
	"unrest_fall": [0, 1000000],
	"unrest_slow_threshold": [0, 1000000],
	"min_productivity_percent": [1, 100],
	"growth_interval": [1, 1000000],
	"growth_percent": [0, 100],
	"growth_unrest_limit": [0, 1000000],
	"step_seconds": [1, 86400],
	"offline_limit_seconds": [0, 172800],
}

## Reglas opcionales (valen 0 si no están): nombre -> [mínimo, máximo].
## calendar_start_year: año de la partida nueva (0 = 1000); calendar_start_day: día del año (0 a 364) de la partida nueva.
## recruits_per_barracks: soldados que aloja cada cuartel (0 = no hace falta cuartel);
## recruit_weapons: armas (milésimas) que gasta cada recluta; recruit_upkeep: moneda por soldado y paso.
const RULE_OPTIONAL_INTS := {
	"recruits_per_barracks": [0, 100000],
	"recruit_weapons": [0, 100000000],
	"recruit_upkeep": [0, 1000000],
	"calendar_start_year": [0, 9999],
	"calendar_start_day": [0, 364],
}

## Mercancías por id: id -> {id, name, category, unit, physical}
var goods: Dictionary = {}
## Edificios por id: id -> campos normalizados (cantidades como enteros)
var buildings: Dictionary = {}
## Reglas de juego normalizadas (enteros) más "currency" y "food_goods"
var rules: Dictionary = {}
## Errores acumulados de la última carga o validación
var errors: Array[String] = []

var _id_regex := RegEx.new()


func _init() -> void:
	_id_regex.compile("^[a-z][a-z0-9_]*$")


## Carga los archivos estándar del juego (mercancías, edificios y reglas).
func load_defaults() -> bool:
	return load_files(DEFAULT_GOODS_PATH, DEFAULT_BUILDINGS_PATH, DEFAULT_RULES_PATH)


## Carga los archivos. Si `rules_path` está vacío no se cargan reglas.
## Devuelve true si todo es válido; si no, deja los motivos en `errors`.
func load_files(goods_path: String, buildings_path: String, rules_path: String = "") -> bool:
	goods = {}
	buildings = {}
	rules = {}
	errors = []
	var goods_root = _read_json_file(goods_path)
	var buildings_root = _read_json_file(buildings_path)
	var rules_root = null
	if rules_path != "":
		rules_root = _read_json_file(rules_path)
	if not errors.is_empty():
		return false
	var goods_list: Array = extract_list(goods_root, "goods", goods_path)
	var buildings_list: Array = extract_list(buildings_root, "buildings", buildings_path)
	var rules_object: Dictionary = {}
	if rules_path != "":
		rules_object = extract_object(rules_root, "rules", rules_path)
	if not errors.is_empty():
		return false
	if not build_goods(goods_list):
		return false
	if not build_buildings(buildings_list):
		return false
	if rules_path != "":
		return build_rules(rules_object)
	return true


## Convierte texto JSON en datos. Devuelve null y anota el error si no es JSON válido.
func parse_json_text(text: String, label: String) -> Variant:
	var json := JSON.new()
	var code := json.parse(text)
	if code != OK:
		errors.append("%s: JSON no válido en la línea %d: %s" % [label, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Comprueba la raíz del archivo (objeto, versión de formato) y devuelve la lista indicada.
func extract_list(root: Variant, key: String, label: String) -> Array:
	if typeof(root) != TYPE_DICTIONARY:
		errors.append("%s: la raíz debe ser un objeto" % label)
		return []
	if not _is_integer_number(root.get("format_version", null)) or int(root["format_version"]) != SUPPORTED_FORMAT_VERSION:
		errors.append("%s: format_version debe ser %d" % [label, SUPPORTED_FORMAT_VERSION])
		return []
	var list = root.get(key, null)
	if typeof(list) != TYPE_ARRAY:
		errors.append("%s: falta la lista \"%s\"" % [label, key])
		return []
	return list


## Igual que extract_list, pero devuelve un objeto.
func extract_object(root: Variant, key: String, label: String) -> Dictionary:
	if typeof(root) != TYPE_DICTIONARY:
		errors.append("%s: la raíz debe ser un objeto" % label)
		return {}
	if not _is_integer_number(root.get("format_version", null)) or int(root["format_version"]) != SUPPORTED_FORMAT_VERSION:
		errors.append("%s: format_version debe ser %d" % [label, SUPPORTED_FORMAT_VERSION])
		return {}
	var obj = root.get(key, null)
	if typeof(obj) != TYPE_DICTIONARY:
		errors.append("%s: falta el objeto \"%s\"" % [label, key])
		return {}
	return obj


## Valida las reglas (necesita `goods` ya cargado) y rellena `rules`.
func build_rules(raw: Dictionary) -> bool:
	var before := errors.size()
	var result := {}
	for key in RULE_INTS.keys():
		var limits: Array = RULE_INTS[key]
		var value = raw.get(key, null)
		if not _is_integer_number(value) or int(value) < limits[0] or int(value) > limits[1]:
			errors.append("regla \"%s\": debe ser un entero entre %d y %d" % [key, limits[0], limits[1]])
			continue
		result[key] = int(value)
	for key in RULE_OPTIONAL_INTS.keys():
		var limits2: Array = RULE_OPTIONAL_INTS[key]
		var value2 = raw.get(key, 0)
		if not _is_integer_number(value2) or int(value2) < limits2[0] or int(value2) > limits2[1]:
			errors.append("regla \"%s\": debe ser un entero entre %d y %d" % [key, limits2[0], limits2[1]])
			continue
		result[key] = int(value2)
	for key in raw.keys():
		if not RULE_INTS.has(key) and not RULE_OPTIONAL_INTS.has(key) and key != "currency" and key != "food_goods":
			errors.append("regla \"%s\": nombre desconocido (¿error de escritura?)" % str(key))
	var currency = raw.get("currency", null)
	if typeof(currency) != TYPE_STRING or not goods.has(currency):
		errors.append("regla \"currency\": debe ser el id de una mercancía existente")
	elif goods[currency]["physical"]:
		errors.append("regla \"currency\": la moneda no puede ser una mercancía física")
	else:
		result["currency"] = currency
	var food = raw.get("food_goods", null)
	var food_list: Array = []
	if typeof(food) != TYPE_ARRAY or food.is_empty():
		errors.append("regla \"food_goods\": debe ser una lista no vacía de {good, value}")
	else:
		var seen := {}
		for i in range(food.size()):
			var item = food[i]
			var where := "regla \"food_goods\" #%d" % (i + 1)
			if typeof(item) != TYPE_DICTIONARY:
				errors.append("%s: debe ser un objeto" % where)
				continue
			var good = item.get("good", null)
			if typeof(good) != TYPE_STRING or not goods.has(good):
				errors.append("%s: mercancía desconocida" % where)
				continue
			if not goods[good]["physical"]:
				errors.append("%s: el alimento debe ser una mercancía física" % where)
				continue
			if seen.has(good):
				errors.append("%s: mercancía repetida (%s)" % [where, good])
				continue
			seen[good] = true
			var value = item.get("value", null)
			if not _is_integer_number(value) or int(value) <= 0:
				errors.append("%s: \"value\" debe ser un entero positivo" % where)
				continue
			food_list.append({"good": good, "value": int(value)})
	if errors.size() == before:
		if result["unrest_slow_threshold"] >= result["unrest_max"]:
			errors.append("regla \"unrest_slow_threshold\": debe ser menor que unrest_max")
		else:
			result["food_goods"] = food_list
			rules = result
	return errors.size() == before


## Valida la lista de mercancías y rellena `goods`. Devuelve true si no hubo errores nuevos.
func build_goods(list: Array) -> bool:
	var before := errors.size()
	var seen := {}
	for i in range(list.size()):
		var entry = list[i]
		var where := "mercancía #%d" % (i + 1)
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("%s: debe ser un objeto" % where)
			continue
		var id = entry.get("id", null)
		if not _is_valid_id(id):
			errors.append("%s: id ausente o no válido (minúsculas, números y guion bajo)" % where)
			continue
		where = "mercancía \"%s\"" % id
		if seen.has(id):
			errors.append("%s: id repetido" % where)
			continue
		seen[id] = true
		var ok := true
		for field in ["name", "unit"]:
			if not _is_non_empty_string(entry.get(field, null)):
				errors.append("%s: falta el texto \"%s\"" % [where, field])
				ok = false
		var category = entry.get("category", null)
		if typeof(category) != TYPE_STRING or not GOODS_CATEGORIES.has(category):
			errors.append("%s: categoría no válida (%s)" % [where, _join(GOODS_CATEGORIES)])
			ok = false
		if typeof(entry.get("physical", null)) != TYPE_BOOL:
			errors.append("%s: \"physical\" debe ser verdadero o falso" % where)
			ok = false
		var share = entry.get("storage_share_percent", null)
		if not _is_integer_number(share) or int(share) < 0 or int(share) > 100:
			errors.append("%s: \"storage_share_percent\" debe ser un entero entre 0 y 100" % where)
			ok = false
		if ok:
			goods[id] = {
				"id": id,
				"name": entry["name"],
				"category": category,
				"unit": entry["unit"],
				"physical": entry["physical"],
				"share": int(share),
			}
	if errors.size() == before:
		var total := 0
		for good_id in goods.keys():
			if goods[good_id]["physical"]:
				total += goods[good_id]["share"]
		if total > 100:
			errors.append("mercancías: la suma de storage_share_percent de las físicas es %d y no puede pasar de 100" % total)
	return errors.size() == before


## Valida la lista de edificios (necesita `goods` ya cargado) y rellena `buildings`.
func build_buildings(list: Array) -> bool:
	var before := errors.size()
	var seen := {}
	for i in range(list.size()):
		var entry = list[i]
		var where := "edificio #%d" % (i + 1)
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("%s: debe ser un objeto" % where)
			continue
		var id = entry.get("id", null)
		if not _is_valid_id(id):
			errors.append("%s: id ausente o no válido (minúsculas, números y guion bajo)" % where)
			continue
		where = "edificio \"%s\"" % id
		if seen.has(id):
			errors.append("%s: id repetido" % where)
			continue
		seen[id] = true
		var ok := true
		if not _is_non_empty_string(entry.get("name", null)):
			errors.append("%s: falta el texto \"name\"" % where)
			ok = false
		var category = entry.get("category", null)
		if typeof(category) != TYPE_STRING or not BUILDING_CATEGORIES.has(category):
			errors.append("%s: categoría no válida (%s)" % [where, _join(BUILDING_CATEGORIES)])
			ok = false
		var workers = _int_field(entry, "workers", 0, where)
		var build_workers = _int_field(entry, "build_workers", 0, where)
		var build_steps = _int_field(entry, "build_steps", 1, where)
		var cycle_steps = _int_field(entry, "cycle_steps", 1, where)
		var storage_capacity = _int_field(entry, "storage_capacity", 0, where)
		var housing = _int_field(entry, "housing", 0, where)
		var build_cost = _amount_map(entry, "build_cost", where, false)
		var inputs = _amount_map(entry, "inputs", where, true)
		var outputs = _amount_map(entry, "outputs", where, true)
		var upkeep = _amount_map(entry, "upkeep", where, true)
		var parsed := [workers, build_workers, build_steps, cycle_steps, storage_capacity, housing, build_cost, inputs, outputs, upkeep]
		if parsed.has(null):
			ok = false
		elif not inputs.is_empty() and outputs.is_empty():
			errors.append("%s: consume insumos pero no produce nada" % where)
			ok = false
		if ok:
			buildings[id] = {
				"id": id,
				"name": entry["name"],
				"category": category,
				"workers": workers,
				"build_workers": build_workers,
				"build_cost": build_cost,
				"build_steps": build_steps,
				"inputs": inputs,
				"outputs": outputs,
				"cycle_steps": cycle_steps,
				"upkeep": upkeep,
				"storage_capacity": storage_capacity,
				"housing": housing,
			}
	return errors.size() == before


func is_physical(good_id: String) -> bool:
	return goods.has(good_id) and goods[good_id]["physical"]


func _read_json_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("%s: no se pudo abrir el archivo (código %d)" % [path, FileAccess.get_open_error()])
		return null
	return parse_json_text(file.get_as_text(), path)


func _int_field(entry: Dictionary, field: String, min_value: int, where: String) -> Variant:
	var raw = entry.get(field, null)
	if not _is_integer_number(raw) or int(raw) < min_value:
		errors.append("%s: \"%s\" debe ser un entero mayor o igual que %d" % [where, field, min_value])
		return null
	return int(raw)


func _amount_map(entry: Dictionary, field: String, where: String, allow_empty: bool) -> Variant:
	var raw = entry.get(field, null)
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("%s: \"%s\" debe ser un objeto {mercancía: cantidad}" % [where, field])
		return null
	var result := {}
	var ok := true
	for good_id in raw.keys():
		if not goods.has(good_id):
			errors.append("%s: \"%s\" usa una mercancía desconocida: \"%s\"" % [where, field, str(good_id)])
			ok = false
			continue
		var amount = raw[good_id]
		if not _is_integer_number(amount) or int(amount) <= 0:
			errors.append("%s: \"%s\" de \"%s\" debe ser un entero positivo (milésimas)" % [where, field, str(good_id)])
			ok = false
			continue
		result[good_id] = int(amount)
	if raw.is_empty() and not allow_empty:
		errors.append("%s: \"%s\" no puede estar vacío" % [where, field])
		ok = false
	if ok:
		return result
	return null


func _is_integer_number(value: Variant) -> bool:
	var kind := typeof(value)
	if kind == TYPE_INT:
		return true
	if kind == TYPE_FLOAT:
		return value == floor(value)
	return false


func _is_valid_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and _id_regex.search(value) != null


func _is_non_empty_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and String(value).strip_edges() != ""


func _join(items: Array) -> String:
	var text := ""
	for i in range(items.size()):
		if i > 0:
			text += ", "
		text += str(items[i])
	return text
