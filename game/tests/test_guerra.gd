extends "res://tests/province_case.gd"
## Guerra y conquista (war.gd, docs/DISENO_CONQUISTA.md). Las pruebas llaman a War.step() con el contador de pasos puesto
## a mano para ver el resultado exacto; los parámetros son los del juego (rules.json), que no son datos históricos.

const WORLD := "res://scripts/sim/world.gd"
const WAR := "res://scripts/sim/war.gd"
const TRADE := "res://scripts/sim/trade.gd"
const SAVE_GAME := "res://scripts/sim/save_game.gd"
const GAME_MAP := "res://scripts/sim/game_map.gd"
const MAIN_SCENE := "res://main.tscn"
const SESSION := "res://scripts/sim/game_session.gd"
const DIR := "user://pruebas_guerra"
const PATH := "user://pruebas_guerra/partida.json"

const LINKS := {
	"a": {"realm": "leon", "neighbors": ["b"]},
	"b": {"realm": "leon", "neighbors": ["a", "c"]},
	"c": {"realm": "tolosa", "neighbors": ["b", "d"]},
	"d": {"realm": "tolosa", "neighbors": ["c"]},
}


## Cuatro provincias en fila: a y b del jugador (León), c y d de Tolosa. Cada una con 100 habitantes y monedas.
func _world(data, player_realm: String = "leon"):
	var world = load(WORLD).new(data)
	for id in ["a", "b", "c", "d"]:
		var p = world.add_province(id, id, 100)
		p.store.seed_initial("coin", 20000)
	world.set_network(LINKS)
	world.owners = {"a": "leon", "b": "leon", "c": "tolosa", "d": "tolosa"}
	world.player_realm = player_realm
	return world


func _tick(world, step: int) -> void:
	world.step_count = step
	load(WAR).step(world)


func _soldiers(world) -> int:
	return load(WAR).total_soldiers(world)


func test_war_rules_are_validated() -> void:
	var data = new_data()
	assert_true(data.rules["war_march_steps_per_hop"] > 0, "la guerra está activa en los datos del juego")
	for key in ["war_attack_percent", "war_defense_percent", "war_round_loss_percent", "war_max_rounds"]:
		var raw: Dictionary = (data.rules as Dictionary).duplicate(true)
		raw[key] = 0
		var bad = load(GAME_DATA).new()
		bad.build_goods(JSON.parse_string(FileAccess.get_file_as_string("res://data/goods.json"))["goods"])
		assert_true(not bad.build_rules(raw), "%s = 0 se rechaza" % key)
	var raw2: Dictionary = (data.rules as Dictionary).duplicate(true)
	raw2["war_conquest_unrest"] = int(data.rules["unrest_max"]) + 1
	var bad2 = load(GAME_DATA).new()
	bad2.build_goods(JSON.parse_string(FileAccess.get_file_as_string("res://data/goods.json"))["goods"])
	assert_true(not bad2.build_rules(raw2), "un descontento de conquista por encima del máximo se rechaza")
	done()


func test_resolve_is_deterministic_and_monotonic() -> void:
	var rules: Dictionary = new_data().rules
	var war = load(WAR)
	assert_eq(JSON.stringify(war.resolve(40, 25, rules)), JSON.stringify(war.resolve(40, 25, rules)), "mismo resultado con los mismos datos")
	var last_att := -1
	var last_def := 1000000
	for attackers in range(0, 301, 5):
		var r: Dictionary = war.resolve(attackers, 60, rules)
		assert_true(r["attacker_left"] >= last_att, "más atacantes nunca dejan menos supervivientes (%d)" % attackers)
		assert_true(r["defender_left"] <= last_def, "más atacantes nunca dejan más defensores (%d)" % attackers)
		assert_true(r["attacker_left"] <= attackers and r["defender_left"] <= 60, "nadie sobrevive en mayor número del que empezó")
		assert_true(not (r["won"] and r["defender_left"] > 0), "ganar significa que no queda defensa")
		last_att = r["attacker_left"]
		last_def = r["defender_left"]
	assert_true(war.resolve(300, 60, rules)["won"], "un ejército cinco veces mayor gana")
	assert_true(not war.resolve(20, 60, rules)["won"], "un ejército mucho menor pierde")
	assert_eq(war.resolve(20, 60, rules)["attacker_left"], 0, "y no deja supervivientes")
	done()


