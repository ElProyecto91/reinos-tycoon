extends RefCounted
## Casas, mezquitas, iglesia, alcázar y mercado hacia el año 1000.
## Cada función añade geometría a una Malla en coordenadas locales (centro de la casilla = origen,
## suelo = y 0). Lo que es dato y lo que es suposición está en docs/REGION_IBERIA_1000.md.

const Malla = preload("res://scripts/view/malla.gd")
const U = preload("res://scripts/view/epoca_util.gd")
const Campo = preload("res://scripts/view/epoca_campo.gd")


## Losa hexagonal baja de tierra batida o piedra bajo un edificio o una manzana: las callejas entre
## las casas se leen como tierra y no como césped.
static func suelo_urbano(m: Malla, col: Color) -> void:
	m.push(Vector3.ZERO, 30.0)
	m.cyl(Vector3.ZERO, 1.1, 1.1, 0.016, 6, col)
	m.pop()


# ---------------------------------------------------------------------------------------------
# Casas

## Casa de una planta con patio central (H-22: el patio ocupa algo más de un tercio de la superficie,
## sin pruebas de segunda planta). Cubierta: azotea plana (suposición: H-22 no confirma la cubierta).
static func casa_patio(m: Malla, centro: Vector3, w: float, d: float, h: float, rot_deg: float, col: Color, seed: int, arbol: bool) -> void:
	m.push(centro, rot_deg)
	var t := minf(w, d) * 0.27
	var top := col.lightened(0.07)
	m.box(Vector3(0, 0, -(d - t) * 0.5), Vector3(w, h, t), col, 1.0, top)
	m.box(Vector3(0, 0, (d - t) * 0.5), Vector3(w, h, t), col, 1.0, top)
	m.box(Vector3(-(w - t) * 0.5, 0, 0), Vector3(t, h, d - 2.0 * t), col, 1.0, top)
	m.box(Vector3((w - t) * 0.5, 0, 0), Vector3(t, h, d - 2.0 * t), col, 1.0, top)
	m.box(Vector3(0, 0, 0), Vector3(w - 2.0 * t + 0.01, 0.012, d - 2.0 * t + 0.01), U.SUELO_PATIO)
	if arbol:
		Campo.arbolillo(m, Vector3(0, 0.012, 0), 0.03 + 0.012 * U.rnd(seed, 3), U.jit(U.VERDE_HUERTA, 0.05, seed, 4))
	m.pop()


## Manzana de casas de patio apretadas, con callejas estrechas entre ellas (H-22: calles secundarias
## de 2,7 a 3 m y adarves). densidad 0..1; plaza deja un hueco central con un pozo.
## color_base: ocre/tapial en Córdoba, cal en Zaragoza (H-23).
static func manzana(m: Malla, seed: int, densidad: float, color_base: Color, plaza: bool) -> void:
	var giro := 18.0 * floorf(U.rnd(seed, 1) * 4.0)   # 0, 18, 36 o 54 grados para toda la manzana
	m.push(Vector3.ZERO, giro)
	var n := 0
	for j in 9:
		for i in 8:
			var k := j * 8 + i
			var cx := (float(i) - 3.5) * 0.34 + (0.17 if j % 2 == 1 else 0.0) - 0.08
			var cz := (float(j) - 4.0) * 0.30
			if plaza and absf(cx) < 0.30 and absf(cz) < 0.27:
				continue
			if U.rnd(seed, 10 + k) > densidad:
				continue
			var w := 0.27 + 0.05 * U.rnd(seed, 30 + k)
			var d := 0.22 + 0.04 * U.rnd(seed, 50 + k)
			var h := 0.075 + 0.045 * U.rnd(seed, 70 + k)
			var px := cx + (U.rnd(seed, 90 + k) - 0.5) * 0.02
			var pz := cz + (U.rnd(seed, 110 + k) - 0.5) * 0.02
			var rot := (U.rnd(seed, 130 + k) - 0.5) * 9.0
			# Las cuatro esquinas, ya giradas con la manzana, han de caber en la casilla.
			var ok := true
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var lx: float = px + sx * w * 0.5
					var lz: float = pz + sz * d * 0.5
					var a := deg_to_rad(giro)
					# giro de Godot sobre y: x' = x cos + z sin ; z' = -x sin + z cos
					var wx: float = lx * cos(a) + lz * sin(a)
					var wz: float = -lx * sin(a) + lz * cos(a)
					if not U.in_hex(wx, wz, 0.07):
						ok = false
			if not ok:
				continue
			var col := U.jit(color_base, 0.05, seed, k)
			casa_patio(m, Vector3(px, 0, pz), w, d, h, rot, col, seed + k, U.rnd(seed, 150 + k) < 0.5)
			n += 1
	if plaza:
		# Pozo de brocal bajo en el centro.
		m.cyl(Vector3(0, 0, 0), 0.07, 0.07, 0.05, 8, U.PIEDRA_NORTE)
		m.cyl(Vector3(0, 0.04, 0), 0.05, 0.05, 0.012, 8, U.AGUA)
	m.pop()


