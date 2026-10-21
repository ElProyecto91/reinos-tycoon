extends RefCounted
## Árboles, campos, huertas, norias, molinos y talleres rurales hacia el año 1000.
## Respaldo y suposiciones: docs/REGION_IBERIA_1000.md (H-03 regadío con acequias y norias,
## H-10 calendario agrícola de Córdoba, H-19 norias y molinos).

const Malla = preload("res://scripts/view/malla.gd")
const U = preload("res://scripts/view/epoca_util.gd")

## Puntos de la casilla donde pueden crecer árboles (todos caben con margen 0,15).
const PUNTOS_BOSQUE: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.45, 0.20), Vector2(-0.45, 0.25), Vector2(0.15, -0.50),
	Vector2(-0.30, -0.45), Vector2(0.60, -0.30), Vector2(-0.62, -0.10), Vector2(0.30, 0.62),
	Vector2(-0.20, 0.65), Vector2(0.70, 0.35), Vector2(-0.70, 0.40), Vector2(0.0, 0.32),
	Vector2(0.35, -0.05), Vector2(-0.18, -0.12),
]


# ---------------------------------------------------------------------------------------------
# Árboles

## Arbusto o frutal pequeño (patios de casas y mezquitas: H-17 cita frutales en el patio).
static func arbolillo(m: Malla, base: Vector3, r: float, col: Color) -> void:
	m.cyl(base, 0.008, 0.006, r * 0.9, 5, U.TRONCO)
	m.blob(base + Vector3(0, r * 1.1, 0), r, 6, 4, col, 0.85)


static func olivo(m: Malla, base: Vector3, s: float = 1.0) -> void:
	m.cyl(base, 0.022 * s, 0.015 * s, 0.075 * s, 5, U.TRONCO)
	m.blob(base + Vector3(0, 0.125 * s, 0), 0.085 * s, 6, 4, U.OLIVO_COPA, 0.72)
	m.blob(base + Vector3(0.045 * s, 0.10 * s, 0.02 * s), 0.055 * s, 6, 3, U.OLIVO_COPA.lightened(0.10), 0.7)


static func cipres(m: Malla, base: Vector3, s: float = 1.0) -> void:
	m.cyl(base, 0.012 * s, 0.01 * s, 0.03 * s, 5, U.TRONCO)
	m.cyl(base + Vector3(0, 0.025 * s, 0), 0.045 * s, 0.0, 0.34 * s, 6, U.CIPRES, false)


static func encina(m: Malla, base: Vector3, s: float = 1.0, copa: Color = U.ENCINA_COPA) -> void:
	m.cyl(base, 0.028 * s, 0.02 * s, 0.09 * s, 5, U.TRONCO)
	m.blob(base + Vector3(0, 0.17 * s, 0), 0.12 * s, 6, 4, copa, 0.85, copa.lightened(0.07))


static func roble(m: Malla, base: Vector3, s: float = 1.0) -> void:
	encina(m, base, s, U.ROBLE_COPA)


static func pino(m: Malla, base: Vector3, s: float = 1.0) -> void:
	m.cyl(base, 0.02 * s, 0.014 * s, 0.17 * s, 5, U.TRONCO)
	m.blob(base + Vector3(0, 0.21 * s, 0), 0.12 * s, 7, 4, U.PINO_COPA, 0.42, U.PINO_COPA.lightened(0.06))


static func alamo(m: Malla, base: Vector3, s: float = 1.0) -> void:
	m.cyl(base, 0.014 * s, 0.01 * s, 0.05 * s, 5, U.TRONCO)
	m.blob(base + Vector3(0, 0.20 * s, 0), 0.055 * s, 6, 4, Color(0.48, 0.62, 0.30), 2.8)


## Palmera datilera: solo en jardines de palacio (suposición de diseño; H-17 solo las atestigua en sellos de 1262 y 1445).
static func palmera(m: Malla, base: Vector3, s: float = 1.0) -> void:
	m.cyl(base, 0.018 * s, 0.012 * s, 0.26 * s, 5, U.MADERA_CLARA)
	for i in 7:
		m.push(base + Vector3(0, 0.26 * s, 0), 360.0 * float(i) / 7.0, 0.0, -22.0)
		m.box(Vector3(0.065 * s, -0.004, 0), Vector3(0.14 * s, 0.008, 0.04 * s), U.PINO_COPA.lightened(0.05))
		m.pop()


