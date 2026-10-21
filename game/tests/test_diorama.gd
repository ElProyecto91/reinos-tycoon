extends "res://tests/test_case.gd"
## Vista 3D (diorama): modelos, rejilla hexagonal, casillas de río/camino/costa, murallas y validación.
## Solo comprueba datos y estructura; cómo se ve se revisa con tools/captura_diorama.gd.

const DIORAMA := "res://scripts/view/diorama.gd"


func _new_diorama(faction: String = "blue"):
	var d = load(DIORAMA).new()
	d.faction = faction
	return d


func _errors_text(errors: Array) -> String:
	return "\n".join(errors)


## Construye un diorama de radio 2 (19 casillas) a partir de casillas por coordenadas axiales.
func _built(cells: Dictionary, radius: int = 2, towers: bool = true):
	var d = _new_diorama()
	d.wall_towers = towers
	var layers: Dictionary = d.layers_from_cells(radius, cells)
	assert_eq(layers["errors"].size(), 0, "el diseño de prueba cabe en el mapa: %s" % _errors_text(layers["errors"]))
	assert_true(d.build(layers["terrain"], layers["things"], layers["paths"]), "el diseño de prueba se construye")
	return d


## Nodos colocados cuyo modelo es `file` (por el nombre del archivo) en la casilla (q, r).
func _nodes_at(d, file: String, q: int, r: int) -> Array:
	var found: Array = []
	var at: Vector3 = d.hex_to_world(q, r)
	for child in d.get_children():
		if absf(child.position.x - at.x) < 0.01 and absf(child.position.z - at.z) < 0.01:
			if child.scene_file_path.get_file().get_basename() == file:
				found.append(child)
	return found


## Primer modelo de la casilla cuyo nombre empieza por prefix (o null).
func _first_with_prefix(d, prefix: String, q: int, r: int):
	var at: Vector3 = d.hex_to_world(q, r)
	for child in d.get_children():
		if absf(child.position.x - at.x) < 0.01 and absf(child.position.z - at.z) < 0.01:
			if child.scene_file_path.get_file().get_basename().begins_with(prefix):
				return child
	return null


## Bordes que cubre un modelo de la tabla `tiles` cuando se gira rot grados.
func _edges(tiles: Dictionary, file: String, rot: float) -> Array:
	var k := int(round(rot / 60.0)) % 6
	var edges: Array = []
	for e in tiles[file]:
		edges.append((e + k) % 6)
	edges.sort()
	return edges


func _count_with_prefix(d, prefix: String) -> int:
	var n := 0
	for child in d.get_children():
		if child.scene_file_path.get_file().get_basename().begins_with(prefix):
			n += 1
	return n


func test_every_model_loads_for_every_faction() -> void:
	for faction in ["blue", "green", "red"]:
		var d = _new_diorama(faction)
		for key in d.MODELS.keys():
			var scene = d.model(key)
			assert_true(scene != null and scene is PackedScene, "modelo «%s» (%s) debe cargarse" % [key, faction])
			if scene != null:
				var node = scene.instantiate()
				assert_true(node is Node3D, "modelo «%s» (%s) debe ser un nodo 3D" % [key, faction])
				node.free()
		d.free()
	done()


func test_every_tile_of_the_auto_tables_loads() -> void:
	var d = _new_diorama()
	for table in [d.RIVER_TILES, d.ROAD_TILES, d.COAST_TILES, d.CROSSING_TILES]:
		for file in table.keys():
			assert_true(d.file_model(file) != null, "casilla «%s» debe cargarse" % file)
			assert_true(table[file].size() >= 1 and table[file].size() <= 6, "«%s»: entre 1 y 6 bordes" % file)
			for e in table[file]:
				assert_true(e >= 0 and e < 6, "«%s»: bordes del 0 al 5" % file)
	d.free()
	done()