## Casas de aldea del norte cristiano: zócalo de piedra, muros de tapial o entramado, tejado a dos
## aguas bajo (H-25, Madrid siglos V–IX; extrapolado al año 1000 en León y Castilla: suposición).
static func casa_aldea(m: Malla, centro: Vector3, w: float, d: float, rot_deg: float, seed: int, teja: bool) -> void:
	m.push(centro, rot_deg)
	var zocalo := 0.035
	var muro := 0.06 + 0.02 * U.rnd(seed, 1)
	m.box(Vector3.ZERO, Vector3(w, zocalo, d), U.PIEDRA_NORTE)
	m.box(Vector3(0, zocalo, 0), Vector3(w - 0.015, muro, d - 0.015), U.jit(U.TAPIAL, 0.05, seed, 2))
	var techo := U.TEJA_OSCURA if teja else U.jit(U.PAJA, 0.05, seed, 3)
	m.gable(Vector3(0, zocalo + muro, 0), Vector3(w + 0.05, 0.075, d + 0.05), techo)
	# Puerta: una pequeña mancha oscura en una de las caras largas.
	m.box(Vector3(0.0, zocalo, d * 0.5 + 0.002), Vector3(0.04, 0.05, 0.004), U.SOMBRA)
	m.pop()


## Aldea: n casitas sueltas con huertos cercados. grande añade un granero y un cercado común.
static func aldea(m: Malla, seed: int, n: int, grande: bool) -> void:
	var puestos: Array[Vector2] = [
		Vector2(-0.45, -0.42), Vector2(0.38, -0.50), Vector2(0.62, 0.10), Vector2(-0.58, 0.18),
		Vector2(0.05, 0.50), Vector2(-0.10, -0.05), Vector2(0.50, 0.58), Vector2(-0.48, 0.65),
	]
	var usados := 0
	for i in puestos.size():
		if usados >= n:
			break
		var p := puestos[i]
		var rot := 25.0 * (U.rnd(seed, i) - 0.5) + (90.0 if U.rnd(seed, 20 + i) < 0.4 else 0.0)
		var w := 0.26 + 0.07 * U.rnd(seed, 40 + i)
		var d := 0.19 + 0.05 * U.rnd(seed, 60 + i)
		if not U.in_hex(p.x, p.y, 0.22):
			continue
		casa_aldea(m, Vector3(p.x, 0, p.y), w, d, rot, seed + i, U.rnd(seed, 80 + i) < 0.5)
		usados += 1
	if grande:
		# Cercado de estacas y un granero de madera.
		Campo.cercado(m, Vector3(0.0, 0, 0.0), 0.0)
		m.push(Vector3(0.0, 0, 0.05), 0.0)
		m.box(Vector3.ZERO, Vector3(0.22, 0.07, 0.17), U.MADERA_CLARA)
		m.gable(Vector3(0, 0.07, 0), Vector3(0.26, 0.07, 0.2), U.PAJA)
		m.pop()


# ---------------------------------------------------------------------------------------------
# Edificios religiosos

