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
		states.append([b["uid"], b["type"], b["workers"], b["enabled"], b["active"], b["progress"], b["status"], b["missing"]])
	var state := {
		"id": province.id, "step": province.step_count, "population": province.population,
		"unrest": province.unrest, "hunger": province.hunger_steps, "recruits": province.recruits,
		"next_uid": province.next_uid, "auto_staff": province.auto_staff,
		"shortage": province.food_shortage_percent, "capacity": province.store.capacity,
		"stock": stock, "ledgers": ledgers, "buildings": states, "projects": province.projects,
		"modifiers": province.modifiers, "wasted": province.wasted, "alerts": Array(province.alerts),
	}
	return JSON.stringify(state, "", true)
