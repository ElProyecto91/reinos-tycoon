extends Control
## Mapa grande estilo antiguo: tierra y mar sobre pergamino, cada reino de un color, ríos, rótulos de reinos
## y mares, escala, rosa de los vientos y marco. Se arrastra con un dedo, se acerca con dos (o con los
## botones + y −) y se toca una provincia para elegirla. Solo lee el mundo: no cambia nada.
##
## Las formas de los territorios son una aproximación de juego (ver docs/REGION_IBERIA_1000.md), no fronteras
## históricas. El estado no depende solo del color: los avisos añaden un signo "!" y las graves, "!!".
## Rendimiento en el móvil: SIN MEDIR. Las superficies se triangulan una sola vez al cargar el mapa.

signal province_selected(province_id: String)

const Texts := preload("res://scripts/ui/texts.gd")
const FONT_PATH := "res://assets/fonts/Lora-Variable.ttf"

const COLOR_SEA := Color("#a9bcb8")
const COLOR_SEA_LIGHT := Color("#d3e0da")
const COLOR_LAND := Color("#e0d0a4")
const COLOR_FOREIGN := Color("#cbbb91")
const COLOR_INK := Color("#3d2a1a")
const COLOR_COAST := Color("#4a3624")
const COLOR_RIVER := Color("#6f8f98")
const COLOR_SELECTED := Color("#fff3c4")
const COLOR_GOLD := Color("#c8902c")
const COLOR_WARNING := Color("#b0781c")
const COLOR_DANGER := Color("#b3321f")
const WarScript := preload("res://scripts/sim/war.gd")
const COLOR_PARCHMENT_MIX := 0.34   # cuánto pergamino se mezcla con el color del reino

const MAX_ZOOM := 7.0
## Zoom con el que se abre el mapa: la península es apaisada y el móvil vertical; con el mapa entero las
## provincias pequeñas quedarían diminutas para el dedo. «−» y el botón de inicio lo recuperan.
const INITIAL_ZOOM := 1.25
const ZOOM_STEP := 1.6
## Movimiento (en píxeles de pantalla) a partir del cual un toque deja de ser un toque y pasa a ser arrastre.
const TAP_SLOP := 14.0
## Con este zoom o más se rotulan todas las provincias.
const ZOOM_NAMES := 1.7
const ZOOM_POPULATION := 3.0

var map = null
var world = null
## Versión de los propietarios con la que se pintaron las provincias (ver World.owners_version).
var _painted_owners: int = -1
var selected_id: String = ""
## Zoom respecto al encaje de todo el mapa (1 = mapa entero) y desplazamiento en píxeles.
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO

var _font: Font
var _font_bold: Font
var _font_italic: Font
var _mesh_land: ArrayMesh
var _mesh_foreign: ArrayMesh
var _mesh_provinces: ArrayMesh
var _touches := {}
var _pinch_distance := 0.0
var _pinched := false
var _pressed := false
var _moved := false
var _press_pos := Vector2.ZERO
var _buttons: Array[Button] = []


func _ready() -> void:
	clip_contents = true
	_make_fonts()
	_make_buttons()
	resized.connect(_on_resized)


func _make_fonts() -> void:
	var base := load(FONT_PATH) as Font
	if base == null:
		_font = ThemeDB.fallback_font
		_font_bold = _font
		_font_italic = _font
		return
	_font = _variation(base, 500, 0.0)
	_font_bold = _variation(base, 700, 0.0)
	_font_italic = _variation(base, 500, 0.2)


func _variation(base: Font, weight: int, slant: float) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {"wght": weight}
	v.variation_transform = Transform2D(Vector2(1, 0), Vector2(slant, 1), Vector2.ZERO)
	return v


func _make_buttons() -> void:
	for spec in [["+", 1], ["−", -1], ["⌂", 0]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(88, 88)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 40)
		b.pressed.connect(_on_zoom_button.bind(int(spec[1])))
		add_child(b)
		_buttons.append(b)
	_place_buttons()


func _place_buttons() -> void:
	for i in _buttons.size():
		_buttons[i].position = Vector2(size.x - 88.0 - 16.0, 16.0 + float(i) * 100.0)