func test_resolve_edge_cases() -> void:
	var rules: Dictionary = new_data().rules
	var war = load(WAR)
	var empty: Dictionary = war.resolve(25, 0, rules)
	assert_true(empty["won"] and empty["attacker_left"] == 25 and empty["rounds"] == 0, "sin defensa se entra sin bajas")
	var none: Dictionary = war.resolve(0, 10, rules)
	assert_true(not none["won"] and none["defender_left"] == 10, "sin atacantes no pasa nada")
	assert_true(not war.resolve(0, 0, rules)["won"], "nadie contra nadie no es una conquista")
	var small: Dictionary = war.resolve(10, 3, rules)
	assert_true(small["won"] and small["rounds"] == 3 and small["attacker_left"] == 7, "contra una defensa mínima cada ronda cuesta al menos 1 soldado a cada bando: %s" % str(small))
	var capped := rules.duplicate(true)
	capped["war_max_rounds"] = 1
	var one: Dictionary = war.resolve(100, 100, capped)
	assert_true(not one["won"] and one["rounds"] == 1, "si no se decide en las rondas máximas, aguanta el defensor")
	done()


func test_order_validation() -> void:
	var data = new_data()
	var world = _world(data)
	var war = load(WAR)
	world.find_province("a").recruits = 30
	world.find_province("c").recruits = 30
	assert_eq(war.order_problem(world, "a", "b", 10), "", "refuerzo a una vecina propia")
	assert_true(war.order_problem(world, "a", "c", 10) != "", "c no es vecina de a")
	assert_true(war.order_problem(world, "c", "b", 10) != "", "no se manda desde una provincia ajena")
	assert_true(war.order_problem(world, "a", "a", 10) != "", "no se marcha a la misma provincia")
	assert_true(war.order_problem(world, "a", "b", 31) != "", "no hay tantos soldados")
	assert_true(war.order_problem(world, "a", "b", 0) != "", "al menos un soldado")
	assert_true(war.order_problem(world, "a", "zzz", 1) != "", "provincia desconocida")
	var before := _soldiers(world)
	var bad: Dictionary = war.send(world, "a", "c", 10)
	assert_true(not bad["ok"] and world.armies.is_empty() and _soldiers(world) == before, "una orden no válida no cambia nada")
	var peace = _world(data, "")
	peace.find_province("a").recruits = 30
	assert_true(war.order_problem(peace, "a", "b", 10) != "", "sin reino de jugador no hay guerra")
	var nowhere = _world(data)
	nowhere.owners = {}
	nowhere.find_province("a").recruits = 30
	assert_true(war.order_problem(nowhere, "a", "b", 10) != "", "sin propietarios tampoco")
	done()


func test_march_takes_time_and_reinforcement_joins_the_garrison() -> void:
	var data = new_data()
	var world = _world(data)
	var war = load(WAR)
	world.find_province("a").recruits = 30
	world.step_count = 10
	var sent: Dictionary = war.send(world, "a", "b", 12)
	assert_true(sent["ok"], "se envía")
	assert_eq(world.find_province("a").recruits, 18, "salen de la provincia de origen")
	assert_eq(world.armies.size(), 1, "un ejército en marcha")
	var arrive: int = world.armies[0]["arrive"]
	assert_eq(arrive, 10 + int(data.rules["war_march_steps_per_hop"]), "tarda los pasos por salto")
	_tick(world, arrive - 1)
	assert_eq(world.armies.size(), 1, "todavía no ha llegado")
	assert_eq(world.find_province("b").recruits, 0, "ni refuerza")
	_tick(world, arrive)
	assert_true(world.armies.is_empty(), "llega")
	assert_eq(world.find_province("b").recruits, 12, "y se suma a la guarnición")
	assert_eq(world.battle_count, 0, "entre provincias propias no hay batalla")
	done()


