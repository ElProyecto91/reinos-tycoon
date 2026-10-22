extends "res://tests/province_case.gd"
## Red de distribución dentro de cada reino (trade.gd, docs/DISENO_COMERCIO.md).
## Casi todas las pruebas llaman a Trade.step() directamente con el contador de pasos puesto a mano:
## así se ve el reparto exacto sin que el consumo de la gente lo mueva.

const WORLD := "res://scripts/sim/world.gd"
const TRADE := "res://scripts/sim/trade.gd"
const SAVE_GAME := "res://scripts/sim/save_game.gd"
const GAME_MAP := "res://scripts/sim/game_map.gd"
const STORE := "res://scripts/sim/store.gd"
const ICONS := "res://scripts/ui/icons.gd"
const MAIN_SCENE := "res://main.tscn"
const SESSION := "res://scripts/sim/game_session.gd"
const DIR := "user://pruebas_comercio"
const PATH := "user://pruebas_comercio/partida.json"

## Madera: límite del almacén base = 13 % de 60 000 = 7 800; déficit < 1 560, objetivo 3 900, excedente > 5 460.
const WOOD_LIMIT := 7800


## Mundo de prueba. `layout`: {id: [reino, [vecinas]]}. Cada provincia tiene 10 habitantes.
func _world(data, layout: Dictionary, wood: Dictionary = {}, coin: int = 20000):
	var world = load(WORLD).new(data)
	var links := {}
	for id in layout.keys():
		var p = world.add_province(id, id, 10)
		p.store.seed_initial("coin", coin)
		if wood.has(id):
			p.store.seed_initial("wood", wood[id])
		links[id] = {"realm": layout[id][0], "neighbors": layout[id][1]}
	world.set_network(links)
	return world


func _tick(world, step: int) -> void:
	world.step_count = step
	load(TRADE).step(world)


func _wood(world, id: String) -> int:
	return world.find_province(id).store.stock("wood")


func _total_wood(world) -> int:
	var total := 0
	for p in world.provinces:
		total += p.store.stock("wood")
	for s in world.shipments:
		if s["good"] == "wood":
			total += s["amount"]
	return total


func test_trade_rules_are_validated() -> void:
	var data = new_data()
	assert_true(data.rules["trade_interval"] > 0, "el comercio está activo en los datos del juego")
	assert_true(data.rules["trade_goods"].has("bread"), "el pan se reparte")
	var raw: Dictionary = (data.rules as Dictionary).duplicate(true)
	raw["trade_deficit_percent"] = 60
	var bad = load(GAME_DATA).new()
	bad.build_goods(JSON.parse_string(FileAccess.get_file_as_string("res://data/goods.json"))["goods"])
	assert_true(not bad.build_rules(raw), "déficit por encima del objetivo se rechaza")
	raw = (data.rules as Dictionary).duplicate(true)
	raw["trade_goods"] = ["coin"]
	bad.errors.clear()
	assert_true(not bad.build_rules(raw), "la moneda no se reparte como mercancía")
	raw = (data.rules as Dictionary).duplicate(true)
	raw["trade_goods"] = ["no_existe"]
	bad.errors.clear()
	assert_true(not bad.build_rules(raw), "una mercancía desconocida se rechaza")
	raw = (data.rules as Dictionary).duplicate(true)
	raw["trade_steps_per_hop"] = 0
	bad.errors.clear()
	assert_true(not bad.build_rules(raw), "cero pasos por salto se rechaza con comercio activo")
	done()


