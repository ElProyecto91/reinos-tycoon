extends Node3D
## Gente de la vista 3D: aldeanos que van y vienen por los caminos, obreros en las obras, gente en el
## mercado y humo en los hornos. Solo dibuja: no toca la simulación (qué se ve lo decide
## provincia_layout.gd, función `gente`).
##
## Escala: las figuras miden ~0,32 unidades (tras el aumento) y las casas ~0,10, así que la gente va EXAGERADA (unas cinco veces)
## para que se vea en un móvil; es una decisión de aspecto, no de realismo.
## Animación: se mueve con `avanzar(dt)`; la vista lo llama a un ritmo fijo y bajo (ver province_view.gd).

const Malla = preload("res://scripts/view/malla.gd")
const U = preload("res://scripts/view/epoca_util.gd")

const VELOCIDAD := 0.40            # unidades por segundo
const ESPERA_MIN := 1.5
const ESPERA_MAX := 4.5
## Aumento de las figuras (se ven en un móvil; ver la nota de escala de arriba).
const ESCALA := 1.8
const PIEL := Color(0.78, 0.58, 0.44)

var caminantes: Array = []         # [{mi, pts, largo, s, sentido, espera, vel, fase}]
var obreros: Array = []            # [{mi, base, fase}]
var parados: Array = []            # gente del mercado
var humos: Array = []              # [{mi, base, fase}]
var guardias: Array = []           # soldados de guardia junto al cuartel
var _ciudad = null
var _sur := true
var _reloj := 0.0
var _mallas := {}
var _humo_malla: ArrayMesh


## Prepara a la gente de una provincia. `datos` es el resultado de Layout.gente(...); `ciudad` es la
## ciudad de época ya construida (da las alturas del suelo).
func configurar(ciudad, datos: Dictionary, sur: bool) -> void:
	_ciudad = ciudad
	_sur = sur
	for hijo in get_children():
		hijo.queue_free()
	caminantes.clear()
	obreros.clear()
	parados.clear()
	humos.clear()
	guardias.clear()
	_reloj = 0.0

	var rutas: Array = datos["rutas"]
	var rutas_3d: Array = []
	for r in rutas:
		var p := puntos_de_ruta(r)
		if p.size() >= 2:
			rutas_3d.append(p)
	if not rutas_3d.is_empty():
		for i in int(datos["caminantes"]):
			_nuevo_caminante(i, rutas_3d[i % rutas_3d.size()], i / rutas_3d.size())
	for k in (datos["obras"] as Array).size():
		var c: Vector2i = datos["obras"][k]
		var base := _pos(c.x, c.y)
		for j in 2:
			var a := 1.2 + 3.1 * float(j) + float(k)
			var mi := _persona(1000 + k * 2 + j)
			mi.position = base + Vector3(cos(a), 0, sin(a)) * 0.42
			mi.rotation.y = atan2(-cos(a), -sin(a))
			add_child(mi)
			obreros.append({"mi": mi, "base": mi.position, "fase": float(j) * 1.7 + float(k)})
	var mc: Vector2i = datos["mercado"]
	for j in int(datos["gente_mercado"]):
		var a2 := TAU * float(j) / float(datos["gente_mercado"]) + 0.5
		var mi2 := _persona(2000 + j)
		mi2.position = _pos(mc.x, mc.y) + Vector3(cos(a2), 0, sin(a2)) * 0.26
		mi2.rotation.y = a2 + PI * 0.5
		add_child(mi2)
		parados.append({"mi": mi2, "base": mi2.position, "fase": float(j) * 2.3})
	var n_g := int(datos.get("guardias", 0))
	if n_g > 0:
		var qc: Vector2i = datos["cuartel"]
		for j in n_g:
			var a3 := TAU * float(j) / float(n_g) + 0.3
			var mi5 := _soldado(j)
			mi5.position = _pos(qc.x, qc.y) + Vector3(cos(a3), 0, sin(a3)) * (0.62 + 0.10 * float(j % 2))
			mi5.rotation.y = atan2(cos(a3), sin(a3))
			add_child(mi5)
			guardias.append({"mi": mi5, "base": mi5.position, "fase": float(j) * 1.9})
	for c2 in datos["humos"]:
		var base2 := _pos(c2.x, c2.y) + Vector3(0.34, 0.30, 0.0)
		for j in 3:
			var mi3 := MeshInstance3D.new()
			mi3.mesh = _malla_humo()
			mi3.material_override = Malla.material()
			mi3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi3)
			humos.append({"mi": mi3, "base": base2, "fase": float(j) / 3.0})
	avanzar(0.0)