func test_conquest_changes_owner_network_unrest_and_conserves_soldiers() -> void:
	var data = new_data()
	var world = _world(data)
	var war = load(WAR)
	world.find_province("b").recruits = 200
	world.find_province("c").recruits = 20
	var garrison: int = war.garrison_of(world, world.find_province("c"))
	var total_before := _soldiers(world)
	var population_before: int = world.find_province("c").population
	assert_true(war.send(world, "b", "c", 200)["ok"], "se manda el ejército")
	_tick(world, int(world.armies[0]["arrive"]))
	assert_eq(world.owners["c"], "leon", "c pasa a León")
	assert_eq(world.trade_links["c"]["realm"], "leon", "y entra en su red de comercio")
	assert_true(load(TRADE).hops_from(world, "b").has("c"), "b alcanza c por la red del reino")
	assert_true(not load(TRADE).hops_from(world, "d").has("c"), "d ya no alcanza c")
	assert_eq(world.battle_count, 1, "una batalla")
	assert_eq(world.battle_log.size(), 1, "con su informe")
	assert_true(world.battle_log[0]["won"] and world.battle_log[0]["garrison"] == garrison, "el informe recoge victoria y guarnición")
	var c = world.find_province("c")
	assert_eq(c.unrest, int(data.rules["war_conquest_unrest"]), "queda inquieta")
	assert_eq(c.recruits, world.battle_log[0]["attacker_left"], "los supervivientes son su guarnición")
	var militia_dead: int = population_before - c.population
	assert_true(militia_dead > 0, "la milicia que defendía salió de la población")
	assert_eq(_soldiers(world) + world.war_dead - militia_dead, total_before, "los soldados ni aparecen ni desaparecen: las bajas se cuentan (y la milicia no era soldado)")
	assert_true(war.is_player(world, "c"), "ahora manda el jugador")
	done()


func test_soldiers_that_arrive_never_leave_more_workers_than_the_labor_force() -> void:
	var data = new_data()
	var world = _world(data)
	var war = load(WAR)
	var b = world.find_province("b")
	for type_id in ["granary", "farm", "farm", "mill", "bakery", "woodcutter"]:
		b.add_building(type_id)
	b.store.seed_initial("wheat", 6000)
	world.run_steps(5)
	assert_true(b.assigned_labor() > 10, "la provincia tiene trabajadores asignados (%d)" % b.assigned_labor())
	world.find_province("a").recruits = 45
	war.send(world, "a", "b", 45)
	world.step_count = int(world.armies[0]["arrive"])
	war.step(world)
	assert_eq(b.recruits, 45, "llegan los refuerzos")
	assert_true(b.assigned_labor() <= b.labor_force(), "y no sobran trabajadores asignados (%d de %d)" % [b.assigned_labor(), b.labor_force()])
	assert_eq(world.check_invariants().size(), 0, "estado coherente: %s" % str(world.check_invariants()))
	var result: Dictionary = load(SAVE_GAME).decode(data, load(SAVE_GAME).encode(world, "0.5.0"), LINKS)
	assert_true(result["ok"], "y el guardado se puede volver a cargar: %s" % str(result.get("error", "")))
	done()


