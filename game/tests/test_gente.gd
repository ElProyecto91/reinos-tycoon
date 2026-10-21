extends "res://tests/province_case.gd"
## Gente de la vista 3D (aldeanos, obreros, mercado, humo): qué se ve según la provincia
## (provincia_layout.gd, función `gente`) y cómo se mueve (epoca_gente.gd). Solo datos y movimiento;
## cómo se ve se revisa con capturas.

const Layout = preload("res://scripts/view/provincia_layout.gd")
const CIUDAD := "res://scripts/view/ciudad_epoca.gd"
const GENTE := "res://scripts/view/epoca_gente.gd"
const VISTA := "res://scripts/ui/province_view.gd"
const AMBAS := ["cordoba", "norte"]


func _edificios(tipos: Array) -> Array:
	var out: Array = []
	for t in tipos:
		out.append({"type": t})
	return out


func _raiz() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _en_radio(q: int, r: int) -> bool:
	return maxi(maxi(absi(q), absi(r)), absi(q + r)) <= Layout.RADIO


func test_walking_routes_stay_inside_the_map_and_have_at_least_two_points() -> void:
	for aspecto in AMBAS:
		var t: Dictionary = Layout.plantilla(aspecto)
		assert_true((t["rutas"] as Array).size() >= 3, "%s tiene rutas" % aspecto)
		for r in t["rutas"]:
			var pts: Array = r["pts"]
			assert_true(pts.size() >= 2, "%s: una ruta tiene al menos dos puntos" % aspecto)
			for w in pts:
				assert_true(_en_radio(int(w[0]), int(w[1])), "%s: el punto %s está dentro del mapa" % [aspecto, str(w)])
				if w.size() >= 4:
					assert_true(int(w[2]) >= 0 and int(w[2]) <= 5 and float(w[3]) > 0.0 and float(w[3]) <= 1.0, "%s: borde y fracción válidos en %s" % [aspecto, str(w)])
	done()


func test_routes_only_exist_when_what_they_lead_to_is_built() -> void:
	for aspecto in AMBAS:
		var sin: Dictionary = Layout.plan(aspecto, [], [], 60)
		var con: Dictionary = Layout.plan(aspecto, _edificios(["farm", "farm", "mill", "mill", "woodcutter", "woodcutter"]), [], 60)
		var n_sin: int = (sin["gente"]["rutas"] as Array).size()
		var n_con: int = (con["gente"]["rutas"] as Array).size()
		assert_true(n_sin >= 2, "%s: sin edificios aún hay rutas de siempre (%d)" % [aspecto, n_sin])
		assert_true(n_con > n_sin, "%s: con granjas y molinos hay más rutas (%d > %d)" % [aspecto, n_con, n_sin])
	# Una granja habilita la ruta de los campos, y un molino la del molino, en el sur.
	var base: int = (Layout.plan("cordoba", [], [], 0)["gente"]["rutas"] as Array).size()
	assert_eq((Layout.plan("cordoba", _edificios(["farm"]), [], 0)["gente"]["rutas"] as Array).size(), base + 1, "una granja suma una ruta")
	assert_eq((Layout.plan("cordoba", _edificios(["mill"]), [], 0)["gente"]["rutas"] as Array).size(), base + 1, "un molino suma una ruta")
	assert_eq((Layout.plan("cordoba", [], _edificios(["mill"]), 0)["gente"]["rutas"] as Array).size(), base, "una obra de molino todavía no abre la ruta")
	done()


func test_walkers_follow_the_population_with_a_floor_and_a_cap() -> void:
	assert_eq(Layout.plan("cordoba", [], [], 0)["gente"]["caminantes"], 2, "mínimo de 2 aldeanos")
	assert_eq(Layout.plan("cordoba", [], [], 120)["gente"]["caminantes"], 10, "120 habitantes: 10 aldeanos")
	assert_eq(Layout.plan("cordoba", [], [], 100000)["gente"]["caminantes"], Layout.MAX_CAMINANTES, "tope de aldeanos")
	done()


