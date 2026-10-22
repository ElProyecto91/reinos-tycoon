extends RefCounted
## Red de distribución dentro de cada reino (docs/DISENO_COMERCIO.md).
##
## Cada `trade_interval` pasos, en cada reino, lo que sobra en unas provincias viaja a las que
## les falta, sin que el jugador toque nada. Las mercancías tardan en llegar (pasos por salto
## según la distancia en provincias; lo que no cabe al llegar vuelve al origen) y mientras viajan no están en ningún almacén: salen como
## «exportado» de la provincia de origen y entran como «importado» en la de destino. La
## conservación de cada almacén no cambia; la del mundo se comprueba con `check()`:
##   Σ exportado − Σ importado = en camino + perdido en el viaje   (por mercancía)
##
## Todo es entero y determinista: mismo estado, mismas caravanas (empates por orden del mundo).
## Las cifras son parámetros de juego (rules.json, claves trade_*), no datos históricos.
## Un mundo sin `trade_links` (pruebas sueltas) no comercia.

const Fixed := preload("res://scripts/sim/fixed.gd")
const StoreScript := preload("res://scripts/sim/store.gd")

## Cuánto más tarde de lo previsto se acepta una llegada al cargar una partida (pasos)
const MAX_ARRIVAL_AHEAD := 1000000


static func enabled(world) -> bool:
	return int(world.data.rules.get("trade_interval", 0)) > 0 and not world.trade_links.is_empty()


## Un paso del comercio: primero llegan las caravanas, y si toca se reparte de nuevo.
static func step(world) -> void:
	if not enabled(world):
		return
	_deliver(world)
	if world.step_count % int(world.data.rules["trade_interval"]) == 0:
		_distribute(world)


static func _deliver(world) -> void:
	if world.shipments.is_empty():
		return
	var pending: Array = []
	for s in world.shipments:
		if int(s["arrive"]) > world.step_count:
			pending.append(s)
			continue
		var amount: int = s["amount"]
		var accepted := 0
		var dest = world.find_province(s["to"])
		if dest != null:
			accepted = dest.store.add(s["good"], amount, StoreScript.IMPORTED)
		if accepted < amount:
			# No cabe en destino: la caravana vuelve con lo que sobra y lo guarda el origen. Solo si tampoco
			# allí cabe se pierde (y se anota, para que la conservación siga cuadrando).
			var origin = world.find_province(s["from"])
			var returned := 0
			if origin != null:
				returned = origin.store.add(s["good"], amount - accepted, StoreScript.IMPORTED)
			if accepted + returned < amount:
				world.trade_lost[s["good"]] = int(world.trade_lost.get(s["good"], 0)) + amount - accepted - returned
	world.shipments = pending


static func _distribute(world) -> void:
	var rules: Dictionary = world.data.rules
	var order := {}
	for i in range(world.provinces.size()):
		order[world.provinces[i].id] = i
	var by_realm := {}
	for province in world.provinces:
		var link: Dictionary = world.trade_links.get(province.id, {})
		if link.is_empty():
			continue
		var realm: String = link["realm"]
		if not by_realm.has(realm):
			by_realm[realm] = []
		by_realm[realm].append(province)
	var incoming := {}
	for s in world.shipments:
		var key: String = "%s|%s" % [s["to"], s["good"]]
		incoming[key] = int(incoming.get(key, 0)) + int(s["amount"])
	var food := {}
	for item in rules["food_goods"]:
		food[item["good"]] = true
	var realms: Array = by_realm.keys()
	realms.sort()
	for realm in realms:
		var members: Array = by_realm[realm]
		if members.size() < 2:
			continue
		for good in rules["trade_goods"]:
			_distribute_good(world, members, good, incoming, food, order)


