extends RefCounted
## Constructor de mallas de bajo polígono, generadas por código (sin modelos externos).
##
## Acumula cajas, tejados, cilindros, cúpulas, esferas y muros con arcos en UNA sola malla
## con color por vértice y caras planas. Un edificio entero = un solo objeto que dibujar
## (importa en el móvil). Las coordenadas son locales: y = 0 es el suelo.
##
## Cada primitiva se orienta sola hacia fuera (comprobando contra un punto interior), así no
## hay que acertar a mano el sentido de los triángulos.

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _origin := Vector3.ZERO
var _basis := Basis.IDENTITY
var _stack: Array = []


# ---------------------------------------------------------------------------------------------
# Transformación activa

## Entra en un sistema de coordenadas desplazado y girado (grados) respecto al actual.
func push(origin: Vector3 = Vector3.ZERO, rot_y_deg: float = 0.0, rot_x_deg: float = 0.0, rot_z_deg: float = 0.0) -> void:
	_stack.append([_origin, _basis])
	_origin = _origin + _basis * origin
	var local := Basis.from_euler(Vector3(deg_to_rad(rot_x_deg), deg_to_rad(rot_y_deg), deg_to_rad(rot_z_deg)), EULER_ORDER_YXZ)
	_basis = _basis * local


func pop() -> void:
	if _stack.is_empty():
		push_error("Malla.pop sin push")
		return
	var s: Array = _stack.pop_back()
	_origin = s[0]
	_basis = s[1]


func _p(local: Vector3) -> Vector3:
	return _origin + _basis * local


# ---------------------------------------------------------------------------------------------
# Triángulos

## Oscurecimiento en la base de todo (sombra de contacto, como la oclusión ambiental): 0 = nada,
## 0,3 = la base queda un 30 % más oscura. Se desvanece al subir `ao_altura`. Y una pequeña variación
## de tono por cara (`tinte`), siempre la misma, para que no parezca plástico liso.
var ao := 0.28
var ao_altura := 0.13
var tinte := 0.035


## Color de un vértice a la altura y, con la variación de la cara.
func _shade(col: Color, y: float, jitter: float) -> Color:
	var f := 1.0 - ao * clampf(1.0 - y / ao_altura, 0.0, 1.0)
	f *= jitter
	return Color(col.r * f, col.g * f, col.b * f, 1.0)


## Triángulo con la cara hacia el lado que indica `out` (dirección local hacia fuera).
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, out: Vector3) -> void:
	tri_c(a, b, c, col, col, col, out)


## Igual que tri, con un color distinto en cada vértice (relieves con color según la altura).
func tri_c(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, out: Vector3) -> void:
	var pa := _p(a)
	var pb := _p(b)
	var pc := _p(c)
	var nrm := (pb - pa).cross(pc - pa)
	if nrm.length_squared() < 1e-14:
		return
	nrm = nrm.normalized()
	var want := _basis * out
	if nrm.dot(want) < 0.0:
		# Godot dibuja la cara delantera con los vértices en sentido horario.
		var tp := pb
		pb = pc
		pc = tp
		var tc := cb
		cb = cc
		cc = tc
		nrm = -nrm
	var centro := (pa + pb + pc) / 3.0
	var j := 1.0 + tinte * (fposmod(sin(centro.x * 127.1 + centro.z * 311.7 + centro.y * 74.7) * 43758.5453, 1.0) - 0.5) * 2.0
	_v.append(pa)
	_v.append(pc)
	_v.append(pb)
	_c.append(_shade(ca, pa.y, j))
	_c.append(_shade(cc, pc.y, j))
	_c.append(_shade(cb, pb.y, j))
	for i in 3:
		_n.append(nrm)


## Cuadrilátero a, b, c, d (en orden alrededor) con la cara hacia `out`.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out: Vector3) -> void:
	tri(a, b, c, col, out)
	tri(a, c, d, col, out)


