extends "res://tests/province_case.gd"
## Ejércitos con coste real (pieza G2): reclutar necesita cuartel, armas y trabajadores libres;
## cada soldado cuesta moneda por paso; sin moneda sube el descontento. Aún no hay combate.
## Todas las cifras son parámetros de juego provisionales, no datos históricos.

const Layout = preload("res://scripts/view/provincia_layout.gd")
const PANEL := "res://scripts/ui/province_panel.gd"
const CIUDAD := "res://scripts/view/ciudad_epoca.gd"


func _con_cuartel(data, armas: int = 3000, moneda: int = 50000):
	var p = new_province(data, 100)
	p.store.seed_initial("bread", 18000)
	p.store.seed_initial("coin", moneda)
	p.store.seed_initial("weapons", armas)
	assert_true(p.add_building("barracks") >= 0, "el cuartel se puede añadir")
	return p


func test_recruiting_needs_a_barracks() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("weapons", 3000)
	assert_true(not p.recruit(5), "sin cuartel no se recluta")
	assert_true(p.last_error.contains("cuarteles"), "dice por qué: %s" % p.last_error)
	assert_eq(p.recruits, 0, "no hay soldados")
	assert_eq(p.store.stock("weapons"), 3000, "no se gastaron armas")
	done()


func test_recruiting_costs_weapons_and_is_atomic() -> void:
	var data = new_data()
	var por_soldado: int = data.rules["recruit_weapons"]
	var p = _con_cuartel(data, por_soldado * 3 + 10)
	assert_true(not p.recruit(4), "con armas para 3 no se reclutan 4")
	assert_true(p.last_error.contains("armas"), "dice por qué: %s" % p.last_error)
	assert_eq(p.recruits, 0, "no cambió nada")
	assert_eq(p.store.stock("weapons"), por_soldado * 3 + 10, "ni las armas")
	assert_true(p.recruit(3), "con armas para 3 se reclutan 3")
	assert_eq(p.recruits, 3, "tres soldados")
	assert_eq(p.store.stock("weapons"), 10, "cada soldado gastó %d de armas" % por_soldado)
	done()


func test_barracks_capacity_limits_soldiers() -> void:
	var data = new_data()
	data.rules["recruit_weapons"] = 100   # el almacén de armas es pequeño: aquí solo se prueba el sitio
	var cap: int = data.rules["recruits_per_barracks"]
	var p = _con_cuartel(data, 3000)
	assert_eq(p.recruit_capacity(), cap, "un cuartel, su capacidad")
	assert_true(not p.recruit(cap + 1), "no caben más que la capacidad")
	assert_true(p.last_error.contains("sitio"), "dice por qué: %s" % p.last_error)
	assert_true(p.recruit(cap), "caben justo los de la capacidad")
	assert_true(not p.recruit(1), "ni uno más")
	p.add_building("barracks")
	assert_eq(p.recruit_capacity(), cap * 2, "dos cuarteles, el doble")
	done()


func test_recruits_come_out_of_free_workers() -> void:
	var data = new_data()
	var p = _con_cuartel(data, 3000)
	var antes: int = p.available_workers()
	assert_true(p.recruit(5), "reclutar")
	assert_eq(p.available_workers(), antes - 5, "salen de la mano de obra libre")
	assert_true(p.release_recruits(5), "licenciar")
	assert_eq(p.available_workers(), antes, "vuelven al trabajo")
	assert_eq(p.store.stock("weapons"), 3000 - 5 * int(data.rules["recruit_weapons"]), "las armas no se devuelven")
	done()


func test_soldiers_cost_coin_every_step() -> void:
	var data = new_data()
	var p = _con_cuartel(data, 3000, 50000)
	p.recruit(5)
	var cuesta: int = 5 * int(data.rules["recruit_upkeep"])
	var base = _con_cuartel(new_data(), 3000, 50000)
	p.step()
	base.step()
	assert_eq(base.store.stock("coin") - p.store.stock("coin"), cuesta, "cada paso cuestan %d más que sin soldados" % cuesta)
	assert_true(not p.soldiers_unpaid, "con moneda cobran")
	done()


func test_unpaid_soldiers_raise_unrest_and_alert() -> void:
	var data = new_data()
	data.rules["tax_per_person"] = 0   # sin impuestos: la única moneda es la que hay en el almacén
	var p = _con_cuartel(data, 3000, 0)
	p.recruit(5)
	p.store.remove("coin", p.store.stock("coin"), "consumed")
	var d0: int = p.unrest
	for i in 3:
		p.store.remove("coin", p.store.stock("coin"), "consumed")
		p.step()
	assert_true(p.soldiers_unpaid, "sin moneda no cobran")
	assert_true(p.unrest > d0, "sube el descontento (%d → %d)" % [d0, p.unrest])
	assert_true("soldiers_unpaid" in p.alerts, "hay aviso")
	var data2 = new_data()
	data2.rules["tax_per_person"] = 0
	var sin = _con_cuartel(data2, 3000, 0)
	sin.step()
	assert_true(not ("soldiers_unpaid" in sin.alerts), "sin soldados no hay aviso")
	done()