func test_the_six_neighbors_of_a_tile_are_exactly_two_units_away_in_the_edge_directions() -> void:
	var d = _new_diorama()
	for q in [-3, 0, 2]:
		for r in [-2, 0, 3]:
			var center: Vector3 = d.hex_to_world(q, r)
			for e in 6:
				var other: Vector3 = d.hex_to_world(q + d.DIRS[e].x, r + d.DIRS[e].y)
				assert_true(absf(center.distance_to(other) - 2.0) < 0.0001, "vecino por el borde %d a 2,0" % e)
				# El borde e mira en la dirección de 60·e grados (0 = este, sentido contrario a las agujas
				# del reloj visto desde arriba; el norte es -z).
				var angle := rad_to_deg(atan2(-(other.z - center.z), other.x - center.x))
				var expected := 60.0 * float(e)
				var diff := fposmod(angle - expected + 180.0, 360.0) - 180.0
				assert_true(absf(diff) < 0.01, "borde %d en la dirección %d° (obtenido %.1f°)" % [e, int(expected), angle])
	assert_eq(d.hex_to_world(1, 2, 3.0).y, 3.0, "la altura se conserva")
	d.free()
	done()


func test_layers_from_cells_shapes_defaults_and_out_of_range() -> void:
	var d = _new_diorama()
	var layers: Dictionary = d.layers_from_cells(1, {Vector2i(0, 0): {"t": "1", "p": "c", "o": "C"}})
	assert_eq(layers["terrain"], ["00", "010", "00"], "terreno con valores por defecto")
	assert_eq(layers["paths"], ["..", ".c.", ".."], "caminos")
	assert_eq(layers["things"], ["..", ".C.", ".."], "objetos")
	assert_eq(layers["errors"].size(), 0, "sin errores")
	var bad: Dictionary = d.layers_from_cells(1, {Vector2i(1, 1): {}, Vector2i(0, 0): {}})
	assert_eq(bad["errors"].size(), 1, "una casilla fuera del radio")
	assert_true(_errors_text(bad["errors"]).contains("(1, 1)"), "el error dice cuál")
	d.free()
	done()


func test_a_valid_layout_has_no_errors() -> void:
	var d = _new_diorama()
	assert_eq(d.validate(["00", "000", "00"], ["..", "...", ".."]).size(), 0, "radio 1 sin caminos")
	assert_eq(d.validate(["00", "000", "00"], ["..", "...", ".."], ["..", ".c.", ".."]).size(), 0, "radio 1 con caminos")
	assert_eq(d.validate(["0"], ["."]).size(), 0, "radio 0 válido")
	d.free()
	done()


func test_layout_with_wrong_shape_or_symbols_is_rejected() -> void:
	var d = _new_diorama()
	assert_true(_errors_text(d.validate(["00", "000"], ["..", "..."])).contains("impar"), "número de filas par")
	assert_true(_errors_text(d.validate(["00", "000", "00"], ["..", "..."])).contains("filas"), "capas de distinto tamaño")
	assert_true(_errors_text(d.validate(["00", "00", "00"], ["..", "...", ".."])).contains("debe tener 3"), "fila central corta")
	assert_true(_errors_text(d.validate(["00", "000", "00"], ["..", "....", ".."])).contains("debe tener 3"), "fila de objetos larga")
	assert_true(_errors_text(d.validate(["00", "0a0", "00"], ["..", "...", ".."])).contains("«a»"), "símbolo de terreno desconocido")
	assert_true(_errors_text(d.validate(["00", "000", "00"], ["..", ".%.", ".."])).contains("«%»"), "símbolo de objeto desconocido")
	assert_true(_errors_text(d.validate(["00", "000", "00"], ["..", "...", ".."], ["..", ".q.", ".."])).contains("«q»"), "símbolo de camino desconocido")
	assert_true(_errors_text(d.validate(["00", "000", "00"], ["..", "...", ".."], ["..", "..", ".."])).contains("caminos: debe tener 3"), "fila de caminos corta")
	assert_true(_errors_text(d.validate(["00", "000", "00"], ["..", "...", ".."], ["..", "..."])).contains("caminos"), "capa de caminos de otro tamaño")
	d.free()
	done()


func test_invalid_layout_builds_nothing() -> void:
	var d = _new_diorama()
	# push_error es esperado aquí: el diseño es inválido a propósito.
	var ok: bool = d.build(["00", "00", "00"], ["..", "...", ".."])
	assert_true(not ok, "build debe devolver false")
	assert_eq(d.get_child_count(), 0, "no se construye nada a medias")
	d.free()
	done()


