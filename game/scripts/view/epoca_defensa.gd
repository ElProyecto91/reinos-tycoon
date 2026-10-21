extends RefCounted
## Murallas, torres, puertas, puente y castro hacia el año 1000.
## Estilos de muralla (ver docs/REGION_IBERIA_1000.md):
##   "sillería": piedra clara con torres semicirculares (Córdoba; H-20, muralla romana: no se sabe si seguía en uso)
##   "tapial":   tierra, adobe y ladrillo con torres cuadradas (Zaragoza; H-23 da el material, no la forma de las torres)
##   "piedra":   mampostería con torres cuadradas (Toledo; sin fuente en esta fecha: suposición)
##   "tierra":   terraplén con empalizada y torres de madera sobre base de piedra (norte; H-26 habla de «muralias de tierra y piedra, terraplenes y fosos»)

const Malla = preload("res://scripts/view/malla.gd")
const U = preload("res://scripts/view/epoca_util.gd")
const Campo = preload("res://scripts/view/epoca_campo.gd")

const ESTILOS := ["sillería", "tapial", "piedra", "tierra"]
const ALTO := 0.30


static func color_muro(estilo: String) -> Color:
	match estilo:
		"tapial":
			return U.TAPIAL.darkened(0.02)
		"piedra":
			return Color(0.76, 0.70, 0.58)
		"tierra":
			return U.TIERRA
		_:
			return U.CALIZA


# ---------------------------------------------------------------------------------------------
# Murallas

## Tramo de muralla desde el centro de la casilla hasta el borde e (longitud algo mayor que 1,0
## para que los tramos vecinos se solapen).
static func muro_brazo(m: Malla, e: int, estilo: String) -> void:
	m.push(Vector3.ZERO, 60.0 * float(e))
	var col := color_muro(estilo)
	if estilo == "tierra":
		# Terraplén de sección trapezoidal con empalizada encima.
		m.push(Vector3(0.5, 0, 0), 90.0)
		var perfil := PackedVector2Array([Vector2(-0.21, 0.0), Vector2(0.21, 0.0), Vector2(0.09, 0.15), Vector2(-0.09, 0.15)])
		m.extrude(Vector3.ZERO, perfil, 1.04, col)
		m.pop()
		for i in 14:
			var x := 0.04 + 0.072 * float(i)
			m.box(Vector3(x, 0.15, 0), Vector3(0.026, 0.13, 0.026), U.MADERA)
			m.pyramid(Vector3(x, 0.28, 0), Vector3(0.034, 0.04, 0.034), U.MADERA)
	else:
		m.box(Vector3(0.5, 0, 0), Vector3(1.04, ALTO, 0.16), col)
		for i in 10:
			var x := 0.06 + 0.10 * float(i)
			m.box(Vector3(x, ALTO, 0), Vector3(0.055, 0.05, 0.16), col.darkened(0.02))
	m.pop()


## Torre en `pos`. `hacia_fuera` es la dirección (en el plano) hacia el exterior de la ciudad.
static func torre(m: Malla, pos: Vector3, estilo: String, hacia_fuera: Vector3) -> void:
	var fuera := Vector3(hacia_fuera.x, 0, hacia_fuera.z)
	if fuera.length() > 0.001:
		fuera = fuera.normalized()
	var col := color_muro(estilo)
	var h := ALTO + 0.10
	match estilo:
		"sillería":
			# Torre semicircular: un cilindro adelantado hacia fuera, de modo que mitad sobresale del lienzo.
			var c := pos + fuera * 0.07
			m.cyl(c, 0.17, 0.17, h, 8, col.lightened(0.02))
			for i in 8:
				var a := TAU * float(i) / 8.0
				m.box(c + Vector3(cos(a), 0, sin(a)) * 0.145 + Vector3(0, h, 0), Vector3(0.05, 0.045, 0.05), col)
		"tierra":
			var c2 := pos + fuera * 0.03
			m.box(c2, Vector3(0.27, 0.20, 0.27), U.PIEDRA_NORTE)
			m.box(c2 + Vector3(0, 0.20, 0), Vector3(0.32, 0.09, 0.32), U.MADERA, 0.96)
			m.pyramid(c2 + Vector3(0, 0.29, 0), Vector3(0.36, 0.13, 0.36), U.MADERA.darkened(0.12))
		_:
			var c3 := pos + fuera * 0.05
			m.box(c3, Vector3(0.30, h, 0.30), col.lightened(0.02))
			for dx in [-1.0, 1.0]:
				for dz in [-1.0, 1.0]:
					m.box(c3 + Vector3(dx * 0.115, h, dz * 0.115), Vector3(0.06, 0.045, 0.06), col)
			m.box(c3 + Vector3(0, h, 0), Vector3(0.20, 0.02, 0.20), col.darkened(0.12))


