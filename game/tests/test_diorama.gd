extends "res://tests/test_case.gd"
## Vista 3D (diorama): modelos, rejilla hexagonal y validación del diseño.
## Solo comprueba datos y estructura; cómo se ve se revisa con tools/captura_diorama.gd.

const DIORAMA := "res://scripts/view/diorama.gd"


func _new_diorama(faction: String = "blue"):
	var d = load(DIORAMA).new()
	d.faction = faction
	return d


func _errors_text(errors: Array) -> String:
	return "\n".join(errors)


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


func test_the_six_neighbors_of_a_tile_are_exactly_two_units_away() -> void:
	var d = _new_diorama()
	var dirs := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, -1], [-1, 1]]
	for q in [-3, 0, 2]:
		for r in [-2, 0, 3]:
			var center: Vector3 = d.hex_to_world(q, r)
			for dir in dirs:
				var other: Vector3 = d.hex_to_world(q + dir[0], r + dir[1])
				assert_true(absf(center.distance_to(other) - 2.0) < 0.0001,
					"vecino (%d,%d)->(%d,%d) a 2,0 de distancia" % [q, r, q + dir[0], r + dir[1]])
	assert_eq(d.hex_to_world(1, 2, 3.0).y, 3.0, "la altura se conserva")
	d.free()
	done()


func test_a_valid_layout_has_no_errors() -> void:
	var d = _new_diorama()
	assert_eq(d.validate(["00", "000", "00"], ["..", "...", ".."]).size(), 0, "radio 1 válido")
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


func test_build_places_one_tile_per_cell_and_stacks_height() -> void:
	var d = _new_diorama()
	assert_true(d.build(["00", "000", "00"], ["..", "...", ".."]), "radio 1 se construye")
	assert_eq(d.get_child_count(), 7, "7 casillas")
	d.free()

	var h = _new_diorama()
	assert_true(h.build(["00", "020", "00"], ["..", "...", ".."]), "con una casilla elevada")
	assert_eq(h.get_child_count(), 6 + 3, "la casilla de altura 2 apila 3 piezas")
	var top := -1.0
	for child in h.get_children():
		top = maxf(top, child.position.y)
	assert_eq(top, 2.0, "la pieza más alta está a y = 2")
	h.free()

	var w = _new_diorama()
	assert_true(w.build(["ww", "www", "ww"], ["..", "...", ".."]), "solo agua")
	assert_eq(w.get_child_count(), 7, "7 casillas de agua")
	w.free()
	done()


func test_things_sit_on_top_of_the_tile_height() -> void:
	var d = _new_diorama()
	assert_true(d.build(["00", "010", "00"], ["..", ".C.", ".."]), "castillo sobre una casilla elevada")
	var castle_y := -1.0
	var castle_nodes := 0
	for child in d.get_children():
		if child.position.y > 0.5 and child.position.x == 0.0:
			castle_y = child.position.y
			castle_nodes += 1
	# La pieza de suelo elevada está a y = 1 y el castillo también (se apoya encima).
	assert_eq(castle_y, 1.0, "el castillo se apoya a la altura de la casilla")
	assert_eq(castle_nodes, 2, "casilla elevada + castillo")
	d.free()
	done()


func test_every_allowed_symbol_builds_something() -> void:
	var probe = _new_diorama()
	var symbols: String = probe.THING_SYMBOLS
	probe.free()
	assert_true(symbols.contains("t") and symbols.contains("T"), "bosque grande y mediano están permitidos")
	var checked := 0
	for symbol in symbols:
		if symbol == ".":
			continue
		var d = _new_diorama()
		assert_true(d.build(["0"], [symbol]), "símbolo «%s» se construye" % symbol)
		# Un símbolo permitido pero sin modelo dejaría solo el suelo: eso es un fallo.
		assert_true(d.get_child_count() >= 2, "símbolo «%s» añade al menos un modelo a la casilla" % symbol)
		d.free()
		checked += 1
	assert_true(checked >= 20, "se probaron todos los símbolos (%d)" % checked)
	var empty = _new_diorama()
	assert_true(empty.build(["0"], ["."]), "casilla vacía")
	assert_eq(empty.get_child_count(), 1, "solo el suelo")
	empty.free()
	done()
