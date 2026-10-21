extends RefCounted
## Una provincia: población agregada, almacén, edificios y obras.
##
## Toda la economía usa enteros (D-012): cantidades en milésimas de unidad y tiempos
## en pasos de simulación. No hay azar: con el mismo estado, `step()` da siempre el
## mismo resultado. Los valores de las reglas son parámetros de juego provisionales.
##
## Orden de un paso: caducar efectos, ajustar mano de obra, impuestos, consumo de
## alimento (la población come antes de que los molinos y panaderías se lleven el
## grano), obras, producción, descontento y población, avisos.
##
## El descontento no reduce lo que se produce sino la velocidad de trabajo: un ciclo
## tarda más, pero no se desperdician insumos. Reducir el resultado en cada eslabón de
## una cadena (trigo, harina, pan) se multiplicaba y creaba una espiral de la que la
## provincia no salía (descubierto por la prueba de crisis de cosecha, ver D-014).

const Fixed := preload("res://scripts/sim/fixed.gd")
const StoreScript := preload("res://scripts/sim/store.gd")

## Estados de un edificio. Son códigos estables; la interfaz los traduce a texto.
const STATUS_IDLE := "idle"
const STATUS_RUNNING := "running"
const STATUS_DISABLED := "disabled"
const STATUS_NO_WORKERS := "no_workers"
const STATUS_MISSING_INPUTS := "missing_inputs"
const STATUS_NO_UPKEEP := "no_upkeep"
const STATUS_STORAGE_FULL := "storage_full"

## Avisos de la provincia.
const ALERT_HUNGER_WARNING := "hunger_warning"
const ALERT_UNREST := "unrest"
const ALERT_STARVATION := "starvation"
const ALERT_STORAGE_FULL := "storage_full"
const ALERT_NO_WORKERS := "no_workers"
const ALERT_WASTE := "waste"
const ALERT_SOLDIERS_UNPAID := "soldiers_unpaid"

const STATUSES: Array[String] = [STATUS_IDLE, STATUS_RUNNING, STATUS_DISABLED, STATUS_NO_WORKERS, STATUS_MISSING_INPUTS, STATUS_NO_UPKEEP, STATUS_STORAGE_FULL]
const ALERTS: Array[String] = [ALERT_HUNGER_WARNING, ALERT_UNREST, ALERT_STARVATION, ALERT_STORAGE_FULL, ALERT_NO_WORKERS, ALERT_WASTE, ALERT_SOLDIERS_UNPAID]
const BIG := 1000000000000
## Mercancía que gasta cada recluta (la cantidad está en rules.recruit_weapons).
const RECRUIT_GOOD := "weapons"

var id: String = ""
var display_name: String = ""
var population: int = 0
## Personas apartadas del trabajo (reclutadas). Reducen los trabajadores disponibles.
var recruits: int = 0
## Descontento de 0 a rules.unrest_max
var unrest: int = 0
## Pasos seguidos con falta de alimento
var hunger_steps: int = 0
var step_count: int = 0
var next_uid: int = 1
## Si es true, el paso reparte los trabajadores libres entre obras y edificios
var auto_staff: bool = true
## Edificios: Array de Dictionary {uid, type, workers, enabled, active, progress, status, missing}
var buildings: Array = []
## Obras en curso: Array de Dictionary {uid, type, remaining, workers}
var projects: Array = []
## Efectos temporales sobre la producción: id de mercancía -> {percent, until_step}
var modifiers: Dictionary = {}
## Avisos del último paso (códigos ALERT_*)
var alerts: Array[String] = []
## Producción desperdiciada por no caber en el almacén, acumulada: id de mercancía -> cantidad.
## No forma parte del libro del almacén: esas cantidades nunca llegaron a existir en él.
var wasted: Dictionary = {}
## Porcentaje de alimento que faltó en el último paso (0 = todos alimentados)
var food_shortage_percent: int = 0
## ¿Faltó moneda para pagar a los soldados en el último paso?
var soldiers_unpaid: bool = false
## Motivo del último rechazo de una acción (vacío si fue válida)
var last_error: String = ""
var store = null

var _data = null
var _rules: Dictionary = {}
var _waste_this_step: bool = false


func _init(data, province_id: String, province_name: String, start_population: int) -> void:
	_data = data
	_rules = data.rules
	id = province_id
	display_name = province_name
	population = start_population
	store = StoreScript.new(data.goods, 0)
	_recompute_capacity()