## Bosque en una casilla: n árboles de un tipo ("encinar", "robledal", "pinar", "mixto").
static func bosque(m: Malla, seed: int, n: int, tipo: String) -> void:
	var usados := 0
	# Se recorre la lista desde un punto de partida distinto por casilla.
	var inicio := int(U.rnd(seed, 1) * float(PUNTOS_BOSQUE.size()))
	for k in PUNTOS_BOSQUE.size():
		if usados >= n:
			break
		var p := PUNTOS_BOSQUE[(inicio + k) % PUNTOS_BOSQUE.size()]
		var s := 0.85 + 0.35 * U.rnd(seed, 10 + k)
		var base := Vector3(p.x, 0, p.y)
		match tipo:
			"robledal":
				roble(m, base, s)
			"pinar":
				pino(m, base, s)
			"mixto":
				if U.rnd(seed, 40 + k) < 0.55:
					encina(m, base, s)
				elif U.rnd(seed, 60 + k) < 0.5:
					pino(m, base, s)
				else:
					olivo(m, base, s * 1.1)
			_:
				encina(m, base, s)
		usados += 1


# ---------------------------------------------------------------------------------------------
# Relieve

## Colina o monte irregular ("h" colina, "H" colina grande, "M" monte, "N" monte alto, "Q" monte con una
## segunda cumbre). seco: matorral ocre-oliva en el sur; verde apagado en el norte. Sustituye a los
## modelos KayKit, de aspecto de dibujos animados. El color es suposición de diseño.
static func relieve(m: Malla, tipo: String, seed: int, seco: bool) -> void:
	var bajo := Color(0.44, 0.42, 0.26) if seco else Color(0.30, 0.41, 0.22)
	var medio := Color(0.55, 0.47, 0.34) if seco else Color(0.42, 0.42, 0.32)
	var alto := Color(0.66, 0.60, 0.50) if seco else Color(0.60, 0.58, 0.54)
	match tipo:
		"h":
			m.lump(Vector3.ZERO, 1.10, 0.40, 14, 4, seed, bajo, medio, alto, 2)
		"H":
			m.lump(Vector3.ZERO, 1.12, 0.65, 14, 5, seed, bajo, medio, alto, 3)
		"M":
			m.lump(Vector3.ZERO, 1.12, 0.95, 14, 5, seed, bajo, medio, alto, 4)
		"N":
			m.lump(Vector3.ZERO, 1.12, 1.25, 14, 6, seed, bajo, medio, alto, 5)
		_:
			m.lump(Vector3.ZERO, 1.12, 0.85, 14, 5, seed, bajo, medio, alto, 3)
	# Matorral y alguna encina sobre las laderas bajas.
	for k in 4:
		var a := TAU * (float(k) + 0.5 * U.rnd(seed, k)) / 4.0
		var rad := 0.55 + 0.25 * U.rnd(seed, 10 + k)
		if tipo == "h" or tipo == "H":
			encina(m, Vector3(cos(a) * rad, 0.08 + 0.05 * (1.0 - rad), sin(a) * rad), 0.55, bajo.lightened(0.15))


# ---------------------------------------------------------------------------------------------
# Campos

## Campo de cereal de secano en franjas de trigo y barbecho (H-03, H-10: cereal de secano).
static func campo_secano(m: Malla, seed: int) -> void:
	var giro := 60.0 * floorf(U.rnd(seed, 1) * 3.0)
	m.push(Vector3.ZERO, giro)
	for i in 5:
		var z := (float(i) - 2.0) * 0.34
		var mitad := U.hex_half_width(absf(z) + 0.15) - 0.09
		if mitad < 0.12:
			continue
		var col := U.jit(U.TRIGO if i % 2 == 0 else U.BARBECHO, 0.04, seed, i)
		m.box(Vector3(0, 0, z), Vector3(mitad * 2.0, 0.03 + 0.012 * U.rnd(seed, 20 + i), 0.29), col)
	m.pop()


