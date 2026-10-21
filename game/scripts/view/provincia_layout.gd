extends RefCounted
## Reparto de la vista 3D de una provincia: qué va en cada casilla según lo que hay construido.
##
## Es lógica pura (sin nodos): dado el aspecto de la provincia, sus edificios, sus obras y su población,
## devuelve las casillas para `Diorama.layers_from_cells`. La vista (province_view.gd) solo dibuja.
##
## Cada región tiene una PLANTILLA: el paisaje fijo (muralla, río, puente, colinas, bosques, huertas,
## monumentos) y, por cada tipo de edificio del juego, una lista ordenada de HUECOS. El primer edificio
## ocupa el primer hueco, el segundo el segundo, etc.; una obra en curso se dibuja como obra en el
## siguiente hueco libre de su tipo, de modo que al terminar el edificio aparece donde estaba la obra.
## Los huecos libres se quedan como terreno vacío: así se ve lo que falta por construir.
##
## HONESTIDAD: las plantillas son esquemas de juego, no planos históricos. Toledo y Zaragoza comparten
## el esquema de Córdoba (ciudad amurallada junto a un río con puente) y se distinguen por el estilo
## (ver ciudad_epoca.gd, REGIONES); Castilla y León comparten el del norte. Los monumentos de cada
## provincia (aljama, alcázar…) forman parte de la plantilla y no dependen de lo construido.

const RADIO := 4

## Aspecto de cada provincia del mapa (map.json). Las pruebas exigen que toda provincia tenga uno.
const ASPECTOS := {
	"cordoba": "cordoba",
	"toledo": "toledo",
	"zaragoza": "zaragoza",
	"castilla": "norte",
	"leon": "norte",
}

## Qué ocupa cada tipo de edificio del juego (buildings.json). La vivienda no tiene hueco propio:
## su efecto es añadir una manzana al caserío (ver `manzanas`).
const HUECO_DE := {
	"house": "vivienda",
	"granary": "granero",
	"farm": "granja",
	"mill": "molino",
	"bakery": "panaderia",
	"woodcutter": "lenador",
	"olive_grove": "olivar",
	"olive_press": "almazara",
	"sheepfold": "aprisco",
	"loom": "telar",
	"market": "mercado",
	"mine": "mina",
	"smithy": "herreria",
	"barracks": "cuartel",
}

## Habitantes que representa cada manzana del caserío (parámetro de aspecto, no de simulación).
const HABITANTES_POR_MANZANA := 30
## Habitantes que representa cada aldeano que se ve caminando (parámetro de aspecto) y tope.
const HABITANTES_POR_CAMINANTE := 12
const MAX_CAMINANTES := 16
## Soldados que representa cada figura de guardia junto al cuartel (parámetro de aspecto) y tope.
const SOLDADOS_POR_FIGURA := 5
const MAX_GUARDIAS := 8


## Aspecto («cordoba», «toledo», «zaragoza» o «norte») de una provincia; vacío si no se conoce.
static func aspecto_de(province_id: String) -> String:
	return ASPECTOS.get(province_id, "")


## Plantilla de un aspecto: «sur» para cordoba, toledo y zaragoza; «norte» para el norte.
static func plantilla(aspecto: String) -> Dictionary:
	return _norte() if aspecto == "norte" else _sur()


## Manzanas de casas que se dibujan: una por cada HABITANTES_POR_MANZANA habitantes más una por cada
## vivienda terminada, con un mínimo de una y sin pasar de los huecos de la plantilla.
static func manzanas(poblacion: int, viviendas: int, huecos: int) -> int:
	return clampi(maxi(poblacion, 0) / HABITANTES_POR_MANZANA + maxi(viviendas, 0), 1, huecos)


