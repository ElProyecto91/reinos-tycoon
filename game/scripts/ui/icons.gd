extends RefCounted
## Iconos de la interfaz dibujados por código (polígonos y círculos): sin imágenes ni fuentes externas,
## así que no hay licencias que registrar y se ven igual en cualquier móvil. Cada icono se dibuja en el
## cuadrado de `rect`; los ids de mercancías y edificios del juego son también el nombre del icono.
## Los dibujos son simples a propósito: tienen que leerse a 40–60 píxeles.

const GOODS: Array[String] = ["wheat", "flour", "bread", "wood", "firewood", "olives", "oil", "wool", "cloth", "iron", "weapons", "coin"]
const BUILDINGS: Array[String] = ["house", "granary", "farm", "mill", "bakery", "woodcutter", "olive_grove", "olive_press", "sheepfold", "loom", "market", "mine", "smithy", "barracks"]
const SYMBOLS: Array[String] = ["people", "hammer", "town", "face", "bolt", "clock", "warning", "danger", "storage", "helmet", "arrow", "calendar"]

const GOLD := Color("#e6b84a")
const GOLD_D := Color("#b8892a")
const WHEAT := Color("#e9c85e")
const BROWN := Color("#7d5330")
const BROWN_L := Color("#b98655")
const RED := Color("#c4523f")
const RED_D := Color("#8f3326")
const STONE := Color("#a8a8a0")
const STONE_D := Color("#6f6f69")
const STONE_L := Color("#cfcfc6")
const WHITE := Color("#f1e9d6")
const GREEN := Color("#6fb05c")
const GREEN_D := Color("#46823f")
const BLUE := Color("#5f8cbe")
const BLUE_D := Color("#3f6592")
const DARK := Color("#3a2c20")
const AMBER := Color("#e58f2d")
const SKIN := Color("#e4bb92")
const OLIVE := Color("#7f8c3c")


static func is_kind(kind: String) -> bool:
	return kind in GOODS or kind in BUILDINGS or kind in SYMBOLS


# --- Ayudas de dibujo en coordenadas 0..1 ------------------------------------------------------------

static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x * r.size.x, y * r.size.y)


static func _poly(c: CanvasItem, r: Rect2, pts: Array, col: Color) -> void:
	var v := PackedVector2Array()
	for q in pts:
		v.append(_p(r, q[0], q[1]))
	c.draw_colored_polygon(v, col)


static func _line(c: CanvasItem, r: Rect2, a: Array, b: Array, col: Color, w: float) -> void:
	c.draw_line(_p(r, a[0], a[1]), _p(r, b[0], b[1]), col, maxf(1.0, w * r.size.x), true)


static func _circle(c: CanvasItem, r: Rect2, x: float, y: float, rad: float, col: Color) -> void:
	c.draw_circle(_p(r, x, y), rad * r.size.x, col)


static func _rect(c: CanvasItem, r: Rect2, x: float, y: float, w: float, h: float, col: Color) -> void:
	c.draw_rect(Rect2(_p(r, x, y), Vector2(w * r.size.x, h * r.size.y)), col)


