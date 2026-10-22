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
const DEFAULT_SEASONS_PATH := "res://data/seasons.json"

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
## heating_per_person: leña por persona y paso en invierno (0 = sin necesidad de calefacción);
## cold_warning_steps, cold_unrest_rise y cold_unrest_limit: escasez de leña gradual (sube el descontento hasta un
## tope, 0 = hasta el máximo; no hay muertes);
## upgrade_cost_percent y upgrade_steps_percent: coste y duración de una mejora en % de los de construcción
## (0 = no se puede mejorar); upgrade_output_percent y upgrade_upkeep_percent: aumento por nivel de la
## producción y del mantenimiento en %.
## recruits_per_barracks: soldados que aloja cada cuartel (0 = no hace falta cuartel);
## recruit_weapons: armas (milésimas) que gasta cada recluta; recruit_upkeep: moneda por soldado y paso.
const RULE_OPTIONAL_INTS := {
	"recruits_per_barracks": [0, 100000],
	"recruit_weapons": [0, 100000000],
	"recruit_upkeep": [0, 1000000],
	"calendar_start_year": [0, 9999],
	"calendar_start_day": [0, 364],
	"heating_per_person": [0, 100000],
	"cold_warning_steps": [0, 1000000],
	"cold_unrest_rise": [0, 1000000],
	"cold_unrest_limit": [0, 1000000],
	"upgrade_cost_percent": [0, 10000],
	"upgrade_steps_percent": [0, 10000],
	"upgrade_output_percent": [0, 1000],
	"upgrade_upkeep_percent": [0, 1000],
	"trade_interval": [0, 100000],
	"trade_deficit_percent": [0, 100],
	"trade_target_percent": [0, 100],
	"trade_surplus_percent": [0, 100],
	"trade_steps_per_hop": [0, 100000],
	"trade_cost_per_unit_hop": [0, 1000000],
	"trade_route_cap": [0, 1000000000],
	"trade_max_shipments": [0, 100000],
	"war_march_steps_per_hop": [0, 100000],
	"war_attack_percent": [0, 10000],
	"war_defense_percent": [0, 10000],
	"war_militia_percent": [0, 100],
	"war_round_loss_percent": [0, 100],
	"war_max_rounds": [0, 100000],
	"war_conquest_unrest": [0, 1000000],
	"war_admin_cost": [0, 100000000],
	"war_ai_interval": [0, 1000000],
	"war_ai_start_steps": [0, 100000000],
	"war_ai_levy_per_day": [0, 1000],
	"war_ai_levy_target_percent": [0, 100],
	"war_ai_min_soldiers": [0, 100000],
	"war_ai_ratio_percent": [0, 100000],
	"war_ai_keep_percent": [0, 99],
	"war_wall_cap_percent": [0, 10000],
}

## Mercancías por id: id -> {id, name, category, unit, physical}
var goods: Dictionary = {}
## Edificios por id: id -> campos normalizados (cantidades como enteros)
var buildings: Dictionary = {}
## Estacionalidad de cultivos: id de mercancía -> 12 porcentajes (enero a diciembre). Vacío = sin estaciones.
var seasons: Dictionary = {}
## Reglas de juego normalizadas (enteros) más "currency" y "food_goods"
var rules: Dictionary = {}
## Errores acumulados de la última carga o validación
var errors: Array[String] = []

var _id_regex := RegEx.new()


func _init() -> void:
	_id_regex.compile("^[a-z][a-z0-9_]*$")


## Carga los archivos estándar del juego (mercancías, edificios y reglas).
func load_defaults() -> bool:
	return load_files(DEFAULT_GOODS_PATH, DEFAULT_BUILDINGS_PATH, DEFAULT_RULES_PATH, DEFAULT_SEASONS_PATH)