## Cuadrilátero que mira hacia fuera de un punto interior (para sólidos convexos).
func _quad_from(inside: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	var center := (a + b + c + d) * 0.25
	quad(a, b, c, d, col, center - inside)


func _tri_from(inside: Vector3, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var center := (a + b + c) / 3.0
	tri(a, b, c, col, center - inside)


# ---------------------------------------------------------------------------------------------
# Primitivas

## Caja (o tronco de pirámide si top_scale != 1) con la base centrada en `base`.
## Sin cara inferior. col_top permite un color distinto para la cara de arriba.
func box(base: Vector3, size: Vector3, col: Color, top_scale: float = 1.0, col_top: Color = Color(0, 0, 0, 0)) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var tx := hx * top_scale
	var tz := hz * top_scale
	var b0 := base + Vector3(-hx, 0, -hz)
	var b1 := base + Vector3(hx, 0, -hz)
	var b2 := base + Vector3(hx, 0, hz)
	var b3 := base + Vector3(-hx, 0, hz)
	var t0 := base + Vector3(-tx, size.y, -tz)
	var t1 := base + Vector3(tx, size.y, -tz)
	var t2 := base + Vector3(tx, size.y, tz)
	var t3 := base + Vector3(-tx, size.y, tz)
	var inside := base + Vector3(0, size.y * 0.5, 0)
	_quad_from(inside, b3, b2, t2, t3, col)   # +z
	_quad_from(inside, b1, b0, t0, t1, col)   # -z
	_quad_from(inside, b2, b1, t1, t2, col)   # +x
	_quad_from(inside, b0, b3, t3, t0, col)   # -x
	_quad_from(inside, t0, t3, t2, t1, col if col_top.a == 0.0 else col_top)


## Tejado a dos aguas: la cumbrera va a lo largo de x, la base mide size.x por size.z.
func gable(base: Vector3, size: Vector3, col: Color, col_end: Color = Color(0, 0, 0, 0)) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var inside := base + Vector3(0, size.y * 0.3, 0)
	var e := col if col_end.a == 0.0 else col_end
	_quad_from(inside, base + Vector3(-hx, 0, hz), base + Vector3(hx, 0, hz), base + Vector3(hx, size.y, 0), base + Vector3(-hx, size.y, 0), col)
	_quad_from(inside, base + Vector3(hx, 0, -hz), base + Vector3(-hx, 0, -hz), base + Vector3(-hx, size.y, 0), base + Vector3(hx, size.y, 0), col)
	_tri_from(inside, base + Vector3(hx, 0, hz), base + Vector3(hx, 0, -hz), base + Vector3(hx, size.y, 0), e)
	_tri_from(inside, base + Vector3(-hx, 0, -hz), base + Vector3(-hx, 0, hz), base + Vector3(-hx, size.y, 0), e)


## Tejado piramidal (a cuatro aguas).
func pyramid(base: Vector3, size: Vector3, col: Color) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var apex := base + Vector3(0, size.y, 0)
	var inside := base + Vector3(0, size.y * 0.25, 0)
	_tri_from(inside, base + Vector3(-hx, 0, hz), base + Vector3(hx, 0, hz), apex, col)
	_tri_from(inside, base + Vector3(hx, 0, -hz), base + Vector3(-hx, 0, -hz), apex, col)
	_tri_from(inside, base + Vector3(hx, 0, hz), base + Vector3(hx, 0, -hz), apex, col)
	_tri_from(inside, base + Vector3(-hx, 0, -hz), base + Vector3(-hx, 0, hz), apex, col)


## Cilindro o tronco de cono (r_top distinto de r_bottom). Tapa superior opcional.
func cyl(base: Vector3, r_bottom: float, r_top: float, height: float, segs: int, col: Color, cap: bool = true, col_top: Color = Color(0, 0, 0, 0)) -> void:
	var inside := base + Vector3(0, height * 0.5, 0)
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var b0 := base + Vector3(cos(a0), 0, sin(a0)) * r_bottom
		var b1 := base + Vector3(cos(a1), 0, sin(a1)) * r_bottom
		var t0 := base + Vector3(cos(a0), 0, sin(a0)) * r_top + Vector3(0, height, 0)
		var t1 := base + Vector3(cos(a1), 0, sin(a1)) * r_top + Vector3(0, height, 0)
		if r_top > 0.0001:
			_quad_from(inside, b0, b1, t1, t0, col)
		else:
			_tri_from(inside, b0, b1, t0, col)
		if cap and r_top > 0.0001:
			_tri_from(inside, base + Vector3(0, height, 0), t1, t0, col if col_top.a == 0.0 else col_top)


## Media esfera (cúpula) de radio r sobre `base`; squash aplasta la altura.
func dome(base: Vector3, r: float, segs: int, rings: int, col: Color, squash: float = 1.0) -> void:
	var inside := base
	for k in rings:
		var f0 := (PI * 0.5) * float(k) / float(rings)
		var f1 := (PI * 0.5) * float(k + 1) / float(rings)
		var r0 := r * cos(f0)
		var r1 := r * cos(f1)
		var y0 := r * sin(f0) * squash
		var y1 := r * sin(f1) * squash
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var p00 := base + Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p01 := base + Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p10 := base + Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var p11 := base + Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			if k == rings - 1:
				_tri_from(inside, p00, p01, p10, col)
			else:
				_quad_from(inside, p00, p01, p11, p10, col)


## Esfera o elipsoide (copas de árbol, arbustos): centro, radio, achatamiento vertical.
func blob(center: Vector3, r: float, segs: int, rings: int, col: Color, squash: float = 1.0, col_top: Color = Color(0, 0, 0, 0)) -> void:
	for k in rings:
		var f0 := -PI * 0.5 + PI * float(k) / float(rings)
		var f1 := -PI * 0.5 + PI * float(k + 1) / float(rings)
		var r0 := r * cos(f0)
		var r1 := r * cos(f1)
		var y0 := r * sin(f0) * squash
		var y1 := r * sin(f1) * squash
		var c := col
		if col_top.a != 0.0 and k >= rings / 2:
			c = col_top
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var p00 := center + Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p01 := center + Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p10 := center + Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var p11 := center + Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			if k == 0:
				_tri_from(center, p00, p11, p10, c)
			elif k == rings - 1:
				_tri_from(center, p00, p01, p10, c)
			else:
				_quad_from(center, p00, p01, p11, p10, c)


## Relieve irregular (colina, cerro, monte): cúpula de radio r y altura h con el radio y la altura
## alterados por ruido determinista (semilla). El color pasa de c_bajo a c_medio y c_alto según la altura.
## `cumbres` suma cumbres más pequeñas desplazadas (montañas).
func lump(base: Vector3, r: float, h: float, segs: int, rings: int, seed: int, c_bajo: Color, c_medio: Color, c_alto: Color, cumbres: int = 0) -> void:
	_lump_una(base, r, h, segs, rings, seed, c_bajo, c_medio, c_alto)
	for k in cumbres:
		var a := TAU * (float(k) + 0.3 * float((seed % 7))) / float(maxi(cumbres, 1))
		var off := Vector3(cos(a), 0, sin(a)) * r * 0.45
		_lump_una(base + off, r * 0.55, h * (0.55 + 0.15 * float(k % 2)), segs, rings, seed + 31 * (k + 1), c_bajo, c_medio, c_alto)


func _lump_una(base: Vector3, r: float, h: float, segs: int, rings: int, seed: int, c_bajo: Color, c_medio: Color, c_alto: Color) -> void:
	var puntos: Array = []
	var colores: Array = []
	for k in rings + 1:
		var t := float(k) / float(rings)
		var fila: Array = []
		var cfila: Array = []
		for i in segs:
			var ang := TAU * float(i) / float(segs)
			var ruido := 1.0 + 0.30 * (_hash(seed, i * 17 + k) - 0.5)
			var ruido_h := 1.0 + 0.30 * (_hash(seed + 5, i * 13 + k * 3) - 0.5)
			var radial := r * pow(1.0 - t, 0.85) * (ruido if k > 0 else 1.0)
			var y := h * (1.0 - pow(1.0 - t, 2.0)) * (ruido_h if k < rings else 1.0)
			fila.append(base + Vector3(cos(ang) * radial, y, sin(ang) * radial))
			var col := c_bajo.lerp(c_medio, clampf(t * 2.0, 0.0, 1.0))
			if t > 0.5:
				col = c_medio.lerp(c_alto, clampf((t - 0.5) * 2.0, 0.0, 1.0))
			cfila.append(col)
		puntos.append(fila)
		colores.append(cfila)
	for k in rings:
		for i in segs:
			var i2 := (i + 1) % segs
			var p00: Vector3 = puntos[k][i]
			var p01: Vector3 = puntos[k][i2]
			var p10: Vector3 = puntos[k + 1][i]
			var p11: Vector3 = puntos[k + 1][i2]
			var c00: Color = colores[k][i]
			var c01: Color = colores[k][i2]
			var c10: Color = colores[k + 1][i]
			var c11: Color = colores[k + 1][i2]
			var fuera := ((p00 + p01 + p10 + p11) * 0.25) - base
			tri_c(p00, p01, p11, c00, c01, c11, fuera)
			tri_c(p00, p11, p10, c00, c11, c10, fuera)


## Número en [0, 1) determinista.
static func _hash(seed: int, k: int) -> float:
	var x: int = (seed * 73856093) ^ (k * 19349663) ^ 0x5bd1e995
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return float(x & 0xffff) / 65536.0


## Prisma recto a partir de un polígono 2D (x, y) extruido en z de -thick/2 a +thick/2.
## Sirve para muros con arcos. `outline` debe ser un polígono simple.
func extrude(base: Vector3, outline: PackedVector2Array, thick: float, col: Color, col_side: Color = Color(0, 0, 0, 0)) -> void:
	var tris := Geometry2D.triangulate_polygon(outline)
	if tris.is_empty():
		push_error("Malla.extrude: polígono no válido")
		return
	var hz := thick * 0.5
	var side := col if col_side.a == 0.0 else col_side
	for i in range(0, tris.size(), 3):
		var a := outline[tris[i]]
		var b := outline[tris[i + 1]]
		var c := outline[tris[i + 2]]
		tri(base + Vector3(a.x, a.y, hz), base + Vector3(b.x, b.y, hz), base + Vector3(c.x, c.y, hz), col, Vector3(0, 0, 1))
		tri(base + Vector3(a.x, a.y, -hz), base + Vector3(b.x, b.y, -hz), base + Vector3(c.x, c.y, -hz), col, Vector3(0, 0, -1))
	# Lados: la normal hacia fuera del sólido depende del sentido del polígono.
	var area := 0.0
	for i in outline.size():
		var p := outline[i]
		var q := outline[(i + 1) % outline.size()]
		area += p.x * q.y - q.x * p.y
	var ccw := area > 0.0
	for i in outline.size():
		var p := outline[i]
		var q := outline[(i + 1) % outline.size()]
		var d := q - p
		if d.length() < 0.0001:
			continue
		var nrm2 := Vector2(d.y, -d.x) if ccw else Vector2(-d.y, d.x)
		if nrm2.y < -0.99:
			continue   # cara de abajo, apoyada en el suelo
		var out := Vector3(nrm2.x, nrm2.y, 0.0)
		quad(base + Vector3(p.x, p.y, -hz), base + Vector3(q.x, q.y, -hz), base + Vector3(q.x, q.y, hz), base + Vector3(p.x, p.y, hz), side, out)


## Contorno de un muro de ancho `width` y alto `height` (base en y = 0, centrado en x) con
## aberturas en arco que llegan hasta el suelo.
## openings: [{"x": centro, "r": radio, "y": altura del arranque, "tipo": "herradura" | "medio_punto"}].
## La herradura es un arco de unos tres cuartos de círculo (estrecha por abajo, más ancha en el arranque).
static func arch_outline(width: float, height: float, openings: Array, steps: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(-width * 0.5, 0.0))
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a, b): return a["x"] < b["x"])
	for o in sorted:
		var xc: float = o["x"]
		var r: float = o["r"]
		var yc: float = o["y"]
		if o.get("tipo", "medio_punto") == "herradura":
			var j := r * 0.70710678
			pts.append(Vector2(xc - j, 0.0))
			for s in range(steps * 2 + 1):
				var ang := deg_to_rad(225.0 - 270.0 * float(s) / float(steps * 2))
				pts.append(Vector2(xc + r * cos(ang), yc + r * sin(ang)))
			pts.append(Vector2(xc + j, 0.0))
		else:
			pts.append(Vector2(xc - r, 0.0))
			for s in range(steps + 1):
				var ang := deg_to_rad(180.0 - 180.0 * float(s) / float(steps))
				pts.append(Vector2(xc + r * cos(ang), yc + r * sin(ang)))
			pts.append(Vector2(xc + r, 0.0))
	pts.append(Vector2(width * 0.5, 0.0))
	pts.append(Vector2(width * 0.5, height))
	pts.append(Vector2(-width * 0.5, height))
	return pts