# --- Consulta -----------------------------------------------------------------

func labor_force() -> int:
	return maxi(Fixed.percent_of(population, _rules["labor_percent"]) - recruits, 0)


func assigned_labor() -> int:
	var total := 0
	for b in buildings:
		total += b["workers"]
	for p in projects:
		total += p["workers"]
	return total


func available_workers() -> int:
	return maxi(labor_force() - assigned_labor(), 0)


func housing_capacity() -> int:
	var total: int = _rules["base_housing"]
	for b in buildings:
		total += _data.buildings[b["type"]]["housing"]
	return total


## Velocidad de trabajo en porcentaje según el descontento (100 = normal).
func productivity_percent() -> int:
	var threshold: int = _rules["unrest_slow_threshold"]
	if unrest <= threshold:
		return 100
	var min_percent: int = _rules["min_productivity_percent"]
	var span: int = _rules["unrest_max"] - threshold
	var lost := Fixed.div_floor((unrest - threshold) * (100 - min_percent), span)
	return clampi(100 - lost, min_percent, 100)


func find_building(uid: int) -> Dictionary:
	for b in buildings:
		if b["uid"] == uid:
			return b
	return {}


func count_buildings(type_id: String) -> int:
	var total := 0
	for b in buildings:
		if b["type"] == type_id:
			total += 1
	return total


# --- Acciones del jugador ------------------------------------------------------

## Añade un edificio ya terminado, sin coste (para empezar una partida y para pruebas).
func add_building(type_id: String) -> int:
	if not _data.buildings.has(type_id):
		last_error = "edificio desconocido: %s" % type_id
		return 0
	var uid := next_uid
	next_uid += 1
	buildings.append({
		"uid": uid, "type": type_id, "workers": 0, "enabled": true,
		"active": false, "progress": 0, "status": STATUS_IDLE, "missing": {},
	})
	_recompute_capacity()
	last_error = ""
	return uid


func assign_workers(uid: int, count: int) -> bool:
	last_error = ""
	var b := find_building(uid)
	if b.is_empty():
		last_error = "no existe el edificio %d" % uid
		return false
	var required: int = _data.buildings[b["type"]]["workers"]
	if count < 0 or count > required:
		last_error = "el edificio admite entre 0 y %d trabajadores" % required
		return false
	var extra: int = count - b["workers"]
	if extra > available_workers():
		last_error = "no hay trabajadores libres suficientes"
		return false
	b["workers"] = count
	return true


func set_enabled(uid: int, enabled: bool) -> bool:
	var b := find_building(uid)
	if b.is_empty():
		last_error = "no existe el edificio %d" % uid
		return false
	b["enabled"] = enabled
	last_error = ""
	return true


## Soldados que caben en los cuarteles (BIG si las reglas no piden cuartel).
func recruit_capacity() -> int:
	var per: int = _rules.get("recruits_per_barracks", 0)
	if per <= 0:
		return BIG
	return count_buildings("barracks") * per


## Recluta soldados: salen de la mano de obra libre, caben en los cuarteles y cada uno gasta armas.
## No cambia nada si no se cumple alguna condición.
func recruit(count: int) -> bool:
	last_error = ""
	if count < 0 or count > available_workers():
		last_error = "no hay tantos trabajadores libres para reclutar"
		return false
	if recruits + count > recruit_capacity():
		last_error = "los cuarteles no tienen sitio para tantos soldados"
		return false
	var weapons: int = count * int(_rules.get("recruit_weapons", 0))
	if weapons > 0 and store.stock(RECRUIT_GOOD) < weapons:
		last_error = "faltan armas"
		return false
	if weapons > 0:
		store.remove(RECRUIT_GOOD, weapons, StoreScript.CONSUMED)
	recruits += count
	return true


func release_recruits(count: int) -> bool:
	last_error = ""
	if count < 0 or count > recruits:
		last_error = "no hay tantos reclutas"
		return false
	recruits -= count
	return true