## Huerta de regadío: parcelas verdes separadas por acequias (H-03: regadío con acequias, norias y
## pozos). Con noria genérica de madera en un borde si con_noria. No es «la noria de la Albolafia» (H-19).
static func huerta(m: Malla, seed: int, con_noria: bool) -> void:
	var giro := 60.0 * floorf(U.rnd(seed, 1) * 3.0)
	m.push(Vector3.ZERO, giro)
	for fila in [-1.0, 1.0]:
		for k in 2:
			var z: float = fila * (0.20 + 0.36 * float(k))
			var mitad := U.hex_half_width(absf(z) + 0.14) - 0.10
			if mitad < 0.14:
				continue
			for lado in [-1.0, 1.0]:
				var cx: float = lado * (mitad * 0.5 + 0.03)
				var col := U.jit(U.VERDE_HUERTA if (k + int(lado)) % 2 == 0 else U.VERDE_HUERTA_2, 0.04, seed, k * 7 + int(lado + 2.0))
				m.box(Vector3(cx, 0, z), Vector3(mitad - 0.06, 0.035, 0.27), col)
	# Acequias: una a lo largo y otra que cruza.
	m.box(Vector3(0, 0, 0), Vector3(1.55, 0.02, 0.05), U.AGUA)
	m.box(Vector3(0, 0, 0), Vector3(0.05, 0.02, 1.25), U.AGUA)
	if con_noria:
		noria(m, Vector3(0.0, 0, -0.80), 0.0, 0.8)
	m.pop()


## Olivar en hileras (H-10: recogida de la aceituna en septiembre–octubre en Córdoba).
static func olivar(m: Malla, seed: int) -> void:
	var giro := 60.0 * floorf(U.rnd(seed, 1) * 3.0)
	m.push(Vector3.ZERO, giro)
	m.box(Vector3(0, 0, 0), Vector3(1.5, 0.012, 1.3), U.BARBECHO.darkened(0.04))
	var fila := 0
	for z in [-0.60, -0.30, 0.0, 0.30, 0.60]:
		var mitad := U.hex_half_width(absf(z) + 0.12) - 0.12
		var n := 4 if mitad > 0.6 else 3
		for i in n:
			var x := -mitad + (2.0 * mitad) * (float(i) + 0.5 * float(fila % 2)) / float(n)
			if U.in_hex(x, z, 0.14):
				olivo(m, Vector3(x, 0.012, z), 0.85 + 0.2 * U.rnd(seed, i + fila * 5))
		fila += 1
	m.pop()


# ---------------------------------------------------------------------------------------------
# Norias y molinos

## Noria de madera genérica: dos ruedas con radios, arcaduces (cangilones de barro) y un acueducto
## de arcos que lleva el agua a la huerta. Madera: encina o roble (H-19). Sin fecha ni medidas de ninguna noria concreta.
static func noria(m: Malla, pos: Vector3, rot_deg: float, s: float) -> void:
	m.push(pos, rot_deg)
	var R := 0.24 * s
	var cy := R + 0.05 * s
	for z in [-0.03 * s, 0.03 * s]:
		for i in 12:
			var ang := 30.0 * float(i)
			m.push(Vector3(0, cy, z), 0.0, 0.0, ang)
			m.box(Vector3(R * 0.5, -0.006, 0), Vector3(R, 0.012, 0.012), U.MADERA)
			m.box(Vector3(R, -R * 0.2588, 0), Vector3(0.014, R * 0.5176, 0.022), U.MADERA_CLARA)
			if z > 0:
				m.box(Vector3(R + 0.012, -0.013, -0.03 * s), Vector3(0.026, 0.026, 0.06 * s), U.TEJA)
			m.pop()
	# Eje y soportes de piedra.
	m.box(Vector3(0, 0, -0.045 * s), Vector3(0.05 * s, cy + 0.02, 0.025 * s), U.CALIZA.darkened(0.08))
	m.box(Vector3(0, 0, 0.045 * s), Vector3(0.05 * s, cy + 0.02, 0.025 * s), U.CALIZA.darkened(0.08))
	# Acueducto: canal sobre cinco arcos de medio punto.
	var alto := (cy + R) * 0.92
	var arcos: Array = []
	for i in 5:
		arcos.append({"x": -0.34 * s + 0.68 * s * (float(i) + 0.5) / 5.0, "r": 0.05 * s, "y": 0.13 * s, "tipo": "medio_punto"})
	m.push(Vector3(0.45 * s, 0, 0), 0.0)
	m.arch_wall(Vector3.ZERO, 0.68 * s, alto, 0.06 * s, arcos, U.CALIZA, 6)
	m.box(Vector3(0, alto, 0), Vector3(0.68 * s, 0.03 * s, 0.08 * s), U.CALIZA.lightened(0.04))
	m.box(Vector3(0, alto + 0.03 * s, 0), Vector3(0.66 * s, 0.008, 0.05 * s), U.AGUA)
	m.pop()
	m.pop()