## Mezquita aljama de Córdoba tras la ampliación de Almanzor (H-17): sala de oración de 19 naves
## (aquí 9, simplificado) con tejados a dos aguas y contrafuertes; patio al norte con árboles y
## arcada de herradura (H-21); alminar cuadrado, alto y esbelto (47 m sobre 8,5 m de base).
## El remate del alminar y la posición del alminar en el patio son suposiciones de diseño.
static func mezquita_aljama(m: Malla) -> void:
	var piedra := U.CALIZA
	var naves := 9
	var ancho := 1.62
	var fondo := 0.62
	# Sala de oración al sur (z > 0): el sur es la dirección de la alquibla en Córdoba.
	m.box(Vector3(0, 0, 0.30), Vector3(ancho, 0.15, fondo), piedra)
	for i in naves:
		var x := -ancho * 0.5 + ancho * (float(i) + 0.5) / float(naves)
		m.push(Vector3(x, 0.15, 0.30), 90.0)
		m.gable(Vector3.ZERO, Vector3(fondo + 0.04, 0.075, ancho / float(naves) + 0.005), U.TEJA)
		m.pop()
	# Contrafuertes en el muro sur y en los costados.
	for i in 9:
		var x := -ancho * 0.5 + ancho * float(i) / 8.0
		m.box(Vector3(x, 0, 0.30 + fondo * 0.5 + 0.02), Vector3(0.05, 0.13, 0.05), piedra.darkened(0.04))
	for s in [-1.0, 1.0]:
		for z in [0.10, 0.30, 0.50]:
			m.box(Vector3(s * (ancho * 0.5 + 0.02), 0, z), Vector3(0.05, 0.13, 0.05), piedra.darkened(0.04))
	# Patio al norte: suelo, arcada de herradura en el muro norte y árboles en filas.
	m.box(Vector3(0, 0, -0.34), Vector3(ancho, 0.012, 0.56), U.SUELO_PATIO)
	m.box(Vector3(0, 0, -0.64), Vector3(ancho, 0.11, 0.03), U.SOMBRA)
	var arcos: Array = []
	for i in 9:
		arcos.append({"x": -ancho * 0.5 + ancho * (float(i) + 0.5) / 9.0, "r": 0.034, "y": 0.052, "tipo": "herradura"})
	m.arch_wall(Vector3(0, 0, -0.62), ancho, 0.115, 0.04, arcos, piedra, 6)
	m.box(Vector3(-ancho * 0.5 + 0.015, 0, -0.34), Vector3(0.03, 0.09, 0.56), piedra)
	m.box(Vector3(ancho * 0.5 - 0.015, 0, -0.34), Vector3(0.03, 0.09, 0.56), piedra)
	for fila in 2:
		for i in 6:
			var x := -0.62 + float(i) * 0.248
			Campo.arbolillo(m, Vector3(x, 0.012, -0.26 - 0.20 * float(fila)), 0.05, U.jit(U.VERDE_HUERTA, 0.04, i, fila))
	# Fuente de abluciones en el centro del patio.
	m.cyl(Vector3(0, 0.012, -0.37), 0.06, 0.06, 0.03, 8, piedra)
	m.cyl(Vector3(0, 0.04, -0.37), 0.045, 0.045, 0.006, 8, U.AGUA)
	# Alminar: base cuadrada, cuerpo ligeramente cónico, cuerpo de campanas y remate.
	m.push(Vector3(0, 0, -0.55), 0.0)
	m.box(Vector3.ZERO, Vector3(0.17, 0.95, 0.17), piedra.lightened(0.02), 0.84)
	m.box(Vector3(0, 0.30, 0), Vector3(0.152, 0.015, 0.152), piedra.darkened(0.08), 0.98)
	m.box(Vector3(0, 0.62, 0), Vector3(0.136, 0.015, 0.136), piedra.darkened(0.08), 0.98)
	for y in [0.20, 0.46, 0.78]:
		m.box(Vector3(0, y, 0.0665), Vector3(0.035, 0.07, 0.008), U.SOMBRA)
		m.box(Vector3(0, y, -0.0665), Vector3(0.035, 0.07, 0.008), U.SOMBRA)
	m.box(Vector3(0, 0.95, 0), Vector3(0.115, 0.13, 0.115), piedra)
	m.box(Vector3(0, 1.05, 0.058), Vector3(0.05, 0.05, 0.006), U.SOMBRA)
	m.pyramid(Vector3(0, 1.08, 0), Vector3(0.13, 0.11, 0.13), U.TEJA)
	m.pop()