## Empieza una obra: comprueba recursos, mano de obra y cola antes de tocar nada.
func start_construction(type_id: String) -> bool:
	last_error = ""
	if not _data.buildings.has(type_id):
		last_error = "edificio desconocido: %s" % type_id
		return false
	var t: Dictionary = _data.buildings[type_id]
	if projects.size() >= _rules["max_projects"]:
		last_error = "ya hay %d obras en curso" % projects.size()
		return false
	# Tope de edificios por provincia (D-020): cuentan los terminados y las obras en curso.
	if buildings.size() + projects.size() >= _rules["max_buildings"]:
		last_error = "no hay sitio para más edificios (máximo %d por provincia)" % _rules["max_buildings"]
		return false
	if not store.can_afford(t["build_cost"]):
		last_error = "faltan recursos para construir"
		return false
	var needed: int = t["build_workers"]
	var reserved := 0
	for p in projects:
		reserved += p["workers"]
	if labor_force() - reserved < needed:
		last_error = "faltan trabajadores para la obra"
		return false
	if available_workers() < needed:
		if not auto_staff:
			last_error = "faltan trabajadores libres para la obra"
			return false
		_release_building_workers(needed - available_workers())
	for good in t["build_cost"].keys():
		store.remove(good, t["build_cost"][good], StoreScript.CONSUMED)
	projects.append({"uid": next_uid, "type": type_id, "remaining": t["build_steps"], "workers": needed})
	next_uid += 1
	return true


## Efecto temporal sobre la producción de una mercancía (por ejemplo, una mala cosecha).
func add_modifier(good_id: String, percent: int, duration_steps: int) -> void:
	modifiers[good_id] = {"percent": percent, "until_step": step_count + duration_steps}


# --- Paso de simulación ---------------------------------------------------------

func step() -> void:
	step_count += 1
	_waste_this_step = false
	_expire_modifiers()
	_enforce_labor_limit()
	if auto_staff:
		_staff_automatically()
	_collect_taxes()
	_pay_soldiers()
	_consume_food()
	_advance_projects()
	for b in buildings:
		_run_building(b)
	_update_population()
	# La población puede haber bajado: así nunca queda un paso con más trabajadores
	# asignados que mano de obra, ni siquiera entre dos pasos (por ejemplo, al guardar).
	_enforce_labor_limit()
	_update_alerts()


func _expire_modifiers() -> void:
	for good in modifiers.keys():
		if modifiers[good]["until_step"] <= step_count:
			modifiers.erase(good)


func _modifier_percent(good_id: String) -> int:
	if modifiers.has(good_id):
		return modifiers[good_id]["percent"]
	return 100


func _recompute_capacity() -> void:
	var capacity: int = _rules["base_capacity"]
	for b in buildings:
		capacity += _data.buildings[b["type"]]["storage_capacity"]
	if not store.set_capacity(capacity):
		last_error = "capacidad: %s" % store.last_error


# --- Mano de obra ---------------------------------------------------------------

## Si hay más trabajadores asignados que mano de obra, quita primero a los últimos edificios.
func _enforce_labor_limit() -> void:
	var over := assigned_labor() - labor_force()
	if over > 0:
		over -= _release_building_workers(over)
	var index := projects.size() - 1
	while over > 0 and index >= 0:
		var cut := mini(over, projects[index]["workers"])
		projects[index]["workers"] -= cut
		over -= cut
		index -= 1


## Libera hasta `count` trabajadores de edificios, empezando por el último. Devuelve los liberados.
func _release_building_workers(count: int) -> int:
	var released := 0
	var index := buildings.size() - 1
	while released < count and index >= 0:
		var cut := mini(count - released, buildings[index]["workers"])
		buildings[index]["workers"] -= cut
		released += cut
		index -= 1
	return released


## Reparte los trabajadores libres: primero las obras y después los edificios por antigüedad.
func _staff_automatically() -> void:
	var spare := available_workers()
	for p in projects:
		var needed: int = _data.buildings[p["type"]]["build_workers"]
		var extra := mini(needed - p["workers"], spare)
		if extra > 0:
			p["workers"] += extra
			spare -= extra
	for b in buildings:
		var required: int = _data.buildings[b["type"]]["workers"]
		var extra := mini(required - b["workers"], spare)
		if extra > 0:
			b["workers"] += extra
			spare -= extra


# --- Economía --------------------------------------------------------------------

func _collect_taxes() -> void:
	var amount: int = population * _rules["tax_per_person"]
	if amount > 0:
		store.add(_rules["currency"], amount, StoreScript.PRODUCED)