func test_each_land_tile_is_a_thin_grass_cap_on_a_rock_pillar_down_to_the_base() -> void:
	for height in [0, 1, 2]:
		var d = _new_diorama()
		var layers: Dictionary = d.layers_from_cells(0, {Vector2i(0, 0): {"t": str(height)}})
		assert_true(d.build(layers["terrain"], layers["things"], layers["paths"]), "una casilla de altura %d" % height)
		assert_eq(d.get_child_count(), 2, "altura %d: capa de césped y pilar" % height)
		var cap = null
		var pillar = null
		for child in d.get_children():
			if _material_of(child) != null:
				pillar = child
			else:
				cap = child
		assert_true(cap != null and pillar != null, "altura %d: hay capa y pilar" % height)
		if cap != null and pillar != null:
			assert_eq(cap.position.y, float(height), "altura %d: la capa está en y = %d" % [height, height])
			assert_true(absf(cap.scale.y - d.CAP) < 0.0001, "la capa es fina")
			# La base del pilar está siempre en y = -1 y su parte de arriba toca la capa, sin huecos.
			var pillar_top: float = pillar.position.y
			var pillar_bottom: float = pillar.position.y - pillar.scale.y
			assert_true(absf(pillar_bottom + 1.0) < 0.0001, "altura %d: el pilar llega hasta y = -1 (base %.3f)" % [height, pillar_bottom])
			assert_true(absf(pillar_top - (float(height) - d.CAP)) < 0.0001, "altura %d: el pilar toca la capa" % height)
		d.free()
	done()


func _material_of(node: Node):
	if node is MeshInstance3D and (node as MeshInstance3D).material_override != null:
		return (node as MeshInstance3D).material_override
	for child in node.get_children():
		var m = _material_of(child)
		if m != null:
			return m
	return null


func test_water_cells_are_single_flat_tiles() -> void:
	var d = _built({Vector2i(0, 0): {"t": "w"}, Vector2i(1, 0): {"t": "w"}}, 1)
	assert_eq(_nodes_at(d, "hex_water", 0, 0).size(), 1, "una pieza de agua en (0,0)")
	assert_eq(_nodes_at(d, "hex_water", 1, 0).size(), 1, "una pieza de agua en (1,0)")
	assert_eq(_count_with_prefix(d, "hex_water"), 2, "solo dos casillas de agua")
	assert_eq(d.get_child_count(), 2 + 5 * 2, "2 de agua y 5 casillas de tierra con 2 piezas cada una")
	d.free()
	done()


func test_things_sit_on_top_of_the_tile_height() -> void:
	var d = _built({Vector2i(0, 0): {"t": "1", "o": "C"}}, 1)
	var castle = _first_with_prefix(d, "building_castle", 0, 0)
	assert_true(castle != null, "hay un castillo")
	if castle != null:
		assert_eq(castle.position.y, 1.0, "el castillo se apoya a la altura de la casilla")
	d.free()
	done()


func test_straight_road_bend_and_dead_end_pick_the_tile_with_the_right_edges() -> void:
	# Recta de este a oeste
	var d = _built({Vector2i(-1, 0): {"p": "c"}, Vector2i(0, 0): {"p": "c"}, Vector2i(1, 0): {"p": "c"}})
	var mid = _first_with_prefix(d, "hex_road", 0, 0)
	assert_true(mid != null, "casilla de camino en el centro")
	if mid != null:
		var file: String = mid.scene_file_path.get_file().get_basename()
		assert_eq(_edges(d.ROAD_TILES, file, mid.rotation_degrees.y), [0, 3], "recta: bordes este y oeste (%s)" % file)
	d.free()
	# Giro: este y noroeste (diferencia de 2 bordes)
	var b = _built({Vector2i(0, 0): {"p": "c"}, Vector2i(1, 0): {"p": "c"}, Vector2i(0, -1): {"p": "c"}})
	var bend = _first_with_prefix(b, "hex_road", 0, 0)
	if bend != null:
		var file2: String = bend.scene_file_path.get_file().get_basename()
		assert_eq(_edges(b.ROAD_TILES, file2, bend.rotation_degrees.y), [0, 2], "giro: bordes este y noroeste (%s)" % file2)
	else:
		assert_true(false, "casilla de camino en el giro")
	b.free()
	# Fondo de saco: un solo vecino
	var e = _built({Vector2i(0, 0): {"p": "c"}, Vector2i(0, 1): {"p": "c"}})
	var end_piece = _first_with_prefix(e, "hex_road", 0, 0)
	if end_piece != null:
		var file3: String = end_piece.scene_file_path.get_file().get_basename()
		assert_eq(file3, "hex_road_M", "un solo vecino: casilla de fondo de saco")
		assert_eq(_edges(e.ROAD_TILES, file3, end_piece.rotation_degrees.y), [5], "mira hacia el vecino del sureste")
	else:
		assert_true(false, "casilla de camino de fondo de saco")
	e.free()
	done()


