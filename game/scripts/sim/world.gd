extends RefCounted
## El mundo de una partida: las provincias y el contador de pasos global.

const ProvinceScript := preload("res://scripts/sim/province.gd")
const Fixed := preload("res://scripts/sim/fixed.gd")
const TradeScript := preload("res://scripts/sim/trade.gd")
const RivalAIScript := preload("res://scripts/sim/rival_ai.gd")
const WarScript := preload("res://scripts/sim/war.gd")

var data = null
var step_count: int = 0
var provinces: Array = []
## Motivo del último error al cargar (vacío si fue bien)
var last_error: String = ""
## Red de comercio (no se guarda: sale del mapa): id de provincia -> {realm, neighbors}.
## Vacía = el mundo no comercia (pruebas sueltas).
var trade_links: Dictionary = {}
## Caravanas en camino [{from, to, good, amount, arrive}] y lo perdido en el viaje por mercancía.
## Esto sí se guarda.
var shipments: Array = []
var trade_lost: Dictionary = {}
## Propietario de cada provincia (id -> reino) y reino que manda el jugador. Sin propietarios (mundos de prueba) o con
## `player_realm` vacío no hay guerra y el jugador manda en todas. Se guardan.
var owners: Dictionary = {}
var player_realm: String = ""
## Sube cada vez que cambia algún propietario (para que el mapa vuelva a colorearse). No se guarda.
var owners_version: int = 0
## Ejércitos en marcha [{from, to, soldiers, arrive}] (se guardan) y, sin guardar, los informes de las últimas batallas y
## el total de muertos de la partida en curso.
var armies: Array = []
var battle_log: Array = []
var war_dead: int = 0
var ai_paused: bool = false     ## los rivales no atacan (la ausencia offline se simula con esto puesto; no se guarda)
var incoming_count: int = 0     ## ataques rivales lanzados contra el jugador (no se guarda): la interfaz avisa de los nuevos
var incoming_log: Array = []
var battle_count: int = 0       ## batallas libradas (no se guarda): la interfaz lo usa para avisar de las nuevas
## Caché de saltos entre provincias (se vacía al cambiar la red)
var hop_cache: Dictionary = {}
var _index: Dictionary = {}


func _init(game_data) -> void:
	data = game_data


func add_province(province_id: String, province_name: String, population: int):
	var province = ProvinceScript.new(data, province_id, province_name, population)
	provinces.append(province)
	return province


## Devuelve la provincia con ese id, o null si no existe.
func find_province(province_id: String):
	if _index.size() != provinces.size():
		_index = {}
		for province in provinces:
			_index[province.id] = province
	return _index.get(province_id, null)


## Pone la red de comercio: {id: {"realm": String, "neighbors": Array}}.
func set_network(links: Dictionary) -> void:
	trade_links = links.duplicate(true)
	# Una provincia conquistada pasa a la red de su nuevo reino.
	for id in owners.keys():
		if trade_links.has(id):
			trade_links[id]["realm"] = owners[id]
	hop_cache = {}


## Cambia el propietario de una provincia (conquista) y la pasa a la red de comercio de su nuevo reino.
func set_owner(province_id: String, realm: String) -> void:
	owners[province_id] = realm
	owners_version += 1
	if trade_links.has(province_id):
		trade_links[province_id]["realm"] = realm
	hop_cache = {}


func step() -> void:
	step_count += 1
	for province in provinces:
		province.step()
	TradeScript.step(self)
	WarScript.step(self)
	RivalAIScript.step(self)


func run_steps(count: int) -> void:
	for i in range(count):
		step()


## Lista de incoherencias de todas las provincias; vacía si todo es correcto.
func check_invariants() -> Array[String]:
	var problems: Array[String] = []
	for province in provinces:
		for problem in province.check_invariants():
			problems.append("%s: %s" % [province.id, problem])
	for problem in TradeScript.check(self):
		problems.append(problem)
	return problems


func to_dict() -> Dictionary:
	var list: Array = []
	for province in provinces:
		list.append(province.to_dict())
	return {"step_count": step_count, "provinces": list, "shipments": shipments.duplicate(true), "trade_lost": trade_lost.duplicate(),
		"owners": owners.duplicate(), "player_realm": player_realm, "armies": armies.duplicate(true)}


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
	var parsed_shipments = _parse_shipments(raw.get("shipments", []), seen, steps)
	if parsed_shipments == null:
		return false
	var parsed_lost = _parse_lost(raw.get("trade_lost", {}))
	if parsed_lost == null:
		return false
	var parsed_owners = _parse_owners(raw.get("owners", {}), seen)
	if parsed_owners == null:
		return false
	var parsed_player = raw.get("player_realm", "")
	if typeof(parsed_player) != TYPE_STRING or (parsed_player != "" and not parsed_owners.values().has(parsed_player)):
		last_error = "mundo: reino del jugador no válido"
		return false
	var parsed_armies = _parse_armies(raw.get("armies", []), seen, steps, parsed_owners)
	if parsed_armies == null:
		return false
	provinces = loaded
	step_count = steps
	_index = {}
	shipments = parsed_shipments
	trade_lost = parsed_lost
	owners = parsed_owners
	owners_version += 1
	player_realm = parsed_player
	armies = parsed_armies
	battle_log = []
	battle_count = 0
	incoming_count = 0
	incoming_log = []
	war_dead = 0
	var problems := TradeScript.check(self)
	if not problems.is_empty():
		provinces = []
		shipments = []
		trade_lost = {}
		owners = {}
		player_realm = ""
		armies = []
		last_error = problems[0]
		return false
	return true