func test_builders_work_at_each_building_site_and_ovens_smoke() -> void:
	var p: Dictionary = Layout.plan("cordoba", _edificios(["bakery"]), _edificios(["farm", "house"]), 60)
	assert_eq((p["gente"]["obras"] as Array).size(), 2, "una casilla de obra por cada obra")
	assert_eq((p["gente"]["humos"] as Array).size(), 1, "un humo por cada panadería terminada")
	var sin: Dictionary = Layout.plan("cordoba", [], [], 60)
	assert_eq((sin["gente"]["humos"] as Array).size(), 0, "sin panadería no hay humo")
	var obra_en_sitio := true
	for c in p["gente"]["obras"]:
		if p["cells"][c]["o"] != "S":
			obra_en_sitio = false
	assert_true(obra_en_sitio, "las obras están donde se dibuja el andamio")
	done()


func test_people_change_does_not_change_the_ground_signature() -> void:
	var a: Dictionary = Layout.plan("cordoba", [], [], 60)
	var b: Dictionary = Layout.plan("cordoba", [], [], 80)
	assert_eq(Layout.firma("cordoba", a), Layout.firma("cordoba", b), "el suelo es el mismo (60 y 80 habitantes: dos manzanas)")
	assert_true(Layout.firma_gente(a) != Layout.firma_gente(b), "pero la gente sí cambia")
	done()


func _gente_de(aspecto: String, edificios: Array, obras: Array, poblacion: int):
	var plan: Dictionary = Layout.plan(aspecto, edificios, obras, poblacion)
	var ciudad = load(CIUDAD).new()
	ciudad.region = aspecto
	_raiz().add_child(ciudad)
	var capas: Dictionary = ciudad.layers_from_cells(plan["radio"], plan["cells"])
	ciudad.build(capas["terrain"], capas["things"], capas["paths"])
	var gente = load(GENTE).new()
	_raiz().add_child(gente)
	gente.configurar(ciudad, plan["gente"], aspecto != "norte")
	return [ciudad, gente, plan]


func _quitar(nodos: Array) -> void:
	for n in nodos:
		_raiz().remove_child(n)
		n.free()


func test_walkers_move_along_their_route_turn_back_at_the_ends_and_never_leave_it() -> void:
	var r: Array = _gente_de("cordoba", _edificios(["farm", "mill", "woodcutter", "woodcutter"]), [], 140)
	var gente = r[1]
	assert_eq(gente.caminantes.size(), 11, "11 aldeanos para 140 habitantes")
	var inicio: Array = []
	for c in gente.caminantes:
		inicio.append((c["mi"] as Node3D).position)
	var se_movio := false
	var dio_la_vuelta := false
	var sentidos: Array = []
	for c in gente.caminantes:
		sentidos.append(c["sentido"])
	var fuera := 0.0
	var vio_inicio: Array = []
	var vio_final: Array = []
	for c in gente.caminantes:
		vio_inicio.append(false)
		vio_final.append(false)
	for paso in 1500:
		gente.avanzar(0.1)
		for i in gente.caminantes.size():
			var c: Dictionary = gente.caminantes[i]
			var pos: Vector3 = (c["mi"] as Node3D).position
			if pos.distance_to(inicio[i]) > 0.2:
				se_movio = true
			if c["sentido"] != sentidos[i]:
				dio_la_vuelta = true
			if float(c["s"]) <= 0.001:
				vio_inicio[i] = true
			if float(c["s"]) >= float(c["largo"]) - 0.001:
				vio_final[i] = true
			# La posición (sin el botecito de andar) está sobre la ruta: la s recorre la ruta y no se sale.
			var info: Dictionary = gente.punto_en(c["pts"], float(c["s"]))
			var d: float = Vector2(pos.x - info["pos"].x, pos.z - info["pos"].z).length()
			fuera = maxf(fuera, d)
			assert_true(float(c["s"]) >= 0.0 and float(c["s"]) <= float(c["largo"]) + 0.001, "s dentro de la ruta")
	assert_true(se_movio, "los aldeanos se mueven")
	assert_true(dio_la_vuelta, "y dan la vuelta en los extremos")
	assert_true(not vio_inicio.has(false) and not vio_final.has(false), "y todos van de un extremo al otro y vuelven")
	assert_true(fuera < 0.001, "y siempre están sobre su ruta (desvío máximo %f)" % fuera)
	_quitar([r[1], r[0]])
	done()