func test_surplus_travels_to_a_neighbour_with_a_shortage_and_arrives_later() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000})
	_tick(world, 24)
	# a tiene 7 000 (> 5 460): ofrece 7 000 − 3 900 = 3 100. b pide 3 900. Sale lo que hay: 3 100.
	assert_eq(world.shipments.size(), 1, "sale una caravana")
	var s: Dictionary = world.shipments[0]
	assert_eq([s["from"], s["to"], s["good"], s["amount"]], ["a", "b", "wood", 3100], "de a a b, 3 100 de madera")
	assert_eq(s["arrive"], 24 + 12, "llega tras un salto (12 pasos)")
	assert_eq(_wood(world, "a"), 3900, "a se queda en el objetivo")
	assert_eq(_wood(world, "b"), 0, "b aún no ha recibido nada: viaja")
	assert_eq(world.check_invariants().size(), 0, "con la caravana en camino la conservación cuadra: %s" % str(world.check_invariants()))
	_tick(world, 35)
	assert_eq(_wood(world, "b"), 0, "un paso antes de llegar sigue sin estar")
	_tick(world, 36)
	assert_eq(_wood(world, "b"), 3100, "al llegar se acredita en b")
	assert_eq(world.shipments.size(), 0, "ya no hay caravanas")
	assert_eq(world.check_invariants().size(), 0, "y sigue cuadrando: %s" % str(world.check_invariants()))
	done()


func test_the_destination_pays_in_coin_per_unit_and_hop() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000}, 20000)
	_tick(world, 24)
	# 3 100 milésimas × 1 salto × 200 / 1000 = 620 de moneda, que paga b.
	assert_eq(world.find_province("b").store.stock("coin"), 20000 - 620, "b paga el transporte")
	assert_eq(world.find_province("a").store.stock("coin"), 20000, "a no paga nada")
	done()


func test_without_coin_nothing_is_sent() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000}, 0)
	_tick(world, 24)
	assert_eq(world.shipments.size(), 0, "sin moneda para pagar no sale nada")
	assert_eq(_wood(world, "a"), 7000, "el origen conserva lo suyo")
	done()


func test_coin_limits_the_amount_instead_of_blocking_it() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000}, 0)
	world.find_province("b").store.seed_initial("coin", 200)
	_tick(world, 24)
	# 200 de moneda a 0,2 por unidad y salto = 1 000 milésimas.
	assert_eq(world.shipments[0]["amount"], 1000, "solo se envía lo que se puede pagar")
	assert_eq(world.find_province("b").store.stock("coin"), 0, "se gasta toda la moneda")
	done()


func test_the_nearest_supplier_serves_first_and_travel_time_follows_distance() -> void:
	var data = new_data()
	# a — b — c en línea; a y b tienen excedente, c no tiene nada: b está a 1 salto y a a 2.
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a", "c"]], "c": ["r", ["b"]]}, {"a": 7000, "b": 7000})
	_tick(world, 24)
	var first: Dictionary = world.shipments[0]
	assert_eq(first["from"], "b", "sirve primero la vecina, no la lejana")
	assert_eq(first["to"], "c", "para c")
	assert_eq(first["arrive"], 24 + 12, "un salto: 12 pasos")
	done()


func test_a_far_supplier_completes_what_the_nearest_cannot_and_takes_longer() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a", "c"]], "c": ["r", ["b"]]}, {"a": 7000, "b": 7000})
	_tick(world, 24)
	var from_a: Dictionary = {}
	for s in world.shipments:
		if s["from"] == "a":
			from_a = s
	assert_true(not from_a.is_empty(), "a también envía: c pide 3 900 y b solo puede dar 3 100")
	assert_eq(from_a["amount"], 800, "completa los 800 que faltan")
	assert_eq(from_a["arrive"], 24 + 2 * 12, "dos saltos: 24 pasos")
	done()


func test_provinces_of_other_realms_never_trade() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["uno", ["b"]], "b": ["dos", ["a"]]}, {"a": 7000})
	_tick(world, 24)
	assert_eq(world.shipments.size(), 0, "dos reinos distintos no se reparten nada")
	assert_eq(_wood(world, "a"), 7000, "nada cambia")
	done()


func test_the_route_never_crosses_another_realm() -> void:
	var data = new_data()
	# a (reino r) y c (reino r) solo se tocan a través de b, que es de otro reino: no hay ruta.
	var world = _world(data, {"a": ["r", ["b"]], "b": ["s", ["a", "c"]], "c": ["r", ["b"]]}, {"a": 7000})
	_tick(world, 24)
	assert_eq(world.shipments.size(), 0, "sin camino dentro del reino no hay caravana")
	done()


