extends RefCounted
## El mundo de una partida: las provincias y el contador de pasos global.

const ProvinceScript := preload("res://scripts/sim/province.gd")
const Fixed := preload("res://scripts/sim/fixed.gd")

var data = null
var step_count: int = 0
var provinces: Array = []
## Motivo del último error al cargar (vacío si fue bien)
var last_error: String = ""


func _init(game_data) -> void:
	data = game_data


func add_province(province_id: String, province_name: String, population: int):
	var province = ProvinceScript.new(data, province_id, province_name, population)
	provinces.append(province)
	return province


## Devuelve la provincia con ese id, o null si no existe.
func find_province(province_id: String):
	for province in provinces:
		if province.id == province_id:
			return province
	return null


func step() -> void:
	step_count += 1
	for province in provinces:
		province.step()


func run_steps(count: int) -> void:
	for i in range(count):
		step()


## Lista de incoherencias de todas las provincias; vacía si todo es correcto.
func check_invariants() -> Array[String]:
	var problems: Array[String] = []
	for province in provinces:
		for problem in province.check_invariants():
			problems.append("%s: %s" % [province.id, problem])
	return problems


func to_dict() -> Dictionary:
	var list: Array = []
	for province in provinces:
		list.append(province.to_dict())
	return {"step_count": step_count, "provinces": list}


## Carga un estado guardado en este mundo (que debe estar vacío). Si falla devuelve false
## y deja el motivo en `last_error`; entonces este objeto no debe usarse.
func load_dict(raw: Variant) -> bool:
	last_error = ""
	if typeof(raw) != TYPE_DICTIONARY:
		last_error = "el mundo guardado no es un objeto"
		return false
	var steps = Fixed.exact_int(raw.get("step_count", null))
	if steps == null or steps < 0:
		last_error = "mundo: step_count no válido"
		return false
	var list = raw.get("provinces", null)
	if typeof(list) != TYPE_ARRAY or list.is_empty():
		last_error = "mundo: falta la lista de provincias"
		return false
	var loaded: Array = []
	var seen := {}
	for entry in list:
		var province = ProvinceScript.new(data, "pendiente", "pendiente", 1)
		if not province.load_dict(entry):
			last_error = province.last_error
			return false
		if seen.has(province.id):
			last_error = "mundo: provincia repetida (%s)" % province.id
			return false
		seen[province.id] = true
		loaded.append(province)
	provinces = loaded
	step_count = steps
	return true
