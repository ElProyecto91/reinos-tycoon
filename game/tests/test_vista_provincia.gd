extends "res://tests/province_case.gd"
## Vista 3D de la provincia dentro del juego: reparto de casillas según lo construido
## (provincia_layout.gd), el control que lo dibuja (province_view.gd) y su integración en la pantalla
## principal (main.gd). Solo comprueba datos y estructura; cómo se ve se revisa con
## tools/captura_juego.gd y, en el móvil, con el plan de pruebas (docs/TEST_PLAN.md).

const Layout = preload("res://scripts/view/provincia_layout.gd")
const CIUDAD := "res://scripts/view/ciudad_epoca.gd"
const VISTA := "res://scripts/ui/province_view.gd"
const MAIN_SCENE := "res://main.tscn"
const SESSION := "res://scripts/sim/game_session.gd"
const MAP_SCRIPT := "res://scripts/sim/game_map.gd"
const DIR := "user://pruebas_vista"
const PATH := "user://pruebas_vista/partida.json"
const AJUSTES := "user://pruebas_vista/ajustes.json"
const T0 := 1800000000
const AMBAS := ["cordoba", "norte"]
const TIPOS := ["house", "granary", "farm", "mill", "bakery", "woodcutter"]


func _edificios(tipos: Array) -> Array:
	var out: Array = []
	for t in tipos:
		out.append({"type": t})
	return out


func _raiz() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _limpiar() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.open(DIR).get_files():
		DirAccess.remove_absolute(DIR + "/" + f)


## Pantalla principal dentro del árbol (hace falta para que se construya la vista 3D).
func _main_en_arbol(con_3d: bool = true, provincia_inicial: String = "cordoba"):
	_limpiar()
	var main = load(MAIN_SCENE).instantiate()
	main.session = load(SESSION).new(PATH, "0.0.test")
	main.fixed_now = T0
	main.enable_3d = con_3d
	main.start_province = provincia_inicial
	main.settings_path = ""
	_raiz().add_child(main)
	return main


func _quitar(nodo: Node) -> void:
	_raiz().remove_child(nodo)
	nodo.free()


func _provincia(id: String, poblacion: int = 140):
	return load(PROVINCE).new(new_data(), id, id.capitalize(), poblacion)


# --- Reparto de casillas -------------------------------------------------------------------

func test_every_province_of_the_map_has_a_3d_look_and_its_start_fits() -> void:
	var data = new_data()
	var map = load(MAP_SCRIPT).new()
	assert_true(map.load_defaults(data), "el mapa del juego carga: %s" % str(map.errors))
	var regiones: Dictionary = load(CIUDAD).REGIONES
	for p in map.provinces:
		var aspecto: String = Layout.aspecto_de(p["id"])
		assert_true(aspecto != "" and regiones.has(aspecto), "%s tiene aspecto 3D (%s)" % [p["id"], aspecto])
		var plan: Dictionary = Layout.plan(aspecto, _edificios(p["start"]["buildings"]), [], p["start"]["population"])
		assert_eq(plan["ocultos"].size(), 0, "%s: lo de partida cabe en el paisaje" % p["id"])
	assert_eq(Layout.aspecto_de("atlantida"), "", "una provincia sin aspecto devuelve vacío")
	done()