func test_soldiers_survive_save_and_load() -> void:
	var data = new_data()
	var p = _con_cuartel(data, 3000)
	p.recruit(5)
	var q = new_province(data, 100)
	assert_true(q.load_dict(p.to_dict()), "se carga")
	assert_eq(q.recruits, 5, "siguen los 5 soldados")
	assert_eq(q.recruit_capacity(), p.recruit_capacity(), "y la capacidad")
	done()


func test_panel_shows_army_and_buttons_work() -> void:
	var data = new_data()
	var p = _con_cuartel(data, 3000)
	var panel = load(PANEL).new()
	panel.setup(data)
	panel.show_province(p, [])
	var info: Dictionary = panel.army_info()
	assert_eq(info["soldiers"], 0, "sin soldados")
	assert_eq(info["capacity"], p.recruit_capacity(), "muestra la capacidad de los cuarteles")
	assert_eq(info["barracks"], 1, "y los cuarteles")
	assert_true(panel.release_button().disabled, "sin soldados no se puede licenciar")
	panel.recruit_button().pressed.emit()
	assert_eq(p.recruits, 5, "el botón recluta 5")
	assert_true("Reclutados" in panel.feedback_text(), "avisa: %s" % panel.feedback_text())
	panel.release_button().pressed.emit()
	assert_eq(p.recruits, 0, "el botón licencia 5")
	var vacia = new_province(data, 100)
	panel.show_province(vacia, [])
	panel.recruit_button().pressed.emit()
	assert_eq(vacia.recruits, 0, "sin cuartel no recluta")
	assert_true("No se pudo reclutar" in panel.feedback_text(), "y lo explica: %s" % panel.feedback_text())
	panel.free()
	done()


func test_barracks_is_drawn_and_guards_follow_soldiers() -> void:
	for aspecto in ["cordoba", "norte"]:
		var sin: Dictionary = Layout.plan(aspecto, [], [], 100, 30)
		assert_eq(int(sin["gente"]["guardias"]), 0, "%s: sin cuartel no hay guardias a la vista" % aspecto)
		var con: Dictionary = Layout.plan(aspecto, [{"type": "barracks"}], [], 100, 0)
		assert_eq(int(con["gente"]["guardias"]), 0, "%s: cuartel sin soldados, sin guardias" % aspecto)
		var uno: Dictionary = Layout.plan(aspecto, [{"type": "barracks"}], [], 100, 1)
		assert_eq(int(uno["gente"]["guardias"]), 1, "%s: un soldado, una figura" % aspecto)
		var muchos: Dictionary = Layout.plan(aspecto, [{"type": "barracks"}], [], 100, 400)
		assert_eq(int(muchos["gente"]["guardias"]), Layout.MAX_GUARDIAS, "%s: tope de figuras" % aspecto)
		assert_true(Layout.firma_gente(uno) != Layout.firma_gente(muchos), "%s: la firma de la gente cambia con los soldados" % aspecto)
		var suelo: String = Layout.firma(aspecto, uno)
		assert_eq(suelo, Layout.firma(aspecto, muchos), "%s: pero el suelo no se reconstruye" % aspecto)
		var celdas: Dictionary = con["cells"]
		var visto := false
		for c in celdas.values():
			if c.get("o", "") == "u":
				visto = true
		assert_true(visto, "%s: el cuartel está en el mapa" % aspecto)
	done()


func test_the_view_shows_guards_for_the_real_soldiers_of_the_province() -> void:
	var data = new_data()
	var p = load(PROVINCE).new(data, "cordoba", "Cordoba", 100)
	p.store.seed_initial("coin", 50000)
	p.store.seed_initial("weapons", 3000)
	p.add_building("barracks")
	var vista = load("res://scripts/ui/province_view.gd").new()
	(Engine.get_main_loop() as SceneTree).root.add_child(vista)
	vista.mostrar(p)
	assert_eq(vista._gente.guardias.size(), 0, "sin soldados no hay guardias")
	assert_true(p.recruit(6), "se reclutan 6")
	vista.mostrar(p)
	assert_eq(vista._gente.guardias.size(), 2, "6 soldados, 2 figuras")
	p.release_recruits(6)
	vista.mostrar(p)
	assert_eq(vista._gente.guardias.size(), 0, "licenciados, ya no hay guardias")
	(Engine.get_main_loop() as SceneTree).root.remove_child(vista)
	vista.free()
	done()