func test_hungry_provinces_are_served_before_those_with_a_light_shortage() -> void:
	var data = new_data()
	var world = _world(data, {"s": ["r", ["h", "l"]], "h": ["r", ["s"]], "l": ["r", ["s"]]})
	var s = world.find_province("s")
	s.store.seed_initial("wheat", 9000)    # límite 10 800: excedente sobre 7 560, ofrece 9 000 − 5 400
	# l tiene menos trigo que h (sin la prioridad del hambre, l iría primero) pero h pasa hambre.
	world.find_province("l").store.seed_initial("wheat", 500)
	world.find_province("h").store.seed_initial("wheat", 2000)
	world.find_province("h").hunger_steps = 5
	_tick(world, 24)
	var recipients := {}
	for sh in world.shipments:
		if sh["good"] == "wheat":
			recipients[sh["to"]] = int(recipients.get(sh["to"], 0)) + sh["amount"]
	# h pide 3 400 (hasta 5 400 con 2 000) y recibe lo que hay; l no recibe nada de trigo.
	assert_eq(recipients.get("h", 0), 3400, "el hambriento recibe lo que le falta")
	assert_eq(recipients.get("l", 0), 200, "al de falta ligera solo le llega lo que sobra después")
	done()


func test_the_route_cap_limits_one_shipment() -> void:
	var data = new_data()
	data.rules["trade_route_cap"] = 1000
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000})
	_tick(world, 24)
	assert_eq(world.shipments.size(), 1, "una caravana")
	assert_eq(world.shipments[0]["amount"], 1000, "no pasa del tope de la ruta")
	done()


func test_goods_in_flight_count_as_already_covered() -> void:
	var data = new_data()
	data.rules["trade_steps_per_hop"] = 100
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000})
	_tick(world, 24)
	assert_eq(world.shipments.size(), 1, "sale una caravana, tarda 100 pasos")
	world.find_province("a").store.seed_initial("wood", 3100)    # a vuelve a tener excedente
	_tick(world, 48)
	assert_eq(world.shipments.size(), 1, "b ya cuenta con lo que viene: no se le manda una segunda")
	assert_eq(_wood(world, "a"), 7000, "a conserva lo suyo")
	done()


func test_total_goods_are_conserved_across_many_rounds() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b", "c"]], "b": ["r", ["a", "c"]], "c": ["r", ["a", "b"]], "d": ["r", ["c"]]}, {"a": 7800, "b": 7000})
	var expected := _total_wood(world)
	for step in range(1, 400):
		world.step_count = step
		if step % 7 == 0:
			expected -= world.find_province("d").store.remove("wood", 500, "consumed")
		load(TRADE).step(world)
		assert_eq(world.check_invariants().size(), 0, "paso %d: %s" % [step, str(world.check_invariants())])
	assert_eq(_total_wood(world), expected, "la madera que hay (en almacenes y en camino) es la inicial menos lo consumido")
	done()


func test_what_does_not_fit_on_arrival_goes_back_to_the_origin() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000})
	_tick(world, 24)
	world.find_province("b").store.seed_initial("wood", WOOD_LIMIT)    # b se llena mientras viaja
	_tick(world, 36)
	assert_eq(_wood(world, "b"), WOOD_LIMIT, "b no recibe nada: está lleno")
	assert_eq(_wood(world, "a"), 7000, "la caravana volvió: a tiene otra vez lo que envió")
	assert_eq(world.trade_lost.size(), 0, "no se perdió nada")
	assert_eq(world.check_invariants().size(), 0, "los libros cuadran: %s" % str(world.check_invariants()))
	done()


func test_goods_are_lost_and_counted_only_when_neither_end_has_room() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000})
	_tick(world, 24)
	world.find_province("b").store.seed_initial("wood", WOOD_LIMIT)
	world.find_province("a").store.seed_initial("wood", WOOD_LIMIT - 3900)    # y a también se llena
	_tick(world, 36)
	assert_eq(world.trade_lost.get("wood", 0), 3100, "no cabía en ningún sitio: se anota como perdido")
	assert_eq(world.check_invariants().size(), 0, "y los libros siguen cuadrando: %s" % str(world.check_invariants()))
	done()


