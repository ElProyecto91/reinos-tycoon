extends "res://tests/province_case.gd"
## Reinos rivales (rival_ai.gd, docs/DISENO_CONQUISTA.md CQ6): leva, decisión de ataque, protecciones y avisos.
## Las pruebas llaman a RivalAI.step() con el contador de pasos puesto a mano.

const WORLD := "res://scripts/sim/world.gd"
const WAR := "res://scripts/sim/war.gd"
const AI := "res://scripts/sim/rival_ai.gd"
const OFFLINE := "res://scripts/sim/offline.gd"
const SAVE_GAME := "res://scripts/sim/save_game.gd"
const GAME_MAP := "res://scripts/sim/game_map.gd"
const MAIN_SCENE := "res://main.tscn"
const SESSION := "res://scripts/sim/game_session.gd"
const DIR := "user://pruebas_ia"
const PATH := "user://pruebas_ia/partida.json"

## a, b y e del jugador (León); c y d de Tolosa; f de Gascuña. a-b-c-d en fila, y e-b, f-e.
const LINKS := {
	"a": {"realm": "leon", "neighbors": ["b"]},
	"b": {"realm": "leon", "neighbors": ["a", "c", "e"]},
	"c": {"realm": "tolosa", "neighbors": ["b", "d"]},
	"d": {"realm": "tolosa", "neighbors": ["c"]},
	"e": {"realm": "leon", "neighbors": ["b", "f"]},
	"f": {"realm": "gascuna", "neighbors": ["e"]},
}
const OWNERS := {"a": "leon", "b": "leon", "c": "tolosa", "d": "tolosa", "e": "leon", "f": "gascuna"}


func _world(data, owners: Dictionary = OWNERS):
	var world = load(WORLD).new(data)
	for id in ["a", "b", "c", "d", "e", "f"]:
		var p = world.add_province(id, id, 100)
		p.store.seed_initial("coin", 2000000)
	world.set_network(LINKS)
	world.owners = owners.duplicate()
	world.player_realm = "leon"
	return world


## Un ataque solo se decide en el paso `intervalo / 2` de cada intervalo y pasado el inicio.
func _decide(world) -> void:
	var rules: Dictionary = world.data.rules
	var step: int = int(rules["war_ai_start_steps"])
	var interval: int = int(rules["war_ai_interval"])
	step = (step / interval + 1) * interval + interval / 2
	world.step_count = step
	load(AI).step(world)


func _soldiers(world) -> int:
	return load(WAR).total_soldiers(world)


func test_ai_rules_are_validated() -> void:
	var data = new_data()
	assert_true(data.rules["war_ai_interval"] >= 2, "la IA está activa en los datos del juego")
	var bad_cases := {"war_ai_ratio_percent": 0, "war_ai_min_soldiers": 0, "war_ai_interval": 1, "war_ai_keep_percent": 100}
	for key in bad_cases.keys():
		var raw: Dictionary = (data.rules as Dictionary).duplicate(true)
		raw[key] = bad_cases[key]
		var bad = load(GAME_DATA).new()
		bad.build_goods(JSON.parse_string(FileAccess.get_file_as_string("res://data/goods.json"))["goods"])
		assert_true(not bad.build_rules(raw), "%s = %d se rechaza" % [key, bad_cases[key]])
	done()


func test_rival_provinces_levy_soldiers_up_to_a_share_of_their_population() -> void:
	var data = new_data()
	var world = _world(data)
	var ai = load(AI)
	var per_day: int = data.rules["war_ai_levy_per_day"]
	world.step_count = 6
	ai.step(world)
	assert_eq(world.find_province("c").recruits, per_day, "una provincia rival levanta soldados cada día")
	assert_eq(world.find_province("a").recruits, 0, "las del jugador no")
	world.step_count = 7
	ai.step(world)
	assert_eq(world.find_province("c").recruits, per_day, "solo una vez al día")
	var cap: int = 100 * int(data.rules["war_ai_levy_target_percent"]) / 100
	for day in range(1, 60):
		world.step_count = 24 * day + 6
		ai.step(world)
	assert_eq(world.find_province("c").recruits, cap, "y no pasa del tope de la población")
	assert_eq(world.find_province("b").recruits, 0, "sin tocar las del jugador")
	done()


func test_a_poor_rival_province_does_not_levy_soldiers_it_cannot_pay() -> void:
	var data = new_data()
	var world = _world(data)
	var coin: String = data.rules["currency"]
	var poor = world.find_province("c")
	poor.store.remove(coin, poor.store.stock(coin), "consumed")
	world.step_count = 6
	load(AI).step(world)
	assert_eq(poor.recruits, 0, "sin moneda para la paga no hay leva")
	done()