## Mezquita de barrio: Cristo de la Luz, Toledo, hacia 999–1000 (H-24). Planta cuadrada de nueve
## tramos con una cúpula cada uno, fachada de arcos con ladrillo, sin alminar descrito en la fuente.
static func mezquita_barrio(m: Malla) -> void:
	var lado := 0.70
	var alto := 0.26
	m.push(Vector3(0, 0, -0.04), 0.0)
	m.box(Vector3.ZERO, Vector3(lado, alto, lado - 0.04), U.LADRILLO.lightened(0.04))
	# Nueve cúpulas bajas sobre una terraza.
	for fx in 3:
		for fz in 3:
			var x := (float(fx) - 1.0) * 0.215
			var z := (float(fz) - 1.0) * 0.215
			m.dome(Vector3(x, alto, z), 0.10, 8, 3, U.OCRE.darkened(0.02), 0.8)
	# Fachada de tres arcos de herradura con fondo oscuro.
	var zf := (lado - 0.04) * 0.5
	m.box(Vector3(0, 0.0, zf + 0.002), Vector3(lado - 0.02, alto - 0.02, 0.006), U.SOMBRA)
	var arcos: Array = []
	for x in [-0.20, 0.0, 0.20]:
		arcos.append({"x": x, "r": 0.065, "y": 0.10, "tipo": "herradura"})
	m.arch_wall(Vector3(0, 0, zf + 0.012), lado, alto, 0.026, arcos, U.LADRILLO.lightened(0.12), 6)
	# Arcos ciegos entrecruzados: dos hileras de rectángulos oscuros en los lados.
	for s in [-1.0, 1.0]:
		for z in [-0.20, 0.0, 0.20]:
			m.box(Vector3(s * (lado * 0.5 - 0.02) + s * 0.002, 0.14, z), Vector3(0.006, 0.07, 0.07), U.LADRILLO.darkened(0.2))
	m.pop()


## Iglesia mozárabe de tres naves, cabecera tripartita y pórtico de arcos de herradura, como San
## Miguel de Escalada (913; H-27). Sin torre: la de Escalada es de finales del siglo XI.
## Aplicarla a una iglesia de aldea es una suposición: Escalada es un monasterio rico.
static func iglesia_mozarabe(m: Malla) -> void:
	var piedra := U.PIEDRA_NORTE.lightened(0.05)
	m.push(Vector3(-0.08, 0, 0.0), 0.0)
	# Nave central y naves laterales (más bajas).
	m.box(Vector3.ZERO, Vector3(0.86, 0.13, 0.30), piedra)
	m.gable(Vector3(0, 0.13, 0), Vector3(0.88, 0.13, 0.34), U.TEJA_OSCURA)
	for s in [-1.0, 1.0]:
		m.box(Vector3(0, 0, s * 0.215), Vector3(0.86, 0.085, 0.13), piedra.darkened(0.03))
		m.gable(Vector3(0, 0.085, s * 0.215), Vector3(0.88, 0.05, 0.15), U.TEJA_OSCURA.lightened(0.04))
	# Cabecera tripartita: tres ábsides al este.
	for z in [-0.215, 0.0, 0.215]:
		var grande := absf(z) < 0.01
		m.box(Vector3(0.50, 0, z), Vector3(0.14, 0.13 if grande else 0.085, 0.12 if grande else 0.11), piedra)
		m.pyramid(Vector3(0.50, 0.13 if grande else 0.085, z), Vector3(0.15, 0.06, 0.13 if grande else 0.12), U.TEJA_OSCURA)
	# Pórtico al sur: siete arcos de herradura (H-27) y cubierta inclinada.
	var arcos: Array = []
	for i in 7:
		arcos.append({"x": 0.0, "r": 0.036, "y": 0.052, "tipo": "herradura"})
	m.box(Vector3(0, 0, 0.345), Vector3(0.80, 0.105, 0.03), U.SOMBRA)
	m.arch_wall(Vector3(0, 0, 0.36), 0.80, 0.105, 0.03, _centrar(arcos, 0.80), piedra.lightened(0.04), 6)
	m.gable(Vector3(0, 0.105, 0.31), Vector3(0.82, 0.04, 0.12), U.TEJA_OSCURA.lightened(0.06))
	m.pop()