## Carga los archivos. Si `rules_path` está vacío no se cargan reglas.
## Devuelve true si todo es válido; si no, deja los motivos en `errors`.
func load_files(goods_path: String, buildings_path: String, rules_path: String = "", seasons_path: String = "") -> bool:
	goods = {}
	buildings = {}
	rules = {}
	seasons = {}
	errors = []
	var goods_root = _read_json_file(goods_path)
	var buildings_root = _read_json_file(buildings_path)
	var rules_root = null
	if rules_path != "":
		rules_root = _read_json_file(rules_path)
	var seasons_root = null
	if seasons_path != "":
		seasons_root = _read_json_file(seasons_path)
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
	if rules_path != "" and not build_rules(rules_object):
		return false
	if seasons_path != "":
		var crops: Dictionary = extract_object(seasons_root, "crops", seasons_path)
		if not errors.is_empty():
			return false
		return build_seasons(crops)
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
		if not RULE_INTS.has(key) and not RULE_OPTIONAL_INTS.has(key) and key != "currency" and key != "food_goods" and key != "trade_goods":
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
	# Red de distribución dentro de cada reino (docs/DISENO_COMERCIO.md). trade_interval 0 = sin comercio.
	var trade_list: Array = []
	var trade_raw = raw.get("trade_goods", [])
	if typeof(trade_raw) != TYPE_ARRAY:
		errors.append("regla \"trade_goods\": debe ser una lista de mercancías")
	else:
		for good in trade_raw:
			if typeof(good) != TYPE_STRING or not goods.has(good) or not goods[good]["physical"]:
				errors.append("regla \"trade_goods\": %s no es una mercancía física existente" % str(good))
			elif trade_list.has(good):
				errors.append("regla \"trade_goods\": mercancía repetida (%s)" % good)
			else:
				trade_list.append(good)
	if errors.size() == before and int(result.get("war_march_steps_per_hop", 0)) > 0:
		if result["war_attack_percent"] < 1 or result["war_defense_percent"] < 1 or result["war_round_loss_percent"] < 1 or result["war_max_rounds"] < 1:
			errors.append("reglas de guerra: ataque, defensa, bajas por ronda y rondas máximas deben ser al menos 1")
		elif int(result.get("war_ai_interval", 0)) > 0 and (result["war_ai_ratio_percent"] < 1 or result["war_ai_min_soldiers"] < 1 or result["war_ai_interval"] < 2):
			errors.append("reglas de la IA rival: relación mínima y soldados mínimos al menos 1 e intervalo al menos 2")
		elif result["war_conquest_unrest"] > int(result.get("unrest_max", 0)):
			errors.append("regla \"war_conquest_unrest\": no puede pasar de unrest_max")
	if errors.size() == before and int(result.get("trade_interval", 0)) > 0:
		var tr: Dictionary = result
		if trade_list.is_empty():
			errors.append("regla \"trade_goods\": con comercio activo debe haber al menos una mercancía")
		elif not (tr["trade_deficit_percent"] < tr["trade_target_percent"] and tr["trade_target_percent"] < tr["trade_surplus_percent"]):
			errors.append("reglas de comercio: deficit < objetivo < excedente (en porcentaje)")
		elif tr["trade_steps_per_hop"] < 1 or tr["trade_route_cap"] < 1 or tr["trade_max_shipments"] < 1:
			errors.append("reglas de comercio: pasos por salto, tope de ruta y máximo de envíos deben ser al menos 1")
	if errors.size() == before:
		if result["unrest_slow_threshold"] >= result["unrest_max"]:
			errors.append("regla \"unrest_slow_threshold\": debe ser menor que unrest_max")
		else:
			result["food_goods"] = food_list
			result["trade_goods"] = trade_list
			rules = result
	return errors.size() == before


## Valida la estacionalidad (necesita `goods` ya cargado): cada cultivo es una mercancía física con
## 12 porcentajes enteros entre 0 y 1000 (enero a diciembre).
func build_seasons(raw: Dictionary) -> bool:
	var before := errors.size()
	var result := {}
	for good_id in raw.keys():
		var where := "estaciones \"%s\"" % str(good_id)
		if not goods.has(good_id) or not goods[good_id]["physical"]:
			errors.append("%s: debe ser una mercancía física existente" % where)
			continue
		var list = raw[good_id]
		if typeof(list) != TYPE_ARRAY or list.size() != 12:
			errors.append("%s: debe ser una lista de 12 porcentajes (enero a diciembre)" % where)
			continue
		var parsed: Array[int] = []
		var good_ok := true
		for value in list:
			if not _is_integer_number(value) or int(value) < 0 or int(value) > 1000:
				errors.append("%s: cada porcentaje debe ser un entero entre 0 y 1000" % where)
				good_ok = false
				break
			parsed.append(int(value))
		if good_ok:
			result[good_id] = parsed
	if errors.size() == before:
		seasons = result
	return errors.size() == before


## Porcentaje de producción de una mercancía en un mes (0 a 11); 100 si no tiene estacionalidad.
func season_percent(good_id: String, month: int) -> int:
	if not seasons.has(good_id):
		return 100
	return seasons[good_id][clampi(month, 0, 11)]


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
		var max_level = 1
		if entry.has("max_level"):
			max_level = _int_field(entry, "max_level", 1, where)
			if max_level != null and max_level > 3:
				errors.append("%s: \"max_level\" no puede pasar de 3" % where)
				max_level = null
		var defense_percent = 0
		if entry.has("defense_percent"):
			defense_percent = _int_field(entry, "defense_percent", 0, where)
			if defense_percent != null and defense_percent > 1000:
				errors.append("%s: \"defense_percent\" no puede pasar de 1000" % where)
				defense_percent = null
		var build_cost = _amount_map(entry, "build_cost", where, false)
		var inputs = _amount_map(entry, "inputs", where, true)
		var outputs = _amount_map(entry, "outputs", where, true)
		var upkeep = _amount_map(entry, "upkeep", where, true)
		var parsed := [workers, build_workers, build_steps, cycle_steps, storage_capacity, housing, max_level, defense_percent, build_cost, inputs, outputs, upkeep]
		if parsed.has(null):
			ok = false
		elif not inputs.is_empty() and outputs.is_empty():
			errors.append("%s: consume insumos pero no produce nada" % where)
			ok = false
		elif max_level > 1 and outputs.is_empty():
			errors.append("%s: no produce nada, así que no puede tener mejoras (max_level)" % where)
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
				"max_level": max_level,
				"defense_percent": defense_percent,
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
