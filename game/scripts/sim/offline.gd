extends RefCounted
## Progreso offline (criterio A9, sección 19 del documento maestro).
##
## No es una simulación aparte ni una aproximación: el tiempo ausente se convierte en un
## número de pasos y se ejecutan los mismos pasos de la simulación normal, así que la
## economía es idéntica a haber dejado el juego abierto.
##
## Reglas (las dos cifras están en rules.json y son provisionales):
## - Cada `step_seconds` segundos reales de ausencia equivalen a un paso.
## - La ausencia contada tiene un tope de `offline_limit_seconds`; lo que sobre se pierde.
## - Si el reloj está atrasado respecto a la hora del guardado, o la hora del guardado se
##   desconoce, no se simula nada (nunca hay recompensa por un tiempo negativo).
## - El resto de tiempo que no llega a completar un paso se conserva en la marca de
##   tiempo nueva, para que repartir la ausencia en varias cargas no pierda ni regale
##   tiempo. Cargar otra vez con la misma hora no vuelve a dar pasos.
##
## El reloj no está aquí: quien llama pasa `now` (en segundos Unix). Así las pruebas no
## dependen de la hora real.

const CLOCK_OK := ""
const CLOCK_WENT_BACK := "clock_went_back"
const CLOCK_UNKNOWN := "unknown_saved_time"


## Aplica el tiempo ausente al mundo. Devuelve:
##   steps, elapsed_seconds (ausencia real, ≥ 0), applied_seconds (la que cuenta),
##   capped, clock_problem, new_saved_at (marca que hay que guardar a partir de ahora) y
##   provinces: por provincia, el resumen de lo ocurrido.
static func settle(world, saved_at: int, now: int) -> Dictionary:
	var rules: Dictionary = world.data.rules
	var step_seconds: int = rules["step_seconds"]
	var limit_seconds: int = rules["offline_limit_seconds"]
	var result := {
		"steps": 0, "elapsed_seconds": 0, "applied_seconds": 0, "capped": false,
		"clock_problem": CLOCK_OK, "new_saved_at": now, "provinces": [],
	}
	if saved_at <= 0:
		result["clock_problem"] = CLOCK_UNKNOWN
		return result
	if now < saved_at:
		result["clock_problem"] = CLOCK_WENT_BACK
		return result
	var elapsed := now - saved_at
	result["elapsed_seconds"] = elapsed
	var applied := mini(elapsed, limit_seconds)
	result["capped"] = elapsed > limit_seconds
	var steps := applied / step_seconds
	result["steps"] = steps
	result["applied_seconds"] = steps * step_seconds
	# Si se recortó por el tope, el exceso se descarta; si no, el resto de tiempo que no
	# llega a un paso se queda en la marca para la próxima vez.
	result["new_saved_at"] = now if result["capped"] else saved_at + steps * step_seconds
	if steps > 0:
		result["provinces"] = _run_with_summary(world, steps)
	return result


static func _run_with_summary(world, steps: int) -> Array:
	var before := {}
	var worst := {}
	for province in world.provinces:
		before[province.id] = {
			"population": province.population,
			"buildings": _building_counts(province),
			"stock": _stocks(world.data, province),
		}
		worst[province.id] = {"hunger": province.hunger_steps, "unrest": province.unrest}
	# Mientras el jugador está ausente los rivales no atacan: la economía corre igual, pero no se pierden provincias con el móvil apagado.
	var was_paused: bool = world.ai_paused
	world.ai_paused = true
	for i in range(steps):
		world.step()
		for province in world.provinces:
			var w: Dictionary = worst[province.id]
			w["hunger"] = maxi(w["hunger"], province.hunger_steps)
			w["unrest"] = maxi(w["unrest"], province.unrest)
	world.ai_paused = was_paused
	var list: Array = []
	for province in world.provinces:
		var b: Dictionary = before[province.id]
		var after_stock := _stocks(world.data, province)
		var delta := {}
		for good in after_stock.keys():
			var change: int = after_stock[good] - b["stock"][good]
			if change != 0:
				delta[good] = change
		list.append({
			"id": province.id, "name": province.display_name,
			"population_before": b["population"], "population_after": province.population,
			"buildings_before": b["buildings"], "buildings_after": _building_counts(province),
			"stock_delta": delta, "worst_hunger_steps": worst[province.id]["hunger"],
			"worst_unrest": worst[province.id]["unrest"], "alerts": Array(province.alerts),
		})
	return list


static func _building_counts(province) -> Dictionary:
	var counts := {}
	for b in province.buildings:
		counts[b["type"]] = counts.get(b["type"], 0) + 1
	return counts


static func _stocks(data, province) -> Dictionary:
	var stocks := {}
	for good in data.goods.keys():
		stocks[good] = province.store.stock(good)
	return stocks