func test_templates_are_inside_the_map_and_their_slots_never_collide() -> void:
	for aspecto in AMBAS:
		var t: Dictionary = Layout.plantilla(aspecto)
		var d = load(CIUDAD).new()
		var capas: Dictionary = d.layers_from_cells(Layout.RADIO, t["base"])
		assert_eq(capas["errors"].size(), 0, "%s: el paisaje fijo cabe en el mapa: %s" % [aspecto, str(capas["errors"])])
		d.free()
		var vistas := {}
		for tipo in t["huecos"].keys():
			assert_true(t["huecos"][tipo].size() >= 1, "%s: al menos un hueco para %s" % [aspecto, tipo])
			for hueco in t["huecos"][tipo]:
				var celda: Vector2i = hueco[0]
				assert_true(maxi(maxi(absi(celda.x), absi(celda.y)), absi(celda.x + celda.y)) <= Layout.RADIO, "%s: el hueco %s está dentro del mapa" % [aspecto, str(celda)])
				assert_true(not vistas.has(celda), "%s: el hueco %s no se repite" % [aspecto, str(celda)])
				vistas[celda] = true
				var fija: Dictionary = t["base"].get(celda, {})
				# Un hueco solo puede ocupar terreno que se roturaba o desbrozaba (bosque, monte, huerta, olivar),
				# nunca un monumento, un camino, un río ni una muralla.
				assert_true(not fija.has("p"), "%s: el hueco %s no pisa un camino, río o muralla" % [aspecto, str(celda)])
				assert_true(not fija.has("o") or str(fija["o"]) in "TthHMNiaA", "%s: el hueco %s no pisa un monumento (%s)" % [aspecto, str(celda), str(fija.get("o", ""))])
				assert_true(str(hueco[1]).length() == 1 and load("res://scripts/view/diorama.gd").THING_SYMBOLS.contains(hueco[1]), "%s: el símbolo %s existe" % [aspecto, hueco[1]])
		for tipo in Layout.HUECO_DE.keys():
			assert_true(t["huecos"].has(Layout.HUECO_DE[tipo]), "%s: hay huecos para %s" % [aspecto, tipo])
	done()


func test_every_game_building_type_has_a_slot_kind() -> void:
	var data = new_data()
	for tipo in data.buildings.keys():
		assert_true(Layout.HUECO_DE.has(tipo), "el edificio «%s» del juego tiene sitio en el paisaje (añádelo a HUECO_DE)" % tipo)
	for tipo in Layout.HUECO_DE.keys():
		assert_true(data.buildings.has(tipo), "HUECO_DE no menciona edificios que no existen: %s" % tipo)
	done()


func test_each_building_appears_in_its_first_free_slot_and_only_then() -> void:
	for aspecto in AMBAS:
		var t: Dictionary = Layout.plantilla(aspecto)
		for tipo in TIPOS:
			if tipo == "house":
				continue
			var lista: Array = t["huecos"][Layout.HUECO_DE[tipo]]
			var vacio: Dictionary = Layout.plan(aspecto, [], [], 0)
			assert_true(not vacio["cells"].has(lista[0][0]), "%s: sin %s el hueco queda vacío" % [aspecto, tipo])
			var uno: Dictionary = Layout.plan(aspecto, _edificios([tipo]), [], 0)
			assert_eq(uno["cells"][lista[0][0]]["o"], lista[0][1], "%s: un %s ocupa el primer hueco" % [aspecto, tipo])
			assert_true(not uno["cells"].has(lista[1][0]), "%s: y deja libre el segundo" % aspecto)
			var dos: Dictionary = Layout.plan(aspecto, _edificios([tipo, tipo]), [], 0)
			assert_eq(dos["cells"][lista[1][0]]["o"], lista[1][1], "%s: dos %s ocupan los dos primeros" % [aspecto, tipo])
	done()


func test_a_project_is_drawn_as_a_building_site_where_the_building_will_stand() -> void:
	for aspecto in AMBAS:
		var t: Dictionary = Layout.plantilla(aspecto)
		var granjas: Array = t["huecos"]["granja"]
		var plan: Dictionary = Layout.plan(aspecto, _edificios(["farm"]), [{"type": "farm"}], 0)
		assert_eq(plan["cells"][granjas[0][0]]["o"], "F", "%s: la granja hecha, en el primer hueco" % aspecto)
		assert_eq(plan["cells"][granjas[1][0]]["o"], "S", "%s: la obra, en el siguiente" % aspecto)
		var terminada: Dictionary = Layout.plan(aspecto, _edificios(["farm", "farm"]), [], 0)
		assert_eq(terminada["cells"].keys().size(), plan["cells"].keys().size(), "%s: al terminar la obra, ocupa la misma casilla" % aspecto)
		assert_eq(terminada["cells"][granjas[1][0]]["o"], "F", "%s: y la obra pasa a ser granja" % aspecto)
		# Una vivienda en obra se dibuja tras las manzanas que ya hay.
		var casas: Array = t["huecos"]["vivienda"]
		var con_obra: Dictionary = Layout.plan(aspecto, [], [{"type": "house"}], 0)
		assert_eq(con_obra["cells"][casas[1][0]]["o"], "S", "%s: la obra de vivienda, tras la primera manzana" % aspecto)
	done()