## Casillas de la provincia.
##   aspecto: ver ASPECTOS; buildings: [{type}]; projects: [{type}]; population: habitantes.
## Devuelve {"cells": {Vector2i: {...}}, "radio", "foco": Vector3, "ocultos": {tipo: n}}.
## «ocultos» cuenta edificios u obras que no caben en la plantilla (siguen existiendo en el juego,
## solo que no se dibujan).
static func plan(aspecto: String, buildings: Array, projects: Array, population: int, soldados: int = 0) -> Dictionary:
	var t := plantilla(aspecto)
	var cells: Dictionary = (t["base"] as Dictionary).duplicate(true)
	var huecos: Dictionary = t["huecos"]
	var ocultos := {}
	var visibles := {}      # tipo de hueco -> cuántos edificios terminados se dibujan
	var celdas_obra: Array = []

	var hechos := {}
	for b in buildings:
		var tipo: String = b["type"]
		hechos[tipo] = int(hechos.get(tipo, 0)) + 1
	var obras := {}
	for p in projects:
		var tipo: String = p["type"]
		obras[tipo] = int(obras.get(tipo, 0)) + 1

	for tipo in HUECO_DE.keys():
		var lista: Array = huecos[HUECO_DE[tipo]]
		var terminados := int(hechos.get(tipo, 0))
		var mostrados := terminados
		if tipo == "house":
			mostrados = manzanas(population, terminados, lista.size())
		var en_obra := int(obras.get(tipo, 0))
		var libres := lista.size()
		for i in range(mostrados):
			if i < libres:
				cells[lista[i][0]] = {"o": lista[i][1]}
		if mostrados > libres:
			ocultos[tipo] = mostrados - libres
		visibles[HUECO_DE[tipo]] = mini(mostrados, libres)
		for k in range(en_obra):
			var idx := mostrados + k
			if idx < libres:
				cells[lista[idx][0]] = {"o": "S"}
				celdas_obra.append(lista[idx][0])
			else:
				ocultos[tipo] = int(ocultos.get(tipo, 0)) + 1
	var cuartel_cell = null
	if int(visibles.get("cuartel", 0)) > 0:
		cuartel_cell = huecos["cuartel"][0][0]
	var horno_cells: Array = []
	var hornos: Array = huecos["panaderia"]
	for i in range(int(visibles.get("panaderia", 0))):
		horno_cells.append(hornos[i][0])
	return {
		"cells": cells, "radio": RADIO, "foco": t["foco"], "ocultos": ocultos,
		"gente": gente(t, visibles, celdas_obra, horno_cells, population, soldados, cuartel_cell),
	}


## Quién se ve moviéndose por la provincia (lógica pura; la vista solo lo dibuja):
##   rutas: caminos de ida y vuelta (puntos [q, r] o [q, r, borde, fracción]) cuyos requisitos se cumplen,
##   caminantes: cuántos aldeanos las recorren, obras: casillas con obra (llevan obreros),
##   humos: casillas con horno encendido, mercado: casilla del mercado y cuántas personas hay en él.
static func gente(t: Dictionary, visibles: Dictionary, celdas_obra: Array, horno_cells: Array, poblacion: int, soldados: int = 0, cuartel = null) -> Dictionary:
	var rutas: Array = []
	for r in t["rutas"]:
		var req = r["req"]
		if req == null or int(visibles.get(req[0], 0)) > int(req[1]):
			rutas.append(r["pts"])
	return {
		"rutas": rutas,
		"caminantes": clampi(maxi(poblacion, 0) / HABITANTES_POR_CAMINANTE, 2, MAX_CAMINANTES),
		"obras": celdas_obra,
		"humos": horno_cells,
		"mercado": t["mercado"],
		"gente_mercado": t["gente_mercado"],
		# Sin cuartel dibujado no hay guardias a la vista (los soldados siguen existiendo en el juego).
		"guardias": 0 if cuartel == null else clampi(ceili(float(maxi(soldados, 0)) / float(SOLDADOS_POR_FIGURA)), 0, MAX_GUARDIAS),
		"cuartel": cuartel if cuartel != null else Vector2i(0, 0),
	}


## Firma estable de lo que se dibuja: si no cambia, no hace falta reconstruir la escena 3D.
static func firma(aspecto: String, resultado: Dictionary) -> String:
	return "%s:%d" % [aspecto, (resultado["cells"] as Dictionary).hash()]


## Firma de la gente (rutas, aldeanos, obreros, humos): si cambia solo esto, no hace falta reconstruir el suelo.
static func firma_gente(resultado: Dictionary) -> String:
	return str((resultado["gente"] as Dictionary).hash())


# ---------------------------------------------------------------------------------------------
# Plantillas

static func _ring(cq: int, cr: int, d: int) -> Array:
	var out: Array = []
	for q in range(-RADIO, RADIO + 1):
		for r in range(-RADIO, RADIO + 1):
			if maxi(maxi(absi(q), absi(r)), absi(q + r)) > RADIO:
				continue
			var dq := q - cq
			var dr := r - cr
			if (absi(dq) + absi(dr) + absi(dq + dr)) / 2 == d:
				out.append(Vector2i(q, r))
	return out