static func _ellipse(c: CanvasItem, r: Rect2, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var pts: Array = []
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append([cx + cos(a) * rx, cy + sin(a) * ry])
	_poly(c, r, pts, col)


static func _quad(c: CanvasItem, r: Rect2, cx: float, cy: float, w: float, h: float, deg: float, col: Color) -> void:
	var a := deg_to_rad(deg)
	var ux := Vector2(cos(a), sin(a)) * w * 0.5
	var uy := Vector2(-sin(a), cos(a)) * h * 0.5
	var ctr := Vector2(cx, cy)
	var pts: Array = []
	for corner in [ctr - ux - uy, ctr + ux - uy, ctr + ux + uy, ctr - ux + uy]:
		pts.append([corner.x, corner.y])
	_poly(c, r, pts, col)


## Dibuja el icono `kind` dentro de `rect`. Un nombre desconocido dibuja una interrogación simple (nunca falla).
static func draw(c: CanvasItem, kind: String, rect: Rect2) -> void:
	var r := rect
	match kind:
		"wheat":
			_line(c, r, [0.5, 0.95], [0.5, 0.25], BROWN_L, 0.06)
			for i in 3:
				var y := 0.3 + 0.2 * i
				_poly(c, r, [[0.5, y + 0.12], [0.22, y - 0.02], [0.5, y + 0.02]], WHEAT)
				_poly(c, r, [[0.5, y + 0.12], [0.78, y - 0.02], [0.5, y + 0.02]], GOLD)
			_poly(c, r, [[0.5, 0.02], [0.4, 0.22], [0.6, 0.22]], WHEAT)
		"flour":
			_poly(c, r, [[0.2, 0.34], [0.8, 0.34], [0.9, 0.92], [0.1, 0.92]], WHITE)
			_poly(c, r, [[0.2, 0.34], [0.5, 0.2], [0.8, 0.34]], STONE_L)
			_rect(c, r, 0.38, 0.14, 0.24, 0.12, WHITE)
			_line(c, r, [0.2, 0.36], [0.8, 0.36], BROWN_L, 0.05)
			_circle(c, r, 0.5, 0.65, 0.12, STONE_L)
		"bread":
			_ellipse(c, r, 0.5, 0.58, 0.42, 0.28, BROWN_L)
			_ellipse(c, r, 0.5, 0.52, 0.38, 0.22, Color("#cf9a60"))
			for x in [0.32, 0.5, 0.68]:
				_line(c, r, [x - 0.05, 0.62], [x + 0.05, 0.42], BROWN, 0.045)
		"wood":
			_circle(c, r, 0.3, 0.7, 0.2, BROWN)
			_circle(c, r, 0.7, 0.7, 0.2, BROWN)
			_circle(c, r, 0.5, 0.36, 0.2, BROWN)
			for p in [[0.3, 0.7], [0.7, 0.7], [0.5, 0.36]]:
				_circle(c, r, p[0], p[1], 0.14, BROWN_L)
				_circle(c, r, p[0], p[1], 0.07, Color("#d8aa72"))
		"firewood":
			_quad(c, r, 0.5, 0.78, 0.8, 0.14, -12.0, BROWN)
			_quad(c, r, 0.5, 0.78, 0.8, 0.14, 12.0, BROWN_L)
			_poly(c, r, [[0.5, 0.06], [0.74, 0.4], [0.66, 0.66], [0.34, 0.66], [0.26, 0.4]], AMBER)
			_poly(c, r, [[0.5, 0.28], [0.64, 0.5], [0.58, 0.66], [0.42, 0.66], [0.36, 0.5]], Color("#f7d24f"))
		"olives":
			_line(c, r, [0.12, 0.2], [0.88, 0.3], BROWN_L, 0.05)
			_poly(c, r, [[0.55, 0.28], [0.9, 0.1], [0.78, 0.38]], GREEN)
			_ellipse(c, r, 0.34, 0.58, 0.16, 0.22, OLIVE)
			_ellipse(c, r, 0.64, 0.66, 0.16, 0.22, Color("#5d6b2b"))
			_line(c, r, [0.34, 0.24], [0.34, 0.38], BROWN_L, 0.04)
			_line(c, r, [0.64, 0.3], [0.64, 0.44], BROWN_L, 0.04)
		"oil":
			_ellipse(c, r, 0.5, 0.62, 0.3, 0.3, AMBER)
			_rect(c, r, 0.4, 0.2, 0.2, 0.2, GOLD_D)
			_rect(c, r, 0.34, 0.14, 0.32, 0.08, BROWN)
			_circle(c, r, 0.4, 0.56, 0.07, Color("#f7d98c"))
		"wool":
			for p in [[0.33, 0.52], [0.5, 0.36], [0.68, 0.5], [0.4, 0.68], [0.62, 0.68]]:
				_circle(c, r, p[0], p[1], 0.22, Color("#8d8a82"))
			for p in [[0.33, 0.5], [0.5, 0.34], [0.68, 0.48], [0.4, 0.66], [0.62, 0.66]]:
				_circle(c, r, p[0], p[1], 0.2, WHITE)
		"cloth":
			_rect(c, r, 0.16, 0.3, 0.72, 0.42, BLUE)
			_rect(c, r, 0.16, 0.44, 0.72, 0.08, Color("#a8c4e2"))
			_ellipse(c, r, 0.16, 0.51, 0.1, 0.21, BLUE_D)
			_ellipse(c, r, 0.16, 0.51, 0.04, 0.09, Color("#a8c4e2"))
			_rect(c, r, 0.3, 0.72, 0.5, 0.08, BLUE_D)
		"iron":
			for p in [[0.06, 0.58], [0.5, 0.58]]:
				_poly(c, r, [[p[0] + 0.06, p[1]], [p[0] + 0.38, p[1]], [p[0] + 0.44, p[1] + 0.3], [p[0], p[1] + 0.3]], STONE_D)
				_poly(c, r, [[p[0] + 0.06, p[1]], [p[0] + 0.38, p[1]], [p[0] + 0.35, p[1] + 0.08], [p[0] + 0.09, p[1] + 0.08]], STONE_L)
			_poly(c, r, [[0.28, 0.26], [0.7, 0.26], [0.76, 0.56], [0.22, 0.56]], STONE)
			_poly(c, r, [[0.28, 0.26], [0.7, 0.26], [0.67, 0.34], [0.31, 0.34]], STONE_L)
		"weapons":
			_line(c, r, [0.3, 0.7], [0.88, 0.12], STONE_L, 0.12)
			_line(c, r, [0.3, 0.7], [0.88, 0.12], STONE, 0.05)
			_line(c, r, [0.2, 0.52], [0.48, 0.8], BROWN, 0.08)
			_line(c, r, [0.26, 0.74], [0.1, 0.9], DARK, 0.09)
			_circle(c, r, 0.1, 0.9, 0.07, GOLD)
		"coin":
			_circle(c, r, 0.5, 0.5, 0.42, GOLD_D)
			_circle(c, r, 0.5, 0.5, 0.35, GOLD)
			_circle(c, r, 0.5, 0.5, 0.25, GOLD_D)
			_circle(c, r, 0.5, 0.5, 0.21, Color("#f0cb5f"))
			_rect(c, r, 0.46, 0.3, 0.08, 0.4, GOLD_D)
		"house":
			_rect(c, r, 0.2, 0.48, 0.6, 0.4, Color("#dcc59b"))
			_poly(c, r, [[0.08, 0.52], [0.5, 0.12], [0.92, 0.52]], RED)
			_poly(c, r, [[0.08, 0.52], [0.5, 0.12], [0.5, 0.2], [0.18, 0.52]], RED_D)
			_rect(c, r, 0.42, 0.62, 0.16, 0.26, BROWN)
			_rect(c, r, 0.26, 0.58, 0.11, 0.11, DARK)
			_rect(c, r, 0.63, 0.58, 0.11, 0.11, DARK)
		"granary":
			_rect(c, r, 0.16, 0.38, 0.68, 0.52, BROWN_L)
			for y in [0.5, 0.62, 0.74]:
				_line(c, r, [0.16, y], [0.84, y], BROWN, 0.025)
			_poly(c, r, [[0.08, 0.4], [0.5, 0.08], [0.92, 0.4]], BROWN)
			_rect(c, r, 0.36, 0.55, 0.28, 0.35, DARK)
			_line(c, r, [0.36, 0.55], [0.64, 0.9], BROWN_L, 0.03)
			_line(c, r, [0.64, 0.55], [0.36, 0.9], BROWN_L, 0.03)
			_circle(c, r, 0.5, 0.28, 0.06, WHEAT)
		"farm":
			_poly(c, r, [[0.14, 0.58], [0.86, 0.58], [1.0, 0.94], [0.0, 0.94]], BROWN)
			for i in 3:
				var t := 0.25 + 0.25 * i
				_line(c, r, [0.5 + (t - 0.5) * 0.7, 0.6], [0.5 + (t - 0.5) * 1.5, 0.93], GOLD, 0.04)
			draw(c, "wheat", Rect2(_p(r, 0.2, 0.0), r.size * Vector2(0.6, 0.65)))
		"mill":
			_poly(c, r, [[0.36, 0.45], [0.64, 0.45], [0.74, 0.94], [0.26, 0.94]], STONE_L)
			_poly(c, r, [[0.3, 0.46], [0.5, 0.28], [0.7, 0.46]], BROWN)
			_rect(c, r, 0.44, 0.74, 0.12, 0.2, BROWN)
			for a in [45.0, 135.0, 225.0, 315.0]:
				var d := Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a)))
				_line(c, r, [0.5, 0.4], [0.5 + d.x * 0.46, 0.4 + d.y * 0.46], BROWN, 0.05)
				_quad(c, r, 0.5 + d.x * 0.32, 0.4 + d.y * 0.32, 0.26, 0.1, a + 90.0, WHITE)
			_circle(c, r, 0.5, 0.4, 0.06, DARK)
		"bakery":
			_rect(c, r, 0.14, 0.58, 0.72, 0.32, RED_D)
			_poly(c, r, [[0.14, 0.6], [0.2, 0.36], [0.35, 0.2], [0.5, 0.14], [0.65, 0.2], [0.8, 0.36], [0.86, 0.6]], RED)
			_poly(c, r, [[0.36, 0.9], [0.36, 0.66], [0.42, 0.56], [0.58, 0.56], [0.64, 0.66], [0.64, 0.9]], DARK)
			_poly(c, r, [[0.42, 0.9], [0.5, 0.64], [0.58, 0.9]], AMBER)
			_rect(c, r, 0.68, 0.06, 0.1, 0.22, STONE_D)
		"woodcutter":
			_line(c, r, [0.22, 0.86], [0.7, 0.2], BROWN, 0.08)
			_poly(c, r, [[0.56, 0.14], [0.9, 0.28], [0.8, 0.52], [0.58, 0.4]], STONE_L)
			_poly(c, r, [[0.56, 0.14], [0.9, 0.28], [0.86, 0.34], [0.6, 0.22]], STONE)
			_rect(c, r, 0.38, 0.8, 0.56, 0.14, BROWN_L)
			_ellipse(c, r, 0.94, 0.87, 0.05, 0.07, Color("#d8aa72"))
		"olive_grove":
			_rect(c, r, 0.45, 0.5, 0.1, 0.42, BROWN)
			for p in [[0.32, 0.4], [0.5, 0.28], [0.68, 0.4], [0.42, 0.5], [0.6, 0.52]]:
				_circle(c, r, p[0], p[1], 0.2, Color("#7f9a58"))
			for p in [[0.3, 0.46], [0.56, 0.3], [0.7, 0.46], [0.46, 0.56]]:
				_circle(c, r, p[0], p[1], 0.05, Color("#3d4a22"))
			_rect(c, r, 0.2, 0.9, 0.6, 0.05, GREEN_D)
		"olive_press":
			_rect(c, r, 0.18, 0.12, 0.1, 0.72, BROWN)
			_rect(c, r, 0.72, 0.12, 0.1, 0.72, BROWN)
			_rect(c, r, 0.14, 0.12, 0.72, 0.12, BROWN_L)
			_line(c, r, [0.5, 0.24], [0.5, 0.56], STONE_D, 0.08)
			_rect(c, r, 0.3, 0.54, 0.4, 0.1, BROWN_L)
			_rect(c, r, 0.14, 0.82, 0.72, 0.1, STONE_D)
			_ellipse(c, r, 0.5, 0.74, 0.1, 0.07, AMBER)
		"sheepfold":
			for p in [[0.36, 0.42], [0.5, 0.32], [0.64, 0.42], [0.42, 0.54], [0.58, 0.54]]:
				_circle(c, r, p[0], p[1], 0.17, WHITE)
			_circle(c, r, 0.82, 0.48, 0.09, DARK)
			_line(c, r, [0.4, 0.62], [0.4, 0.74], DARK, 0.04)
			_line(c, r, [0.6, 0.62], [0.6, 0.74], DARK, 0.04)
			for x in [0.1, 0.38, 0.62, 0.9]:
				_rect(c, r, x - 0.03, 0.68, 0.06, 0.26, BROWN)
			_line(c, r, [0.06, 0.76], [0.94, 0.76], BROWN_L, 0.04)
			_line(c, r, [0.06, 0.88], [0.94, 0.88], BROWN_L, 0.04)
		"loom":
			_rect(c, r, 0.12, 0.1, 0.08, 0.82, BROWN)
			_rect(c, r, 0.8, 0.1, 0.08, 0.82, BROWN)
			_rect(c, r, 0.12, 0.1, 0.76, 0.08, BROWN_L)
			_rect(c, r, 0.12, 0.84, 0.76, 0.08, BROWN_L)
			for x in [0.28, 0.4, 0.52, 0.64, 0.76]:
				_line(c, r, [x, 0.18], [x, 0.84], Color("#d7c9a8"), 0.025)
			_rect(c, r, 0.2, 0.5, 0.6, 0.14, BLUE)
			_rect(c, r, 0.2, 0.56, 0.6, 0.03, Color("#a8c4e2"))
			_rect(c, r, 0.2, 0.36, 0.6, 0.1, RED)
		"market":
			for i in 4:
				var x0 := 0.1 + 0.2 * i
				_poly(c, r, [[x0, 0.14], [x0 + 0.2, 0.14], [x0 + 0.22, 0.42], [x0 - 0.02, 0.42]], RED if i % 2 == 0 else WHITE)
			_line(c, r, [0.14, 0.42], [0.14, 0.9], BROWN, 0.05)
			_line(c, r, [0.86, 0.42], [0.86, 0.9], BROWN, 0.05)
			_rect(c, r, 0.1, 0.64, 0.8, 0.1, BROWN_L)
			_circle(c, r, 0.3, 0.57, 0.08, RED)
			_circle(c, r, 0.46, 0.57, 0.08, GREEN)
			_circle(c, r, 0.62, 0.57, 0.08, AMBER)
			_circle(c, r, 0.76, 0.58, 0.06, GOLD)
		"mine":
			_poly(c, r, [[0.04, 0.88], [0.42, 0.18], [0.62, 0.5], [0.76, 0.34], [0.96, 0.88]], STONE)
			_poly(c, r, [[0.42, 0.18], [0.62, 0.5], [0.5, 0.52]], STONE_L)
			_poly(c, r, [[0.34, 0.88], [0.34, 0.6], [0.4, 0.5], [0.6, 0.5], [0.66, 0.6], [0.66, 0.88]], DARK)
			_rect(c, r, 0.3, 0.52, 0.06, 0.38, BROWN_L)
			_rect(c, r, 0.64, 0.52, 0.06, 0.38, BROWN_L)
			_rect(c, r, 0.28, 0.48, 0.44, 0.07, BROWN_L)
			_circle(c, r, 0.82, 0.8, 0.04, GOLD)
			_circle(c, r, 0.14, 0.82, 0.04, GOLD)
		"smithy":
			_poly(c, r, [[0.1, 0.42], [0.9, 0.42], [0.8, 0.54], [0.64, 0.58], [0.64, 0.72], [0.78, 0.86], [0.22, 0.86], [0.36, 0.72], [0.36, 0.58], [0.2, 0.54]], STONE_D)
			_rect(c, r, 0.1, 0.38, 0.8, 0.08, STONE)
			_line(c, r, [0.62, 0.06], [0.34, 0.34], BROWN, 0.07)
			_quad(c, r, 0.68, 0.1, 0.3, 0.16, 35.0, STONE_L)
			for p in [[0.14, 0.2], [0.24, 0.1], [0.12, 0.34]]:
				_circle(c, r, p[0], p[1], 0.035, AMBER)
		"barracks":
			_poly(c, r, [[0.16, 0.12], [0.84, 0.12], [0.84, 0.56], [0.5, 0.92], [0.16, 0.56]], RED_D)
			_poly(c, r, [[0.22, 0.18], [0.78, 0.18], [0.78, 0.54], [0.5, 0.84], [0.22, 0.54]], RED)
			_line(c, r, [0.32, 0.64], [0.68, 0.28], STONE_L, 0.08)
			_line(c, r, [0.32, 0.28], [0.68, 0.64], STONE_L, 0.08)
			_rect(c, r, 0.46, 0.0, 0.08, 0.16, GOLD)
		"people":
			_circle(c, r, 0.34, 0.3, 0.15, SKIN)
			_poly(c, r, [[0.08, 0.9], [0.12, 0.58], [0.34, 0.5], [0.56, 0.58], [0.6, 0.9]], BLUE)
			_circle(c, r, 0.7, 0.38, 0.12, SKIN)
			_poly(c, r, [[0.54, 0.9], [0.56, 0.66], [0.7, 0.58], [0.86, 0.66], [0.92, 0.9]], RED)
		"hammer":
			_line(c, r, [0.22, 0.88], [0.62, 0.38], BROWN_L, 0.1)
			_quad(c, r, 0.64, 0.3, 0.52, 0.24, 38.0, STONE_L)
			_quad(c, r, 0.64, 0.3, 0.52, 0.08, 38.0, STONE)
		"town":
			_rect(c, r, 0.14, 0.34, 0.72, 0.56, STONE)
			for x in [0.14, 0.34, 0.54, 0.74]:
				_rect(c, r, x, 0.2, 0.12, 0.16, STONE)
			_poly(c, r, [[0.4, 0.9], [0.4, 0.62], [0.5, 0.52], [0.6, 0.62], [0.6, 0.9]], DARK)
			_rect(c, r, 0.22, 0.46, 0.08, 0.12, DARK)
			_rect(c, r, 0.7, 0.46, 0.08, 0.12, DARK)
		"face":
			_circle(c, r, 0.5, 0.5, 0.42, Color("#e0584a"))
			_circle(c, r, 0.5, 0.5, 0.36, Color("#ef7a64"))
			_circle(c, r, 0.36, 0.46, 0.05, DARK)
			_circle(c, r, 0.64, 0.46, 0.05, DARK)
			_line(c, r, [0.26, 0.32], [0.44, 0.4], DARK, 0.05)
			_line(c, r, [0.74, 0.32], [0.56, 0.4], DARK, 0.05)
			_line(c, r, [0.34, 0.74], [0.5, 0.64], DARK, 0.05)
			_line(c, r, [0.5, 0.64], [0.66, 0.74], DARK, 0.05)
		"bolt":
			_poly(c, r, [[0.58, 0.04], [0.2, 0.54], [0.45, 0.54], [0.36, 0.96], [0.8, 0.4], [0.54, 0.4]], Color("#f3cf4a"))
			_poly(c, r, [[0.58, 0.04], [0.2, 0.54], [0.32, 0.54], [0.58, 0.18]], Color("#fbe58c"))
		"clock":
			_circle(c, r, 0.5, 0.5, 0.42, STONE_D)
			_circle(c, r, 0.5, 0.5, 0.35, WHITE)
			_line(c, r, [0.5, 0.5], [0.5, 0.22], DARK, 0.06)
			_line(c, r, [0.5, 0.5], [0.7, 0.58], DARK, 0.05)
		"warning":
			_poly(c, r, [[0.5, 0.06], [0.96, 0.9], [0.04, 0.9]], Color("#e0b04c"))
			_poly(c, r, [[0.5, 0.2], [0.84, 0.82], [0.16, 0.82]], Color("#f2c85e"))
			_rect(c, r, 0.46, 0.38, 0.08, 0.26, DARK)
			_rect(c, r, 0.46, 0.69, 0.08, 0.08, DARK)
		"danger":
			_poly(c, r, [[0.5, 0.06], [0.96, 0.9], [0.04, 0.9]], RED_D)
			_poly(c, r, [[0.5, 0.2], [0.84, 0.82], [0.16, 0.82]], Color("#e5654f"))
			_rect(c, r, 0.46, 0.38, 0.08, 0.26, WHITE)
			_rect(c, r, 0.46, 0.69, 0.08, 0.08, WHITE)
		"storage":
			_rect(c, r, 0.1, 0.3, 0.8, 0.6, BROWN_L)
			_rect(c, r, 0.1, 0.3, 0.8, 0.1, BROWN)
			_line(c, r, [0.1, 0.9], [0.9, 0.3], BROWN, 0.05)
			_line(c, r, [0.1, 0.3], [0.9, 0.9], BROWN, 0.05)
			_poly(c, r, [[0.1, 0.3], [0.2, 0.14], [0.8, 0.14], [0.9, 0.3]], BROWN)
		"helmet":
			_poly(c, r, [[0.14, 0.62], [0.16, 0.38], [0.3, 0.2], [0.5, 0.14], [0.7, 0.2], [0.84, 0.38], [0.86, 0.62]], STONE_L)
			_poly(c, r, [[0.14, 0.62], [0.16, 0.38], [0.3, 0.2], [0.34, 0.3], [0.26, 0.62]], STONE)
			_rect(c, r, 0.14, 0.58, 0.72, 0.1, STONE_D)
			_rect(c, r, 0.24, 0.42, 0.52, 0.07, DARK)
			_rect(c, r, 0.46, 0.42, 0.08, 0.48, STONE_D)
			_rect(c, r, 0.2, 0.68, 0.14, 0.22, STONE_D)
			_rect(c, r, 0.66, 0.68, 0.14, 0.22, STONE_D)
			_poly(c, r, [[0.5, 0.14], [0.44, 0.0], [0.62, 0.04], [0.56, 0.16]], RED)
		"arrow":
			_poly(c, r, [[0.1, 0.4], [0.58, 0.4], [0.58, 0.22], [0.92, 0.5], [0.58, 0.78], [0.58, 0.6], [0.1, 0.6]], STONE_L)
		"calendar":
			_rect(c, r, 0.12, 0.2, 0.76, 0.7, WHITE)
			_rect(c, r, 0.12, 0.2, 0.76, 0.2, RED)
			_rect(c, r, 0.26, 0.08, 0.08, 0.2, STONE_D)
			_rect(c, r, 0.66, 0.08, 0.08, 0.2, STONE_D)
			for i in 6:
				_rect(c, r, 0.2 + 0.2 * (i % 3), 0.48 + 0.2 * (i / 3), 0.14, 0.12, STONE)
		_:
			_circle(c, r, 0.5, 0.5, 0.4, STONE_D)
			_rect(c, r, 0.46, 0.3, 0.08, 0.26, WHITE)
			_rect(c, r, 0.46, 0.64, 0.08, 0.08, WHITE)