func _on_resized() -> void:
	_place_buttons()
	_clamp_pan()
	queue_redraw()


func _on_zoom_button(direction: int) -> void:
	if direction == 0:
		zoom = INITIAL_ZOOM
		pan = Vector2.ZERO
	else:
		_zoom_at(size / 2.0, ZOOM_STEP if direction > 0 else 1.0 / ZOOM_STEP)
	queue_redraw()


func setup(game_map, game_world) -> void:
	map = game_map
	world = game_world
	selected_id = ""
	zoom = INITIAL_ZOOM
	pan = Vector2.ZERO
	_build_meshes()
	queue_redraw()


func select(province_id: String) -> void:
	selected_id = province_id
	queue_redraw()
	province_selected.emit(province_id)


# --- Transformación entre mapa y pantalla -----------------------------------------------------------

func fit_scale() -> float:
	if map == null or size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	return minf(size.x / float(map.width), size.y / float(map.height))


## Escala total (píxeles de pantalla por unidad de mapa).
func view_scale() -> float:
	return fit_scale() * zoom


func _base_offset() -> Vector2:
	if map == null:
		return Vector2.ZERO
	return (size - Vector2(map.width, map.height) * view_scale()) / 2.0


func view_offset() -> Vector2:
	return _base_offset() + pan


func map_to_view(x: float, y: float) -> Vector2:
	return view_offset() + Vector2(x, y) * view_scale()


func view_to_map_f(point: Vector2) -> Vector2:
	return (point - view_offset()) / view_scale()


func view_to_map(point: Vector2) -> Vector2i:
	var local := view_to_map_f(point)
	return Vector2i(int(floor(local.x)), int(floor(local.y)))


## Provincia bajo un punto del control (coordenadas locales), o "".
func province_at_view(point: Vector2) -> String:
	if map == null:
		return ""
	var p := view_to_map_f(point)
	return map.province_at(p.x, p.y)


## Mantiene el mapa a la vista: si es más pequeño que el control en una dirección, centrado; si no, sin huecos.
func _clamp_pan() -> void:
	if map == null:
		return
	var s := view_scale()
	var msize := Vector2(map.width, map.height) * s
	var base := (size - msize) / 2.0
	for axis in 2:
		if msize[axis] <= size[axis]:
			pan[axis] = 0.0
		else:
			pan[axis] = clampf(pan[axis], (size[axis] - msize[axis]) - base[axis], -base[axis])


func _zoom_at(point: Vector2, factor: float) -> void:
	if map == null:
		return
	var anchor := view_to_map_f(point)
	zoom = clampf(zoom * factor, 1.0, MAX_ZOOM)
	pan = point - anchor * view_scale() - _base_offset()
	_clamp_pan()


# --- Entrada ----------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 2:
				_pinched = true
				_pinch_distance = _touch_distance()
		else:
			_touches.erase(event.index)
			_pinch_distance = 0.0
		accept_event()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var d := _touch_distance()
			if _pinch_distance > 1.0 and d > 1.0:
				_zoom_at(_touch_center(), d / _pinch_distance)
				queue_redraw()
			_pinch_distance = d
			_moved = true
		accept_event()
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion and _pressed and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if _pinched or _touches.size() >= 2:
			return
		if not _moved and (event.position - _press_pos).length() > TAP_SLOP:
			_moved = true
		elif _moved:
			pan += event.relative
			_clamp_pan()
			queue_redraw()
		accept_event()


func _on_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 1.25)
		queue_redraw()
		accept_event()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 1.0 / 1.25)
		queue_redraw()
		accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_moved = false
			_press_pos = event.position
			if _touches.size() < 2:
				_pinched = false
		else:
			var was_tap := _pressed and not _moved and not _pinched
			_pressed = false
			if was_tap:
				tap_at(event.position)
		accept_event()


## Un toque (sin arrastre) en el punto: elige la provincia que haya debajo, si hay alguna.
func tap_at(point: Vector2) -> void:
	var hit := province_at_view(point)
	if hit != "":
		select(hit)


func _touch_distance() -> float:
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _touch_center() -> Vector2:
	var pts: Array = _touches.values()
	return ((pts[0] as Vector2) + (pts[1] as Vector2)) / 2.0