func test_defeat_costs_the_attackers_and_changes_no_owner() -> void:
	var data = new_data()
	var world = _world(data)
	var war = load(WAR)
	world.find_province("b").recruits = 60
	world.find_province("c").recruits = 100
	var population_before: int = world.find_province("c").population
	var total_before := _soldiers(world)
	war.send(world, "b", "c", 60)
	_tick(world, int(world.armies[0]["arrive"]))
	assert_eq(world.owners["c"], "tolosa", "c sigue siendo de Tolosa")
	assert_true(not world.battle_log[0]["won"] and world.battle_log[0]["attacker_left"] == 0, "derrota sin supervivientes")
	assert_true(world.find_province("c").recruits < 100, "la guarnición también sufre bajas")
	assert_eq(world.find_province("c").population, population_before, "la milicia no se toca si la guarnición aguanta")
	assert_eq(_soldiers(world) + world.war_dead, total_before, "los soldados cuadran")
	done()


func test_militia_losses_come_out_of_the_population_after_the_garrison() -> void:
	var data = new_data()
	var world = _world(data)
	var war = load(WAR)
	world.find_province("b").recruits = 150
	# Sin guarnición: solo defiende la milicia (10 % de 100 habitantes = 10).
	war.send(world, "b", "c", 150)
	_tick(world, int(world.armies[0]["arrive"]))
	assert_eq(world.owners["c"], "leon", "cae")
	assert_true(world.find_province("c").population <= 100 and world.find_province("c").population >= 1, "la población no baja de 1")
	assert_true(world.war_dead > 0, "hay bajas anotadas")
	done()


func test_administration_cost_grows_with_the_empire_and_is_consumed() -> void:
	var data = new_data()
	var world = _world(data)
	var cost: int = data.rules["war_admin_cost"]
	var coin: String = data.rules["currency"]
	_tick(world, 24)
	assert_eq(world.find_province("a").store.stock(coin), 20000 - cost, "con dos provincias cada una paga 1 vez")
	assert_eq(world.find_province("c").store.stock(coin), 20000, "las ajenas no pagan")
	_tick(world, 25)
	assert_eq(world.find_province("a").store.stock(coin), 20000 - cost, "solo se cobra una vez al día")
	world.set_owner("c", "leon")
	_tick(world, 48)
	assert_eq(world.find_province("a").store.stock(coin), 20000 - cost - 2 * cost, "con tres provincias cada una paga 2 veces")
	assert_eq(world.find_province("c").store.stock(coin), 20000 - 2 * cost, "la conquistada también")
	var single = _world(data)
	single.owners = {"a": "leon", "b": "tolosa", "c": "tolosa", "d": "tolosa"}
	_tick(single, 24)
	assert_eq(single.find_province("a").store.stock(coin), 20000, "una sola provincia no paga administración")
	var empty = _world(data)
	assert_eq(empty.check_invariants().size(), 0, "estado coherente: %s" % str(empty.check_invariants()))
	_tick(empty, 24)
	assert_eq(empty.check_invariants().size(), 0, "y lo sigue siendo tras cobrar: %s" % str(empty.check_invariants()))
	done()


func test_rivals_only_defend() -> void:
	var data = new_data()
	var world = _world(data)
	world.find_province("c").recruits = 500
	world.find_province("d").recruits = 500
	world.run_steps(500)
	assert_true(world.armies.is_empty() and world.battle_count == 0, "los rivales no atacan")
	assert_eq(JSON.stringify(world.owners), JSON.stringify({"a": "leon", "b": "leon", "c": "tolosa", "d": "tolosa"}), "nadie cambia de dueño")
	done()


func test_attackable_lists_only_foreign_provinces_next_to_yours() -> void:
	var data = new_data()
	var world = _world(data)
	var war = load(WAR)
	assert_eq(war.attackable(world), ["c"], "solo c toca con las tuyas")
	world.set_owner("c", "leon")
	assert_eq(war.attackable(world), ["d"], "al conquistar c se puede atacar d")
	assert_eq(war.attackable(_world(data, "")).size(), 0, "sin reino de jugador no hay objetivos")
	done()