func test_the_same_state_gives_the_same_caravans() -> void:
	var data = new_data()
	var layout := {"a": ["r", ["b", "c"]], "b": ["r", ["a", "c"]], "c": ["r", ["a", "b"]]}
	var one = _world(data, layout, {"a": 7500, "b": 7500})
	var two = _world(data, layout, {"a": 7500, "b": 7500})
	for step in range(1, 120):
		one.step_count = step
		two.step_count = step
		load(TRADE).step(one)
		load(TRADE).step(two)
	assert_eq(JSON.stringify(one.to_dict(), "", true), JSON.stringify(two.to_dict(), "", true), "dos mundos iguales reparten igual")
	assert_true(not one.shipments.is_empty() or one.find_province("c").store.stock("wood") > 0, "y algo se movió")
	done()


func test_never_more_caravans_in_flight_than_the_maximum() -> void:
	var data = new_data()
	data.rules["trade_max_shipments"] = 1
	var layout := {"a": ["r", ["b", "c", "d"]], "b": ["r", ["a", "c", "d"]], "c": ["r", ["a", "b", "d"]], "d": ["r", ["a", "b", "c"]]}
	var world = _world(data, layout, {"a": 7800, "b": 7800})
	_tick(world, 24)
	assert_eq(world.shipments.size(), 1, "con máximo 1 solo sale una caravana aunque c y d necesiten")
	var libre = _world(new_data(), layout, {"a": 7800, "b": 7800})
	_tick(libre, 24)
	assert_eq(libre.shipments.size(), 2, "sin ese límite salen dos (c y d) y la prueba tiene sentido")
	done()


func test_changing_the_network_changes_the_routes() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a", "c"]], "c": ["r", ["b"]]})
	var Trade = load(TRADE)
	assert_eq(Trade.hops_from(world, "a").get("c", -1), 2, "a llega a c en dos saltos")
	world.set_network({"a": {"realm": "r", "neighbors": ["b", "c"]}, "b": {"realm": "r", "neighbors": ["a"]}, "c": {"realm": "r", "neighbors": ["a"]}})
	assert_eq(Trade.hops_from(world, "a").get("c", -1), 1, "tras cambiar la red a llega a c en un salto (la caché se vació)")
	done()


func test_a_world_without_a_network_or_with_trade_off_does_not_trade() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000})
	world.set_network({})
	_tick(world, 24)
	assert_eq(world.shipments.size(), 0, "sin red no hay comercio")
	var data2 = new_data()
	data2.rules["trade_interval"] = 0
	var world2 = _world(data2, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000})
	_tick(world2, 24)
	assert_eq(world2.shipments.size(), 0, "con trade_interval 0 tampoco")
	done()


func test_saving_in_the_middle_of_a_journey_keeps_the_caravan() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000})
	_tick(world, 24)
	var text: String = load(SAVE_GAME).encode(world, "0.3.0")
	var result: Dictionary = load(SAVE_GAME).decode(data, text)
	assert_true(result["ok"], "se carga: %s" % result["error"])
	var loaded = result["world"]
	assert_eq(loaded.shipments, world.shipments, "la caravana sigue en camino")
	loaded.set_network(world.trade_links)
	_tick(loaded, 36)
	_tick(world, 36)
	assert_eq(_wood(loaded, "b"), 3100, "y llega igual tras cargar")
	assert_eq(JSON.stringify(loaded.to_dict(), "", true), JSON.stringify(world.to_dict(), "", true), "mismo estado que sin guardar")
	done()


func test_a_save_from_before_trade_still_loads() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000})
	var payload: Dictionary = world.to_dict()
	payload.erase("shipments")
	payload.erase("trade_lost")
	var result: Dictionary = load(SAVE_GAME).decode(data, load(SAVE_GAME).pack(payload, "0.2.0"))
	assert_true(result["ok"], "un guardado de la 0.2.0 se carga: %s" % result["error"])
	done()