# --- Mallas (se calculan una vez) -------------------------------------------------------------------

## Triangula un anillo; devuelve los índices (vacío si el anillo no se puede triangular).
func triangulate(ring: PackedVector2Array) -> PackedInt32Array:
	return Geometry2D.triangulate_polygon(ring)


func _add_ring(verts: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, ring: PackedVector2Array, color: Color) -> bool:
	var tri := triangulate(ring)
	if tri.is_empty():
		return false
	var base := verts.size()
	verts.append_array(ring)
	for i in ring.size():
		colors.append(color)
	for i in tri:
		indices.append(base + i)
	return true


func _mesh_from(rings: Array, colors_per_ring: Array) -> ArrayMesh:
	var verts := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i in rings.size():
		_add_ring(verts, colors, indices, rings[i], colors_per_ring[i])
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_meshes() -> void:
	if map == null:
		return
	var rings: Array = []
	var colors: Array = []
	for ring in map.land:
		rings.append(ring)
		colors.append(COLOR_LAND)
	_mesh_land = _mesh_from(rings, colors)
	rings = []
	colors = []
	for ring in map.foreign_land:
		rings.append(ring)
		colors.append(COLOR_FOREIGN)
	_mesh_foreign = _mesh_from(rings, colors)
	rings = []
	colors = []
	var index := 0
	for p in map.provinces:
		# El color sigue al propietario actual (una provincia conquistada toma el color de su nuevo reino).
		var owner_id: String = world.owners.get(p["id"], p["realm"]) if world != null else p["realm"]
		var base: Color = map.realms[owner_id]["color"] if map.realms.has(owner_id) else map.realms[p["realm"]]["color"]
		var tone := base.lerp(COLOR_LAND, COLOR_PARCHMENT_MIX)
		# Un poco de variación entre provincias vecinas del mismo reino para distinguir sus límites.
		var shade := 0.94 + 0.12 * float((index * 7) % 5) / 4.0
		tone = Color(tone.r * shade, tone.g * shade, tone.b * shade, 1.0)
		for ring in p["rings"]:
			rings.append(ring)
			colors.append(tone)
		index += 1
	_mesh_provinces = _mesh_from(rings, colors)


# --- Dibujo -----------------------------------------------------------------------------------------

func _draw() -> void:
	if map == null or world == null:
		return
	if _painted_owners != world.owners_version:
		_painted_owners = world.owners_version
		_build_meshes()
	var s := view_scale()
	var o := view_offset()
	var inv := 1.0 / s
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_SEA)
	# Geometría en unidades de mapa; el grosor de las líneas se da en píxeles de pantalla dividiendo por la escala.
	draw_set_transform(o, 0.0, Vector2(s, s))
	for ring in map.land:
		draw_polyline(_closed(ring), Color(COLOR_SEA_LIGHT, 0.20), 16.0 * inv)
		draw_polyline(_closed(ring), Color(COLOR_SEA_LIGHT, 0.28), 8.0 * inv)
	draw_mesh(_mesh_foreign, null)
	draw_mesh(_mesh_land, null)
	draw_mesh(_mesh_provinces, null)
	for r in map.rivers:
		draw_polyline(r["points"], Color(COLOR_RIVER, 0.9), 1.6 * inv)
	for p in map.provinces:
		for ring in p["rings"]:
			draw_polyline(_closed(ring), Color(COLOR_INK, 0.35), 1.0 * inv)
	for id in map.realms.keys():
		for ring in map.realms[id]["outline"]:
			draw_polyline(_closed(ring), Color(COLOR_INK, 0.85), 2.6 * inv)
	for ring in map.foreign_land:
		draw_polyline(_closed(ring), Color(COLOR_COAST, 0.75), 1.3 * inv)
	for ring in map.land:
		draw_polyline(_closed(ring), Color(COLOR_COAST, 0.9), 1.6 * inv)
	_draw_war(inv)
	if selected_id != "" and not map.find(selected_id).is_empty():
		var sel: Dictionary = map.find(selected_id)
		for ring in sel["rings"]:
			draw_colored_polygon(ring, Color(COLOR_SELECTED, 0.38))
			draw_polyline(_closed(ring), Color(COLOR_GOLD, 1.0), 4.0 * inv)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_labels(s)
	_draw_cities(s)
	_draw_vignette()
	_draw_frame()
	_draw_scale_bar(s)
	_draw_compass()


