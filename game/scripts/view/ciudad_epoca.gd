extends "res://scripts/view/diorama.gd"
## Diorama «de época»: el mismo suelo hexagonal (relieve, río, camino, costa) que diorama.gd, pero con
## edificios, murallas, puente, árboles y campos generados por código y pensados para la Península
## Ibérica hacia el año 1000 (ver docs/REGION_IBERIA_1000.md, sección «Aspecto urbano y arquitectónico»,
## y docs/HISTORICAL_SOURCES.md, fuentes H-17 a H-27).
##
## La región elige el estilo: casas de patio o de aldea, tipo de muralla, mezquita o iglesia, paleta del suelo.
## Los símbolos son los de diorama.gd; aquí cambian de significado con la región:
##   o, O    casas (manzana de patios en el sur; aldea en el norte)
##   Y       mezquita (aljama en Córdoba, de barrio en Toledo y Zaragoza) o iglesia mozárabe (norte)
##   C       alcázar / alcazaba (sur) o castro (norte)
##   m, g    muralla y puerta (el estilo depende de la región); b = puente de arcos
##   T t s   bosque grande, mediano y pequeño; F cereal de secano; a huerta; A huerta con noria; i olivar
##   W       noria con huerta (sur) o cereal (norte): no hay molinos de viento (sin fuente)
##   V       molino de agua (junto al río); L aserradero; Z herrería; E mercado
##   p g S   panadería (horno), granero y obra en curso
##   h H M N Q colinas y montes propios (matorral y roca)
## Lo demás (minas, andamios, utensilios) sigue siendo de KayKit.

const Malla = preload("res://scripts/view/malla.gd")
const U = preload("res://scripts/view/epoca_util.gd")
const Urbano = preload("res://scripts/view/epoca_urbano.gd")
const Campo = preload("res://scripts/view/epoca_campo.gd")
const Defensa = preload("res://scripts/view/epoca_defensa.gd")

const PALETA_SECA := "res://assets/kaykit/models/hexagons_seco.png"
const PALETA_NORTE := "res://assets/kaykit/models/hexagons_norte.png"

## Datos por región. `seco`: paleta de tierra seca. Todo lo demás se explica en REGION_IBERIA_1000.md.
const REGIONES := {
	"cordoba": {"seco": true, "muro": "sillería", "casas": "patio", "color_casa": Color(0.84, 0.72, 0.52), "mezquita": "aljama", "palacio": "alcazar", "suelo": Color(0.74, 0.64, 0.48), "arboles": "mixto"},
	"toledo": {"seco": true, "muro": "piedra", "casas": "patio", "color_casa": Color(0.82, 0.70, 0.52), "mezquita": "barrio", "palacio": "alcazar", "suelo": Color(0.72, 0.62, 0.48), "arboles": "mixto"},
	"zaragoza": {"seco": true, "muro": "tapial", "casas": "patio", "color_casa": Color(0.93, 0.89, 0.80), "mezquita": "barrio", "palacio": "alcazaba", "suelo": Color(0.76, 0.66, 0.50), "arboles": "mixto"},
	"norte": {"seco": false, "muro": "tierra", "casas": "aldea", "color_casa": Color(0.80, 0.66, 0.47), "mezquita": "iglesia", "palacio": "castro", "suelo": Color(0.58, 0.48, 0.34), "arboles": "robledal"},
}

## Región activa (una clave de REGIONES). Se ha de fijar antes de build().
var region := "cordoba"

## Triángulos de los edificios, murallas y árboles generados por código (no cuenta el suelo de KayKit).
var triangulos := 0

var _palette_cache := {}


func _datos() -> Dictionary:
	return REGIONES.get(region, REGIONES["cordoba"])


func build(terrain: Array, things: Array, paths: Array = []) -> bool:
	if not REGIONES.has(region):
		push_error("Región desconocida: " + region)
		return false
	var ok: bool = super(terrain, things, paths)
	if ok:
		_aplicar_paleta(PALETA_SECA if _datos()["seco"] else PALETA_NORTE)
	return ok


## Cambia la textura de paleta de todos los modelos KayKit colocados (suelo, río, camino, costa).
func _aplicar_paleta(ruta: String) -> void:
	var tex := load(ruta) as Texture2D
	if tex == null:
		push_warning("Falta la paleta: " + ruta)
		return
	for child in get_children():
		if (child as Node).scene_file_path != "":
			_cambiar_paleta(child, tex)


func _cambiar_paleta(nodo: Node, tex: Texture2D) -> void:
	if nodo is MeshInstance3D:
		var mi := nodo as MeshInstance3D
		if mi.mesh != null and mi.material_override == null:
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if mat is BaseMaterial3D:
					if not _palette_cache.has(mat):
						var copia := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
						copia.albedo_texture = tex
						_palette_cache[mat] = copia
					mi.set_surface_override_material(s, _palette_cache[mat])
	for hijo in nodo.get_children():
		_cambiar_paleta(hijo, tex)


func _rock_material(q: int, r: int) -> StandardMaterial3D:
	if _rock == null:
		_rock = StandardMaterial3D.new()
		_rock.albedo_color = Color(0.52, 0.42, 0.30) if _datos()["seco"] else Color(0.40, 0.35, 0.28)
		_rock.roughness = 1.0
	return super(q, r)


# ---------------------------------------------------------------------------------------------
# Puente y muralla

## Sobre una casilla de río con puente, el suelo es el río recto o curvo; el puente de arcos va encima.
func _path_ground(key: Vector2i, c: Dictionary) -> Array:
	if c["p"] == "b":
		var mask := _connections(key, "rR", true, false)
		if mask.size() >= 2:
			return _pick(RIVER_TILES, mask, key)
		return ["hex_grass", 0.0]
	return super(key, c)


