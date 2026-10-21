extends RefCounted
## Carga y validación de los datos de juego (mercancías y edificios).
##
## Las cantidades son enteros en milésimas de unidad (1 unidad = 1000), para que
## la economía sea exacta y la conservación de recursos se pueda comprobar sin
## errores de redondeo. Los valores de los archivos de datos son parámetros de
## juego provisionales, no datos históricos.

const SUPPORTED_FORMAT_VERSION := 1
const GOODS_CATEGORIES: Array[String] = ["food", "forestry", "manufactured", "institutional"]
const BUILDING_CATEGORIES: Array[String] = ["residential", "agricultural", "storage", "forestry", "industrial"]

## Mercancías por id: id -> {id, name, category, unit, physical}
var goods: Dictionary = {}
## Edificios por id: id -> campos normalizados (cantidades como enteros)
var buildings: Dictionary = {}
## Errores acumulados de la última carga o validación
var errors: Array[String] = []

var _id_regex := RegEx.new()


func _init() -> void:
	_id_regex.compile("^[a-z][a-z0-9_]*$")


## Carga los dos archivos. Devuelve true si todo es válido; si no, deja los motivos en `errors`.
func load_files(goods_path: String, buildings_path: String) -> bool:
	goods = {}
	buildings = {}
	errors = []
	var goods_root = _read_json_file(goods_path)
	var buildings_root = _read_json_file(buildings_path)
	if not errors.is_empty():
		return false
	var goods_list: Array = extract_list(goods_root, "goods", goods_path)
	var buildings_list: Array = extract_list(buildings_root, "buildings", buildings_path)
	if not errors.is_empty():
		return false
	if not build_goods(goods_list):
		return false
	return build_buildings(buildings_list)


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
		if ok:
			goods[id] = {
				"id": id,
				"name": entry["name"],
				"category": category,
				"unit": entry["unit"],
				"physical": entry["physical"],
			}
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
		var build_steps = _int_field(entry, "build_steps", 1, where)
		var cycle_steps = _int_field(entry, "cycle_steps", 1, where)
		var storage_capacity = _int_field(entry, "storage_capacity", 0, where)
		var housing = _int_field(entry, "housing", 0, where)
		var build_cost = _amount_map(entry, "build_cost", where, false)
		var inputs = _amount_map(entry, "inputs", where, true)
		var outputs = _amount_map(entry, "outputs", where, true)
		var upkeep = _amount_map(entry, "upkeep", where, true)
		var parsed := [workers, build_steps, cycle_steps, storage_capacity, housing, build_cost, inputs, outputs, upkeep]
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