func test_a_road_with_no_neighbors_is_plain_grass() -> void:
	var d = _built({Vector2i(0, 0): {"p": "c"}})
	assert_true(_first_with_prefix(d, "hex_road", 0, 0) == null, "un camino aislado no dibuja camino")
	assert_eq(_nodes_at(d, "hex_grass", 0, 0).size(), 2, "césped: capa y pilar")
	d.free()
	done()


func test_river_open_end_continues_off_the_map_and_closed_end_becomes_a_pond() -> void:
	# R en el borde del mapa: el río sigue hacia fuera en línea recta.
	var open = _built({Vector2i(1, 0): {"p": "r"}, Vector2i(2, 0): {"p": "R"}})
	var end_tile = _first_with_prefix(open, "hex_river", 2, 0)
	assert_true(end_tile != null, "casilla de río en el borde")
	if end_tile != null:
		var file: String = end_tile.scene_file_path.get_file().get_basename()
		assert_eq(_edges(open.RIVER_TILES, file, end_tile.rotation_degrees.y), [0, 3], "sigue hacia el este (fuera del mapa)")
	open.free()
	# r (minúscula) en el borde: no continúa; un río con un solo borde no existe y queda como estanque.
	var closed = _built({Vector2i(1, 0): {"p": "r"}, Vector2i(2, 0): {"p": "r"}})
	assert_eq(_nodes_at(closed, "hex_water", 2, 0).size(), 1, "extremo cerrado: estanque")
	closed.free()
	done()


func test_river_connects_to_lakes_and_bends_by_edges() -> void:
	# Un río que gira al llegar al lago: (0,0) conecta con el lago por el borde suroeste y con (1,-1)... (noreste)
	var d = _built({Vector2i(0, 0): {"p": "r"}, Vector2i(1, -1): {"p": "r"}, Vector2i(-1, 1): {"t": "w"}})
	var tile = _first_with_prefix(d, "hex_river", 0, 0)
	assert_true(tile != null, "casilla de río junto al lago")
	if tile != null:
		var file: String = tile.scene_file_path.get_file().get_basename()
		assert_eq(_edges(d.RIVER_TILES, file, tile.rotation_degrees.y), [1, 4], "bordes noreste y suroeste (el lago cuenta como agua)")
	d.free()
	done()


func test_shore_tiles_face_the_water() -> void:
	# Un lago de una casilla: la casilla de tierra de al lado tiene agua en un borde.
	var d = _built({Vector2i(0, 0): {"t": "w"}})
	var shore = _first_with_prefix(d, "hex_coast", 1, 0)
	assert_true(shore != null, "orilla en (1,0)")
	if shore != null:
		var file: String = shore.scene_file_path.get_file().get_basename()
		assert_eq(_edges(d.COAST_TILES, file, shore.rotation_degrees.y), [3], "el agua queda al oeste")
	d.free()
	# Dos bordes de agua seguidos
	var two = _built({Vector2i(0, 0): {"t": "w"}, Vector2i(1, -1): {"t": "w"}})
	var shore2 = _first_with_prefix(two, "hex_coast", 1, 0)
	assert_true(shore2 != null, "orilla con dos bordes de agua")
	if shore2 != null:
		var file2: String = shore2.scene_file_path.get_file().get_basename()
		assert_eq(_edges(two.COAST_TILES, file2, shore2.rotation_degrees.y), [2, 3], "el agua queda al noroeste y al oeste")
	two.free()
	# Dos bordes de agua separados: no hay pieza para eso, queda césped
	var apart = _built({Vector2i(0, 1): {"t": "w"}, Vector2i(2, 1): {"t": "w"}, Vector2i(1, 0): {}}, 3)
	assert_true(_first_with_prefix(apart, "hex_coast", 1, 1) == null, "agua en bordes separados: césped normal")
	apart.free()
	done()