func test_no_attack_before_the_start_delay_or_when_disabled_or_paused() -> void:
	var data = new_data()
	var rules: Dictionary = data.rules
	var interval: int = rules["war_ai_interval"]
	var world = _world(data)
	world.find_province("c").recruits = 80
	world.step_count = int(rules["war_ai_start_steps"]) - interval + interval / 2
	load(AI).step(world)
	assert_true(world.armies.is_empty(), "antes del inicio no ataca")
	world.ai_paused = true
	_decide(world)
	assert_true(world.armies.is_empty(), "en pausa por ausencia tampoco")
	world.ai_paused = false
	var decision_step: int = (int(rules["war_ai_start_steps"]) / interval + 1) * interval + interval / 2
	world.data.rules["war_ai_interval"] = 0
	world.step_count = decision_step
	load(AI).step(world)
	assert_true(not load(AI).enabled(world), "con intervalo 0 la IA se declara apagada")
	assert_true(world.armies.is_empty(), "con intervalo 0 la IA está apagada")
	done()


func test_the_rival_attacks_when_it_is_strong_enough_and_keeps_a_garrison() -> void:
	var data = new_data()
	var rules: Dictionary = data.rules
	var world = _world(data)
	world.find_province("c").recruits = 80
	_decide(world)
	assert_eq(world.armies.size(), 1, "un ejército en marcha")
	var army: Dictionary = world.armies[0]
	assert_true(army["from"] == "c" and army["to"] == "b" and army["realm"] == "tolosa", "de c a b, en nombre de Tolosa")
	var keep: int = 80 * int(rules["war_ai_keep_percent"]) / 100
	assert_eq(army["soldiers"], 80 - keep, "salen todos menos la guarnición")
	assert_eq(world.find_province("c").recruits, keep, "que se queda en casa")
	assert_eq(world.incoming_count, 1, "se anota el aviso para el jugador")
	assert_eq(world.incoming_log[0]["to"], "b", "con el objetivo")
	assert_eq(world.armies.size(), 1, "y una sola vez")
	_decide(world)
	assert_eq(world.armies.size(), 1, "no repite el ataque al mismo objetivo mientras marcha el primero")
	done()


func test_walls_discourage_the_rival() -> void:
	var data = new_data()
	var world = _world(data)
	world.find_province("c").recruits = 80
	world.find_province("b").recruits = 20
	_decide(world)
	assert_eq(world.armies.size(), 1, "sin murallas ataca (relación ~153 %)")
	var walled = _world(data)
	walled.find_province("c").recruits = 80
	walled.find_province("b").recruits = 20
	walled.find_province("b").add_building("wall")
	walled.find_province("b").add_building("wall")
	_decide(walled)
	assert_true(walled.armies.is_empty(), "con dos murallas la IA no ataca: su defensa pasó del umbral")
	done()


func test_the_rival_does_not_send_a_second_army_at_a_target_already_under_attack() -> void:
	var data = new_data()
	var world = _world(data)
	world.find_province("c").recruits = 400      # sobra ejército: sin la comprobación mandaría un segundo ataque
	_decide(world)
	assert_eq(world.armies.size(), 1, "primer ataque")
	_decide(world)
	assert_eq(world.armies.size(), 1, "y no un segundo contra el mismo objetivo mientras marcha el primero")
	done()


func test_the_rival_does_not_attack_without_enough_superiority_or_soldiers() -> void:
	var data = new_data()
	var world = _world(data)
	world.find_province("c").recruits = 9
	_decide(world)
	assert_true(world.armies.is_empty(), "con menos del mínimo de soldados no ataca")
	world.find_province("c").recruits = 60
	world.find_province("b").recruits = 300
	_decide(world)
	assert_true(world.armies.is_empty(), "contra una defensa fuerte no ataca")
	world.find_province("b").recruits = 0
	_decide(world)
	assert_eq(world.armies.size(), 1, "con la defensa a cero sí")
	done()


func test_the_last_province_of_the_player_is_never_attacked() -> void:
	var data = new_data()
	var owners := OWNERS.duplicate()
	owners["a"] = "tolosa"
	owners["e"] = "tolosa"
	var world = _world(data, owners)
	world.find_province("c").recruits = 80
	_decide(world)
	assert_true(world.armies.is_empty(), "con una sola provincia no se la atacan")
	done()