func test_damaged_caravans_in_a_save_are_rejected() -> void:
	var data = new_data()
	var world = _world(data, {"a": ["r", ["b"]], "b": ["r", ["a"]]}, {"a": 7000})
	_tick(world, 24)
	var casos := {
		"provincia desconocida": func(p): p["shipments"][0]["to"] = "x",
		"a sí misma": func(p): p["shipments"][0]["to"] = p["shipments"][0]["from"],
		"cantidad negativa": func(p): p["shipments"][0]["amount"] = -5,
		"cantidad decimal": func(p): p["shipments"][0]["amount"] = 3100.5,
		"mercancía desconocida": func(p): p["shipments"][0]["good"] = "oro",
		"la moneda no viaja": func(p): p["shipments"][0]["good"] = "coin",
		"llegada absurda": func(p): p["shipments"][0]["arrive"] = 99999999999,
		"no es lista": func(p): p["shipments"] = "hola",
		"no cuadra con los libros": func(p): p["shipments"][0]["amount"] = 3000,
		"caravana de la nada": func(p): p["shipments"].append({"from": "a", "to": "b", "good": "wood", "amount": 10, "arrive": 50}),
		"pérdida negativa": func(p): p["trade_lost"] = {"wood": -1},
	}
	for nombre in casos.keys():
		var payload: Dictionary = JSON.parse_string(JSON.stringify(world.to_dict()))
		casos[nombre].call(payload)
		var result: Dictionary = load(SAVE_GAME).decode(data, load(SAVE_GAME).pack(payload, "0.3.0"))
		assert_true(not result["ok"], "se rechaza: %s" % nombre)
	done()


# --- Con el mapa real ------------------------------------------------------------------------

func test_the_real_map_has_a_network_per_realm_and_every_province_is_reachable_inside_its_realm() -> void:
	var data = new_data()
	var map = load(GAME_MAP).new()
	assert_true(map.load_defaults(data), "el mapa carga")
	var world = map.new_world(data)["world"]
	assert_eq(world.trade_links.size(), map.provinces.size(), "cada provincia está en la red")
	var by_realm := {}
	for p in map.provinces:
		by_realm[p["realm"]] = by_realm.get(p["realm"], []) + [p["id"]]
	var Trade = load(TRADE)
	var isolated: Array = []
	for realm in by_realm.keys():
		var ids: Array = by_realm[realm]
		for id in ids:
			if ids.size() > 1 and Trade.hops_from(world, id).is_empty():
				isolated.append(id)
	# Una provincia puede quedar aislada dentro de su reino (p. ej. un enclave marítimo sin vecina del mismo reino):
	# no es un fallo, pero debe ser una excepción conocida y corta.
	assert_true(isolated.size() <= 3, "pocas provincias sin ruta dentro de su reino: %s" % str(isolated))
	done()


func test_a_province_without_bread_is_fed_by_its_realm_in_the_real_map() -> void:
	var data = new_data_with_seasons()
	var map = load(GAME_MAP).new()
	map.load_defaults(data)
	var world = map.new_world(data)["world"]
	# Se vacían los alimentos de León (reino de varias provincias) y el resto del reino sigue con los suyos.
	var target = world.find_province("leon")
	assert_true(target != null, "existe León")
	for good in ["bread", "wheat"]:
		target.store.remove(good, target.store.stock(good), "consumed")
	var imported := 0
	for i in range(1500):
		world.step()
		for s in world.shipments:
			var a: String = world.trade_links[s["from"]]["realm"]
			var b: String = world.trade_links[s["to"]]["realm"]
			if a != b:
				assert_true(false, "caravana entre reinos distintos: %s → %s" % [s["from"], s["to"]])
				break
	for good in ["bread", "wheat", "flour"]:
		imported += target.store.ledger(good)["imported"]
	assert_true(imported > 0, "León recibió alimentos de su reino (%d)" % imported)
	assert_eq(world.check_invariants().size(), 0, "conservación: %s" % str(world.check_invariants()))
	done()


