extends "res://tests/test_case.gd"
## Vista 3D «de época»: constructor de mallas (malla.gd), edificios y paisaje generados por código,
## y el diorama de época (ciudad_epoca.gd). Solo comprueba geometría y estructura (cajas, número de
## triángulos, orientación de las caras, determinismo, símbolos y paleta); cómo se ve se revisa con
## tools/captura_epoca.gd y tools/captura_juego.gd.

const Malla = preload("res://scripts/view/malla.gd")
const Urbano = preload("res://scripts/view/epoca_urbano.gd")
const Campo = preload("res://scripts/view/epoca_campo.gd")
const Defensa = preload("res://scripts/view/epoca_defensa.gd")
const CIUDAD := "res://scripts/view/ciudad_epoca.gd"

const SUR := Color(0.8, 0.7, 0.5)
## Cada edificio cabe en su casilla: la casilla tiene apotema 1,0 (vértices a 1,155).
const LIMITE_XZ := 1.16
const LIMITE_Y_MAX := 1.5
const LIMITE_Y_MIN := -0.25
const MAX_TRIANGULOS := 2000


## Todos los constructores de edificio, paisaje y defensa, con un nombre para los mensajes.
func _constructores() -> Dictionary:
	var c := {}
	c["manzana dispersa"] = func(m): Urbano.manzana(m, 7, 0.55, SUR, false)
	c["manzana densa"] = func(m): Urbano.manzana(m, 7, 0.95, SUR, true)
	c["aldea pequeña"] = func(m): Urbano.aldea(m, 7, 4, false)
	c["aldea grande"] = func(m): Urbano.aldea(m, 7, 6, true)
	c["mezquita aljama"] = func(m): Urbano.mezquita_aljama(m)
	c["mezquita de barrio"] = func(m): Urbano.mezquita_barrio(m)
	c["iglesia mozárabe"] = func(m): Urbano.iglesia_mozarabe(m)
	c["alcázar"] = func(m): Urbano.alcazar(m, false)
	c["alcazaba"] = func(m): Urbano.alcazar(m, true)
	c["mercado sur"] = func(m): Urbano.mercado(m, 3, true)
	c["mercado norte"] = func(m): Urbano.mercado(m, 3, false)
	c["horno sur"] = func(m): Urbano.horno(m, 3, true)
	c["horno norte"] = func(m): Urbano.horno(m, 3, false)
	c["granero sur"] = func(m): Urbano.granero(m, 3, true)
	c["granero norte"] = func(m): Urbano.granero(m, 3, false)
	c["obra"] = func(m): Urbano.obra(m, 3)
	c["bosque mixto"] = func(m): Campo.bosque(m, 5, 9, "mixto")
	c["bosque robledal"] = func(m): Campo.bosque(m, 5, 9, "robledal")
	for tipo in ["h", "H", "M", "N", "Q"]:
		c["relieve " + tipo] = func(m): Campo.relieve(m, tipo, 5, true)
	c["cereal"] = func(m): Campo.campo_secano(m, 5)
	c["huerta"] = func(m): Campo.huerta(m, 5, false)
	c["huerta con noria"] = func(m): Campo.huerta(m, 5, true)
	c["olivar"] = func(m): Campo.olivar(m, 5)
	c["molino de agua"] = func(m): Campo.molino_agua(m, 0.0)
	c["aserradero"] = func(m): Campo.aserradero(m)
	c["herrería"] = func(m): Campo.herreria(m)
	c["puente"] = func(m): Defensa.puente(m, 0.0)
	c["castro"] = func(m): Defensa.castro(m)
	for estilo in ["sillería", "tapial", "piedra", "tierra"]:
		c["muralla " + estilo] = func(m): Defensa.casilla_muralla(m, [0, 3], estilo, false, Vector3(0, 0, 1), true)
		c["puerta " + estilo] = func(m): Defensa.casilla_muralla(m, [0, 3], estilo, true, Vector3(0, 0, 1), true)
	return c