static func _huecos(lista: Array) -> Array:
	var out: Array = []
	for e in lista:
		out.append([Vector2i(e[0], e[1]), e[2]])
	return out


## Ciudad amurallada (la muralla rodea a (-1,-1)) junto a un río que corre de noreste a suroeste,
## con la puerta frente al puente, mercado, mezquita y alcázar dentro de las murallas.
static func _sur() -> Dictionary:
	var c := {}
	for cell in _ring(-1, -1, 2):
		c[cell] = {"p": "m"}
	c[Vector2i(0, 0)] = {"p": "g"}
	# Monumentos.
	c[Vector2i(0, -2)] = {"o": "E"}
	c[Vector2i(-2, 0)] = {"o": "C"}
	c[Vector2i(-1, 0)] = {"o": "Y"}
	# Río, puente y camino.
	c[Vector2i(4, -3)] = {"p": "R"}
	for cell in [Vector2i(3, -2), Vector2i(2, -1), Vector2i(1, 0), Vector2i(-1, 2), Vector2i(-2, 3)]:
		c[cell] = {"p": "r"}
	c[Vector2i(-3, 4)] = {"p": "R"}
	c[Vector2i(0, 1)] = {"p": "b"}
	c[Vector2i(0, 2)] = {"p": "c"}
	c[Vector2i(0, 3)] = {"p": "c"}
	c[Vector2i(0, 4)] = {"p": "C"}
	# Paisaje fijo: huertas y noria, olivares, bosque y sierra.
	c[Vector2i(3, -1)] = {"o": "a"}
	c[Vector2i(-2, 4)] = {"o": "a"}
	c[Vector2i(-1, 3)] = {"o": "A"}
	for cell in [Vector2i(1, 3), Vector2i(-1, 4), Vector2i(-4, 3)]:
		c[cell] = {"o": "i"}
	c[Vector2i(-4, 0)] = {"o": "T"}
	c[Vector2i(4, -4)] = {"o": "H"}
	c[Vector2i(3, -4)] = {"o": "M"}
	c[Vector2i(2, -4)] = {"o": "N"}
	c[Vector2i(1, -4)] = {"o": "M"}
	c[Vector2i(0, -4)] = {"o": "h"}
	var huecos := {
		"vivienda": _huecos([
			[-1, -1, "O"], [0, -1, "O"], [-2, -1, "O"], [-1, -2, "o"],
			[2, -2, "O"], [-2, 2, "O"], [2, -3, "o"], [-3, 2, "o"], [-4, 2, "o"],
		]),
		"granero": _huecos([[-4, 1, "g"], [-4, 4, "g"]]),
		"granja": _huecos([[2, 1, "F"], [3, 1, "F"], [4, 0, "F"], [3, 0, "F"], [4, -1, "F"], [1, 2, "F"]]),
		"molino": _huecos([[1, 1, "V"], [2, 0, "V"]]),
		"panaderia": _huecos([[-3, 3, "p"], [3, -3, "p"]]),
		"lenador": _huecos([[4, -2, "L"], [2, 2, "L"]]),
		"olivar": _huecos([[-4, 0, "i"], [0, -4, "i"]]),
		"almazara": _huecos([[-4, 3, "B"]]),
		"aprisco": _huecos([[-2, 4, "q"], [-1, 4, "q"]]),
		"telar": _huecos([[1, 3, "e"]]),
		"mercado": _huecos([[3, -1, "E"]]),
		"mina": _huecos([[1, -4, "n"], [3, -4, "n"]]),
		"herreria": _huecos([[2, -4, "Z"], [4, -4, "Z"]]),
		"cuartel": _huecos([[-1, 3, "u"]]),
	}
	var rutas := [
		# Camino de la puerta al puente y por la calzada hasta el fondo.
		{"req": null, "pts": [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]]},
		# Huertas y olivares junto a la calzada.
		{"req": null, "pts": [[0, 3], [-1, 3], [-2, 4]]},
		{"req": null, "pts": [[0, 4], [1, 3]]},
		# Del puente a los campos de cereal.
		{"req": ["granja", 0], "pts": [[0, 2], [1, 2], [2, 1], [3, 1], [3, 0]]},
		# Al molino de la orilla.
		{"req": ["molino", 0], "pts": [[0, 2], [1, 1, 3, 0.45]]},
		# Al aserradero.
		{"req": ["lenador", 1], "pts": [[1, 2], [2, 2, 3, 0.5]]},
		# Al arrabal del oeste.
		{"req": null, "pts": [[0, 0], [-1, 1], [-1, 1, 3, 0.6]]},
	]
	return {"base": c, "huecos": huecos, "foco": Vector3(0.0, 0.5, 0.5), "rutas": rutas,
		"mercado": Vector2i(0, -2), "gente_mercado": 3}