static func _centrar(arcos: Array, ancho: float) -> Array:
	# Reparte los arcos a lo ancho del pórtico, centrados en x = 0.
	var out: Array = []
	var n := arcos.size()
	for i in n:
		var a: Dictionary = (arcos[i] as Dictionary).duplicate()
		a["x"] = -ancho * 0.5 + ancho * (float(i) + 0.5) / float(n)
		out.append(a)
	return out


# ---------------------------------------------------------------------------------------------
# Palacio

## Alcázar (Córdoba, Toledo) o alcazaba (Zaragoza, con un fortín en cada ángulo: H-23): recinto de sillería
## con torres y puerta de arco de herradura, y dentro un jardín hundido de cuatro partes con agua y un
## pabellón con arcada (inspirado en Madinat al-Zahra, H-21). Es una síntesis, no un plano.
static func alcazar(m: Malla, fortines: bool) -> void:
	var piedra := U.CALIZA
	var ax := 0.80
	var az := 0.56
	var alto := 0.20
	var grosor := 0.07
	# Muros del recinto (el sur tiene la puerta).
	m.box(Vector3(0, 0, -az), Vector3(2.0 * ax, alto, grosor), piedra)
	m.box(Vector3(-ax, 0, 0), Vector3(grosor, alto, 2.0 * az), piedra)
	m.box(Vector3(ax, 0, 0), Vector3(grosor, alto, 2.0 * az), piedra)
	m.box(Vector3(-ax * 0.5 - 0.11, 0, az), Vector3(ax - 0.22, alto, grosor), piedra)
	m.box(Vector3(ax * 0.5 + 0.11, 0, az), Vector3(ax - 0.22, alto, grosor), piedra)
	# Almenas a lo largo de los muros.
	var paso := 0.10
	var n := int(2.0 * ax / paso)
	for i in n:
		var x := -ax + paso * (float(i) + 0.5)
		m.box(Vector3(x, alto, -az), Vector3(0.05, 0.04, grosor), piedra)
		if absf(x) > 0.24:
			m.box(Vector3(x, alto, az), Vector3(0.05, 0.04, grosor), piedra)
	for i in int(2.0 * az / paso):
		var z := -az + paso * (float(i) + 0.5)
		m.box(Vector3(-ax, alto, z), Vector3(grosor, 0.04, 0.05), piedra)
		m.box(Vector3(ax, alto, z), Vector3(grosor, 0.04, 0.05), piedra)
	# Torres: una en cada ángulo (fortines) y dos a mitad de los lados largos.
	var torres: Array[Vector3] = [Vector3(-ax, 0, -az), Vector3(ax, 0, -az), Vector3(-ax, 0, az), Vector3(ax, 0, az)]
	if not fortines:
		torres.append(Vector3(0, 0, -az))
		torres.append(Vector3(-ax, 0, 0))
		torres.append(Vector3(ax, 0, 0))
	for p in torres:
		m.box(p, Vector3(0.20, alto + 0.12, 0.20), piedra.lightened(0.02))
		for dx in [-1.0, 1.0]:
			for dz in [-1.0, 1.0]:
				m.box(p + Vector3(dx * 0.08, alto + 0.12, dz * 0.08), Vector3(0.045, 0.04, 0.045), piedra)
	# Puerta de herradura en el muro sur.
	m.box(Vector3(0, 0, az), Vector3(0.40, alto + 0.07, grosor + 0.04), U.SOMBRA)
	m.arch_wall(Vector3(0, 0, az), 0.40, alto + 0.07, grosor + 0.05, [{"x": 0.0, "r": 0.075, "y": 0.105, "tipo": "herradura"}], piedra.lightened(0.04), 8)
	# Jardín hundido de cuatro partes con canales en cruz y estanque central.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			m.box(Vector3(sx * 0.33, 0, sz * 0.13 + 0.14), Vector3(0.52, 0.018, 0.18), U.jit(U.VERDE_HUERTA, 0.03, int(sx * 3 + sz)))
	m.box(Vector3(0, 0.004, 0.14), Vector3(0.05, 0.026, 0.60), U.AGUA)
	m.box(Vector3(0, 0.004, 0.14), Vector3(1.40, 0.026, 0.04), U.AGUA)
	m.box(Vector3(0, 0.004, 0.14), Vector3(0.16, 0.03, 0.16), U.AGUA)
	for p in [Vector2(-0.55, 0.30), Vector2(0.55, 0.30), Vector2(-0.55, 0.0), Vector2(0.55, 0.0)]:
		Campo.cipres(m, Vector3(p.x, 0.0, p.y), 0.9)
	# Pabellón con arcada de herradura al norte (suposición: tipo «Salón Rico», sin ser una réplica).
	m.box(Vector3(0, 0, -0.34), Vector3(0.80, 0.12, 0.26), U.CAL.darkened(0.04))
	m.pyramid(Vector3(0, 0.12, -0.34), Vector3(0.86, 0.09, 0.32), U.TEJA)
	var arcos: Array = []
	for i in 5:
		arcos.append({"x": -0.32 + 0.64 * float(i) / 4.0, "r": 0.035, "y": 0.05, "tipo": "herradura"})
	m.box(Vector3(0, 0, -0.205), Vector3(0.78, 0.09, 0.01), U.SOMBRA)
	m.arch_wall(Vector3(0, 0, -0.195), 0.80, 0.10, 0.02, arcos, U.CAL, 6)
	for x in [-0.55, 0.55]:
		m.box(Vector3(x, 0, -0.34), Vector3(0.22, 0.10, 0.22), U.CAL.darkened(0.04))
		m.pyramid(Vector3(x, 0.10, -0.34), Vector3(0.26, 0.07, 0.26), U.TEJA)