## Molino de agua de rueda vertical (el río con presa y molinos junto al puente de Córdoba: H-19, la presa
## es del siglo X; los molinos los citan autores posteriores). La rueda mira hacia +z.
static func molino_agua(m: Malla, rot_deg: float) -> void:
	m.push(Vector3.ZERO, rot_deg)
	m.box(Vector3(0, 0, -0.10), Vector3(0.52, 0.17, 0.34), U.CALIZA.darkened(0.03))
	m.gable(Vector3(0, 0.17, -0.10), Vector3(0.58, 0.12, 0.38), U.TEJA)
	m.box(Vector3(-0.12, 0, 0.07), Vector3(0.05, 0.05, 0.02), U.SOMBRA)
	# Rueda.
	var R := 0.21
	for i in 10:
		m.push(Vector3(0.0, R + 0.01, 0.17), 0.0, 0.0, 36.0 * float(i))
		m.box(Vector3(R * 0.5, -0.006, 0), Vector3(R, 0.012, 0.012), U.MADERA)
		m.box(Vector3(R, -R * 0.3090, 0), Vector3(0.016, R * 0.618, 0.05), U.MADERA_CLARA)
		m.pop()
	# Presa baja de piedra al lado de la rueda.
	m.box(Vector3(0, 0, 0.34), Vector3(0.9, 0.05, 0.07), U.CALIZA.darkened(0.12))
	m.pop()


## Aserradero: cobertizo abierto y troncos apilados.
static func aserradero(m: Malla) -> void:
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			m.box(Vector3(-0.25 + dx * 0.15, 0, dz * 0.11), Vector3(0.025, 0.14, 0.025), U.MADERA)
	m.gable(Vector3(-0.25, 0.14, 0), Vector3(0.40, 0.08, 0.30), U.PAJA)
	for k in 3:
		for j in (3 - k):
			m.push(Vector3(0.28 + float(j) * 0.07 + float(k) * 0.035, 0.03 + float(k) * 0.06, 0.16), 0.0, 0.0, 90.0)
			m.cyl(Vector3(0, -0.12, 0), 0.03, 0.03, 0.24, 6, U.MADERA_CLARA)
			m.pop()
	encina(m, Vector3(0.45, 0, -0.45), 0.9)
	roble(m, Vector3(-0.5, 0, -0.5), 0.9)


## Herrería: casa baja de piedra con chimenea, yunque y carbón.
static func herreria(m: Malla) -> void:
	m.box(Vector3(-0.1, 0, 0), Vector3(0.50, 0.11, 0.34), U.PIEDRA_NORTE)
	m.gable(Vector3(-0.1, 0.11, 0), Vector3(0.56, 0.10, 0.38), U.TEJA_OSCURA)
	m.box(Vector3(0.12, 0.11, -0.10), Vector3(0.07, 0.17, 0.07), U.PIEDRA_NORTE.darkened(0.1), 0.85)
	m.box(Vector3(0.32, 0, 0.14), Vector3(0.07, 0.04, 0.05), Color(0.25, 0.25, 0.28))
	m.box(Vector3(0.32, 0.04, 0.14), Vector3(0.09, 0.02, 0.04), Color(0.30, 0.30, 0.33))
	m.box(Vector3(0.28, 0, -0.18), Vector3(0.12, 0.03, 0.1), Color(0.18, 0.16, 0.15))


# ---------------------------------------------------------------------------------------------
# Cercados