## Cada soldado cuesta moneda por paso. Si no hay para todos, se paga lo que haya y sube el descontento.
func _pay_soldiers() -> void:
	soldiers_unpaid = false
	var due: int = recruits * int(_rules.get("recruit_upkeep", 0))
	if due <= 0:
		return
	var paid: int = store.remove(_rules["currency"], due, StoreScript.CONSUMED)
	if paid < due:
		soldiers_unpaid = true
		unrest = mini(unrest + int(_rules["unrest_rise"]), _rules["unrest_max"])


func _advance_projects() -> void:
	var finished: Array = []
	for p in projects:
		var needed: int = _data.buildings[p["type"]]["build_workers"]
		if p["workers"] < needed:
			continue
		p["remaining"] -= 1
		if p["remaining"] <= 0:
			finished.append(p["uid"])
	for uid in finished:
		for i in range(projects.size()):
			if projects[i]["uid"] == uid:
				var type_id: String = projects[i]["type"]
				projects.remove_at(i)
				add_building(type_id)
				break


func _run_building(b: Dictionary) -> void:
	var t: Dictionary = _data.buildings[b["type"]]
	b["missing"] = {}
	if t["inputs"].is_empty() and t["outputs"].is_empty():
		b["status"] = STATUS_IDLE
		return
	if not b["enabled"]:
		b["status"] = STATUS_DISABLED
		return
	if b["workers"] < t["workers"]:
		b["status"] = STATUS_NO_WORKERS
		return
	if not b["active"]:
		if not _try_start_cycle(b, t):
			return
	# El progreso va en centésimas de paso: un ciclo necesita cycle_steps * 100 y cada
	# paso suma la productividad (100 si no hay descontento).
	var needed: int = t["cycle_steps"] * 100
	if b["progress"] < needed:
		b["progress"] = mini(b["progress"] + productivity_percent(), needed)
	if b["progress"] >= needed:
		_try_finish_cycle(b, t)
	else:
		b["status"] = STATUS_RUNNING


## Empieza un ciclo si hay insumos, mantenimiento y sitio para el resultado.
func _try_start_cycle(b: Dictionary, t: Dictionary) -> bool:
	var missing := {}
	for good in t["inputs"].keys():
		var short: int = t["inputs"][good] - store.stock(good)
		if short > 0:
			missing[good] = short
	if not missing.is_empty():
		b["status"] = STATUS_MISSING_INPUTS
		b["missing"] = missing
		return false
	for good in t["upkeep"].keys():
		var short: int = t["upkeep"][good] - store.stock(good)
		if short > 0:
			missing[good] = short
	if not missing.is_empty():
		b["status"] = STATUS_NO_UPKEEP
		b["missing"] = missing
		return false
	var freed := 0
	for good in t["inputs"].keys():
		if _data.is_physical(good):
			freed += t["inputs"][good]
	if not store.can_fit_any(t["outputs"], freed):
		b["status"] = STATUS_STORAGE_FULL
		return false
	for good in t["inputs"].keys():
		store.remove(good, t["inputs"][good], StoreScript.CONSUMED)
	for good in t["upkeep"].keys():
		store.remove(good, t["upkeep"][good], StoreScript.CONSUMED)
	b["active"] = true
	b["progress"] = 0
	return true


## Termina el ciclo y entrega cada producto que cabe. Si no cabe ninguno, espera con el
## trabajo hecho (estado storage_full). Si caben unos y otros no (un leñador con la
## madera al tope sigue entregando leña), lo que no cabe se desperdicia y se anota en
## `wasted` con un aviso, para que un subproducto sobrante no bloquee el principal.
func _try_finish_cycle(b: Dictionary, t: Dictionary) -> void:
	var produced := {}
	for good in t["outputs"].keys():
		produced[good] = Fixed.percent_of(t["outputs"][good], _modifier_percent(good))
	if not store.can_fit_any(produced):
		b["status"] = STATUS_STORAGE_FULL
		return
	for good in produced.keys():
		var amount: int = produced[good]
		if amount <= 0:
			continue
		if store.room(good) >= amount:
			store.add(good, amount, StoreScript.PRODUCED)
		else:
			wasted[good] = wasted.get(good, 0) + amount
			_waste_this_step = true
	b["active"] = false
	b["progress"] = 0
	b["status"] = STATUS_RUNNING