func _path_extra(key: Vector2i, c: Dictionary, h: int) -> void:
	var p: String = c["p"]
	var pos := hex_to_world(key.x, key.y, float(h))
	if p == "b":
		var mask := _connections(key, "rR", true, false)
		if mask.size() < 2:
			return
		# El puente cruza el río: perpendicular a la línea que une los dos primeros bordes del río.
		var v := U.edge_dir(int(mask[1])) - U.edge_dir(int(mask[0]))
		var flujo := rad_to_deg(atan2(-v.z, v.x))
		var m := Malla.new()
		Defensa.puente(m, flujo + 90.0)
		_poner(m, "puente_%d_%d" % [key.x, key.y], pos)
		return
	if p != "m" and p != "g":
		return
	var bordes := _connections(key, "mg", false, false)
	var muro := Malla.new()
	Defensa.casilla_muralla(muro, bordes, _datos()["muro"], p == "g", _outward(key), wall_towers)
	_poner(muro, "muralla_%d_%d" % [key.x, key.y], pos)


func _poner(m: Malla, etiqueta: String, pos: Vector3, rot_deg: float = 0.0) -> MeshInstance3D:
	if m.is_empty():
		return null
	var mi := m.instance(etiqueta, pos, rot_deg)
	add_child(mi)
	triangulos += m.triangle_count()
	return mi


# ---------------------------------------------------------------------------------------------
# Objetos

func _thing(q: int, r: int, o: String, y: float) -> void:
	var pos := hex_to_world(q, r, y)
	var seed := U.seed_of(q, r)
	var d := _datos()
	var m := Malla.new()
	var etiqueta := ""
	var rot := 0.0
	match o:
		"o", "O":
			etiqueta = "casas"
			var grande := o == "O"
			if d["casas"] == "patio":
				Urbano.suelo_urbano(m, d["suelo"])
				Urbano.manzana(m, seed, 0.95 if grande else 0.55, d["color_casa"], grande)
			else:
				Urbano.aldea(m, seed, 6 if grande else 4, grande)
		"E":
			etiqueta = "mercado"
			Urbano.suelo_urbano(m, d["suelo"])
			Urbano.mercado(m, seed, d["seco"])
		"Y":
			match d["mezquita"]:
				"aljama":
					etiqueta = "mezquita_aljama"
					Urbano.suelo_urbano(m, d["suelo"])
					Urbano.mezquita_aljama(m)
				"barrio":
					etiqueta = "mezquita_barrio"
					Urbano.suelo_urbano(m, d["suelo"])
					Urbano.mezquita_barrio(m)
				_:
					etiqueta = "iglesia"
					Urbano.iglesia_mozarabe(m)
		"C":
			match d["palacio"]:
				"castro":
					etiqueta = "castro"
					Defensa.castro(m)
				_:
					etiqueta = d["palacio"]
					Urbano.suelo_urbano(m, d["suelo"])
					Urbano.alcazar(m, d["palacio"] == "alcazaba")
		"T", "t", "s":
			etiqueta = "bosque"
			var n := 9 if o == "T" else (6 if o == "t" else 3)
			Campo.bosque(m, seed, n, d["arboles"])
		"F":
			etiqueta = "cereal"
			Campo.campo_secano(m, seed)
		"a", "A":
			etiqueta = "huerta"
			Campo.huerta(m, seed, o == "A")
		"i":
			etiqueta = "olivar"
			Campo.olivar(m, seed)
		"W":
			if d["seco"]:
				etiqueta = "huerta"
				Campo.huerta(m, seed, true)
			else:
				etiqueta = "cereal"
				Campo.campo_secano(m, seed)
		"h", "H", "M", "N", "Q":
			etiqueta = "relieve"
			Campo.relieve(m, o, seed, d["seco"])
		"p":
			etiqueta = "horno"
			Urbano.suelo_urbano(m, d["suelo"])
			Urbano.horno(m, seed, d["seco"])
		"g":
			etiqueta = "granero"
			Urbano.granero(m, seed, d["seco"])
		"S":
			etiqueta = "obra"
			Urbano.obra(m, seed)
		"V":
			etiqueta = "molino_agua"
			rot = _hacia_el_agua(q, r)
			Campo.molino_agua(m, 0.0)
		"L":
			etiqueta = "aserradero"
			Campo.aserradero(m)
		"Z":
			etiqueta = "herreria"
			Campo.herreria(m)
		"x", "X", "y", "z":
			etiqueta = "muro_suelto"
			var e0 := {"x": 0, "y": 1, "z": 2, "X": 0}[o] as int
			var bordes := [e0, e0 + 3]
			Defensa.casilla_muralla(m, bordes, d["muro"], o == "X", Vector3(0, 0, 1), false)
		"K":
			etiqueta = "torre"
			Defensa.torre(m, Vector3.ZERO, d["muro"], Vector3.ZERO)
		_:
			super(q, r, o, y)
			return
	_poner(m, "%s_%d_%d" % [etiqueta, q, r], pos, rot)


## Giro (grados) para que el frente (+z) de un molino mire al borde de la casilla que da al agua o al río.
func _hacia_el_agua(q: int, r: int) -> float:
	var key := Vector2i(q, r)
	for e in 6:
		var n: Vector2i = key + DIRS[e]
		if not _cells.has(n):
			continue
		var cell: Dictionary = _cells[n]
		if cell["t"] == "w" or cell["p"] == "r" or cell["p"] == "R":
			return 60.0 * float(e) + 90.0
	return 0.0