func _vertices_igual(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not a[i].is_equal_approx(b[i]):
			return false
	return true


# --- Malla ---------------------------------------------------------------------------------

func test_a_box_has_five_faces_inside_its_bounds_and_faces_outward() -> void:
	var m = Malla.new()
	m.box(Vector3(1, 0, 2), Vector3(0.6, 0.4, 0.2), Color.WHITE)
	assert_eq(m.triangle_count(), 10, "caja sin base: 5 caras de 2 triángulos")
	var b: AABB = m.bounds()
	assert_true(b.position.is_equal_approx(Vector3(0.7, 0, 1.9)) and b.end.is_equal_approx(Vector3(1.3, 0.4, 2.1)), "la caja ocupa lo pedido: %s" % str(b))
	var v: PackedVector3Array = m.vertices()
	var n: PackedVector3Array = m.normals()
	var centro := Vector3(1, 0.2, 2)
	for i in range(0, v.size(), 3):
		var geom := (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
		assert_true(geom.dot(n[i]) < 0.0, "triángulo %d: vértices en sentido horario visto desde fuera (cara delantera de Godot)" % (i / 3))
		var cm := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		assert_true(n[i].dot(cm - centro) > 0.0, "triángulo %d: la normal mira hacia fuera" % (i / 3))
	done()


func test_push_moves_and_turns_following_the_documented_convention() -> void:
	var m = Malla.new()
	m.push(Vector3(1, 0, 2), 90.0)
	m.box(Vector3.ZERO, Vector3(0.6, 0.2, 0.2), Color.WHITE)
	m.pop()
	var b: AABB = m.bounds()
	# Con 90° el eje x local pasa a -z: la caja larga en x queda larga en z, centrada en (1, 2).
	assert_true(absf(b.size.x - 0.2) < 0.0001 and absf(b.size.z - 0.6) < 0.0001, "girada 90°: %s" % str(b.size))
	assert_true(absf(b.get_center().x - 1.0) < 0.0001 and absf(b.get_center().z - 2.0) < 0.0001, "centrada en el origen del push")
	m.box(Vector3.ZERO, Vector3(0.2, 0.2, 0.2), Color.WHITE)
	assert_true(m.bounds().position.x < 0.11, "tras pop, lo siguiente vuelve al sistema original")
	done()


func test_shapes_keep_to_their_parameters() -> void:
	var m = Malla.new()
	m.cyl(Vector3.ZERO, 0.2, 0.2, 0.5, 8, Color.WHITE)
	var b: AABB = m.bounds()
	assert_true(absf(b.size.y - 0.5) < 0.0001 and b.size.x <= 0.4001 and b.size.x > 0.35, "cilindro: alto y diámetro: %s" % str(b.size))
	var d = Malla.new()
	d.dome(Vector3.ZERO, 0.3, 8, 4, Color.WHITE)
	assert_true(d.bounds().size.y <= 0.3001 and d.bounds().size.y > 0.2, "cúpula: media esfera")
	var p = Malla.new()
	p.pyramid(Vector3.ZERO, Vector3(0.4, 0.3, 0.4), Color.WHITE)
	assert_eq(p.triangle_count(), 4, "pirámide: cuatro caras")
	var g = Malla.new()
	g.gable(Vector3.ZERO, Vector3(0.8, 0.2, 0.4), Color.WHITE)
	assert_eq(g.triangle_count(), 6, "tejado a dos aguas: dos faldones y dos hastiales")
	assert_true(Malla.new().is_empty(), "una malla nueva está vacía")
	done()


func test_arches_horseshoe_is_wider_inside_than_at_the_floor_and_round_is_not() -> void:
	var r := 0.15
	var herradura: PackedVector2Array = Malla.arch_outline(1.0, 0.6, [{"x": 0.0, "r": r, "y": 0.25, "tipo": "herradura"}])
	var medio: PackedVector2Array = Malla.arch_outline(1.0, 0.6, [{"x": 0.0, "r": r, "y": 0.25, "tipo": "medio_punto"}])
	var ancho_h := 0.0
	var pie_h := 0.0
	for p in herradura:
		if absf(p.x) < 0.45:
			ancho_h = maxf(ancho_h, absf(p.x))
			if p.y == 0.0:
				pie_h = maxf(pie_h, absf(p.x))
	# El arco se muestrea cada 16,9°: el punto más ancho muestreado queda a menos de un 3 % del radio.
	assert_true(ancho_h > r * 0.97 and ancho_h <= r + 0.0001, "la herradura llega casi a todo el radio a la altura del arranque (%.4f de %.4f)" % [ancho_h, r])
	assert_true(absf(pie_h - r * 0.70710678) < 0.0001, "y se estrecha a 0,707·r en el suelo (la «herradura»)")
	var ancho_m := 0.0
	var pie_m := 0.0
	for p in medio:
		if absf(p.x) < 0.45:
			ancho_m = maxf(ancho_m, absf(p.x))
			if p.y == 0.0:
				pie_m = maxf(pie_m, absf(p.x))
	assert_true(absf(pie_m - r) < 0.0001 and absf(ancho_m - r) < 0.0001, "el medio punto es igual de ancho abajo que arriba")
	assert_true(Geometry2D.triangulate_polygon(herradura).size() >= 3 and Geometry2D.triangulate_polygon(medio).size() >= 3, "ambos contornos se pueden triangular")
	for p in herradura:
		assert_true(p.x >= -0.5001 and p.x <= 0.5001 and p.y >= -0.0001 and p.y <= 0.6001, "el contorno no se sale del muro")
	var m = Malla.new()
	m.arch_wall(Vector3.ZERO, 1.0, 0.6, 0.1, [{"x": 0.0, "r": r, "y": 0.25, "tipo": "herradura"}], Color.WHITE)
	assert_true(m.triangle_count() > 20, "un muro con arco tiene caras, lados y trasdós")
	done()


func test_lump_hills_are_irregular_but_always_the_same() -> void:
	var a = Malla.new()
	a.lump(Vector3.ZERO, 1.0, 0.6, 12, 4, 9, Color.DARK_GREEN, Color.GREEN, Color.WHITE)
	var b = Malla.new()
	b.lump(Vector3.ZERO, 1.0, 0.6, 12, 4, 9, Color.DARK_GREEN, Color.GREEN, Color.WHITE)
	var c = Malla.new()
	c.lump(Vector3.ZERO, 1.0, 0.6, 12, 4, 10, Color.DARK_GREEN, Color.GREEN, Color.WHITE)
	assert_true(_vertices_igual(a.vertices(), b.vertices()), "misma semilla, misma colina")
	assert_true(not _vertices_igual(a.vertices(), c.vertices()), "otra semilla, otra colina")
	assert_true(a.bounds().size.y > 0.3 and a.bounds().size.y <= 0.7, "la colina tiene la altura pedida: %s" % str(a.bounds().size.y))
	done()


# --- Edificios, paisaje y defensas ---------------------------------------------------------

func test_every_period_building_fits_its_tile_and_its_budget() -> void:
	var todos := _constructores()
	for nombre in todos.keys():
		var m = Malla.new()
		todos[nombre].call(m)
		assert_true(not m.is_empty(), "%s: genera geometría" % nombre)
		assert_true(m.triangle_count() <= MAX_TRIANGULOS, "%s: %d triángulos (máximo %d por casilla)" % [nombre, m.triangle_count(), MAX_TRIANGULOS])
		var b: AABB = m.bounds()
		assert_true(b.position.x >= -LIMITE_XZ and b.end.x <= LIMITE_XZ and b.position.z >= -LIMITE_XZ and b.end.z <= LIMITE_XZ, "%s: cabe en la casilla (%s)" % [nombre, str(b)])
		assert_true(b.position.y >= LIMITE_Y_MIN and b.end.y <= LIMITE_Y_MAX, "%s: altura razonable (%s)" % [nombre, str(b)])
		var n: PackedVector3Array = m.normals()
		for q in n:
			assert_true(absf(q.length() - 1.0) < 0.01, "%s: normales unitarias" % nombre)
			if absf(q.length() - 1.0) >= 0.01:
				break
	done()


func test_building_generation_is_deterministic_and_seeds_change_the_town() -> void:
	var a = Malla.new()
	Urbano.manzana(a, 11, 0.9, SUR, false)
	var b = Malla.new()
	Urbano.manzana(b, 11, 0.9, SUR, false)
	var c = Malla.new()
	Urbano.manzana(c, 12, 0.9, SUR, false)
	assert_true(_vertices_igual(a.vertices(), b.vertices()), "misma semilla, mismo barrio")
	assert_true(not _vertices_igual(a.vertices(), c.vertices()), "otra semilla, otro barrio")
	var u = load("res://scripts/view/epoca_util.gd")
	assert_eq(u.seed_of(3, -2), u.seed_of(3, -2), "la semilla de una casilla es estable")
	assert_true(u.seed_of(3, -2) != u.seed_of(-2, 3), "casillas distintas, semillas distintas")
	for k in 50:
		var x: float = u.rnd(5, k)
		assert_true(x >= 0.0 and x < 1.0, "rnd está en [0, 1)")
	done()


func test_denser_districts_have_more_houses_and_the_horseshoe_minaret_stands_tallest() -> void:
	var poca = Malla.new()
	Urbano.manzana(poca, 7, 0.3, SUR, false)
	var mucha = Malla.new()
	Urbano.manzana(mucha, 7, 0.95, SUR, false)
	assert_true(mucha.triangle_count() > poca.triangle_count(), "más densidad, más casas")
	var aljama = Malla.new()
	Urbano.mezquita_aljama(aljama)
	var iglesia = Malla.new()
	Urbano.iglesia_mozarabe(iglesia)
	assert_true(aljama.bounds().end.y > 1.0, "el alminar de la aljama destaca sobre todo lo demás")
	assert_true(iglesia.bounds().end.y < 0.5, "la iglesia mozárabe es baja y sin torre (sin fuente de torre en el 1000)")
	done()


func test_wall_styles_differ_and_gates_add_geometry() -> void:
	var cuentas := {}
	for estilo in ["sillería", "tapial", "piedra", "tierra"]:
		var muro = Malla.new()
		Defensa.casilla_muralla(muro, [0, 3], estilo, false, Vector3(0, 0, 1), true)
		var puerta = Malla.new()
		Defensa.casilla_muralla(puerta, [0, 3], estilo, true, Vector3(0, 0, 1), true)
		assert_true(puerta.triangle_count() > muro.triangle_count(), "%s: la puerta añade geometría" % estilo)
		cuentas[estilo] = Defensa.color_muro(estilo)
	assert_true(cuentas["sillería"] != cuentas["tapial"] and cuentas["tapial"] != cuentas["tierra"] and cuentas["piedra"] != cuentas["tierra"], "cada estilo tiene su color")
	var sin_torres = Malla.new()
	Defensa.casilla_muralla(sin_torres, [0, 3], "sillería", false, Vector3(0, 0, 1), false)
	var con_torres = Malla.new()
	Defensa.casilla_muralla(con_torres, [0, 3], "sillería", false, Vector3(0, 0, 1), true)
	assert_true(con_torres.triangle_count() > sin_torres.triangle_count(), "las torres añaden geometría")
	done()


# --- Diorama de época ----------------------------------------------------------------------

func _ciudad_con(region: String, cells: Dictionary, radio: int):
	var d = load(CIUDAD).new()
	d.region = region
	var capas: Dictionary = d.layers_from_cells(radio, cells)
	assert_eq(capas["errors"].size(), 0, "el diseño de prueba cabe en el mapa: %s" % str(capas["errors"]))
	assert_true(d.build(capas["terrain"], capas["things"], capas["paths"]), "el diseño de prueba se construye (%s)" % region)
	return d


func _celdas_con_todos_los_simbolos() -> Dictionary:
	var simbolos := "oOEYCTtsFWaAihHMNQVLZxXyzKpgS"
	var celdas := {}
	var radio := 3
	var i := 0
	for q in range(-radio, radio + 1):
		for r in range(-radio, radio + 1):
			if maxi(maxi(absi(q), absi(r)), absi(q + r)) > radio or i >= simbolos.length():
				continue
			celdas[Vector2i(q, r)] = {"o": simbolos[i]}
			i += 1
	return celdas


func test_every_region_builds_every_symbol_and_counts_its_triangles() -> void:
	for region in ["cordoba", "toledo", "zaragoza", "norte"]:
		var d = _ciudad_con(region, _celdas_con_todos_los_simbolos(), 3)
		assert_true(d.triangulos > 1000, "%s: se generaron triángulos (%d)" % [region, d.triangulos])
		var contados := 0
		for hijo in d.get_children():
			if hijo is MeshInstance3D and hijo.scene_file_path == "" and hijo.mesh != null:
				for s in hijo.mesh.get_surface_count():
					var arrays: Array = hijo.mesh.surface_get_arrays(s)
					contados += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		assert_eq(contados, d.triangulos, "%s: el contador coincide con lo que hay en las mallas" % region)
		d.free()
	done()


func test_unknown_region_builds_nothing() -> void:
	var d = load(CIUDAD).new()
	d.region = "atlantida"
	var capas: Dictionary = d.layers_from_cells(1, {})
	# push_error es esperado: la región no existe.
	assert_true(not d.build(capas["terrain"], capas["things"], capas["paths"]), "una región desconocida no se construye")
	assert_eq(d.get_child_count(), 0, "y no deja nada a medias")
	d.free()
	done()


func _paletas_de(d) -> Dictionary:
	var rutas := {}
	for hijo in d.get_children():
		if hijo.scene_file_path != "":
			_recoger_paletas(hijo, rutas)
	return rutas


func _recoger_paletas(nodo: Node, rutas: Dictionary) -> void:
	# Los pilares de roca llevan material propio (material_override): no usan la paleta.
	if nodo is MeshInstance3D and nodo.mesh != null and nodo.material_override == null:
		for s in nodo.mesh.get_surface_count():
			var mat = nodo.get_surface_override_material(s)
			var tex = null if mat == null else (mat as BaseMaterial3D).albedo_texture
			var ruta: String = "ninguna" if tex == null else tex.resource_path
			rutas[ruta] = int(rutas.get(ruta, 0)) + 1
	for hijo in nodo.get_children():
		_recoger_paletas(hijo, rutas)


func test_regions_swap_the_ground_palette_and_leave_the_original_view_alone() -> void:
	var celdas := {Vector2i(0, 0): {"o": "o"}, Vector2i(1, 0): {"p": "r"}, Vector2i(-1, 0): {"p": "r"}}
	var sur = _ciudad_con("cordoba", celdas, 1)
	var paletas_sur: Dictionary = _paletas_de(sur)
	assert_eq(paletas_sur.keys(), [load(CIUDAD).PALETA_SECA], "el sur usa solo la paleta seca: %s" % str(paletas_sur))
	sur.free()
	var norte = _ciudad_con("norte", celdas, 1)
	var paletas_norte: Dictionary = _paletas_de(norte)
	assert_eq(paletas_norte.keys(), [load(CIUDAD).PALETA_NORTE], "el norte usa solo la paleta norte: %s" % str(paletas_norte))
	norte.free()
	# La vista original de KayKit no cambia: sus modelos no llevan material propio.
	var original = load("res://scripts/view/diorama.gd").new()
	var capas: Dictionary = original.layers_from_cells(1, celdas)
	assert_true(original.build(capas["terrain"], capas["things"], capas["paths"]), "el diorama original sigue construyéndose")
	assert_eq(_paletas_de(original).keys(), ["ninguna"], "y conserva la paleta del modelo")
	original.free()
	done()


func test_the_period_view_keeps_kaykit_for_what_it_does_not_replace() -> void:
	# Cuatro casillas con algo que la vista de época no redefine («D» = colina de KayKit, «S» = obra propia).
	var celdas := {Vector2i(0, 0): {"o": "S"}, Vector2i(1, 0): {"o": "o"}}
	var d = _ciudad_con("cordoba", celdas, 1)
	var propios := 0
	var kaykit := 0
	for hijo in d.get_children():
		if hijo.scene_file_path == "":
			propios += 1
		else:
			kaykit += 1
	assert_true(propios >= 2, "las casas y la obra son mallas propias (%d)" % propios)
	assert_true(kaykit >= 7, "el suelo sigue siendo de KayKit (%d)" % kaykit)
	d.free()
	done()


func test_undergrowth_stays_inside_the_cell_is_deterministic_and_differs_between_cells() -> void:
	for seco in [true, false]:
		var m := Malla.new()
		Campo.maleza(m, 1234, seco)
		assert_true(not m.is_empty(), "hay maleza (seco=%s)" % seco)
		assert_true(m.triangle_count() < 1500, "pocos triángulos: %d" % m.triangle_count())
		var b: AABB = m.bounds()
		assert_true(b.position.x >= -LIMITE_XZ and b.end.x <= LIMITE_XZ and b.position.z >= -LIMITE_XZ and b.end.z <= LIMITE_XZ, "cabe en la casilla")
		assert_true(b.end.y < 0.2 and b.position.y >= -0.05, "es baja: altura %.2f" % b.end.y)
		var m2 := Malla.new()
		Campo.maleza(m2, 1234, seco)
		assert_eq(m2.vertices(), m.vertices(), "misma casilla, mismo resultado")
		var m3 := Malla.new()
		Campo.maleza(m3, 99, seco)
		assert_true(m3.vertices() != m.vertices(), "otra casilla, otro dibujo")
	done()


func test_undergrowth_only_on_empty_cells() -> void:
	var ciudad = load(CIUDAD).new()
	ciudad.region = "norte"
	var capas: Dictionary = ciudad.layers_from_cells(1, {Vector2i(0, 0): {"o": "T"}, Vector2i(1, 0): {"p": "r"}})
	assert_true(ciudad.build(capas["terrain"], capas["things"], capas["paths"]), "se construye")
	var vacias := 0
	var ocupadas := 0
	for hijo in ciudad.get_children():
		if str(hijo.name).begins_with("maleza_"):
			var partes := str(hijo.name).split("_")
			var k := Vector2i(int(partes[1]), int(partes[2]))
			if k == Vector2i(0, 0) or k == Vector2i(1, 0):
				ocupadas += 1
			else:
				vacias += 1
	var formas := {}
	for hijo in ciudad.get_children():
		if str(hijo.name).begins_with("maleza_") and hijo is MeshInstance3D:
			formas[(hijo as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].to_byte_array().hex_encode().hash()] = true
	assert_true(formas.size() >= 4, "cada casilla vacía tiene su propio dibujo (%d distintos de 5)" % formas.size())
	assert_eq(ocupadas, 0, "ni bosque ni río llevan maleza")
	assert_eq(vacias, 5, "las otras 5 casillas de radio 1 sí")
	ciudad.free()
	done()