## Cada persona necesita una ración por paso. Se come por orden de preferencia (rules.food_goods).
func _consume_food() -> void:
	var required: int = population * _rules["food_per_person"]
	var left := required
	for food in _rules["food_goods"]:
		if left <= 0:
			break
		var value: int = food["value"]
		var wanted := Fixed.div_ceil(left * 1000, value)
		var taken: int = store.remove(food["good"], wanted, StoreScript.CONSUMED)
		left -= Fixed.div_floor(taken * value, 1000)
	if required > 0 and left > 0:
		food_shortage_percent = Fixed.div_ceil(left * 100, required)
	else:
		food_shortage_percent = 0


# --- Población y descontento -----------------------------------------------------

func _update_population() -> void:
	if food_shortage_percent > 0:
		hunger_steps += 1
		if hunger_steps > _rules["hunger_warning_steps"]:
			var rise := maxi(1, Fixed.percent_of(_rules["unrest_rise"], food_shortage_percent))
			unrest = mini(unrest + rise, _rules["unrest_max"])
		if hunger_steps >= _rules["starvation_steps"]:
			var loss := maxi(1, Fixed.percent_of(population, _rules["starvation_loss_percent"]))
			population = maxi(population - loss, _rules["min_population"])
	else:
		hunger_steps = 0
		unrest = maxi(unrest - _rules["unrest_fall"], 0)
		if unrest <= _rules["growth_unrest_limit"] and step_count % _rules["growth_interval"] == 0:
			var room := housing_capacity() - population
			if room > 0:
				var growth := maxi(1, Fixed.percent_of(population, _rules["growth_percent"]))
				population += mini(growth, room)


func _update_alerts() -> void:
	alerts = []
	if food_shortage_percent > 0:
		if hunger_steps >= _rules["starvation_steps"]:
			alerts.append(ALERT_STARVATION)
		elif hunger_steps > _rules["hunger_warning_steps"]:
			alerts.append(ALERT_UNREST)
		else:
			alerts.append(ALERT_HUNGER_WARNING)
	if soldiers_unpaid:
		alerts.append(ALERT_SOLDIERS_UNPAID)
	var full := false
	var idle_workers := false
	for b in buildings:
		if b["status"] == STATUS_STORAGE_FULL:
			full = true
		if b["status"] == STATUS_NO_WORKERS:
			idle_workers = true
	if full:
		alerts.append(ALERT_STORAGE_FULL)
	if idle_workers:
		alerts.append(ALERT_NO_WORKERS)
	if _waste_this_step:
		alerts.append(ALERT_WASTE)


# --- Comprobación de coherencia ------------------------------------------------

## Lista de incoherencias del estado; vacía si todo es correcto.
func check_invariants() -> Array[String]:
	var problems: Array[String] = []
	problems.append_array(store.check_conservation())
	if population < _rules["min_population"]:
		problems.append("población por debajo del mínimo: %d" % population)
	if recruits < 0 or unrest < 0 or hunger_steps < 0:
		problems.append("valor negativo en reclutas, descontento o hambre")
	if unrest > _rules["unrest_max"]:
		problems.append("descontento por encima del máximo: %d" % unrest)
	if assigned_labor() > labor_force():
		problems.append("trabajadores asignados (%d) por encima de la mano de obra (%d)" % [assigned_labor(), labor_force()])
	for b in buildings:
		if typeof(b["workers"]) != TYPE_INT or b["workers"] < 0:
			problems.append("edificio %d: trabajadores no válidos" % b["uid"])
		elif b["workers"] > _data.buildings[b["type"]]["workers"]:
			problems.append("edificio %d: más trabajadores de los que admite" % b["uid"])
		if b["progress"] < 0:
			problems.append("edificio %d: progreso negativo" % b["uid"])
	for p in projects:
		if p["remaining"] < 0 or p["workers"] < 0:
			problems.append("obra %d: valores negativos" % p["uid"])
	return problems


# --- Guardado y carga ----------------------------------------------------------

## Estado completo de la provincia para guardar (solo diccionarios, listas, números,
## textos y booleanos).
func to_dict() -> Dictionary:
	return {
		"id": id, "name": display_name, "population": population, "recruits": recruits,
		"unrest": unrest, "hunger_steps": hunger_steps, "step_count": step_count,
		"next_uid": next_uid, "auto_staff": auto_staff,
		"food_shortage_percent": food_shortage_percent,
		"buildings": buildings.duplicate(true), "projects": projects.duplicate(true),
		"modifiers": modifiers.duplicate(true), "wasted": wasted.duplicate(),
		"alerts": Array(alerts), "store": store.to_dict(),
	}