## Caravanas guardadas (opcional: un guardado anterior al comercio no las tiene). null si no son válidas.
func _parse_shipments(raw: Variant, known_ids: Dictionary, steps: int) -> Variant:
	if typeof(raw) != TYPE_ARRAY:
		last_error = "mundo: las caravanas no son una lista"
		return null
	if raw.size() > 100000:
		last_error = "mundo: demasiadas caravanas"
		return null
	var out: Array = []
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			last_error = "mundo: una caravana no es un objeto"
			return null
		var from_id = entry.get("from", null)
		var to_id = entry.get("to", null)
		var good = entry.get("good", null)
		if typeof(from_id) != TYPE_STRING or typeof(to_id) != TYPE_STRING or typeof(good) != TYPE_STRING \
				or not known_ids.has(from_id) or not known_ids.has(to_id) or from_id == to_id:
			last_error = "mundo: caravana con provincias no válidas"
			return null
		if not data.goods.has(good) or not data.goods[good]["physical"]:
			last_error = "mundo: caravana con una mercancía no válida (%s)" % good
			return null
		var amount = Fixed.exact_int(entry.get("amount", null))
		var arrive = Fixed.exact_int(entry.get("arrive", null))
		if amount == null or amount <= 0 or arrive == null or arrive < 0 or arrive > steps + TradeScript.MAX_ARRIVAL_AHEAD:
			last_error = "mundo: caravana con cantidad o llegada no válidas"
			return null
		out.append({"from": from_id, "to": to_id, "good": good, "amount": amount, "arrive": arrive})
	return out


func _parse_lost(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		last_error = "mundo: lo perdido en el comercio no es un objeto"
		return null
	var out := {}
	for good in raw.keys():
		var amount = Fixed.exact_int(raw[good])
		if typeof(good) != TYPE_STRING or not data.goods.has(good) or amount == null or amount < 0:
			last_error = "mundo: pérdida de comercio no válida"
			return null
		if amount > 0:
			out[good] = amount
	return out


## Propietarios guardados (opcional). null si no son válidos: cada clave una provincia del guardado y cada valor un reino no vacío.
func _parse_owners(raw: Variant, known_ids: Dictionary) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		last_error = "mundo: los propietarios no son un objeto"
		return null
	var out := {}
	for id in raw.keys():
		if typeof(id) != TYPE_STRING or not known_ids.has(id) or typeof(raw[id]) != TYPE_STRING or raw[id] == "":
			last_error = "mundo: propietario no válido"
			return null
		out[id] = raw[id]
	if not out.is_empty() and out.size() != known_ids.size():
		last_error = "mundo: faltan propietarios de algunas provincias"
		return null
	return out


## Ejércitos en marcha guardados (opcional). null si no son válidos.
func _parse_armies(raw: Variant, known_ids: Dictionary, steps: int, parsed_owners: Dictionary) -> Variant:
	if typeof(raw) != TYPE_ARRAY or raw.size() > WarScript.MAX_ARMIES:
		last_error = "mundo: los ejércitos no son una lista razonable"
		return null
	var out: Array = []
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			last_error = "mundo: un ejército no es un objeto"
			return null
		var from_id = entry.get("from", null)
		var to_id = entry.get("to", null)
		if typeof(from_id) != TYPE_STRING or typeof(to_id) != TYPE_STRING or not known_ids.has(from_id) or not known_ids.has(to_id) or from_id == to_id:
			last_error = "mundo: ejército con provincias no válidas"
			return null
		var soldiers = Fixed.exact_int(entry.get("soldiers", null))
		var arrive = Fixed.exact_int(entry.get("arrive", null))
		if soldiers == null or soldiers < 1 or arrive == null or arrive < 0 or arrive > steps + TradeScript.MAX_ARRIVAL_AHEAD:
			last_error = "mundo: ejército con soldados o llegada no válidos"
			return null
		var army := {"from": from_id, "to": to_id, "soldiers": soldiers, "arrive": arrive}
		if entry.has("realm"):
			if typeof(entry["realm"]) != TYPE_STRING or not parsed_owners.values().has(entry["realm"]):
				last_error = "mundo: ejército de un reino desconocido"
				return null
			army["realm"] = entry["realm"]
		out.append(army)
	if not out.is_empty() and parsed_owners.is_empty():
		last_error = "mundo: hay ejércitos pero no hay propietarios"
		return null
	return out