## Aldea cristiana con iglesia y feria, un arroyo, campos, bosque y un castro en el cerro.
static func _norte() -> Dictionary:
	var c := {}
	c[Vector2i(-1, 0)] = {"o": "Y"}
	c[Vector2i(1, -1)] = {"o": "E"}
	# Arroyo que baja del cerro.
	c[Vector2i(3, -4)] = {"p": "R"}
	for cell in [Vector2i(2, -3), Vector2i(2, -2), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(1, 3)]:
		c[cell] = {"p": "r"}
	c[Vector2i(0, 4)] = {"p": "R"}
	# Castro en el cerro.
	c[Vector2i(-1, -3)] = {"t": "2", "o": "C"}
	c[Vector2i(-2, -2)] = {"t": "1", "o": "h"}
	c[Vector2i(0, -3)] = {"t": "1", "o": "t"}
	c[Vector2i(-1, -2)] = {"t": "1", "o": "T"}
	c[Vector2i(-2, -1)] = {"o": "t"}
	# Bosques y matorral.
	for cell in [Vector2i(3, -1), Vector2i(3, -2), Vector2i(4, -2), Vector2i(4, -3), Vector2i(3, -3), Vector2i(4, -1), Vector2i(4, 0), Vector2i(-3, 0), Vector2i(-4, 1), Vector2i(-4, 2), Vector2i(-3, -1), Vector2i(-4, 3), Vector2i(4, -4), Vector2i(-4, 4)]:
		c[cell] = {"o": "T"}
	c[Vector2i(-3, 1)] = {"o": "t"}
	c[Vector2i(2, -4)] = {"o": "h"}
	for cell in [Vector2i(-2, 4), Vector2i(-3, 4)]:
		c[cell] = {"o": "F"}
	var huecos := {
		"vivienda": _huecos([
			[0, 0, "O"], [0, 1, "O"], [1, 0, "o"], [-1, 1, "o"], [0, -1, "o"],
			[-1, -1, "o"], [0, -2, "o"], [1, -2, "o"], [-2, 0, "o"],
		]),
		"granero": _huecos([[1, -4, "g"], [-1, 4, "g"]]),
		"granja": _huecos([
			[-2, 1, "F"], [-2, 2, "F"], [-1, 2, "F"], [0, 2, "F"], [-3, 2, "F"],
			[-3, 3, "F"], [0, 3, "F"], [-1, 3, "F"], [-2, 3, "F"],
		]),
		"molino": _huecos([[3, 0, "V"], [1, 1, "V"]]),
		"panaderia": _huecos([[1, -3, "p"], [0, -4, "p"]]),
		"lenador": _huecos([[2, 2, "L"], [3, 1, "L"]]),
		"olivar": _huecos([[-3, 0, "a"], [-4, 1, "a"]]),
		"almazara": _huecos([[-4, 2, "B"]]),
		"aprisco": _huecos([[-3, -1, "q"], [-4, 3, "q"]]),
		"telar": _huecos([[-3, 1, "e"]]),
		"mercado": _huecos([[3, -3, "E"]]),
		"mina": _huecos([[2, -4, "n"], [4, -4, "n"]]),
		"herreria": _huecos([[4, -2, "Z"], [4, -3, "Z"]]),
		"cuartel": _huecos([[3, -1, "u"], [4, -1, "u"]]),
	}
	var rutas := [
		# Vuelta por los campos de cereal.
		{"req": null, "pts": [[0, 1, 5, 0.8], [0, 2], [-1, 2], [-2, 2], [-2, 1]]},
		{"req": null, "pts": [[-1, 1, 4, 0.8], [-1, 2, 3, 0.2], [-2, 3]]},
		# De la aldea al molino del arroyo.
		{"req": ["molino", 1], "pts": [[0, 1, 0, 0.8], [1, 1, 3, 0.45]]},
		# De las casas a la feria.
		{"req": null, "pts": [[0, 0, 1, 0.85], [1, -1, 4, 0.65]]},
	]
	return {"base": c, "huecos": huecos, "foco": Vector3(0.0, 0.5, 0.5), "rutas": rutas,
		"mercado": Vector2i(1, -1), "gente_mercado": 2}