# ---------------------------------------------------------------------------------------------
# Mercado

## Puestos con toldos de colores alrededor de una plaza con pozo. Los comercios se agrupaban junto a
## puertas y mezquitas (H-23); los toldos y colores son suposición.
static func mercado(m: Malla, seed: int, sur: bool) -> void:
	var n := 6
	for i in n:
		var a := TAU * float(i) / float(n) + 0.3
		var p := Vector3(cos(a), 0, sin(a)) * 0.58
		var rot := rad_to_deg(-a) + 90.0
		m.push(p, rot)
		var toldo: Color = U.TOLDOS[(i + seed) % U.TOLDOS.size()]
		for dx in [-1.0, 1.0]:
			for dz in [-1.0, 1.0]:
				m.box(Vector3(dx * 0.085, 0, dz * 0.065), Vector3(0.012, 0.11, 0.012), U.MADERA)
		m.box(Vector3.ZERO, Vector3(0.16, 0.05, 0.11), U.MADERA_CLARA)
		if sur:
			m.gable(Vector3(0, 0.11, 0), Vector3(0.21, 0.04, 0.16), toldo)
		else:
			m.gable(Vector3(0, 0.11, 0), Vector3(0.21, 0.05, 0.16), U.PAJA)
		var mercancia := U.TOLDOS[(i + seed + 1) % U.TOLDOS.size()]
		m.box(Vector3(-0.04, 0.05, 0), Vector3(0.05, 0.025, 0.05), mercancia)
		m.box(Vector3(0.045, 0.05, 0.005), Vector3(0.04, 0.03, 0.045), mercancia.darkened(0.15))
		m.pop()
	m.cyl(Vector3.ZERO, 0.09, 0.09, 0.05, 8, U.PIEDRA_NORTE)
	m.cyl(Vector3(0, 0.045, 0), 0.065, 0.065, 0.01, 8, U.AGUA)