func test_war_state_survives_save_and_load_in_the_middle_of_a_march() -> void:
	var data = new_data()
	var world = _world(data)
	world.find_province("b").recruits = 90
	world.step_count = 5
	load(WAR).send(world, "b", "c", 60)
	world.set_owner("d", "leon")
	var text: String = load(SAVE_GAME).encode(world, "0.4.0")
	var result: Dictionary = load(SAVE_GAME).decode(data, text, LINKS)
	assert_true(result["ok"], "se carga: %s" % str(result.get("error", "")))
	var loaded = result["world"]
	assert_eq(JSON.stringify(loaded.to_dict(), "", true), JSON.stringify(world.to_dict(), "", true), "mismo estado")
	assert_eq(loaded.trade_links["d"]["realm"], "leon", "la red sigue al propietario tras cargar")
	assert_eq(loaded.armies.size(), 1, "el ejército sigue en marcha")
	world.run_steps(40)
	loaded.run_steps(40)
	assert_eq(JSON.stringify(loaded.to_dict(), "", true), JSON.stringify(world.to_dict(), "", true), "y evoluciona igual que sin guardar")
	done()


func test_invalid_war_data_is_rejected_on_load() -> void:
	var data = new_data()
	var world = _world(data)
	world.find_province("b").recruits = 90
	load(WAR).send(world, "b", "c", 60)
	var good: Dictionary = world.to_dict()
	var cases := {
		"propietario de una provincia desconocida": func(d): d["owners"]["zzz"] = "leon",
		"falta un propietario": func(d): d["owners"].erase("d"),
		"propietario vacío": func(d): d["owners"]["a"] = "",
		"ejército con 0 soldados": func(d): d["armies"][0]["soldiers"] = 0,
		"ejército con provincia desconocida": func(d): d["armies"][0]["to"] = "zzz",
		"ejército hacia sí mismo": func(d): d["armies"][0]["to"] = d["armies"][0]["from"],
		"soldados decimales": func(d): d["armies"][0]["soldiers"] = 2.5,
		"ejércitos que no son lista": func(d): d["armies"] = {},
		"llegada negativa": func(d): d["armies"][0]["arrive"] = -3,
	}
	for label in cases.keys():
		var broken: Dictionary = JSON.parse_string(JSON.stringify(good))
		cases[label].call(broken)
		var fresh = load(WORLD).new(data)
		for id in ["a", "b", "c", "d"]:
			fresh.add_province(id, id, 100)
		fresh.set_network(LINKS)
		assert_true(not fresh.load_dict(broken), "se rechaza: %s" % label)
	var armies_without_owners: Dictionary = JSON.parse_string(JSON.stringify(good))
	armies_without_owners["owners"] = {}
	var fresh2 = load(WORLD).new(data)
	for id in ["a", "b", "c", "d"]:
		fresh2.add_province(id, id, 100)
	assert_true(not fresh2.load_dict(armies_without_owners), "ejércitos sin propietarios se rechazan")
	done()


func test_old_saves_without_owners_still_load_and_have_no_war() -> void:
	var data = new_data()
	var world = _world(data)
	var raw: Dictionary = JSON.parse_string(JSON.stringify(world.to_dict()))
	raw.erase("owners")
	raw.erase("armies")
	raw.erase("player_realm")
	var fresh = load(WORLD).new(data)
	for id in ["a", "b", "c", "d"]:
		fresh.add_province(id, id, 100)
	fresh.set_network(LINKS)
	assert_true(fresh.load_dict(raw), "una partida sin datos de guerra carga: %s" % fresh.last_error)
	assert_true(fresh.owners.is_empty() and fresh.armies.is_empty(), "y empieza sin guerra")
	assert_true(not load(WAR).enabled(fresh), "la guerra queda desactivada")
	assert_true(load(WAR).is_player(fresh, "c"), "el jugador manda donde quiera, como antes")
	done()


