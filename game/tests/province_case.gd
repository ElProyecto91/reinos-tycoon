extends "res://tests/test_case.gd"
## Utilidades comunes para las pruebas de la provincia. No es un archivo de pruebas:
## no está en la lista del ejecutor.

const GAME_DATA := "res://scripts/sim/game_data.gd"
const PROVINCE := "res://scripts/sim/province.gd"


## Datos reales del juego (mercancías, edificios y reglas). Cada prueba carga los suyos
## para poder cambiar una regla sin afectar a las demás.
func new_data():
	var data = load(GAME_DATA).new()
	var ok: bool = data.load_defaults()
	assert_true(ok, "los datos por defecto deben cargarse: %s" % "\n".join(data.errors))
	# Las pruebas de producción comprueban cifras exactas: sin estaciones la cosecha no varía con el mes.
	# Las pruebas de estaciones usan `new_data_with_seasons()`.
	data.seasons = {}
	return data


## Datos reales con la estacionalidad de cultivos activada (seasons.json).
func new_data_with_seasons():
	var data = load(GAME_DATA).new()
	var ok: bool = data.load_defaults()
	assert_true(ok, "los datos por defecto deben cargarse: %s" % "\n".join(data.errors))
	return data


func new_province(data, population: int = 100):
	return load(PROVINCE).new(data, "prueba_a", "Provincia de prueba A", population)


## Provincia con la cadena completa de pan y reservas iniciales (no es un dato histórico).
func chain_province(data, population: int = 100):
	var province = new_province(data, population)
	for type_id in ["granary", "farm", "farm", "mill", "bakery", "woodcutter"]:
		province.add_building(type_id)
	province.store.seed_initial("bread", 30000)
	province.store.seed_initial("wheat", 6000)
	province.store.seed_initial("firewood", 5000)
	province.store.seed_initial("wood", 5000)
	province.store.seed_initial("coin", 10000)
	return province


const MILLI_LEDGER_KEYS: Array[String] = ["initial", "produced", "imported", "consumed", "exported", "lost"]


## Cuenta los valores inválidos del estado: no enteros, negativos o fuera de rango.
func _invalid_values(p, data) -> int:
	var bad := 0
	# Se lee el diccionario interno: stock() devuelve int y ocultaría un decimal.
	var raw_stock: Dictionary = p.store.get("_stock")
	for good_id in data.goods.keys():
		var amount = raw_stock[good_id]
		if typeof(amount) != TYPE_INT or amount < 0:
			bad += 1
		var ledger: Dictionary = p.store.ledger(good_id)
		for key in MILLI_LEDGER_KEYS:
			if typeof(ledger[key]) != TYPE_INT or ledger[key] < 0:
				bad += 1
	for value in [p.population, p.unrest, p.recruits, p.hunger_steps, p.step_count, p.food_shortage_percent]:
		if typeof(value) != TYPE_INT or value < 0:
			bad += 1
	for b in p.buildings:
		for key in ["workers", "progress"]:
			if typeof(b[key]) != TYPE_INT or b[key] < 0:
				bad += 1
	for project in p.projects:
		for key in ["remaining", "workers"]:
			if typeof(project[key]) != TYPE_INT or project[key] < 0:
				bad += 1
	return bad


func run_steps(province, count: int) -> void:
	for i in range(count):
		province.step()


## Estado resumido en texto, ordenado, para comparar dos simulaciones.
func snapshot(province) -> String:
	var stock := {}
	var ledgers := {}
	for good_id in province.store.get("_stock").keys():
		stock[good_id] = province.store.stock(good_id)
		ledgers[good_id] = province.store.ledger(good_id)
	var states: Array = []
	for b in province.buildings:
		states.append([b["uid"], b["type"], b.get("level", 1), b["workers"], b["enabled"], b["active"], b["progress"], b["status"], b["missing"]])
	var state := {
		"id": province.id, "step": province.step_count, "population": province.population,
		"unrest": province.unrest, "hunger": province.hunger_steps, "recruits": province.recruits,
		"next_uid": province.next_uid, "auto_staff": province.auto_staff,
		"shortage": province.food_shortage_percent, "capacity": province.store.capacity,
		"stock": stock, "ledgers": ledgers, "buildings": states, "projects": province.projects,
		"modifiers": province.modifiers, "wasted": province.wasted, "alerts": Array(province.alerts),
		"cold": [province.cold_steps, province.cold_shortage_percent],
	}
	return JSON.stringify(state, "", true)
