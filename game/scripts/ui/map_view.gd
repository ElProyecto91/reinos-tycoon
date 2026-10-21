extends Control
## Dibuja el mapa de provincias y detecta el toque. Solo lectura del mundo: no cambia nada.
## El círculo visible es algo menor que la zona de toque (VISIBLE_PERCENT), para que se
## toque con holgura y los nombres no se pisen. El estado no depende solo del color: los
## avisos añaden un signo "!" y las graves, "!!".

signal province_selected(province_id: String)

const Texts := preload("res://scripts/ui/texts.gd")

const COLOR_BACKGROUND := Color("#3a3326")
const COLOR_LINK := Color("#7d6e52")
const COLOR_NODE := Color("#8a6a3a")
const COLOR_NODE_SELECTED := Color("#c99a4a")
const COLOR_TEXT := Color("#f2e8d5")
const COLOR_WARNING := Color("#e8c36a")
const COLOR_DANGER := Color("#e5654f")
const COLOR_RING := Color("#ffffff")
## Radio visible respecto al radio de toque
const VISIBLE_PERCENT := 75

var map = null
var world = null
var selected_id: String = ""


func setup(game_map, game_world) -> void:
	map = game_map
	world = game_world
	selected_id = ""
	queue_redraw()


func select(province_id: String) -> void:
	selected_id = province_id
	queue_redraw()
	province_selected.emit(province_id)


## Escala y desplazamiento que encajan todo el mapa en el control, centrado.
func view_scale() -> float:
	if map == null or size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	return minf(size.x / float(map.width), size.y / float(map.height))


func view_offset() -> Vector2:
	if map == null:
		return Vector2.ZERO
	return (size - Vector2(map.width, map.height) * view_scale()) / 2.0


func map_to_view(x: int, y: int) -> Vector2:
	return view_offset() + Vector2(x, y) * view_scale()


func view_to_map(point: Vector2) -> Vector2i:
	var local := (point - view_offset()) / view_scale()
	return Vector2i(int(floor(local.x)), int(floor(local.y)))


## Provincia bajo un punto del control (coordenadas locales), o "".
func province_at_view(point: Vector2) -> String:
	if map == null:
		return ""
	var p := view_to_map(point)
	return map.province_at(p.x, p.y)


func _gui_input(event: InputEvent) -> void:
	# En Android el toque llega también como clic emulado; se atiende solo el clic para
	# no seleccionar dos veces.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hit := province_at_view(event.position)
		if hit != "":
			select(hit)
			accept_event()


func _draw() -> void:
	if map == null or world == null:
		return
	var scale_factor := view_scale()
	var offset := view_offset()
	draw_rect(Rect2(offset, Vector2(map.width, map.height) * scale_factor), COLOR_BACKGROUND)
	for p in map.provinces:
		for n in p["neighbors"]:
			if p["id"] < n:
				var other: Dictionary = map.find(n)
				draw_line(map_to_view(p["x"], p["y"]), map_to_view(other["x"], other["y"]), COLOR_LINK, maxf(4.0, 12.0 * scale_factor), true)
	var font := ThemeDB.fallback_font
	var radius: float = map.touch_radius * scale_factor * float(VISIBLE_PERCENT) / 100.0
	for p in map.provinces:
		var center := map_to_view(p["x"], p["y"])
		var province = world.find_province(p["id"])
		var selected: bool = p["id"] == selected_id
		draw_circle(center, radius, COLOR_NODE_SELECTED if selected else COLOR_NODE)
		var severity := 0
		if province != null:
			severity = Texts.alert_severity(province.alerts)
		var ring := COLOR_RING if selected else (COLOR_DANGER if severity == 2 else (COLOR_WARNING if severity == 1 else Color(0, 0, 0, 0)))
		if ring.a > 0.0:
			draw_arc(center, radius, 0.0, TAU, 48, ring, 8.0 if selected else 6.0, true)
		if province != null:
			var pop_text := str(province.population)
			draw_string(font, center + Vector2(-radius, 10.0), pop_text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 34, COLOR_TEXT)
			if severity > 0:
				var mark := "!!" if severity == 2 else "!"
				draw_string(font, center + Vector2(radius * 0.25, -radius * 0.45), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, COLOR_DANGER if severity == 2 else COLOR_WARNING)
		var name_width: float = font.get_string_size(p["short"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, center + Vector2(-name_width / 2.0, radius + 30.0), p["short"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, COLOR_TEXT)
