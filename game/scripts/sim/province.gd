extends RefCounted
## Una provincia: población agregada, almacén, edificios y obras.
##
## Toda la economía usa enteros (D-012): cantidades en milésimas de unidad y tiempos
## en pasos de simulación. No hay azar: con el mismo estado, `step()` da siempre el
## mismo resultado. Los valores de las reglas son parámetros de juego provisionales.
##
## Orden de un paso: caducar efectos, ajustar mano de obra, impuestos, obras,
## producción, consumo de alimento, descontento y población, avisos.

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


## Producción en porcentaje según el descontento (100 = normal).
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


func recruit(count: int) -> bool:
	last_error = ""
	if count < 0 or count > available_workers():
		last_error = "no hay tantos trabajadores libres para reclutar"
		return false
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
	_advance_projects()
	for b in buildings:
		_run_building(b)
	_consume_food()
	_update_population()
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
	if b["progress"] < t["cycle_steps"]:
		b["progress"] += 1
	if b["progress"] >= t["cycle_steps"]:
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
	var productivity := productivity_percent()
	for good in t["outputs"].keys():
		produced[good] = Fixed.percent_of_2(t["outputs"][good], productivity, _modifier_percent(good))
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