## Carga un estado guardado, comprobando todo. Devuelve false y deja el motivo en
## `last_error` si algo no es válido; entonces este objeto no debe usarse.
func load_dict(raw: Variant) -> bool:
	last_error = ""
	if typeof(raw) != TYPE_DICTIONARY:
		return _load_fail("la provincia guardada no es un objeto")
	var new_id = raw.get("id", null)
	var new_name = raw.get("name", null)
	if typeof(new_id) != TYPE_STRING or new_id == "" or typeof(new_name) != TYPE_STRING:
		return _load_fail("id o nombre de provincia no válidos")
	var limits := {
		"population": [1, BIG], "recruits": [0, BIG], "unrest": [0, _rules["unrest_max"]],
		"hunger_steps": [0, BIG], "step_count": [0, BIG], "next_uid": [1, BIG],
		"food_shortage_percent": [0, 100],
	}
	var numbers := {}
	for field in limits.keys():
		var value = Fixed.exact_int(raw.get(field, null))
		if value == null or value < limits[field][0] or value > limits[field][1]:
			return _load_fail("%s: \"%s\" no válido" % [new_id, field])
		numbers[field] = value
	if typeof(raw.get("auto_staff", null)) != TYPE_BOOL:
		return _load_fail("%s: \"auto_staff\" debe ser verdadero o falso" % new_id)
	var seen_uids := {}
	var new_buildings: Array = []
	var buildings_raw = raw.get("buildings", null)
	if typeof(buildings_raw) != TYPE_ARRAY:
		return _load_fail("%s: falta la lista de edificios" % new_id)
	for entry in buildings_raw:
		var parsed = _parse_saved_building(entry, seen_uids, numbers["next_uid"])
		if parsed == null:
			return false
		new_buildings.append(parsed)
	var new_projects: Array = []
	var projects_raw = raw.get("projects", null)
	if typeof(projects_raw) != TYPE_ARRAY:
		return _load_fail("%s: falta la lista de obras" % new_id)
	for entry in projects_raw:
		var parsed = _parse_saved_project(entry, seen_uids, numbers["next_uid"])
		if parsed == null:
			return false
		new_projects.append(parsed)
	var new_modifiers := {}
	var modifiers_raw = raw.get("modifiers", null)
	if typeof(modifiers_raw) != TYPE_DICTIONARY:
		return _load_fail("%s: falta el objeto de efectos" % new_id)
	for good in modifiers_raw.keys():
		var entry = modifiers_raw[good]
		if not _data.goods.has(good) or typeof(entry) != TYPE_DICTIONARY:
			return _load_fail("%s: efecto no válido (%s)" % [new_id, str(good)])
		var percent = Fixed.exact_int(entry.get("percent", null))
		var until = Fixed.exact_int(entry.get("until_step", null))
		if percent == null or until == null or percent < 0 or percent > 1000 or until < 0:
			return _load_fail("%s: efecto de %s con valores no válidos" % [new_id, str(good)])
		new_modifiers[good] = {"percent": percent, "until_step": until}
	var new_wasted := {}
	var wasted_raw = raw.get("wasted", null)
	if typeof(wasted_raw) != TYPE_DICTIONARY:
		return _load_fail("%s: falta el objeto de desperdicio" % new_id)
	for good in wasted_raw.keys():
		var amount = Fixed.exact_int(wasted_raw[good])
		if not _data.goods.has(good) or amount == null or amount < 0:
			return _load_fail("%s: desperdicio no válido (%s)" % [new_id, str(good)])
		new_wasted[good] = amount
	var new_alerts: Array[String] = []
	var alerts_raw = raw.get("alerts", null)
	if typeof(alerts_raw) != TYPE_ARRAY:
		return _load_fail("%s: falta la lista de avisos" % new_id)
	for alert in alerts_raw:
		if typeof(alert) != TYPE_STRING or not ALERTS.has(alert):
			return _load_fail("%s: aviso desconocido" % new_id)
		new_alerts.append(alert)
	if not store.load_dict(raw.get("store", null)):
		return _load_fail("%s: %s" % [new_id, store.last_error])
	id = new_id
	display_name = new_name
	population = numbers["population"]
	recruits = numbers["recruits"]
	unrest = numbers["unrest"]
	hunger_steps = numbers["hunger_steps"]
	step_count = numbers["step_count"]
	next_uid = numbers["next_uid"]
	food_shortage_percent = numbers["food_shortage_percent"]
	auto_staff = raw["auto_staff"]
	buildings = new_buildings
	projects = new_projects
	modifiers = new_modifiers
	wasted = new_wasted
	alerts = new_alerts
	var expected_capacity: int = _rules["base_capacity"]
	for b in buildings:
		expected_capacity += _data.buildings[b["type"]]["storage_capacity"]
	if store.capacity != expected_capacity:
		return _load_fail("%s: la capacidad guardada (%d) no coincide con los edificios (%d)" % [id, store.capacity, expected_capacity])
	var problems := check_invariants()
	if not problems.is_empty():
		return _load_fail("%s: estado incoherente: %s" % [id, problems[0]])
	return true