func test_the_bridge_is_walked_on_the_deck_not_through_the_river() -> void:
	var r: Array = _gente_de("cordoba", [], [], 60)
	var gente = r[1]
	var pts: PackedVector3Array = gente.puntos_de_ruta([[0, 0], [0, 1], [0, 2]])
	var sobre_el_puente := 0
	for p in pts:
		if p.y > 0.25:
			sobre_el_puente += 1
	assert_true(sobre_el_puente >= 3, "al cruzar el puente la ruta sube a la calzada (%d puntos altos)" % sobre_el_puente)
	assert_true(pts[0].y < 0.1 and pts[pts.size() - 1].y < 0.1, "y en las orillas vuelve al suelo")
	_quitar([r[1], r[0]])
	done()


func test_builders_stand_at_the_sites_and_the_market_has_people() -> void:
	var r: Array = _gente_de("cordoba", [], _edificios(["farm"]), 60)
	var gente = r[1]
	assert_eq(gente.obreros.size(), 2, "dos obreros por obra")
	assert_eq(gente.parados.size(), 3, "tres personas en el mercado del sur")
	var sitio: Vector2i = r[2]["gente"]["obras"][0]
	var centro := Vector3(2.0 * sitio.x + sitio.y, 0.0, 1.7320508 * sitio.y)
	for o in gente.obreros:
		var d: float = Vector2((o["base"] as Vector3).x - centro.x, (o["base"] as Vector3).z - centro.z).length()
		assert_true(d < 0.6, "el obrero está junto a la obra (%f)" % d)
	var y0: float = (gente.obreros[0]["mi"] as Node3D).position.y
	var subio := false
	for paso in 40:
		gente.avanzar(0.05)
		if (gente.obreros[0]["mi"] as Node3D).position.y > y0 + 0.001:
			subio = true
	assert_true(subio, "el obrero golpea (sube y baja)")
	_quitar([r[1], r[0]])
	done()


func test_smoke_rises_and_starts_over() -> void:
	var r: Array = _gente_de("cordoba", _edificios(["bakery"]), [], 60)
	var gente = r[1]
	assert_eq(gente.humos.size(), 3, "tres bocanadas por horno")
	var base_y: float = (gente.humos[0]["base"] as Vector3).y
	var max_y := base_y
	var reinicio := false
	var anterior := -1.0
	for paso in 300:
		gente.avanzar(0.05)
		var y: float = (gente.humos[0]["mi"] as Node3D).position.y
		max_y = maxf(max_y, y)
		if anterior > 0.0 and y < anterior - 0.2:
			reinicio = true
		anterior = y
	assert_true(max_y > base_y + 0.3, "el humo sube")
	assert_true(reinicio, "y vuelve a empezar desde abajo")
	_quitar([r[1], r[0]])
	done()


func test_the_view_animates_only_when_enabled_and_changing_people_does_not_rebuild_the_ground() -> void:
	var vista = load(VISTA).new()
	_raiz().add_child(vista)
	var p = load(PROVINCE).new(new_data(), "cordoba", "Cordoba", 60)
	vista.mostrar(p)
	assert_true(vista._gente != null, "con la provincia hay gente")
	var s0: float = float(vista._gente.caminantes[0]["s"])
	vista._process(0.5)
	assert_true(float(vista._gente.caminantes[0]["s"]) != s0 or float(vista._gente.caminantes[0]["espera"]) > 0.0, "con animación, avanza")
	vista.set_animacion(false)
	var t0: float = vista._gente._reloj
	vista._process(0.5)
	assert_eq(vista._gente._reloj, t0, "sin animación, la gente se queda quieta")
	vista.set_animacion(true)
	var rec: int = vista.reconstrucciones
	var antes: int = vista._gente.caminantes.size()
	p.population = 80
	vista.mostrar(p)
	assert_eq(vista.reconstrucciones, rec, "más población no reconstruye el suelo")
	assert_true(vista._gente.caminantes.size() > antes, "pero sí suma aldeanos (%d → %d)" % [antes, vista._gente.caminantes.size()])
	_raiz().remove_child(vista)
	vista.free()
	done()