## Guerra: contorno rojo en las provincias que se pueden atacar y un punto que avanza por cada ejército en marcha.
func _draw_war(inv: float) -> void:
	if not WarScript.enabled(world):
		return
	for id in WarScript.attackable(world):
		var entry: Dictionary = map.find(id)
		for ring in entry["rings"]:
			draw_polyline(_closed(ring), Color(COLOR_DANGER, 0.95), 3.4 * inv)
	var march: int = maxi(1, int(world.data.rules["war_march_steps_per_hop"]))
	for army in world.armies:
		var a: Dictionary = map.find(army["from"])
		var b: Dictionary = map.find(army["to"])
		if a.is_empty() or b.is_empty():
			continue
		var from := Vector2(a["x"], a["y"])
		var to := Vector2(b["x"], b["y"])
		var progress := clampf(1.0 - float(int(army["arrive"]) - world.step_count) / float(march), 0.0, 1.0)
		draw_line(from, to, Color(COLOR_DANGER, 0.8), 2.4 * inv)
		draw_circle(from.lerp(to, progress), 7.0 * inv, COLOR_DANGER)
		draw_circle(from.lerp(to, progress), 3.5 * inv, Color.WHITE)


func _closed(ring: PackedVector2Array) -> PackedVector2Array:
	var out := ring.duplicate()
	if ring.size() > 0:
		out.append(ring[0])
	return out