# ---------------------------------------------------------------------------------------------
# Edificios de la economía del juego (panadería, granero, obra)

## Panadería: casa baja con horno de cúpula y chimenea. Los hornos de pan existían en todas partes; la forma es suposición de diseño.
static func horno(m: Malla, seed: int, sur: bool) -> void:
	var col := U.jit(U.TAPIAL if sur else U.PIEDRA_NORTE, 0.04, seed)
	m.box(Vector3(-0.12, 0, 0.0), Vector3(0.52, 0.12, 0.38), col)
	if sur:
		m.box(Vector3(-0.12, 0.12, 0.0), Vector3(0.52, 0.015, 0.38), col.lightened(0.08))
	else:
		m.gable(Vector3(-0.12, 0.12, 0.0), Vector3(0.58, 0.10, 0.42), U.TEJA_OSCURA)
	m.dome(Vector3(0.34, 0, 0.0), 0.17, 8, 3, U.TIERRA.lightened(0.10), 0.85)
	m.box(Vector3(0.34, 0.12, 0.0), Vector3(0.05, 0.16, 0.05), U.PIEDRA_NORTE.darkened(0.1), 0.8)
	m.box(Vector3(0.12, 0, 0.30), Vector3(0.10, 0.04, 0.07), U.MADERA)   # leña apilada
	m.box(Vector3(-0.22, 0, 0.22), Vector3(0.06, 0.05, 0.002), U.SOMBRA)  # puerta


## Granero: nave alargada de muros gruesos y tejado a dos aguas, con rejillas de ventilación.
static func granero(m: Malla, seed: int, sur: bool) -> void:
	var col := U.jit(U.TAPIAL if sur else U.PIEDRA_NORTE.lightened(0.06), 0.04, seed)
	m.box(Vector3.ZERO, Vector3(0.82, 0.16, 0.42), col)
	m.gable(Vector3(0, 0.16, 0), Vector3(0.88, 0.17, 0.48), U.TEJA if sur else U.PAJA)
	for i in 5:
		m.box(Vector3(-0.30 + 0.15 * float(i), 0.09, 0.212), Vector3(0.035, 0.05, 0.004), U.SOMBRA)
	m.box(Vector3(0.0, 0, 0.214), Vector3(0.12, 0.10, 0.004), U.SOMBRA)     # portón
	for k in 3:
		m.box(Vector3(0.30 + 0.05 * float(k), 0, -0.32), Vector3(0.045, 0.04, 0.045), U.PAJA.darkened(0.1))   # sacos


## Obra en curso: cimientos, postes con travesaños, andamio de madera y materiales a pie de obra.
## Va en la casilla de una obra del juego; no representa ningún edificio concreto.
static func obra(m: Malla, seed: int) -> void:
	m.box(Vector3(0, 0, 0), Vector3(0.62, 0.025, 0.46), U.TIERRA.darkened(0.08))
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			m.box(Vector3(dx * 0.26, 0.02, dz * 0.18), Vector3(0.025, 0.30, 0.025), U.MADERA)
	for y in [0.12, 0.24]:
		m.box(Vector3(0, y, -0.18), Vector3(0.54, 0.02, 0.02), U.MADERA_CLARA)
		m.box(Vector3(0, y, 0.18), Vector3(0.54, 0.02, 0.02), U.MADERA_CLARA)
		m.box(Vector3(-0.26, y, 0), Vector3(0.02, 0.02, 0.34), U.MADERA_CLARA)
		m.box(Vector3(0.26, y, 0), Vector3(0.02, 0.02, 0.34), U.MADERA_CLARA)
	m.box(Vector3(-0.15, 0.02, -0.12), Vector3(0.30, 0.07, 0.04), U.TAPIAL)   # tramo de muro a medio levantar
	for k in 3:
		m.box(Vector3(0.40, 0.02 + 0.045 * float(k), 0.28), Vector3(0.26, 0.04, 0.05), U.CALIZA.darkened(0.05 * float(k)))
	m.box(Vector3(-0.42, 0.02, 0.30), Vector3(0.22, 0.04, 0.12), U.MADERA_CLARA)