func test_housing_grows_with_population_and_with_each_finished_house() -> void:
	assert_eq(Layout.manzanas(0, 0, 9), 1, "siempre hay al menos una manzana")
	assert_eq(Layout.manzanas(-5, -1, 9), 1, "valores absurdos no rompen nada")
	assert_eq(Layout.manzanas(90, 0, 9), 3, "90 habitantes, 3 manzanas")
	assert_eq(Layout.manzanas(140, 2, 9), 6, "140 habitantes y 2 viviendas: 4 + 2")
	assert_eq(Layout.manzanas(1000, 20, 9), 9, "no pasa de los huecos")
	var antes := Layout.manzanas(100, 0, 9)
	assert_eq(Layout.manzanas(100, 1, 9), antes + 1, "cada vivienda terminada añade una manzana")
	assert_eq(Layout.manzanas(120, 0, 9), antes + 1, "y cada 30 habitantes más, otra")
	var plan: Dictionary = Layout.plan("cordoba", [], [], 100)
	var casas := 0
	for celda in plan["cells"].values():
		if celda.get("o", "") in ["o", "O"]:
			casas += 1
	assert_eq(casas, antes, "el paisaje dibuja tantas manzanas como dice la regla")
	done()


func test_what_does_not_fit_is_counted_not_lost() -> void:
	var plan: Dictionary = Layout.plan("cordoba", _edificios(["mill", "mill", "mill"]), [{"type": "mill"}], 0)
	assert_eq(plan["ocultos"].get("mill", 0), 2, "3 molinos y 1 obra con 2 huecos: 2 fuera de vista")
	var huecos: Array = Layout.plantilla("cordoba")["huecos"]["molino"]
	assert_eq(plan["cells"][huecos[0][0]]["o"], "V", "los que caben se dibujan")
	assert_eq(plan["cells"][huecos[1][0]]["o"], "V", "los dos huecos, ocupados")
	var casas: Dictionary = Layout.plan("cordoba", _edificios(["house", "house", "house", "house", "house", "house", "house", "house", "house", "house"]), [{"type": "house"}], 500)
	assert_eq(casas["ocultos"].get("house", 0), 1, "una obra de vivienda sin hueco libre se cuenta fuera de vista")
	done()


func test_the_fingerprint_changes_only_when_what_is_drawn_changes() -> void:
	var base: Dictionary = Layout.plan("cordoba", _edificios(["farm"]), [], 140)
	assert_eq(Layout.firma("cordoba", base), Layout.firma("cordoba", Layout.plan("cordoba", _edificios(["farm"]), [], 140)), "lo mismo, la misma firma")
	assert_eq(Layout.firma("cordoba", base), Layout.firma("cordoba", Layout.plan("cordoba", _edificios(["farm"]), [], 145)), "5 habitantes más no cambian el dibujo")
	assert_true(Layout.firma("cordoba", base) != Layout.firma("cordoba", Layout.plan("cordoba", _edificios(["farm", "farm"]), [], 140)), "una granja más, otra firma")
	assert_true(Layout.firma("cordoba", base) != Layout.firma("cordoba", Layout.plan("cordoba", _edificios(["farm"]), [{"type": "farm"}], 140)), "una obra, otra firma")
	assert_true(Layout.firma("cordoba", base) != Layout.firma("cordoba", Layout.plan("cordoba", _edificios(["farm"]), [], 160)), "de 140 a 160 habitantes pasa de 4 a 5 manzanas")
	assert_true(Layout.firma("cordoba", base) != Layout.firma("norte", Layout.plan("norte", _edificios(["farm"]), [], 140)), "otro aspecto, otra firma")
	done()


# --- Control de la vista ---------------------------------------------------------------------