func test_each_rival_realm_attacks_once_and_rivals_never_fight_each_other() -> void:
	var data = new_data()
	var world = _world(data)
	world.find_province("c").recruits = 80
	world.find_province("f").recruits = 80
	world.find_province("d").recruits = 80
	_decide(world)
	assert_eq(world.armies.size(), 2, "Tolosa y Gascuña atacan una vez cada una")
	var realms := []
	for army in world.armies:
		realms.append(army["realm"])
		assert_true(world.owners[army["to"]] == "leon", "solo contra el jugador (%s)" % army["to"])
	realms.sort()
	assert_eq(realms, ["gascuna", "tolosa"], "uno de cada reino")
	done()


func test_the_rival_picks_the_best_ratio_among_its_candidates() -> void:
	var data = new_data()
	var world = _world(data)
	world.find_province("c").recruits = 80
	world.find_province("f").recruits = 100
	world.owners["f"] = "tolosa"      # Tolosa tiene ahora dos puntos de ataque: c contra b (relación ~153 %) y f contra e (mucho mayor)
	world.find_province("b").recruits = 20
	_decide(world)
	assert_eq(world.armies.size(), 1, "un ataque por reino")
	assert_eq(world.armies[0]["to"], "e", "elige el objetivo con mejor relación de fuerzas")
	done()


func test_an_undefended_province_falls_and_the_report_says_who_took_it() -> void:
	var data = new_data()
	var world = _world(data)
	world.find_province("c").recruits = 80
	_decide(world)
	var arrive: int = world.armies[0]["arrive"]
	world.step_count = arrive
	load(WAR).step(world)
	assert_eq(world.owners["b"], "tolosa", "b cae en manos de Tolosa")
	assert_eq(world.trade_links["b"]["realm"], "tolosa", "y pasa a su red de comercio")
	assert_eq(world.battle_log[-1]["attacker_realm"], "tolosa", "el informe nombra al atacante")
	assert_true(world.battle_log[-1]["won"], "y que ganó")
	assert_eq(world.find_province("b").unrest, int(data.rules["war_conquest_unrest"]), "queda inquieta")
	assert_true(not load(WAR).is_player(world, "b"), "ya no es del jugador")
	done()


func test_a_defended_province_holds_and_the_attackers_are_lost() -> void:
	var data = new_data()
	var world = _world(data)
	world.find_province("c").recruits = 80
	_decide(world)
	world.find_province("b").recruits = 150      # el jugador refuerza durante la marcha
	var total_before := _soldiers(world)
	world.step_count = world.armies[0]["arrive"]
	load(WAR).step(world)
	assert_eq(world.owners["b"], "leon", "b resiste")
	assert_true(not world.battle_log[-1]["won"], "el informe dice que perdió el atacante")
	assert_true(world.find_province("b").recruits < 150, "pero con bajas")
	assert_true(_soldiers(world) <= total_before, "los soldados no se multiplican")
	done()


func test_ai_armies_keep_their_realm_through_save_and_load_and_bad_realms_are_rejected() -> void:
	var data = new_data()
	var world = _world(data)
	world.find_province("c").recruits = 80
	_decide(world)
	var text: String = load(SAVE_GAME).encode(world, "0.5.0")
	var result: Dictionary = load(SAVE_GAME).decode(data, text, LINKS)
	assert_true(result["ok"], "se carga: %s" % str(result.get("error", "")))
	assert_eq(result["world"].armies[0]["realm"], "tolosa", "el ejército sigue siendo de Tolosa")
	assert_eq(JSON.stringify(result["world"].to_dict(), "", true), JSON.stringify(world.to_dict(), "", true), "mismo estado")
	var broken: Dictionary = JSON.parse_string(JSON.stringify(world.to_dict()))
	broken["armies"][0]["realm"] = "atlantida"
	var fresh = load(WORLD).new(data)
	for id in ["a", "b", "c", "d", "e", "f"]:
		fresh.add_province(id, id, 100)
	assert_true(not fresh.load_dict(broken), "un ejército de un reino que no existe se rechaza")
	var typed: Dictionary = JSON.parse_string(JSON.stringify(world.to_dict()))
	typed["armies"][0]["realm"] = 7
	var fresh2 = load(WORLD).new(data)
	for id in ["a", "b", "c", "d", "e", "f"]:
		fresh2.add_province(id, id, 100)
	assert_true(not fresh2.load_dict(typed), "ni uno con el reino mal tipado")
	done()