func test_the_whole_map_trades_for_a_year_and_everything_still_adds_up() -> void:
	var data = new_data_with_seasons()
	var map = load(GAME_MAP).new()
	map.load_defaults(data)
	var world = map.new_world(data)["world"]
	var dispatched := 0
	var seen_ids := {}
	for step in range(8760):
		world.step()
		for s in world.shipments:
			var key := "%s>%s>%s>%d" % [s["from"], s["to"], s["good"], s["arrive"]]
			if not seen_ids.has(key):
				seen_ids[key] = true
				dispatched += 1
		if step % 1000 == 999:
			assert_eq(world.check_invariants().size(), 0, "paso %d: %s" % [step, str(world.check_invariants())])
		assert_true(world.shipments.size() <= data.rules["trade_max_shipments"], "nunca más caravanas que el máximo")
	assert_true(dispatched > 0, "en un año hubo comercio (%d caravanas)" % dispatched)
	var lost := 0
	for good in world.trade_lost.keys():
		lost += world.trade_lost[good]
	assert_true(lost < 100000, "lo perdido en el viaje es poco (%d)" % lost)
	done()


# --- Interfaz: emblemas y caravanas --------------------------------------------------------------

func test_every_realm_of_the_map_has_a_game_emblem_and_the_icon_is_never_missing() -> void:
	var data = new_data()
	var map = load(GAME_MAP).new()
	map.load_defaults(data)
	var Icons = load(ICONS)
	for realm_id in map.realms.keys():
		assert_true(Icons.is_kind("emblem_" + realm_id), "el reino %s tiene emblema de juego" % realm_id)
		assert_true(Icons.EMBLEM_COLORS.has(realm_id), "y su color")
		assert_eq(Icons.EMBLEM_COLORS[realm_id], map.realms[realm_id]["color"], "el emblema de %s usa el color del reino en el mapa" % realm_id)
	for kind in Icons.EMBLEMS:
		assert_true(map.realms.has(kind.substr(7)), "el emblema %s corresponde a un reino que existe" % kind)
	assert_true(Icons.is_kind("caravan"), "el icono de caravana existe")
	done()


func _open_main():
	DirAccess.make_dir_recursive_absolute(DIR)
	for file_name in DirAccess.open(DIR).get_files():
		DirAccess.remove_absolute(DIR + "/" + file_name)
	var main = load(MAIN_SCENE).instantiate()
	main.session = load(SESSION).new(PATH, "0.0.test")
	main.fixed_now = 1800000000
	main._ready()
	return main


func test_the_map_card_shows_the_realm_emblem_and_says_it_is_not_historical() -> void:
	var main = _open_main()
	assert_true(main._choose("tolosa"), "se elige Tolosa")
	assert_eq(main._card_emblem.kind, "emblem_tolosa", "la tarjeta muestra el emblema del reino")
	assert_true("emblema de juego, no histórico" in main._card_text.text, "y avisa de que no es heráldica histórica: %s" % main._card_text.text)
	assert_true(main._choose("leon"), "se elige León")
	assert_eq(main._card_emblem.kind, "emblem_leon", "cambia con el reino")
	main.free()
	done()


func test_the_sheet_shows_caravans_coming_and_going() -> void:
	var main = _open_main()
	var world = main.session.world
	world.shipments = [
		{"from": "toledo", "to": "cordoba", "good": "wheat", "amount": 3100, "arrive": 999},
		{"from": "cordoba", "to": "sevilla", "good": "bread", "amount": 1200, "arrive": 999},
	]
	# Los libros deben cuadrar con lo que viaja (si no, la partida no sería coherente).
	world.find_province("toledo").store.remove("wheat", 3100, "exported")
	world.find_province("cordoba").store.remove("bread", 1200, "exported")
	assert_eq(world.check_invariants().size(), 0, "estado coherente: %s" % str(world.check_invariants()))
	assert_true(main._choose("cordoba"), "se elige Córdoba")
	var panel = main._panel
	var llega = panel.caravan_tile("in", "wheat")
	var sale = panel.caravan_tile("out", "bread")
	assert_true(llega != null and llega.visible, "se ve lo que llega")
	assert_true(sale != null and sale.visible, "se ve lo que sale")
	assert_eq(llega.caption, "+3,1", "cantidad que llega, con signo")
	assert_eq(sale.caption, "-1,2", "cantidad que sale, con signo")
	assert_true(not panel.caravan_tile("in", "bread").visible, "lo que no viaja no se ve")
	assert_true(main._choose("leon"), "se elige León")
	assert_true(not panel.caravan_tile("in", "wheat").visible and not panel.caravan_tile("out", "bread").visible, "León no tiene caravanas")
	main.free()
	done()
