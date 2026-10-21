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
}

## Habitantes que representa cada manzana del caserío (parámetro de aspecto, no de simulación).
const HABITANTES_POR_MANZANA := 30


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
static func plan(aspecto: String, buildings: Array, projects: Array, population: int) -> Dictionary:
	var t := plantilla(aspecto)
	var cells: Dictionary = (t["base"] as Dictionary).duplicate(true)
	var huecos: Dictionary = t["huecos"]
	var ocultos := {}

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
		for k in range(en_obra):
			var idx := mostrados + k
			if idx < libres:
				cells[lista[idx][0]] = {"o": "S"}
			else:
				ocultos[tipo] = int(ocultos.get(tipo, 0)) + 1
	return {"cells": cells, "radio": RADIO, "foco": t["foco"], "ocultos": ocultos}


## Firma estable de lo que se dibuja: si no cambia, no hace falta reconstruir la escena 3D.
static func firma(aspecto: String, resultado: Dictionary) -> String:
	return "%s:%d" % [aspecto, (resultado["cells"] as Dictionary).hash()]


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
	}
	return {"base": c, "huecos": huecos, "foco": Vector3(0.0, 0.5, 0.5)}


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
	}
	return {"base": c, "huecos": huecos, "foco": Vector3(0.0, 0.5, 0.5)}