## Cercado circular de estacas y travesaños (el corral).
static func cercado(m: Malla, centro: Vector3, radio_extra: float) -> void:
	var r := 0.80 + radio_extra
	var n := 18
	for i in n:
		var a := TAU * float(i) / float(n)
		var b := TAU * float(i + 1) / float(n)
		var p := centro + Vector3(cos(a), 0, sin(a)) * r
		var q := centro + Vector3(cos(b), 0, sin(b)) * r
		if not U.in_hex(p.x, p.z, 0.02):
			continue
		m.box(p, Vector3(0.018, 0.07, 0.018), U.MADERA)
		var mid := (p + q) * 0.5
		var ang := rad_to_deg(atan2(-(q.z - p.z), q.x - p.x))
		m.push(mid + Vector3(0, 0.045, 0), ang)
		m.box(Vector3.ZERO, Vector3((p - q).length(), 0.012, 0.012), U.MADERA_CLARA)
		m.pop()


# ---------------------------------------------------------------------------------------------
# Ganadería y minería

## Aprisco: redil de estacas con ovejas y un montón de heno. Las ovejas son manchas lanosas con cabeza oscura.
static func aprisco(m: Malla, seed: int) -> void:
	var hx := 0.62
	var hz := 0.46
	var paso := 0.155
	var x := -hx
	while x <= hx + 0.001:
		for z in [-hz, hz]:
			m.box(Vector3(x, 0, z), Vector3(0.022, 0.085, 0.022), U.MADERA)
		x += paso
	var zz := -hz
	while zz <= hz + 0.001:
		for xx in [-hx, hx]:
			m.box(Vector3(xx, 0, zz), Vector3(0.022, 0.085, 0.022), U.MADERA)
		zz += paso
	for y in [0.035, 0.065]:
		m.box(Vector3(0, y, -hz), Vector3(hx * 2.0, 0.012, 0.012), U.MADERA_CLARA)
		m.box(Vector3(0, y, hz), Vector3(hx * 2.0, 0.012, 0.012), U.MADERA_CLARA)
		m.box(Vector3(-hx, y, 0), Vector3(0.012, 0.012, hz * 2.0), U.MADERA_CLARA)
		m.box(Vector3(hx, y, 0), Vector3(0.012, 0.012, hz * 2.0), U.MADERA_CLARA)
	m.box(Vector3(0, -0.0, 0), Vector3(hx * 2.0 - 0.04, 0.012, hz * 2.0 - 0.04), U.TIERRA.lightened(0.05))
	for i in 7:
		var px := (U.rnd(seed, 40 + i) - 0.5) * (hx * 2.0 - 0.3)
		var pz := (U.rnd(seed, 60 + i) - 0.5) * (hz * 2.0 - 0.25)
		var giro := U.rnd(seed, 80 + i) * TAU
		m.blob(Vector3(px, 0.05, pz), 0.065, 6, 4, Color(0.90, 0.88, 0.82), 0.70)
		m.blob(Vector3(px + cos(giro) * 0.07, 0.065, pz + sin(giro) * 0.07), 0.027, 5, 3, Color(0.25, 0.21, 0.18))
	m.box(Vector3(-hx + 0.16, 0, hz - 0.14), Vector3(0.18, 0.07, 0.12), U.PAJA)


## Mina: cerro con la bocamina entibada de madera, una vagoneta y la escombrera.
static func mina(m: Malla, seed: int, seco: bool) -> void:
	relieve(m, "h", seed, seco)
	m.push(Vector3(0, 0, 0.50), 0.0)
	m.box(Vector3(0, 0, 0), Vector3(0.30, 0.20, 0.14), U.SOMBRA)
	for dx in [-1.0, 1.0]:
		m.box(Vector3(dx * 0.17, 0, 0.05), Vector3(0.035, 0.24, 0.045), U.MADERA)
	m.box(Vector3(0, 0.22, 0.05), Vector3(0.40, 0.045, 0.05), U.MADERA)
	m.pop()
	for dz in [0.0, 0.07]:
		m.box(Vector3(0.0, 0.0, 0.64 + dz), Vector3(0.015, 0.012, 0.30), U.MADERA_CLARA)
	m.box(Vector3(0.0, 0.015, 0.78), Vector3(0.11, 0.06, 0.15), Color(0.30, 0.28, 0.27))
	m.box(Vector3(0.0, 0.075, 0.78), Vector3(0.09, 0.025, 0.12), Color(0.46, 0.34, 0.26))
	for k in 4:
		m.blob(Vector3(-0.42 + 0.09 * float(k), 0.04, 0.62 + 0.05 * U.rnd(seed, k)), 0.075, 5, 3, Color(0.52, 0.47, 0.42), 0.6)