func test_the_real_map_starts_with_owners_and_the_player_in_leon() -> void:
	var data = new_data()
	var map = load(GAME_MAP).new()
	assert_true(map.load_defaults(data), "mapa: %s" % str(map.errors))
	var world = map.new_world(data)["world"]
	var war = load(WAR)
	assert_eq(world.player_realm, "leon", "el jugador empieza en León (provisional)")
	assert_eq(world.owners.size(), world.provinces.size(), "todas las provincias tienen propietario")
	for p in world.provinces:
		assert_eq(world.owners[p.id], map.find(p.id)["realm"], "%s empieza con el reino del mapa" % p.id)
	var targets: Array[String] = war.attackable(world)
	assert_true(targets.size() > 0, "hay provincias que atacar")
	for id in targets:
		assert_true(world.owners[id] != "leon", "%s no es de León" % id)
		var touches := false
		for n in world.trade_links[id]["neighbors"]:
			if world.owners[n] == "leon":
				touches = true
		assert_true(touches, "%s toca una provincia de León" % id)
	var free_world = map.new_world(data, "")["world"]
	assert_true(not war.enabled(free_world), "sin reino de jugador no hay guerra")
	done()


func test_a_whole_campaign_on_the_real_map_keeps_everything_consistent() -> void:
	var data = new_data()
	data.rules["war_ai_interval"] = 0     # esta prueba es de la campaña del jugador: los rivales no se arman aquí
	var map = load(GAME_MAP).new()
	assert_true(map.load_defaults(data), "mapa: %s" % str(map.errors))
	var world = map.new_world(data)["world"]
	var war = load(WAR)
	var target: String = war.attackable(world)[0]
	var origin := ""
	for n in world.trade_links[target]["neighbors"]:
		if world.owners[n] == "leon":
			origin = n
	world.find_province(origin).recruits = 4000
	var total_before := _soldiers(world)
	assert_true(war.send(world, origin, target, 4000)["ok"], "se manda un ejército enorme")
	world.run_steps(int(data.rules["war_march_steps_per_hop"]) + 48)
	assert_eq(world.owners[target], "leon", "%s cae" % target)
	assert_eq(world.check_invariants().size(), 0, "estado coherente: %s" % str(world.check_invariants()))
	assert_eq(load(TRADE).check(world).size(), 0, "el comercio sigue cuadrando: %s" % str(load(TRADE).check(world)))
	assert_true(_soldiers(world) <= total_before, "los soldados no se multiplican")
	done()


# --- Interfaz -------------------------------------------------------------------------------------------------

func _open_main():
	DirAccess.make_dir_recursive_absolute(DIR)
	for file_name in DirAccess.open(DIR).get_files():
		DirAccess.remove_absolute(DIR + "/" + file_name)
	var main = load(MAIN_SCENE).instantiate()
	main.session = load(SESSION).new(PATH, "0.0.test")
	main.fixed_now = 1800000000
	main._ready()
	return main


## Una provincia ajena colindante con León y la de León que toca con ella.
func _frontier(world) -> Array:
	var target: String = load(WAR).attackable(world)[0]
	for n in world.trade_links[target]["neighbors"]:
		if world.owners[n] == "leon":
			return [n, target]
	return []


func test_foreign_provinces_are_read_only_and_yours_are_not() -> void:
	var main = _open_main()
	var world = main.session.world
	var pair := _frontier(world)
	assert_true(main._choose(pair[0]), "se elige una provincia propia")
	assert_true(not main._panel.is_read_only(), "la ficha propia se maneja")
	assert_true(main._panel.build_button("house") != null and not main._panel.build_button("house").disabled, "se puede construir")
	assert_true(main._choose(pair[1]), "se elige una ajena")
	assert_true(main._panel.is_read_only(), "la ficha ajena es de solo lectura")
	assert_true("solo se puede mirar" in main._panel.feedback_text(), "y lo dice: %s" % main._panel.feedback_text())
	var button = main._panel.build_button("house")
	assert_true(button.disabled, "no se construye en tierra ajena")
	var projects_before: int = world.find_province(pair[1]).projects.size()
	main._panel._on_build_pressed("house")
	main._panel._on_recruit_pressed()
	assert_eq(world.find_province(pair[1]).projects.size(), projects_before, "ni aunque se fuerce la orden")
	assert_true(main._panel.recruit_button().disabled, "tampoco se recluta")
	main.free()
	done()


