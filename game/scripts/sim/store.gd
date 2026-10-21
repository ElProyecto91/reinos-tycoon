extends RefCounted
## Almacén de una provincia. Cantidades enteras en milésimas de unidad.
##
## Lleva un registro de movimientos para poder comprobar en cualquier momento que no
## se crean ni se pierden recursos:
##   existencias = iniciales + producción + importaciones - consumo - exportaciones - pérdidas
##
## La capacidad es única y se reparte entre las mercancías físicas. Además, cada
## mercancía física puede ocupar como mucho su parte ("share", en porcentaje de la
## capacidad); si la suma de partes no pasa de 100, ninguna mercancía puede dejar el
## almacén sin sitio para las demás. Las mercancías no físicas (moneda) no ocupan espacio.

const Fixed := preload("res://scripts/sim/fixed.gd")

const PRODUCED := "produced"
const IMPORTED := "imported"
const CONSUMED := "consumed"
const EXPORTED := "exported"
const LOST := "lost"
const UNLIMITED := 1 << 60

const LEDGER_KEYS: Array[String] = ["initial", "produced", "imported", "consumed", "exported", "lost"]
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
		_ledger[good_id] = _zero_ledger()


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


## Cantidad máxima de esa mercancía física según su parte de la capacidad.
func limit(good_id: String) -> int:
	if not _goods.has(good_id) or not _goods[good_id]["physical"]:
		return 0
	return Fixed.percent_of(capacity, _goods[good_id].get("share", 100))


## Cuánto más cabe de esa mercancía (por espacio total y por su parte). La no física no tiene tope.
## `extra_free` suma espacio que se va a liberar.
func room(good_id: String, extra_free: int = 0) -> int:
	if not _goods.has(good_id):
		return 0
	if not _goods[good_id]["physical"]:
		return UNLIMITED
	return mini(free_space() + extra_free, maxi(limit(good_id) - _stock[good_id], 0))


## true si al menos una de las cantidades positivas cabe por sí sola, o si no hay ninguna
## positiva. Sirve para saber si un edificio con varios productos puede entregar algo.
func can_fit_any(amounts: Dictionary, extra_free: int = 0) -> bool:
	var positive := false
	for good_id in amounts.keys():
		if amounts[good_id] <= 0:
			continue
		positive = true
		if amounts[good_id] <= room(good_id, extra_free):
			return true
	return not positive


## true si todas las cantidades caben a la vez. `extra_free` suma espacio que se va a liberar.
func can_fit(amounts: Dictionary, extra_free: int = 0) -> bool:
	var total := 0
	for good_id in amounts.keys():
		if not _goods.has(good_id) or not _goods[good_id]["physical"]:
			continue
		if amounts[good_id] > maxi(limit(good_id) - _stock[good_id], 0):
			return false
		total += amounts[good_id]
	return total <= free_space() + extra_free


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
	for good_id in _stock.keys():
		if _goods[good_id]["physical"] and _stock[good_id] > limit(good_id):
			problems.append("%s: existencias %d por encima de su parte de almacén %d" % [good_id, _stock[good_id], limit(good_id)])
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
	return mini(amount, room(good_id))


func _zero_ledger() -> Dictionary:
	var entry := {}
	for key in LEDGER_KEYS:
		entry[key] = 0
	return entry


## Estado para guardar: capacidad, existencias y libro de movimientos.
func to_dict() -> Dictionary:
	var ledgers := {}
	for good_id in _ledger.keys():
		ledgers[good_id] = _ledger[good_id].duplicate()
	return {"capacity": capacity, "stock": _stock.duplicate(), "ledger": ledgers}


## Carga un estado guardado. Si no es válido devuelve false, deja el motivo en `last_error`
## y no cambia nada. Las mercancías que falten en el guardado se toman como cero;
## las desconocidas se rechazan.
func load_dict(raw: Variant) -> bool:
	last_error = ""
	if typeof(raw) != TYPE_DICTIONARY:
		last_error = "almacén: no es un objeto"
		return false
	var new_capacity = Fixed.exact_int(raw.get("capacity", null))
	if new_capacity == null or new_capacity < 0:
		last_error = "almacén: capacidad no válida"
		return false
	var stock_raw = raw.get("stock", null)
	var ledger_raw = raw.get("ledger", null)
	if typeof(stock_raw) != TYPE_DICTIONARY or typeof(ledger_raw) != TYPE_DICTIONARY:
		last_error = "almacén: faltan las existencias o el libro de movimientos"
		return false
	var new_stock := {}
	var new_ledger := {}
	for good_id in _goods.keys():
		new_stock[good_id] = 0
		new_ledger[good_id] = _zero_ledger()
	for good_id in stock_raw.keys():
		if not _goods.has(good_id):
			last_error = "almacén: mercancía desconocida en las existencias (%s)" % str(good_id)
			return false
		var amount = Fixed.exact_int(stock_raw[good_id])
		if amount == null or amount < 0:
			last_error = "almacén: existencias no válidas de %s" % str(good_id)
			return false
		new_stock[good_id] = amount
	for good_id in ledger_raw.keys():
		if not _goods.has(good_id):
			last_error = "almacén: mercancía desconocida en el libro (%s)" % str(good_id)
			return false
		var entry = ledger_raw[good_id]
		if typeof(entry) != TYPE_DICTIONARY:
			last_error = "almacén: libro no válido de %s" % str(good_id)
			return false
		for key in LEDGER_KEYS:
			var value = Fixed.exact_int(entry.get(key, null))
			if value == null or value < 0:
				last_error = "almacén: %s.%s no válido en el libro" % [str(good_id), key]
				return false
			new_ledger[good_id][key] = value
	var old_capacity := capacity
	var old_stock := _stock
	var old_ledger := _ledger
	capacity = new_capacity
	_stock = new_stock
	_ledger = new_ledger
	var problems := check_conservation()
	if not problems.is_empty():
		capacity = old_capacity
		_stock = old_stock
		_ledger = old_ledger
		last_error = "almacén incoherente: %s" % problems[0]
		return false
	return true