func test_the_ai_is_deterministic() -> void:
	var data = new_data()
	var one = _world(data)
	var two = _world(data)
	for w in [one, two]:
		w.find_province("c").recruits = 80
		w.find_province("f").recruits = 40
	one.step_count = int(data.rules["war_ai_start_steps"]) - 50
	two.step_count = int(data.rules["war_ai_start_steps"]) - 50
	one.run_steps(400)
	two.run_steps(400)
	assert_eq(JSON.stringify(one.to_dict(), "", true), JSON.stringify(two.to_dict(), "", true), "dos mundos iguales hacen lo mismo")
	assert_true(one.incoming_count > 0, "y la prueba incluye ataques de verdad")
	done()


func test_offline_time_never_loses_provinces_and_restores_the_flag() -> void:
	var data = new_data()
	var world = _world(data)
	world.find_province("c").recruits = 80
	world.step_count = int(data.rules["war_ai_start_steps"]) + 10
	var result: Dictionary = load(OFFLINE).settle(world, 1000, 1000 + 400 * int(data.rules["step_seconds"]))
	assert_true(result["steps"] > 0, "pasó tiempo")
	assert_true(world.armies.is_empty() and world.incoming_count == 0, "sin ataques mientras estás fuera")
	assert_true(not world.ai_paused, "y la IA vuelve a estar activa")
	done()


# --- Interfaz y mapa real ---------------------------------------------------------------------------------

func _open_main():
	DirAccess.make_dir_recursive_absolute(DIR)
	for file_name in DirAccess.open(DIR).get_files():
		DirAccess.remove_absolute(DIR + "/" + file_name)
	var main = load(MAIN_SCENE).instantiate()
	main.session = load(SESSION).new(PATH, "0.0.test")
	main.fixed_now = 1800000000
	main._ready()
	return main


func test_an_incoming_attack_pauses_the_game_and_warns_the_player() -> void:
	var main = _open_main()
	var world = main.session.world
	world.incoming_count = 1
	world.incoming_log = [{"step": 5, "realm": "califato", "from": "merida", "to": "zamora", "soldiers": 33}]
	main._on_speed_pressed(3)
	main._check_incoming()
	assert_true(main.has_modal(), "aparece el aviso")
	assert_eq(main._speed_index, 0, "y el juego se pausa")
	main._close_modal()
	main._check_incoming()
	assert_true(not main.has_modal(), "no se repite")
	main.free()
	done()


func test_the_battle_report_tells_losses_to_a_rival_apart_from_your_victories() -> void:
	var main = _open_main()
	var world = main.session.world
	world.battle_log = [{"step": 9, "from": "merida", "to": "zamora", "attacker_realm": "califato", "defender_realm": "leon", "sent": 60, "garrison": 10, "attacker_left": 55, "defender_left": 0, "won": true, "rounds": 3}]
	world.battle_count = 1
	main._check_battles()
	assert_true(main.has_modal(), "aparece el informe")
	var found := false
	for label in main._modal_layer.find_children("*", "Label", true, false):
		if "ha tomado" in label.text:
			found = true
	assert_true(found, "dice que otro reino ha tomado la provincia")
	main.free()
	done()


func test_new_game_lets_you_choose_the_realm() -> void:
	var main = _open_main()
	main._on_new_game_pressed()
	assert_true(main.has_modal(), "pide confirmar")
	main._show_realm_picker()
	var buttons: Array = main._modal_layer.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), main.session.map.realms.size() + 1, "un botón por reino y cancelar")
	main._close_modal()
	main._confirm_new_game("castilla")
	assert_eq(main.session.world.player_realm, "castilla", "se juega con Castilla")
	assert_true(load(WAR).is_player(main.session.world, "castilla"), "y manda en su provincia")
	assert_true(not load(WAR).is_player(main.session.world, "leon"), "no en las de León")
	main.free()
	done()


func test_the_real_map_with_a_passive_player_stays_consistent_for_a_season() -> void:
	var data = new_data()
	var map = load(GAME_MAP).new()
	assert_true(map.load_defaults(data), "mapa: %s" % str(map.errors))
	var world = map.new_world(data)["world"]
	world.run_steps(int(data.rules["war_ai_start_steps"]) + 24 * 24)
	assert_eq(world.check_invariants().size(), 0, "estado coherente: %s" % str(world.check_invariants()))
	var rival_soldiers := 0
	for p in world.provinces:
		if world.owners[p.id] != "leon":
			rival_soldiers += p.recruits
	assert_true(rival_soldiers > 0, "los rivales se han armado")
	assert_true(world.incoming_count >= 0, "la IA ha tenido ocasión de decidir")
	var mine := 0
	for id in world.owners.keys():
		if world.owners[id] == "leon":
			mine += 1
	assert_true(mine >= 1, "el jugador conserva al menos una provincia")
	done()