func test_the_view_builds_once_rebuilds_only_on_change_and_clears() -> void:
	var vista = load(VISTA).new()
	_raiz().add_child(vista)
	var p = _provincia("cordoba")
	p.add_building("farm")
	vista.mostrar(p)
	assert_eq(vista.reconstrucciones, 1, "la primera vez se construye")
	assert_eq(vista.aspecto(), "cordoba", "con el aspecto de la provincia")
	assert_true(vista.triangulos() > 5000, "y tiene edificios dibujados (%d triángulos)" % vista.triangulos())
	assert_true(vista.firma() != "", "y firma")
	vista.mostrar(p)
	vista.mostrar(p)
	assert_eq(vista.reconstrucciones, 1, "si no cambia nada, no se reconstruye")
	p.add_building("granary")
	vista.mostrar(p)
	assert_eq(vista.reconstrucciones, 2, "un edificio nuevo reconstruye")
	var antes: int = vista.triangulos()
	p.start_construction("farm")
	vista.mostrar(p)
	assert_true(vista.reconstrucciones == 3 or p.last_error != "", "una obra nueva reconstruye (o no se pudo empezar: %s)" % p.last_error)
	p.population += 5
	var n: int = vista.reconstrucciones
	vista.mostrar(p)
	assert_eq(vista.reconstrucciones, n, "5 habitantes no cambian lo que se ve")
	assert_true(antes > 0, "los triángulos se cuentan")
	vista.mostrar(null)
	assert_eq(vista.aspecto(), "", "con null se vacía")
	assert_eq(vista.triangulos(), 0, "sin triángulos")
	assert_eq(vista.firma(), "", "sin firma")
	vista.mostrar(p)
	assert_eq(vista.reconstrucciones, n + 1, "y al volver a mostrar se reconstruye")
	_quitar(vista)
	done()


func test_the_view_switches_look_between_provinces_without_piling_up_scenes() -> void:
	var vista = load(VISTA).new()
	_raiz().add_child(vista)
	vista.mostrar(_provincia("cordoba"))
	var sur_triangulos: int = vista.triangulos()
	vista.mostrar(_provincia("castilla", 60))
	assert_eq(vista.aspecto(), "norte", "Castilla se ve del norte")
	assert_true(vista.triangulos() != sur_triangulos, "y es otro paisaje")
	var mundo: Node = vista.get("_mundo")
	var ciudades := 0
	for hijo in mundo.get_children():
		if hijo.get_script() == load(CIUDAD):
			ciudades += 1
	assert_eq(ciudades, 1, "solo queda una escena de paisaje")
	# Una provincia sin aspecto no rompe nada ni deja la escena vieja (push_warning es esperado).
	vista.mostrar(_provincia("atlantida"))
	assert_eq(vista.aspecto(), "", "sin aspecto, sin escena")
	_quitar(vista)
	done()


func test_the_3d_viewport_follows_the_size_but_never_exceeds_the_limit() -> void:
	var vista = load(VISTA).new()
	_raiz().add_child(vista)
	var vp: SubViewport = vista.get("_vp")
	assert_true(vp != null, "el control crea su viewport")
	vista.size = Vector2(688, 500)
	vista.call("_ajustar_tamano")
	var escala: float = vista.get_global_transform_with_canvas().get_scale().x
	assert_eq(vp.size, Vector2i(int(round(688.0 * escala)), int(round(500.0 * escala))), "el viewport mide los píxeles reales (escala %.2f)" % escala)
	vista.size = Vector2(4000, 3000)
	vista.call("_ajustar_tamano")
	assert_true(maxi(vp.size.x, vp.size.y) <= load(VISTA).LADO_MAXIMO, "tope de lado: %s" % str(vp.size))
	assert_true(absf(float(vp.size.x) / float(vp.size.y) - 4.0 / 3.0) < 0.01, "y conserva la proporción")
	vista.size = Vector2(0, 0)
	vista.call("_ajustar_tamano")
	assert_true(vp.size.x >= 16 and vp.size.y >= 16, "nunca un viewport vacío")
	assert_eq(vp.render_target_update_mode, SubViewport.UPDATE_ONCE, "se redibuja al cambiar, no a 60 fotogramas por segundo")
	assert_eq(vista.mouse_filter, Control.MOUSE_FILTER_IGNORE, "no se come los toques")
	_quitar(vista)
	done()