func test_wall_ring_uses_corners_and_straights_facing_outward() -> void:
	var cells := {}
	for cell in [Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(-1, 2), Vector2i(-2, 2), Vector2i(-2, 1),
			Vector2i(-2, 0), Vector2i(-1, -1), Vector2i(0, -2), Vector2i(1, -2), Vector2i(2, -2), Vector2i(2, -1)]:
		cells[cell] = {"p": "m"}
	var d = _built(cells)
	assert_eq(_count_with_prefix(d, "wall_corner"), 6, "6 esquinas en un anillo de radio 2")
	assert_eq(_count_with_prefix(d, "wall_straight"), 6, "6 tramos rectos")
	assert_eq(_count_with_prefix(d, "building_tower"), 6, "una torre por esquina")
	for child in d.get_children():
		var name: String = child.scene_file_path.get_file().get_basename()
		if name == "wall_straight":
			# La cara buena (+z sin girar) mira hacia fuera del anillo, no hacia el centro.
			var normal := Vector3(sin(deg_to_rad(child.rotation_degrees.y)), 0.0, cos(deg_to_rad(child.rotation_degrees.y)))
			var outward: Vector3 = child.position
			outward.y = 0.0
			assert_true(normal.dot(outward) > 0.0, "tramo en (%.1f, %.1f): la cara buena mira hacia fuera" % [child.position.x, child.position.z])
	d.free()
	var plain = _built(cells, 2, false)
	assert_eq(_count_with_prefix(plain, "building_tower"), 0, "sin torres si se desactivan")
	plain.free()
	done()


func test_gate_has_a_road_under_it_and_replaces_a_straight_piece() -> void:
	var cells := {}
	for cell in [Vector2i(-2, 2), Vector2i(-1, 2), Vector2i(0, 2)]:
		cells[cell] = {"p": "m"}
	cells[Vector2i(-1, 2)] = {"p": "g"}
	cells[Vector2i(-1, 3)] = {"p": "c"}
	cells[Vector2i(-1, 1)] = {"p": "c"}
	var d = _built(cells, 3)
	assert_eq(_nodes_at(d, "wall_straight_gate", -1, 2).size(), 1, "la puerta es una pieza de muralla con puerta")
	assert_eq(_nodes_at(d, "wall_straight", -1, 2).size(), 0, "y no un tramo recto normal")
	assert_true(_first_with_prefix(d, "hex_road", -1, 2) != null, "hay camino bajo la puerta")
	d.free()
	done()


func test_every_allowed_symbol_builds_something() -> void:
	var probe = _new_diorama()
	var things: String = probe.THING_SYMBOLS
	var paths: String = probe.PATH_SYMBOLS
	probe.free()
	assert_true(things.contains("t") and things.contains("T"), "bosque grande y mediano están permitidos")
	var checked := 0
	for symbol in things:
		if symbol == ".":
			continue
		var d = _new_diorama()
		assert_true(d.build(["0"], [symbol]), "símbolo «%s» se construye" % symbol)
		# Suelo (capa y pilar) más al menos un modelo: un símbolo sin modelo dejaría solo el suelo.
		assert_true(d.get_child_count() >= 3, "símbolo «%s» añade al menos un modelo a la casilla" % symbol)
		d.free()
		checked += 1
	assert_true(checked >= 25, "se probaron todos los símbolos de objetos (%d)" % checked)
	for symbol in paths:
		var d2 = _new_diorama()
		assert_true(d2.build(["0"], ["."], [symbol]), "símbolo de camino «%s» se construye" % symbol)
		assert_true(d2.get_child_count() >= 1, "símbolo de camino «%s» deja algo" % symbol)
		d2.free()
	var empty = _new_diorama()
	assert_true(empty.build(["0"], ["."]), "casilla vacía")
	assert_eq(empty.get_child_count(), 2, "solo el suelo")
	empty.free()
	done()
