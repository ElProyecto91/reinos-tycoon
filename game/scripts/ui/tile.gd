extends Button
## Ficha táctil con símbolos: un icono, un número, un punto de estado, una barra y una fila de costes.
## Sirve de «chip» (icono a la izquierda y número a la derecha) o de «carta» (icono arriba, nombre y costes
## debajo). Es un botón de verdad (el dedo la pulsa como cualquier botón); solo cambia lo que dibuja.
## No guarda estado del juego: quien la usa le pone los valores y llama a `refresh()`.

const Icons := preload("res://scripts/ui/icons.gd")

const COLOR_TEXT := Color("#f1e6cf")
const COLOR_MUTED := Color("#b9a98e")
const COLOR_BAD := Color("#ee6b57")
const COLOR_OK := Color("#6cc08b")
const COLOR_WARN := Color("#e8b94e")
const COLOR_BAR_BG := Color(0, 0, 0, 0.35)

## Nombre del icono principal (ver icons.gd).
var kind: String = ""
## Número o texto corto junto al icono (en «chip») o bajo él (en «carta», como nombre).
var caption: String = ""
## Texto pequeño en la esquina superior derecha, por ejemplo «×3».
var badge: String = ""
## Punto de estado en la esquina superior izquierda; transparente = sin punto.
var dot: Color = Color(0, 0, 0, 0)
## Barra inferior de 0 a 1; negativo = sin barra.
var ratio: float = -1.0
var bar_color: Color = COLOR_OK
## Fila de costes o datos bajo el nombre: [{"icon": "coin", "text": "4,5", "bad": false}].
var footer: Array = []
## "chip", "card" o "mini" (carta pequeña: icono a la izquierda; nombre y costes a la derecha).
var layout: String = "card"
## Color del texto principal (se pone rojo cuando algo va mal).
var text_color: Color = COLOR_TEXT


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	text = ""


## Vuelve a dibujar con los valores actuales (y atenúa la ficha si está desactivada).
func refresh() -> void:
	modulate.a = 0.5 if disabled else 1.0
	queue_redraw()


func _fit_size(font: Font, s: String, wanted: int, max_width: float) -> int:
	var size_px := wanted
	while size_px > 14 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > max_width:
		size_px -= 2
	return size_px


func _draw() -> void:
	var font := get_theme_default_font()
	var w := size.x
	var h := size.y
	if layout == "chip":
		_draw_chip(font, w, h)
	elif layout == "mini":
		_draw_mini(font, w, h)
	else:
		_draw_card(font, w, h)
	if dot.a > 0.0:
		var spot := Vector2(12.0, 12.0) if layout == "card" else Vector2(w - 12.0, 12.0)
		draw_circle(spot, 8.0, Color(0, 0, 0, 0.55))
		draw_circle(spot, 6.0, dot)
	if ratio >= 0.0:
		var bar_h := 8.0 if layout == "card" else 6.0
		var inset := 8.0
		var track := Rect2(inset, h - bar_h - 5.0, w - 2.0 * inset, bar_h)
		draw_rect(track, COLOR_BAR_BG)
		var filled := Rect2(track.position, Vector2(track.size.x * clampf(ratio, 0.0, 1.0), track.size.y))
		draw_rect(filled, bar_color)


func _draw_chip(font: Font, w: float, h: float) -> void:
	var icon_size := h * 0.62
	var pad := 10.0
	var icon_rect := Rect2(pad, (h - icon_size) * 0.5 - (3.0 if ratio >= 0.0 else 0.0), icon_size, icon_size)
	if kind != "":
		Icons.draw(self, kind, icon_rect)
	var text_x := pad + icon_size + 8.0
	var room := w - text_x - pad
	var fs := _fit_size(font, caption, 30, room)
	var ty := (h - (3.0 if ratio >= 0.0 else 0.0)) * 0.5 + fs * 0.35
	draw_string(font, Vector2(text_x, ty), caption, HORIZONTAL_ALIGNMENT_LEFT, room, fs, text_color)


func _draw_mini(font: Font, w: float, h: float) -> void:
	var icon_size := h - 16.0
	if kind != "":
		Icons.draw(self, kind, Rect2(8.0, 8.0, icon_size, icon_size))
	var x := 8.0 + icon_size + 6.0
	var room := w - x - 6.0
	if caption != "":
		var fs := _fit_size(font, caption, 20, room)
		draw_string(font, Vector2(x, 10.0 + fs * 0.85), caption, HORIZONTAL_ALIGNMENT_LEFT, room, fs, text_color)
	if not footer.is_empty():
		_draw_footer(font, room, h - 36.0, x)


func _draw_card(font: Font, w: float, h: float) -> void:
	var has_footer := not footer.is_empty()
	var has_caption := caption != ""
	var below := (22.0 if has_caption else 0.0) + (30.0 if has_footer else 0.0) + (14.0 if ratio >= 0.0 else 0.0)
	var icon_size := minf(w * 0.56, maxf(30.0, h - below - 18.0))
	var icon_rect := Rect2((w - icon_size) * 0.5, 8.0, icon_size, icon_size)
	if kind != "":
		Icons.draw(self, kind, icon_rect)
	var y := icon_rect.end.y + 4.0
	if badge != "":
		var bs := _fit_size(font, badge, 24, w * 0.4)
		var bw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
		draw_rect(Rect2(w - bw - 18.0, 4.0, bw + 12.0, bs + 6.0), Color(0, 0, 0, 0.5))
		draw_string(font, Vector2(w - bw - 12.0, 4.0 + bs), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, COLOR_TEXT)
	if has_caption:
		var fs := _fit_size(font, caption, 21, w - 12.0)
		var cw := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, Vector2((w - cw) * 0.5, y + fs * 0.85), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		y += fs + 6.0
	if has_footer:
		_draw_footer(font, w, y)


## `x0`: desplazamiento a la izquierda de la zona donde se centra la fila de costes.
func _draw_footer(font: Font, w: float, y: float, x0: float = 0.0) -> void:
	var fs := 20
	var icon := 22.0
	var gap := 8.0
	var widths: Array[float] = []
	var total := 0.0
	for entry in footer:
		var t: String = entry.get("text", "")
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ew := (icon + 3.0 if entry.get("icon", "") != "" else 0.0) + tw
		widths.append(ew)
		total += ew
	total += gap * maxf(0.0, float(footer.size() - 1))
	var scale := 1.0
	if total > w - 10.0:
		scale = (w - 10.0) / total
	var x := x0 + (w - total * scale) * 0.5
	for i in footer.size():
		var entry: Dictionary = footer[i]
		var name: String = entry.get("icon", "")
		var color: Color = COLOR_BAD if entry.get("bad", false) else COLOR_MUTED
		var size_i := icon * scale
		if name != "":
			Icons.draw(self, name, Rect2(x, y + 2.0, size_i, size_i))
			x += (icon + 3.0) * scale
		var t: String = entry.get("text", "")
		draw_string(font, Vector2(x, y + 2.0 + 17.0 * scale), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(14.0, fs * scale)), color)
		x += (widths[i] - (icon + 3.0 if name != "" else 0.0)) * scale + gap * scale