## Texto con separación entre letras, centrado en `center`. Devuelve el ancho dibujado.
func _spaced(font: Font, text: String, center: Vector2, size_px: int, color: Color, tracking: float) -> float:
	var width := 0.0
	var widths: Array[float] = []
	for ch in text:
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		widths.append(w)
		width += w + tracking
	width -= tracking
	var x := center.x - width / 2.0
	var i := 0
	for ch in text:
		draw_string(font, Vector2(x, center.y + size_px * 0.35), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
		x += widths[i] + tracking
		i += 1
	return width


func _draw_labels(s: float) -> void:
	for l in map.labels:
		var size_px := int(clampf(22.0 * sqrt(zoom), 16.0, 44.0))
		var col := Color(0.20, 0.32, 0.38, 0.55) if l["kind"] == "mar" else Color(0.30, 0.22, 0.14, 0.5)
		var pos := map_to_view(l["x"], l["y"])
		if Rect2(Vector2.ZERO, size).grow(120.0).has_point(pos):
			_spaced(_font_italic, l["text"], pos, size_px, col, size_px * 0.28)
	for id in map.realms.keys():
		var r: Dictionary = map.realms[id]
		var room: float = r["label_room"] * s
		var text: String = r["label"]
		var lines: Array = _wrap(text)
		var longest := 0
		for line in lines:
			longest = maxi(longest, (line as String).length())
		var size_px := minf(room * 0.55, room * 2.0 * 0.92 / (float(longest) * 0.95))
		size_px = minf(size_px, 54.0)
		if size_px < 11.0:
			continue
		var center := map_to_view(r["label_x"], r["label_y"])
		var line_h := size_px * 1.25
		var y0 := center.y - line_h * float(lines.size() - 1) / 2.0
		for i in lines.size():
			_spaced(_font_bold, lines[i], Vector2(center.x, y0 + line_h * float(i)), int(size_px), Color(COLOR_INK, 0.62), size_px * 0.22)


## Reparte un rótulo largo en dos líneas por el espacio más cercano a la mitad.
func _wrap(text: String) -> Array:
	if text.length() <= 12 or not text.contains(" "):
		return [text]
	var best := -1
	var half := text.length() / 2
	for i in text.length():
		if text[i] == " " and (best < 0 or absi(i - half) < absi(best - half)):
			best = i
	return [text.substr(0, best), text.substr(best + 1)]


func _draw_cities(s: float) -> void:
	var names := zoom >= ZOOM_NAMES
	var radius := clampf(4.0 + zoom * 0.9, 4.5, 9.0)
	for p in map.provinces:
		var center := map_to_view(p["x"], p["y"])
		if not Rect2(Vector2.ZERO, size).grow(60.0).has_point(center):
			continue
		var selected: bool = p["id"] == selected_id
		var province = world.find_province(p["id"])
		var severity := 0
		if province != null:
			severity = Texts.alert_severity(province.alerts)
		draw_circle(center, radius + 2.0, Color(0.96, 0.92, 0.80, 0.95))
		draw_circle(center, radius, COLOR_GOLD if selected else COLOR_INK)
		if severity > 0:
			var mark := "!!" if severity == 2 else "!"
			draw_string(_font_bold, center + Vector2(radius + 3.0, -radius), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, COLOR_DANGER if severity == 2 else COLOR_WARNING)
		if names or selected:
			var size_px := 20 if not selected else 24
			var label_pos := center + Vector2(radius + 5.0, size_px * 0.35)
			if severity > 0:
				label_pos.x += 22.0
			_outlined(_font_bold if selected else _font, p["short"], label_pos, size_px)
			if zoom >= ZOOM_POPULATION and province != null:
				_outlined(_font, "%d hab." % province.population, label_pos + Vector2(0, size_px * 1.05), 16)


## Texto oscuro con un halo claro para que se lea sobre cualquier color.
func _outlined(font: Font, text: String, pos: Vector2, size_px: int) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 5, Color(0.97, 0.94, 0.84, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, COLOR_INK)


func _draw_vignette() -> void:
	var steps := 7
	for i in steps:
		var a := 0.20 * (1.0 - float(i) / float(steps))
		var t := 6.0 * float(i)
		var c := Color(0.25, 0.16, 0.08, a)
		draw_rect(Rect2(t, t, size.x - 2.0 * t, size.y - 2.0 * t), c, false, 6.0)


func _draw_frame() -> void:
	draw_rect(Rect2(5, 5, size.x - 10, size.y - 10), COLOR_INK, false, 3.0)
	draw_rect(Rect2(13, 13, size.x - 26, size.y - 26), Color(COLOR_INK, 0.7), false, 1.2)
	for corner in [Vector2(5, 5), Vector2(size.x - 5, 5), Vector2(5, size.y - 5), Vector2(size.x - 5, size.y - 5)]:
		draw_circle(corner, 6.0, COLOR_INK)
		draw_circle(corner, 3.0, COLOR_GOLD)


func _draw_scale_bar(s: float) -> void:
	var km_per_px: float = float(map.projection["km_per_unit"]) / s
	var chosen := 100.0
	for km in [10.0, 20.0, 50.0, 100.0, 200.0, 500.0]:
		if km / km_per_px >= 90.0:
			chosen = km
			break
	var length := chosen / km_per_px
	var origin := Vector2(34.0, size.y - 38.0)
	draw_line(origin, origin + Vector2(length, 0), COLOR_INK, 3.0)
	for t in [0.0, 0.5, 1.0]:
		draw_line(origin + Vector2(length * t, -7.0), origin + Vector2(length * t, 7.0), COLOR_INK, 2.5)
	_outlined(_font, "%d km" % int(chosen), origin + Vector2(length / 2.0 - 24.0, -14.0), 20)


func _draw_compass() -> void:
	var c := Vector2(size.x - 80.0, size.y - 86.0)
	var r := 44.0
	draw_arc(c, r * 0.62, 0.0, TAU, 40, Color(COLOR_INK, 0.6), 1.5, true)
	for k in 4:
		var a := -PI / 2.0 + float(k) * PI / 2.0
		var tip := c + Vector2(cos(a), sin(a)) * r * (1.0 if k == 0 else 0.8)
		var left := c + Vector2(cos(a - 0.42), sin(a - 0.42)) * r * 0.2
		var right := c + Vector2(cos(a + 0.42), sin(a + 0.42)) * r * 0.2
		draw_colored_polygon(PackedVector2Array([tip, left, c]), COLOR_INK)
		draw_colored_polygon(PackedVector2Array([tip, c, right]), Color(0.93, 0.86, 0.66))
		draw_polyline(PackedVector2Array([c, left, tip, right, c]), COLOR_INK, 1.2)
	_spaced(_font_bold, "N", c + Vector2(0, -r - 12.0), 20, COLOR_INK, 0.0)