func test_the_view_redraws_once_a_second_not_every_frame() -> void:
	var vista = load(VISTA).new()
	_raiz().add_child(vista)
	var vp: SubViewport = vista.get("_vp")
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vista._process(0.4)
	assert_eq(vp.render_target_update_mode, SubViewport.UPDATE_DISABLED, "a los 0,4 s no redibuja")
	vista._process(0.4)
	assert_eq(vp.render_target_update_mode, SubViewport.UPDATE_DISABLED, "a los 0,8 s tampoco")
	vista._process(0.4)
	assert_eq(vp.render_target_update_mode, SubViewport.UPDATE_ONCE, "a partir del segundo, una vez")
	_quitar(vista)
	done()


# --- Pantalla principal ----------------------------------------------------------------------

func test_the_main_screen_starts_on_the_3d_view_of_the_start_province() -> void:
	var main = _main_en_arbol()
	assert_eq(main._panel.current_province_id(), "cordoba", "la ficha muestra la provincia inicial")
	assert_true(main._province_view.visible and not main._map_view.visible, "se ve el paisaje, no el mapa")
	assert_eq(main._province_view.aspecto(), "cordoba", "con el aspecto de Córdoba")
	assert_eq(main._map_button.text, "Mapa", "el botón lleva al mapa")
	assert_true(not main._map_button.disabled, "y está activo")
	assert_true("Córdoba" in main._view_title.text and "140" in main._view_title.text, "rótulo: %s" % main._view_title.text)
	assert_true(main._province_view.triangulos() > 5000, "hay edificios dibujados")
	_quitar(main)
	done()


func test_the_map_highlights_the_chosen_province_even_when_chosen_from_outside_the_map() -> void:
	var main = _main_en_arbol()
	assert_eq(main._map_view.selected_id, "cordoba", "la provincia inicial sale resaltada en el mapa")
	main._on_map_button_pressed()
	assert_eq(main._map_view.selected_id, "cordoba", "y sigue al volver al mapa")
	main._map_view.select("toledo")
	assert_eq(main._map_view.selected_id, "toledo", "tocar otra cambia el resaltado")
	_quitar(main)
	done()


func test_the_map_button_swaps_between_map_and_landscape_and_picking_a_province_returns() -> void:
	var main = _main_en_arbol()
	main._on_map_button_pressed()
	assert_true(main._map_view.visible and not main._province_view.visible, "el mapa sustituye al paisaje")
	assert_eq(main._map_button.text, "Provincia", "y el botón vuelve al paisaje")
	assert_true(not main._chip_title.visible, "sin rótulo del paisaje sobre el mapa")
	main._on_map_button_pressed()
	assert_true(main._province_view.visible and not main._map_view.visible, "otro pulso vuelve al paisaje")
	main._on_map_button_pressed()
	main._map_view.select("toledo")
	assert_true(main._map_view.visible and not main._province_view.visible, "tocar una provincia en el mapa no cambia de pantalla")
	assert_true(main._map_card.visible and main._enter_button.visible, "enseña su tarjeta con el botón de entrar")
	assert_true("Toledo" in main._card_title.text, "tarjeta de la provincia tocada: %s" % main._card_title.text)
	main._on_enter_pressed()
	assert_true(main._province_view.visible and not main._map_view.visible, "entrar lleva al paisaje")
	assert_eq(main._province_view.aspecto(), "toledo", "de la provincia elegida")
	assert_eq(main._panel.current_province_id(), "toledo", "con su ficha")
	_quitar(main)
	done()