func test_the_card_offers_to_attack_only_with_soldiers_next_door() -> void:
	var main = _open_main()
	var world = main.session.world
	var pair := _frontier(world)
	world.find_province(pair[0]).recruits = 0
	for n in world.trade_links[pair[1]]["neighbors"]:
		if world.owners[n] == "leon":
			world.find_province(n).recruits = 0
	main._choose(pair[1])
	assert_true(not main._attack_button.visible, "sin soldados cerca no hay botón")
	assert_true("necesitas soldados" in main._card_text.text, "y se explica: %s" % main._card_text.text)
	world.find_province(pair[0]).recruits = 25
	main._refresh_card()
	assert_true(main._attack_button.visible, "con soldados aparece el botón")
	assert_true("25 soldados" in main._attack_button.text, "con la cifra: %s" % main._attack_button.text)
	main._choose(pair[0])
	assert_true(not main._attack_button.visible, "en tierra propia no se ataca")
	main.free()
	done()


func test_attacking_from_the_card_sends_the_army_and_the_report_pops_up() -> void:
	var main = _open_main()
	var world = main.session.world
	var pair := _frontier(world)
	world.find_province(pair[0]).recruits = 3000
	main._choose(pair[1])
	main._attack_button.pressed.emit()
	assert_eq(world.armies.size(), 1, "sale un ejército")
	assert_eq(world.find_province(pair[0]).recruits, 0, "con todos los soldados de la provincia")
	assert_true(main.has_modal(), "avisa de que se pone en marcha")
	main._close_modal()
	world.run_steps(int(world.data.rules["war_march_steps_per_hop"]))
	assert_eq(world.battle_count, 1, "se libra la batalla")
	main._check_battles()
	assert_true(main.has_modal(), "aparece el informe")
	main._close_modal()
	main._check_battles()
	assert_true(not main.has_modal(), "y no se repite")
	assert_eq(world.owners[pair[1]], "leon", "la provincia cae")
	main._choose(pair[1])
	assert_true(not main._panel.is_read_only(), "y ya se maneja desde su ficha")
	assert_true(not ("solo se puede mirar" in main._panel.feedback_text()), "sin el aviso de solo lectura")
	assert_eq(main._card_emblem.kind, "emblem_leon", "el emblema pasa a ser el del nuevo dueño")
	main.free()
	done()


# --- Murallas ---------------------------------------------------------------------------------------------------

func test_walls_add_a_capped_defense_bonus_only_when_finished() -> void:
	var data = new_data()
	var p = new_province(data)
	assert_eq(p.defense_bonus_percent(), 0, "sin murallas no hay bonus")
	p.add_building("wall")
	assert_eq(p.defense_bonus_percent(), int(data.buildings["wall"]["defense_percent"]), "una muralla da su bonus")
	for i in range(6):
		p.add_building("wall")
	assert_eq(p.defense_bonus_percent(), int(data.rules["war_wall_cap_percent"]), "pero hay un tope")
	var q = new_province(data)
	q.store.seed_initial("wood", 20000)
	q.store.seed_initial("coin", 50000)
	assert_true(q.start_construction("wall"), "se puede empezar una muralla: %s" % q.last_error)
	assert_eq(q.defense_bonus_percent(), 0, "y una obra en curso no defiende todavía")
	done()