## Muro con arcos (puertas, arcadas, puentes). Mira hacia +z.
func arch_wall(base: Vector3, width: float, height: float, thick: float, openings: Array, col: Color, steps: int = 8, col_side: Color = Color(0, 0, 0, 0)) -> void:
	extrude(base, arch_outline(width, height, openings, steps), thick, col, col_side)


# ---------------------------------------------------------------------------------------------
# Resultado

func triangle_count() -> int:
	return _v.size() / 3


func is_empty() -> bool:
	return _v.is_empty()


## Caja que contiene toda la geometría (calculada a mano: no depende del motor gráfico).
func bounds() -> AABB:
	if _v.is_empty():
		return AABB()
	var lo := _v[0]
	var hi := _v[0]
	for p in _v:
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	return AABB(lo, hi - lo)


## Vértices (copia), para pruebas.
func vertices() -> PackedVector3Array:
	return _v.duplicate()


func normals() -> PackedVector3Array:
	return _n.duplicate()


func to_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _v.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static var _material: StandardMaterial3D


## Material común: usa el color de cada vértice.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.95
		_material.metallic = 0.0
	return _material


## Crea el objeto 3D que dibuja la malla acumulada.
func instance(label: String, pos: Vector3 = Vector3.ZERO, rot_y_deg: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = to_mesh()
	mi.material_override = material()
	mi.position = pos
	mi.rotation_degrees.y = rot_y_deg
	return mi