func test_building_something_changes_the_landscape_through_the_real_screen() -> void:
	var main = _main_en_arbol()
	var antes: int = main._province_view.reconstrucciones
	var firma_antes: String = main._province_view.firma()
	var boton: Button = main._panel.build_button("house")
	assert_true(not boton.disabled, "se puede construir una vivienda: %s" % boton.text)
	boton.pressed.emit()
	assert_true(main._province_view.reconstrucciones > antes, "empezar la obra reconstruye el paisaje")
	assert_true(main._province_view.firma() != firma_antes, "y cambia lo dibujado (el andamio ocupa una casilla; antes había maleza)")
	var p = main.session.world.find_province("cordoba")
	var obras_antes: int = p.projects.size()
	assert_eq(obras_antes, 1, "hay una obra en la provincia")
	# Se avanza hasta terminarla: la obra se convierte en manzana y desaparece del paisaje.
	var guard := 0
	while p.projects.size() > 0 and guard < 5000:
		main.session.world.run_steps(10)
		guard += 10
	assert_eq(p.projects.size(), 0, "la obra termina")
	var reconstrucciones: int = main._province_view.reconstrucciones
	main._refresh_all()
	assert_true(main._province_view.reconstrucciones >= reconstrucciones, "el paisaje sigue al juego")
	var plan: Dictionary = Layout.plan("cordoba", p.buildings, p.projects, p.population)
	assert_eq(main._province_view.firma(), Layout.firma("cordoba", plan), "y coincide con lo que dice la provincia ahora")
	_quitar(main)
	done()


func test_without_3d_the_screen_is_the_map_and_nothing_is_built() -> void:
	var main = _main_en_arbol(false)
	assert_true(main._map_view.visible and not main._province_view.visible, "solo el mapa")
	assert_eq(main._province_view.reconstrucciones, 0, "no se construyó paisaje")
	main._map_view.select("toledo")
	assert_eq(main._panel.current_province_id(), "toledo", "la ficha sigue funcionando")
	assert_true(main._map_view.visible and not main._province_view.visible, "y se queda en el mapa")
	assert_eq(main._province_view.reconstrucciones, 0, "sin paisaje")
	_quitar(main)
	done()


func test_without_a_start_province_the_screen_opens_on_the_map() -> void:
	var main = _main_en_arbol(true, "")
	assert_true(main._map_view.visible and not main._province_view.visible, "abre en el mapa")
	assert_true(main._map_button.disabled, "sin provincia no hay paisaje al que volver")
	assert_eq(main._panel.current_province_id(), "", "y sin ficha")
	main._map_view.select("leon")
	assert_true(main._map_view.visible and not main._province_view.visible, "tocar una provincia solo enseña su tarjeta")
	assert_true(not main._map_button.disabled, "y ya hay provincia a la que ir")
	main._on_enter_pressed()
	assert_true(main._province_view.visible, "al entrar, aparece su paisaje")
	assert_eq(main._province_view.aspecto(), "norte", "León es del norte")
	_quitar(main)
	done()


func test_a_new_game_returns_to_the_map_with_no_province() -> void:
	var main = _main_en_arbol()
	assert_true(main._province_view.visible, "se empieza en el paisaje")
	main._confirm_new_game()
	assert_true(main._map_view.visible and not main._province_view.visible, "la partida nueva vuelve al mapa")
	assert_eq(main._panel.current_province_id(), "", "sin ficha")
	assert_eq(main._province_view.aspecto(), "", "y sin paisaje de la partida anterior")
	assert_true(main._map_button.disabled, "sin provincia elegida el botón no hace nada")
	_quitar(main)
	done()


# --- Ajustes de pantalla (menú) ------------------------------------------------------------------

func _main_con_ajustes(ajustes_path: String):
	var main = load(MAIN_SCENE).instantiate()
	main.session = load(SESSION).new(PATH, "0.0.test")
	main.fixed_now = T0
	main.settings_path = ajustes_path
	main.start_province = "cordoba"
	_raiz().add_child(main)
	return main


func _botones_del_modal(main) -> Array:
	var textos: Array = []
	var capa: Node = main.get("_modal_layer")
	if capa != null:
		_recoger_botones(capa, textos)
	return textos


func _recoger_botones(nodo: Node, textos: Array) -> void:
	if nodo is Button:
		textos.append((nodo as Button).text)
	for hijo in nodo.get_children():
		_recoger_botones(hijo, textos)


