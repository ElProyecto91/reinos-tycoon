extends RefCounted
## Almacén de una provincia. Cantidades enteras en milésimas de unidad.
##
## Lleva un registro de movimientos para poder comprobar en cualquier momento que no
## se crean ni se pierden recursos:
##   existencias = iniciales + producción + importaciones - consumo - exportaciones - pérdidas
##
## La capacidad es única y se reparte entre las mercancías físicas. Las mercancías
## no físicas (moneda) no ocupan espacio.

const PRODUCED := "produced"
const IMPORTED := "imported"
const CONSUMED := "consumed"
const EXPORTED := "exported"
const LOST := "lost"

const INCOMING: Array[String] = [PRODUCED, IMPORTED]
const OUTGOING: Array[String] = [CONSUMED, EXPORTED, LOST]

var capacity: int = 0
## Motivo del último rechazo (vacío si la última operación fue válida)
var last_error: String = ""

var _goods: Dictionary = {}
var _stock: Dictionary = {}
var _ledger: Dictionary = {}


func _init(goods: Dictionary, capacity_milli: int) -> void:
	_goods = goods
	capacity = capacity_milli
	for good_id in _goods.keys():
		_stock[good_id] = 0
		_ledger[good_id] = {"initial": 0, "produced": 0, "imported": 0, "consumed": 0, "exported": 0, "lost": 0}


func stock(good_id: String) -> int:
	return _stock.get(good_id, 0)


func used_space() -> int:
	var total := 0
	for good_id in _stock.keys():
		if _goods[good_id]["physical"]:
			total += _stock[good_id]
	return total


func free_space() -> int:
	return maxi(capacity - used_space(), 0)


## Cambia la capacidad. Se rechaza si dejaría las existencias por encima de ella.
func set_capacity(new_capacity: int) -> bool:
	last_error = ""
	if new_capacity < 0 or new_capacity < used_space():
		last_error = "la capacidad no puede ser negativa ni menor que el espacio ya usado"
		return false
	capacity = new_capacity
	return true


## Existencias de partida al crear una partida. Devuelve lo que cabe.
func seed_initial(good_id: String, amount: int) -> int:
	var accepted := _accept(good_id, amount)
	if accepted > 0:
		_stock[good_id] += accepted
		_ledger[good_id]["initial"] += accepted
	return accepted


## Entrada de mercancía (kind: PRODUCED o IMPORTED). Devuelve la cantidad realmente guardada.
func add(good_id: String, amount: int, kind: String) -> int:
	if not INCOMING.has(kind):
		last_error = "tipo de entrada no válido: %s" % kind
		return 0
	var accepted := _accept(good_id, amount)
	if accepted > 0:
		_stock[good_id] += accepted
		_ledger[good_id][kind] += accepted
	return accepted


## Salida de mercancía (kind: CONSUMED, EXPORTED o LOST). Devuelve la cantidad realmente retirada.
func remove(good_id: String, amount: int, kind: String) -> int:
	last_error = ""
	if not OUTGOING.has(kind):
		last_error = "tipo de salida no válido: %s" % kind
		return 0
	if not _goods.has(good_id):
		last_error = "mercancía desconocida: %s" % good_id
		return 0
	if amount < 0:
		last_error = "la cantidad no puede ser negativa"
		return 0
	var removed := mini(amount, _stock[good_id])
	if removed > 0:
		_stock[good_id] -= removed
		_ledger[good_id][kind] += removed
	return removed


## true si hay existencias para todo el coste {mercancía: cantidad}.
func can_afford(costs: Dictionary) -> bool:
	for good_id in costs.keys():
		if stock(good_id) < int(costs[good_id]):
			return false
	return true


func ledger(good_id: String) -> Dictionary:
	if not _ledger.has(good_id):
		return {}
	return _ledger[good_id].duplicate()


## Lista de incoherencias; vacía si el almacén es correcto.
func check_conservation() -> Array[String]:
	var problems: Array[String] = []
	for good_id in _stock.keys():
		var entry: Dictionary = _ledger[good_id]
		var expected: int = entry["initial"] + entry["produced"] + entry["imported"] - entry["consumed"] - entry["exported"] - entry["lost"]
		if _stock[good_id] != expected:
			problems.append("%s: existencias %d, esperadas %d" % [good_id, _stock[good_id], expected])
		if _stock[good_id] < 0:
			problems.append("%s: existencias negativas" % good_id)
	if used_space() > capacity:
		problems.append("espacio usado %d por encima de la capacidad %d" % [used_space(), capacity])
	return problems


func _accept(good_id: String, amount: int) -> int:
	last_error = ""
	if not _goods.has(good_id):
		last_error = "mercancía desconocida: %s" % good_id
		return 0
	if amount < 0:
		last_error = "la cantidad no puede ser negativa"
		return 0
	if _goods[good_id]["physical"]:
		return mini(amount, free_space())
	return amount