## Altura del suelo de una casilla (la cara de arriba del césped).
func _suelo(q: int, r: int) -> float:
	if _ciudad == null:
		return 0.0
	var c: Dictionary = _ciudad.celda(q, r)
	return float(c.get("h", 0)) if not c.is_empty() else 0.0


func _pos(q: int, r: int) -> Vector3:
	return Vector3(2.0 * q + r, _suelo(q, r), 1.7320508 * r)


## Convierte los puntos de una ruta ([q, r] o [q, r, borde, fracción]) en posiciones del mundo.
## Sobre un puente (casilla con puente) la calzada va más alta: se añaden los extremos a esa altura.
func puntos_de_ruta(ruta: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in ruta.size():
		var w: Array = ruta[i]
		var p := _pos(int(w[0]), int(w[1]))
		if w.size() >= 4:
			p += U.edge_dir(int(w[2])) * float(w[3])
		var es_puente := false
		if _ciudad != null:
			es_puente = String(_ciudad.celda(int(w[0]), int(w[1])).get("p", ".")) == "b"
		if es_puente and w.size() < 4:
			var antes: Vector3 = _pos(int(ruta[i - 1][0]), int(ruta[i - 1][1])) if i > 0 else p
			var despues: Vector3 = _pos(int(ruta[i + 1][0]), int(ruta[i + 1][1])) if i + 1 < ruta.size() else p
			var a := p + (antes - p).normalized() * 0.8
			var b := p + (despues - p).normalized() * 0.8
			a.y = p.y + 0.30
			b.y = p.y + 0.30
			p.y += 0.30
			if i > 0:
				out.append(a)
			out.append(p)
			if i + 1 < ruta.size():
				out.append(b)
		else:
			out.append(p)
	return out


func _nuevo_caminante(i: int, pts: PackedVector3Array, vuelta: int) -> void:
	var lat := (float(vuelta % 3) - 1.0) * 0.13
	var dir := (pts[1] - pts[0])
	dir.y = 0.0
	var perp := Vector3(-dir.z, 0, dir.x).normalized() * lat
	var desplazados := PackedVector3Array()
	for p in pts:
		desplazados.append(p + perp)
	var largo := 0.0
	for k in range(1, desplazados.size()):
		largo += desplazados[k].distance_to(desplazados[k - 1])
	var mi := _persona(i)
	add_child(mi)
	var c := {
		"mi": mi, "pts": desplazados, "largo": largo,
		"s": largo * U.rnd(i + 7, 3), "sentido": 1.0 if U.rnd(i, 5) < 0.5 else -1.0,
		"espera": 0.0, "vel": VELOCIDAD * (0.8 + 0.4 * U.rnd(i, 9)), "fase": U.rnd(i, 11) * TAU,
	}
	caminantes.append(c)


## Posición sobre una ruta a la distancia `s` del principio (y hacia dónde mira un tramo).
static func punto_en(pts: PackedVector3Array, s: float) -> Dictionary:
	var resto := maxf(s, 0.0)
	for k in range(1, pts.size()):
		var seg := pts[k].distance_to(pts[k - 1])
		if resto <= seg or k == pts.size() - 1:
			var f := 1.0 if seg <= 0.0 else clampf(resto / seg, 0.0, 1.0)
			return {"pos": pts[k - 1].lerp(pts[k], f), "dir": pts[k] - pts[k - 1]}
		resto -= seg
	return {"pos": pts[pts.size() - 1], "dir": Vector3.ZERO}


## Hace avanzar a la gente `dt` segundos.
func avanzar(dt: float) -> void:
	_reloj += dt
	for c in caminantes:
		if float(c["espera"]) > 0.0:
			c["espera"] = maxf(0.0, float(c["espera"]) - dt)
		else:
			c["s"] = float(c["s"]) + float(c["vel"]) * dt * float(c["sentido"])
			if float(c["s"]) >= float(c["largo"]):
				c["s"] = c["largo"]
				c["sentido"] = -1.0
				c["espera"] = ESPERA_MIN + (ESPERA_MAX - ESPERA_MIN) * U.rnd(int(c["fase"] * 100.0), int(_reloj))
			elif float(c["s"]) <= 0.0:
				c["s"] = 0.0
				c["sentido"] = 1.0
				c["espera"] = ESPERA_MIN + (ESPERA_MAX - ESPERA_MIN) * U.rnd(int(c["fase"] * 100.0), int(_reloj) + 1)
		var info := punto_en(c["pts"], float(c["s"]))
		var mi: MeshInstance3D = c["mi"]
		var andando := float(c["espera"]) <= 0.0
		var bote := (absf(sin(_reloj * 9.0 + float(c["fase"]))) * 0.018) if andando else 0.0
		mi.position = (info["pos"] as Vector3) + Vector3(0, bote, 0)
		var d: Vector3 = info["dir"]
		d *= float(c["sentido"])
		if d.length() > 0.001 and andando:
			mi.rotation.y = atan2(d.x, d.z)
	for o in obreros:
		var mi2: MeshInstance3D = o["mi"]
		var golpe := maxf(0.0, sin(_reloj * 7.0 + float(o["fase"])))
		mi2.position = (o["base"] as Vector3) + Vector3(0, golpe * 0.02, 0)
		mi2.rotation.x = golpe * 0.25
	for p in parados:
		var mi3: MeshInstance3D = p["mi"]
		mi3.rotation.y += sin(_reloj * 0.8 + float(p["fase"])) * dt * 0.6
		mi3.position = (p["base"] as Vector3) + Vector3(0, 0.004 * sin(_reloj * 2.0 + float(p["fase"])), 0)
	for g in guardias:
		var mi6: MeshInstance3D = g["mi"]
		mi6.position = (g["base"] as Vector3) + Vector3(0, 0.003 * sin(_reloj * 1.6 + float(g["fase"])), 0)
	for h in humos:
		var t := fposmod(_reloj * 0.28 + float(h["fase"]), 1.0)
		var mi4: MeshInstance3D = h["mi"]
		var tam := 0.35 + 1.1 * t
		if t > 0.75:
			tam *= (1.0 - t) / 0.25
		mi4.scale = Vector3.ONE * maxf(tam, 0.001)
		mi4.position = (h["base"] as Vector3) + Vector3(0.10 * t, 0.55 * t, 0.06 * t)


# ---------------------------------------------------------------------------------------------
# Figuras

func _persona(semilla: int) -> MeshInstance3D:
	var tunicas: Array[Color]
	if _sur:
		tunicas = [Color(0.62, 0.22, 0.16), Color(0.20, 0.34, 0.52), Color(0.30, 0.42, 0.22), Color(0.45, 0.30, 0.20), Color(0.70, 0.52, 0.16)]
	else:
		tunicas = [Color(0.40, 0.28, 0.18), Color(0.28, 0.40, 0.22), Color(0.52, 0.22, 0.16), Color(0.22, 0.32, 0.50), Color(0.60, 0.46, 0.14)]
	var k := int(U.rnd(semilla, 21) * float(tunicas.size())) % tunicas.size()
	var clave := "%d_%s" % [k, str(_sur)]
	if not _mallas.has(clave):
		var m := Malla.new()
		m.ao = 0.0
		m.tinte = 0.0
		m.cyl(Vector3.ZERO, 0.045, 0.032, 0.115, 6, tunicas[k])
		m.blob(Vector3(0, 0.145, 0), 0.034, 6, 4, PIEL)
		if _sur:
			m.blob(Vector3(0, 0.162, 0), 0.036, 6, 3, Color(0.92, 0.89, 0.82), 0.7)
		else:
			m.dome(Vector3(0, 0.15, 0), 0.037, 6, 2, Color(0.36, 0.28, 0.20), 0.9)
		m.box(Vector3(0.06, 0, 0.0), Vector3(0.010, 0.15, 0.010), U.MADERA)
		_mallas[clave] = m.to_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _mallas[clave]
	mi.material_override = Malla.material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * ESCALA
	return mi


## Soldado: túnica roja, casco gris, lanza alta y escudo; mira hacia fuera del cuartel.
func _soldado(semilla: int) -> MeshInstance3D:
	if not _mallas.has("soldado"):
		var m := Malla.new()
		m.ao = 0.0
		m.tinte = 0.0
		m.cyl(Vector3.ZERO, 0.045, 0.032, 0.115, 6, Color(0.62, 0.13, 0.11))
		m.blob(Vector3(0, 0.145, 0), 0.034, 6, 4, PIEL)
		m.dome(Vector3(0, 0.15, 0), 0.039, 6, 2, Color(0.55, 0.56, 0.60), 0.9)
		m.box(Vector3(0.06, 0, 0.0), Vector3(0.010, 0.26, 0.010), U.MADERA_CLARA)
		m.box(Vector3(0.06, 0.26, 0.0), Vector3(0.016, 0.03, 0.016), Color(0.78, 0.78, 0.80))
		m.box(Vector3(-0.055, 0.03, 0.02), Vector3(0.012, 0.075, 0.06), Color(0.30, 0.22, 0.14))
		_mallas["soldado"] = m.to_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _mallas["soldado"]
	mi.material_override = Malla.material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * ESCALA
	return mi


func _malla_humo() -> ArrayMesh:
	if _humo_malla == null:
		var m := Malla.new()
		m.ao = 0.0
		m.tinte = 0.0
		m.blob(Vector3.ZERO, 0.09, 6, 4, Color(0.62, 0.60, 0.58))
		_humo_malla = m.to_mesh()
	return _humo_malla