static func _distribute_good(world, members: Array, good: String, incoming: Dictionary, food: Dictionary, order: Dictionary) -> void:
	var rules: Dictionary = world.data.rules
	var needs: Array = []
	var offers := {}
	for province in members:
		var limit: int = province.store.limit(good)
		if limit <= 0:
			continue
		var stock: int = province.store.stock(good)
		var coming: int = int(incoming.get("%s|%s" % [province.id, good], 0))
		var target: int = Fixed.percent_of(limit, rules["trade_target_percent"])
		if stock + coming < Fixed.percent_of(limit, rules["trade_deficit_percent"]):
			var hungry := 0 if (food.has(good) and province.hunger_steps > 0) else 1
			needs.append({"p": province, "need": target - stock - coming, "key": [hungry, Fixed.div_floor(stock * 1000, limit), order[province.id]]})
		elif stock > Fixed.percent_of(limit, rules["trade_surplus_percent"]):
			offers[province.id] = {"p": province, "left": stock - target}
	if needs.is_empty() or offers.is_empty():
		return
	needs.sort_custom(func(a, b): return _key_less(a["key"], b["key"]))
	var currency: String = rules["currency"]
	var per_hop: int = rules["trade_cost_per_unit_hop"]
	var route_cap: int = rules["trade_route_cap"]
	for entry in needs:
		var dest = entry["p"]
		var left: int = entry["need"]
		var used := {}      # proveedor -> lo ya enviado por esta ruta en este reparto (tope por ruta)
		while left > 0 and world.shipments.size() < int(rules["trade_max_shipments"]):
			var best = _nearest_supplier(world, dest.id, offers, order, used, route_cap)
			if best == null:
				break
			var hops: int = best["hops"]
			var origin = best["p"]
			var qty: int = mini(mini(left, offers[origin.id]["left"]), route_cap - int(used.get(origin.id, 0)))
			if per_hop > 0:
				var affordable: int = Fixed.div_floor(dest.store.stock(currency) * 1000, hops * per_hop)
				qty = mini(qty, affordable)
			if qty <= 0:
				break
			var cost: int = Fixed.div_ceil(qty * hops * per_hop, 1000)
			if cost > 0:
				dest.store.remove(currency, cost, StoreScript.CONSUMED)
			var sent: int = origin.store.remove(good, qty, StoreScript.EXPORTED)
			used[origin.id] = int(used.get(origin.id, 0)) + qty
			offers[origin.id]["left"] -= qty
			if sent > 0:
				world.shipments.append({"from": origin.id, "to": dest.id, "good": good, "amount": sent, "arrive": world.step_count + hops * int(rules["trade_steps_per_hop"])})
			left -= qty
			if offers[origin.id]["left"] <= 0:
				offers.erase(origin.id)


## El proveedor con excedente más cercano al destino (menos saltos; empate por orden del mundo).
static func _nearest_supplier(world, dest_id: String, offers: Dictionary, order: Dictionary, used: Dictionary, route_cap: int):
	var distances: Dictionary = hops_from(world, dest_id)
	var best = null
	for id in offers.keys():
		if not distances.has(id) or int(used.get(id, 0)) >= route_cap:
			continue
		var h: int = distances[id]
		if best == null or h < best["hops"] or (h == best["hops"] and order[id] < order[best["p"].id]):
			best = {"p": offers[id]["p"], "hops": h}
	return best


static func _key_less(a: Array, b: Array) -> bool:
	for i in range(a.size()):
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


## Saltos desde una provincia a todas las que alcanza sin salir de su reino (1 = vecina).
static func hops_from(world, start_id: String) -> Dictionary:
	if world.hop_cache.has(start_id):
		return world.hop_cache[start_id]
	var result := {}
	if world.trade_links.has(start_id):
		var realm: String = world.trade_links[start_id]["realm"]
		var queue: Array = [start_id]
		var depth := {start_id: 0}
		var head := 0
		while head < queue.size():
			var id: String = queue[head]
			head += 1
			for n in world.trade_links[id]["neighbors"]:
				if world.trade_links.has(n) and world.trade_links[n]["realm"] == realm and not depth.has(n):
					depth[n] = depth[id] + 1
					queue.append(n)
		for id in depth.keys():
			if id != start_id:
				result[id] = depth[id]
	world.hop_cache[start_id] = result
	return result


## Lo que viaja hacia o desde una provincia: {"in": {mercancía: cantidad}, "out": {...}}.
static func summary_for(world, province_id: String) -> Dictionary:
	var incoming := {}
	var outgoing := {}
	for s in world.shipments:
		if s["to"] == province_id:
			incoming[s["good"]] = int(incoming.get(s["good"], 0)) + int(s["amount"])
		if s["from"] == province_id:
			outgoing[s["good"]] = int(outgoing.get(s["good"], 0)) + int(s["amount"])
	return {"in": incoming, "out": outgoing}


## Incoherencias del comercio en el mundo; vacío si todo cuadra.
static func check(world) -> Array[String]:
	var problems: Array[String] = []
	var flow := {}
	for province in world.provinces:
		for good_id in world.data.goods.keys():
			var ledger: Dictionary = province.store.ledger(good_id)
			flow[good_id] = int(flow.get(good_id, 0)) + int(ledger["exported"]) - int(ledger["imported"])
	var traveling := {}
	for s in world.shipments:
		traveling[s["good"]] = int(traveling.get(s["good"], 0)) + int(s["amount"])
	for good_id in world.data.goods.keys():
		var expected: int = int(traveling.get(good_id, 0)) + int(world.trade_lost.get(good_id, 0))
		if int(flow.get(good_id, 0)) != expected:
			problems.append("comercio: de %s han salido y entrado %d de diferencia pero hay %d en camino o perdidas" % [good_id, int(flow.get(good_id, 0)), expected])
	return problems