func test_walls_make_a_battle_harder_for_the_attacker() -> void:
	var data = new_data()
	var rules: Dictionary = data.rules
	var war = load(WAR)
	var plain: Dictionary = war.resolve(100, 40, rules)
	var walled: Dictionary = war.resolve(100, 40, rules, 80)
	assert_true(plain["won"] and walled["won"], "con 100 atacantes caen las dos")
	assert_true(walled["attacker_left"] < plain["attacker_left"], "pero la muralla cuesta más soldados (%d contra %d)" % [walled["attacker_left"], plain["attacker_left"]])
	assert_true(not war.resolve(60, 40, rules, 80)["won"] and war.resolve(60, 40, rules)["won"], "y con 60 atacantes la muralla marca la diferencia")
	var world = _world(data)
	var c = world.find_province("c")
	var before: int = war.defense_strength(world, c)
	c.add_building("wall")
	c.add_building("wall")
	assert_true(war.defense_strength(world, c) > before, "la defensa que se muestra incluye las murallas")
	done()


func test_a_walled_province_is_defeated_less_easily_in_a_real_march() -> void:
	var data = new_data()
	var war = load(WAR)
	var left := []
	for walls in [0, 2]:
		var world = _world(data)
		for i in range(walls):
			world.find_province("c").add_building("wall")
		world.find_province("c").recruits = 20
		world.find_province("b").recruits = 90
		war.send(world, "b", "c", 90)
		world.step_count = int(world.armies[0]["arrive"])
		war.step(world)
		left.append(world.battle_log[-1]["attacker_left"])
	assert_true(left[1] < left[0], "con murallas sobreviven menos atacantes (%s)" % str(left))
	done()


func test_the_card_offers_reinforcements_from_a_neighbor_and_sends_half() -> void:
	var main = _open_main()
	var world = main.session.world
	var target := ""
	var helper := ""
	for id in world.owners.keys():
		if world.owners[id] != "leon":
			continue
		for n in world.trade_links[id]["neighbors"]:
			if world.owners[n] == "leon":
				target = id
				helper = n
				break
		if target != "":
			break
	assert_true(target != "", "hay dos provincias de León colindantes")
	for id in world.owners.keys():
		world.find_province(id).recruits = 0
	world.find_province(helper).recruits = 21
	main._choose(target)
	assert_true(main._attack_button.visible, "aparece el botón de refuerzo")
	assert_eq(main._attack_button.text, "Reforzar con 11 soldados", "manda la mitad, redondeando hacia arriba")
	main._attack_button.pressed.emit()
	assert_eq(world.armies.size(), 1, "sale el refuerzo")
	assert_eq(world.find_province(helper).recruits, 10, "y la vecina conserva el resto")
	main._close_modal()
	world.run_steps(int(world.data.rules["war_march_steps_per_hop"]))
	assert_eq(world.find_province(target).recruits, 11, "llega a la provincia")
	assert_eq(world.battle_count, 0, "sin batalla")
	main.free()
	done()


func test_the_empty_map_card_shows_how_much_you_rule() -> void:
	var main = _open_main()
	var world = main.session.world
	main._selected_id = ""
	main._refresh_card()
	assert_true("Dominas 4 de %d provincias" % world.provinces.size() in main._card_text.text, "dice cuántas provincias tienes: %s" % main._card_text.text)
	world.find_province("leon").recruits = 7
	main._refresh_card()
	assert_true("con 7 soldados" in main._card_text.text, "y cuántos soldados: %s" % main._card_text.text)
	world.armies = [
		{"from": "leon", "to": "asturias", "soldiers": 5, "arrive": 99, "realm": "leon"},
		{"from": "merida", "to": "zamora", "soldiers": 9, "arrive": 99, "realm": "califato"},
	]
	main._refresh_card()
	assert_true("con 12 soldados" in main._card_text.text, "cuenta los que marchan por ti y no los del enemigo: %s" % main._card_text.text)
	main.free()
	done()