func _load_fail(message: String) -> bool:
	last_error = message
	return false


## Valida un edificio guardado. Devuelve el diccionario normalizado o null (con last_error).
func _parse_saved_building(entry: Variant, seen_uids: Dictionary, next_free_uid: int) -> Variant:
	if typeof(entry) != TYPE_DICTIONARY:
		_load_fail("edificio guardado no válido")
		return null
	var type_id = entry.get("type", null)
	if typeof(type_id) != TYPE_STRING or not _data.buildings.has(type_id):
		_load_fail("edificio de tipo desconocido (%s)" % str(type_id))
		return null
	var t: Dictionary = _data.buildings[type_id]
	var uid = Fixed.exact_int(entry.get("uid", null))
	if uid == null or uid < 1 or uid >= next_free_uid or seen_uids.has(uid):
		_load_fail("edificio con uid no válido o repetido")
		return null
	seen_uids[uid] = true
	var workers = Fixed.exact_int(entry.get("workers", null))
	var progress = Fixed.exact_int(entry.get("progress", null))
	if workers == null or workers < 0 or workers > t["workers"] or progress == null or progress < 0 or progress > t["cycle_steps"] * 100:
		_load_fail("edificio %d: trabajadores o progreso fuera de rango" % uid)
		return null
	if typeof(entry.get("enabled", null)) != TYPE_BOOL or typeof(entry.get("active", null)) != TYPE_BOOL:
		_load_fail("edificio %d: enabled o active no son booleanos" % uid)
		return null
	var status = entry.get("status", null)
	if typeof(status) != TYPE_STRING or not STATUSES.has(status):
		_load_fail("edificio %d: estado desconocido" % uid)
		return null
	var missing := {}
	var missing_raw = entry.get("missing", null)
	if typeof(missing_raw) != TYPE_DICTIONARY:
		_load_fail("edificio %d: falta la lista de lo que falta" % uid)
		return null
	for good in missing_raw.keys():
		var amount = Fixed.exact_int(missing_raw[good])
		if not _data.goods.has(good) or amount == null or amount <= 0:
			_load_fail("edificio %d: \"missing\" no válido" % uid)
			return null
		missing[good] = amount
	return {
		"uid": uid, "type": type_id, "workers": workers, "enabled": entry["enabled"],
		"active": entry["active"], "progress": progress, "status": status, "missing": missing,
	}


func _parse_saved_project(entry: Variant, seen_uids: Dictionary, next_free_uid: int) -> Variant:
	if typeof(entry) != TYPE_DICTIONARY:
		_load_fail("obra guardada no válida")
		return null
	var type_id = entry.get("type", null)
	if typeof(type_id) != TYPE_STRING or not _data.buildings.has(type_id):
		_load_fail("obra de tipo desconocido (%s)" % str(type_id))
		return null
	var t: Dictionary = _data.buildings[type_id]
	var uid = Fixed.exact_int(entry.get("uid", null))
	if uid == null or uid < 1 or uid >= next_free_uid or seen_uids.has(uid):
		_load_fail("obra con uid no válido o repetido")
		return null
	seen_uids[uid] = true
	var remaining = Fixed.exact_int(entry.get("remaining", null))
	var workers = Fixed.exact_int(entry.get("workers", null))
	if remaining == null or remaining < 1 or remaining > t["build_steps"] or workers == null or workers < 0 or workers > t["build_workers"]:
		_load_fail("obra %d: tiempo o trabajadores fuera de rango" % uid)
		return null
	return {"uid": uid, "type": type_id, "remaining": remaining, "workers": workers}