## Almazara: casa baja con la muela de piedra al lado, la viga de la prensa y tinajas de aceite.
static func almazara(m: Malla, seed: int, sur: bool) -> void:
	var col := U.jit(U.TAPIAL if sur else U.PIEDRA_NORTE, 0.04, seed)
	m.box(Vector3(-0.15, 0, -0.05), Vector3(0.56, 0.12, 0.40), col)
	m.gable(Vector3(-0.15, 0.12, -0.05), Vector3(0.62, 0.10, 0.44), U.TEJA if sur else U.TEJA_OSCURA)
	m.box(Vector3(-0.30, 0, 0.16), Vector3(0.07, 0.07, 0.003), U.SOMBRA)
	# Muela: rueda de piedra de canto sobre una pila.
	m.cyl(Vector3(0.36, 0, 0.04), 0.17, 0.17, 0.035, 10, U.PIEDRA_NORTE)
	m.push(Vector3(0.36, 0.075, 0.04), 0.0, 0.0, 90.0)
	m.cyl(Vector3(0, -0.02, 0), 0.075, 0.075, 0.05, 10, U.CALIZA.darkened(0.08))
	m.pop()
	m.box(Vector3(0.36, 0.04, 0.04), Vector3(0.012, 0.07, 0.012), U.MADERA)
	# Viga de la prensa.
	m.box(Vector3(0.12, 0.13, 0.26), Vector3(0.30, 0.025, 0.025), U.MADERA)
	m.box(Vector3(0.24, 0, 0.26), Vector3(0.03, 0.13, 0.03), U.MADERA)
	# Tinajas.
	for k in 4:
		var px := -0.36 + 0.09 * float(k)
		m.cyl(Vector3(px, 0, 0.30), 0.036, 0.03, 0.07, 6, U.LADRILLO.lightened(0.05))
		m.blob(Vector3(px, 0.07, 0.30), 0.032, 6, 3, U.LADRILLO.lightened(0.10), 0.5)


## Telar: casa abierta por un lado con el bastidor vertical del telar y paños tendidos de colores.
static func telar(m: Malla, seed: int, sur: bool) -> void:
	var col := U.jit(U.TAPIAL if sur else U.PIEDRA_NORTE.lightened(0.04), 0.04, seed)
	m.box(Vector3(-0.15, 0, -0.12), Vector3(0.58, 0.12, 0.26), col)
	m.gable(Vector3(-0.15, 0.12, -0.12), Vector3(0.64, 0.10, 0.30), U.TEJA if sur else U.PAJA)
	# Bastidor del telar.
	for dx in [-1.0, 1.0]:
		m.box(Vector3(0.30 + dx * 0.07, 0, 0.16), Vector3(0.018, 0.18, 0.018), U.MADERA)
	m.box(Vector3(0.30, 0.17, 0.16), Vector3(0.17, 0.018, 0.018), U.MADERA)
	m.box(Vector3(0.30, 0.05, 0.16), Vector3(0.13, 0.11, 0.004), U.TOLDOS[seed % U.TOLDOS.size()])
	# Tendedero con paños.
	for dx in [-1.0, 1.0]:
		m.box(Vector3(-0.30 + dx * 0.22, 0, 0.26), Vector3(0.014, 0.13, 0.014), U.MADERA)
	m.box(Vector3(-0.30, 0.12, 0.26), Vector3(0.46, 0.010, 0.010), U.MADERA_CLARA)
	for k in 4:
		m.box(Vector3(-0.46 + 0.10 * float(k), 0.045, 0.262), Vector3(0.075, 0.075, 0.004), U.TOLDOS[(seed + k) % U.TOLDOS.size()])