## Puerta que atraviesa el tramo recto que une los bordes e0 y e0+3: bloque con arco de herradura
## (H-21) y dos torrecillas. En el norte, un portón de madera entre postes.
static func puerta(m: Malla, e0: int, estilo: String) -> void:
	m.push(Vector3.ZERO, 60.0 * float(e0))
	var col := color_muro(estilo)
	if estilo == "tierra":
		m.arch_wall(Vector3.ZERO, 0.62, 0.40, 0.18, [{"x": 0.0, "r": 0.11, "y": 0.13, "tipo": "medio_punto"}], U.MADERA_CLARA, 6)
		for dx in [-1.0, 1.0]:
			m.box(Vector3(dx * 0.33, 0, 0), Vector3(0.07, 0.46, 0.07), U.MADERA)
			m.pyramid(Vector3(dx * 0.33, 0.46, 0), Vector3(0.09, 0.08, 0.09), U.MADERA.darkened(0.1))
	else:
		m.arch_wall(Vector3.ZERO, 0.66, 0.46, 0.26, [{"x": 0.0, "r": 0.115, "y": 0.18, "tipo": "herradura"}], col.lightened(0.03), 8)
		for i in 5:
			var x := -0.26 + 0.13 * float(i)
			m.box(Vector3(x, 0.46, 0), Vector3(0.06, 0.05, 0.26), col)
		for dx in [-1.0, 1.0]:
			m.box(Vector3(dx * 0.42, 0, 0), Vector3(0.20, 0.50, 0.26), col.lightened(0.02))
			for sx in [-1.0, 1.0]:
				m.box(Vector3(dx * 0.42 + sx * 0.07, 0.50, 0), Vector3(0.05, 0.04, 0.26), col)
	m.pop()


## Casilla de muralla completa. mask: bordes por los que el muro sale; puerta: si es una puerta.
static func casilla_muralla(m: Malla, mask: Array, estilo: String, puerta_ahi: bool, hacia_fuera: Vector3, torres: bool) -> void:
	for e in mask:
		muro_brazo(m, int(e), estilo)
	var recto := mask.size() == 2 and int(mask[1]) - int(mask[0]) == 3
	if puerta_ahi and recto:
		puerta(m, int(mask[0]), estilo)
		return
	if recto:
		# Tramo recto: una torre en la cara exterior (las murallas llevaban torres a intervalos).
		if torres:
			torre(m, Vector3.ZERO, estilo, hacia_fuera)
		return
	# Esquina, extremo o cruce: torre en el centro.
	if torres:
		torre(m, Vector3.ZERO, estilo, hacia_fuera * 0.9)


# ---------------------------------------------------------------------------------------------
# Puente

## Puente de arcos de medio punto sobre un río (el romano de Córdoba tenía 16 arcos tras la
## reconstrucción islámica y ~9 m de ancho; H-18). Aquí cinco arcos: se simplifica. `rot_deg` gira el puente.
static func puente(m: Malla, rot_deg: float) -> void:
	m.push(Vector3.ZERO, rot_deg)
	var largo := 1.90
	var base_y := -0.22
	var alto := 0.54          # la calzada queda en y = 0,32
	var arcos: Array = []
	for i in 5:
		arcos.append({"x": -0.76 + 0.38 * float(i), "r": 0.15, "y": 0.20, "tipo": "medio_punto"})
	m.arch_wall(Vector3(0, base_y, 0), largo, alto, 0.30, arcos, U.CALIZA.darkened(0.03), 8)
	for dz in [-1.0, 1.0]:
		m.box(Vector3(0, base_y + alto, dz * 0.13), Vector3(largo, 0.06, 0.05), U.CALIZA)
	# Tajamares (puntas de los pilares contra la corriente).
	for i in 4:
		var x := -0.57 + 0.38 * float(i)
		m.box(Vector3(x, base_y, 0.17), Vector3(0.07, 0.30, 0.08), U.CALIZA.darkened(0.06), 0.6)
		m.box(Vector3(x, base_y, -0.17), Vector3(0.07, 0.30, 0.08), U.CALIZA.darkened(0.06), 0.6)
	m.pop()


# ---------------------------------------------------------------------------------------------
# Castro del norte

## Castro: cerro con foso, terraplén y empalizada, una torre de piedra con piso de madera y cabañas
## dentro. H-26 solo dice «muralias de tierra y piedra, terraplenes y fosos» y que las torres eran
## centros de dominio: la torre y las cabañas son suposición de diseño.
static func castro(m: Malla) -> void:
	# Foso (anillo oscuro más bajo) y montículo.
	m.cyl(Vector3.ZERO, 0.92, 0.92, 0.012, 14, U.TIERRA.darkened(0.30))
	m.cyl(Vector3(0, 0.0, 0), 0.74, 0.60, 0.17, 14, U.TIERRA)
	# Empalizada de estacas en el borde del montículo.
	var n := 28
	for i in n:
		var a := TAU * float(i) / float(n)
		var p := Vector3(cos(a), 0, sin(a)) * 0.58
		m.box(p + Vector3(0, 0.17, 0), Vector3(0.028, 0.15, 0.028), U.MADERA)
		m.pyramid(p + Vector3(0, 0.32, 0), Vector3(0.036, 0.04, 0.036), U.MADERA)
	# Torre.
	m.box(Vector3(-0.12, 0.17, -0.05), Vector3(0.28, 0.24, 0.28), U.PIEDRA_NORTE)
	m.box(Vector3(-0.12, 0.41, -0.05), Vector3(0.34, 0.10, 0.34), U.MADERA, 0.97)
	m.pyramid(Vector3(-0.12, 0.51, -0.05), Vector3(0.38, 0.15, 0.38), U.MADERA.darkened(0.15))
	# Cabañas.
	for p in [Vector2(0.28, 0.12), Vector2(0.15, -0.30), Vector2(-0.30, 0.30)]:
		m.push(Vector3(p.x, 0.17, p.y), 20.0 * (p.x + 1.0))
		m.box(Vector3.ZERO, Vector3(0.2, 0.05, 0.14), U.TAPIAL)
		m.gable(Vector3(0, 0.05, 0), Vector3(0.23, 0.07, 0.17), U.PAJA)
		m.pop()