func test_the_menu_offers_3d_and_shadow_switches_that_are_saved_apart_from_the_game() -> void:
	_limpiar()
	var main = _main_con_ajustes(AJUSTES)
	assert_true(main.enable_3d and main.shadows_enabled, "por defecto, 3D y sombras activados")
	assert_true(main._province_view.visible, "y se ve el paisaje")
	main._on_menu_pressed()
	var botones: Array = _botones_del_modal(main)
	assert_true("Vista 3D: sí" in botones, "el menú ofrece quitar la vista 3D: %s" % str(botones))
	assert_true("Sombras de la vista 3D: sí" in botones, "y las sombras: %s" % str(botones))
	main._close_modal()
	main._on_toggle_shadows_pressed()
	assert_true(not main.shadows_enabled and not main._province_view.sombras, "sin sombras en el control")
	var sol: DirectionalLight3D = main._province_view.get("_stage").sun
	assert_true(not sol.shadow_enabled, "y en la luz de la escena ya construida")
	main._on_toggle_3d_pressed()
	assert_true(not main.enable_3d and main._map_view.visible and not main._province_view.visible, "sin 3D se ve el mapa")
	var guardado = JSON.parse_string(FileAccess.get_file_as_string(AJUSTES))
	assert_eq(guardado, {"view_3d": false, "shadows": false, "animation": true}, "los ajustes quedan en su archivo, no en la partida")
	main._on_menu_pressed()
	assert_true("Vista 3D: no" in _botones_del_modal(main), "el menú refleja el estado")
	_quitar(main)
	# Al reabrir el juego se recuerdan.
	var otra = _main_con_ajustes(AJUSTES)
	assert_true(not otra.enable_3d and not otra.shadows_enabled, "al reabrir, sigue sin 3D y sin sombras")
	assert_true(otra._map_view.visible and not otra._province_view.visible, "y empieza en el mapa")
	assert_eq(otra._province_view.reconstrucciones, 0, "sin construir el paisaje")
	otra._on_toggle_3d_pressed()
	assert_true(otra.enable_3d and otra._province_view.visible and otra._province_view.reconstrucciones == 1, "al volver a activarlo, aparece el paisaje de la provincia elegida")
	_quitar(otra)
	done()


func test_unreadable_settings_are_ignored_and_the_game_still_opens() -> void:
	_limpiar()
	for contenido in ["no es json", "[1, 2]", "{\"view_3d\": \"quizá\", \"shadows\": 3}", ""]:
		var f := FileAccess.open(AJUSTES, FileAccess.WRITE)
		f.store_string(contenido)
		f.close()
		var main = _main_con_ajustes(AJUSTES)
		assert_true(main.enable_3d and main.shadows_enabled, "ajustes ilegibles («%s»): valores por defecto" % contenido)
		assert_true(main._province_view.visible, "y el juego abre normal")
		_quitar(main)
	done()


func test_settings_text_is_read_keeping_only_what_is_valid() -> void:
	var main = load("res://scripts/main.gd")
	assert_eq(main.interpretar_ajustes("{\"view_3d\": false, \"shadows\": true}"), {"view_3d": false, "shadows": true}, "ajustes bien escritos")
	assert_eq(main.interpretar_ajustes("{\"view_3d\": false}"), {"view_3d": false}, "una clave que falta no se inventa")
	assert_eq(main.interpretar_ajustes("{\"view_3d\": \"quizá\", \"shadows\": false}"), {"shadows": false}, "un valor de otro tipo se descarta y el válido se conserva")
	assert_eq(main.interpretar_ajustes("{\"view_3d\": 0, \"shadows\": null}"), {}, "ni números ni nulos valen como verdadero o falso")
	assert_eq(main.interpretar_ajustes("[1, 2]"), {}, "JSON que no es un objeto")
	assert_eq(main.interpretar_ajustes("7"), {}, "JSON que es un número")
	assert_eq(main.interpretar_ajustes("no es json"), {}, "texto que no es JSON")
	assert_eq(main.interpretar_ajustes(""), {}, "archivo vacío")
	assert_eq(main.interpretar_ajustes("{\"otra\": true}"), {}, "claves desconocidas")
	done()


func test_settings_file_is_never_touched_when_persistence_is_off() -> void:
	_limpiar()
	var main = _main_en_arbol()
	main._on_toggle_3d_pressed()
	main._on_toggle_shadows_pressed()
	assert_true(not FileAccess.file_exists(AJUSTES), "sin ruta de ajustes no se escribe nada")
	_quitar(main)
	done()
