extends SceneTree
## Captura del diorama de época (ciudad_epoca.gd) para revisarlo a ojo; no es una prueba automática.
## Uso:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path game --rendering-driver opengl3 \
##     --resolution 1080x2400 -s ../tools/captura_epoca.gd -- salida.png [region] [sombras:0|1] [inclinacion] [distancia] [fov] [exposicion] [x] [z] [realista:0|1]
## region: cordoba (por defecto), toledo, zaragoza o norte. Cordoba, Toledo y Zaragoza comparten diseño
## (cambian los estilos); el norte tiene el suyo.
## Limitación: dibujado por software (llvmpipe); no mide el rendimiento del móvil.

const RADIUS := 4


## Casillas a distancia exacta d de (cq, cr) (anillo hexagonal).
func _ring(cq: int, cr: int, d: int) -> Array:
	var out: Array = []
	for q in range(-RADIUS, RADIUS + 1):
		for r in range(-RADIUS, RADIUS + 1):
			if maxi(maxi(absi(q), absi(r)), absi(q + r)) > RADIUS:
				continue
			var dq := q - cq
			var dr := r - cr
			if (absi(dq) + absi(dr) + absi(dq + dr)) / 2 == d:
				out.append(Vector2i(q, r))
	return out


## Ciudad amurallada junto a un río que corre de noreste a suroeste (q + r = 1); la puerta da al puente.
func _ciudad() -> Dictionary:
	var c := {}
	for cell in _ring(-1, -1, 2):
		c[cell] = {"p": "m"}
	c[Vector2i(0, 0)] = {"p": "g"}
	# Dentro de la muralla.
	c[Vector2i(-1, -1)] = {"o": "O"}
	c[Vector2i(0, -1)] = {"o": "O"}
	c[Vector2i(0, -2)] = {"o": "E"}
	c[Vector2i(-1, -2)] = {"o": "o"}
	c[Vector2i(-2, -1)] = {"o": "O"}
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
	# Orilla sureste: huertas, noria, molino, olivares y cereal.
	c[Vector2i(3, -1)] = {"o": "a"}
	c[Vector2i(2, 0)] = {"o": "a"}
	c[Vector2i(1, 1)] = {"o": "V"}
	c[Vector2i(-1, 3)] = {"o": "A"}
	c[Vector2i(-2, 4)] = {"o": "a"}
	for cell in [Vector2i(4, -1), Vector2i(3, 0), Vector2i(1, 2), Vector2i(-1, 4), Vector2i(2, 2), Vector2i(1, 3)]:
		c[cell] = {"o": "i"}
	c[Vector2i(2, 1)] = {"o": "F"}
	c[Vector2i(4, 0)] = {"o": "F"}
	c[Vector2i(3, 1)] = {"o": "F"}
	# Arrabales (barrios fuera de la muralla, como los excavados en H-22) al este, al oeste y junto al río.
	c[Vector2i(2, -2)] = {"o": "O"}
	c[Vector2i(2, -3)] = {"o": "o"}
	c[Vector2i(-2, 2)] = {"o": "O"}
	c[Vector2i(-3, 2)] = {"o": "o"}
	c[Vector2i(-4, 2)] = {"o": "o"}
	c[Vector2i(-4, 1)] = {"o": "s"}
	c[Vector2i(-4, 3)] = {"o": "i"}
	c[Vector2i(-3, 3)] = {"o": "a"}
	# Norte: olivar y sierra.
	c[Vector2i(3, -3)] = {"o": "i"}
	c[Vector2i(4, -4)] = {"o": "H"}
	c[Vector2i(3, -4)] = {"o": "M"}
	c[Vector2i(2, -4)] = {"o": "N"}
	c[Vector2i(1, -4)] = {"o": "M"}
	c[Vector2i(0, -4)] = {"o": "h"}
	c[Vector2i(-4, 0)] = {"o": "T"}
	return c


## Aldea cristiana con iglesia, mercado, arroyo con molino, campos, bosque y un castro en el cerro.
func _norte() -> Dictionary:
	var c := {}
	c[Vector2i(0, 0)] = {"o": "O"}
	c[Vector2i(1, 0)] = {"o": "o"}
	c[Vector2i(-1, 1)] = {"o": "o"}
	c[Vector2i(0, 1)] = {"o": "O"}
	c[Vector2i(-1, 0)] = {"o": "Y"}
	c[Vector2i(1, -1)] = {"o": "E"}
	c[Vector2i(0, -1)] = {"o": "o"}
	# Arroyo que baja del cerro.
	c[Vector2i(3, -4)] = {"p": "R"}
	for cell in [Vector2i(2, -3), Vector2i(2, -2), Vector2i(2, -1), Vector2i(2, 0), Vector2i(1, 2), Vector2i(1, 3)]:
		c[cell] = {"p": "r"}
	c[Vector2i(2, 1)] = {"p": "r"}
	c[Vector2i(1, 4)] = {"p": "R"}
	c[Vector2i(3, 0)] = {"o": "V"}
	# Castro en el cerro.
	c[Vector2i(-1, -3)] = {"t": "2", "o": "C"}
	c[Vector2i(-2, -2)] = {"t": "1", "o": "h"}
	c[Vector2i(0, -3)] = {"t": "1", "o": "t"}
	c[Vector2i(-1, -2)] = {"t": "1", "o": "T"}
	c[Vector2i(-2, -1)] = {"o": "t"}
	# Campos y bosques.
	for cell in [Vector2i(-2, 1), Vector2i(-2, 2), Vector2i(-1, 2), Vector2i(0, 2), Vector2i(-3, 2), Vector2i(-3, 3), Vector2i(0, 3), Vector2i(-1, 3)]:
		c[cell] = {"o": "F"}
	for cell in [Vector2i(3, -1), Vector2i(3, -2), Vector2i(4, -2), Vector2i(4, -3), Vector2i(3, -3), Vector2i(4, -1), Vector2i(4, 0), Vector2i(3, 1)]:
		c[cell] = {"o": "T"}
	c[Vector2i(-3, 0)] = {"o": "T"}
	c[Vector2i(-3, 1)] = {"o": "t"}
	c[Vector2i(-4, 1)] = {"o": "T"}
	c[Vector2i(-4, 2)] = {"o": "T"}
	c[Vector2i(-3, -1)] = {"o": "T"}
	c[Vector2i(1, -2)] = {"o": "t"}
	c[Vector2i(-2, 3)] = {"o": "F"}
	c[Vector2i(2, 2)] = {"o": "L"}
	c[Vector2i(-4, 3)] = {"o": "T"}
	c[Vector2i(-2, 0)] = {"o": "s"}
	c[Vector2i(1, 1)] = {"o": "F"}
	return c


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var region: String = args[1] if args.size() > 1 else "cordoba"
	var shadows: bool = (args[2] == "1") if args.size() > 2 else true
	var pitch: float = float(args[3]) if args.size() > 3 else 40.0
	var dist: float = float(args[4]) if args.size() > 4 else 31.0
	var fov: float = float(args[5]) if args.size() > 5 else 32.0
	var expo: float = float(args[6]) if args.size() > 6 else 0.8
	var realista: bool = (args[9] == "1") if args.size() > 9 else true
	var tx: float = float(args[7]) if args.size() > 7 else 0.0
	var tz: float = float(args[8]) if args.size() > 8 else 0.5

	var world := Node3D.new()
	root.add_child(world)
	var ciudad = load("res://scripts/view/ciudad_epoca.gd").new()
	ciudad.region = region
	world.add_child(ciudad)
	var layout := _norte() if region == "norte" else _ciudad()
	var layers: Dictionary = ciudad.layers_from_cells(RADIUS, layout)
	if not layers["errors"].is_empty():
		printerr("Diseño fuera del mapa: ", layers["errors"])
		quit(1)
		return
	if not ciudad.build(layers["terrain"], layers["things"], layers["paths"]):
		quit(1)
		return
	var stage = load("res://scripts/view/stage.gd").new()
	world.add_child(stage)
	stage.exposure = expo
	stage.realista = realista
	stage.setup(Vector3(tx, 0.5, tz), shadows, pitch, dist, fov)

	for i in range(6):
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("guardada ", out, "  nodos 3D: ", _count(world))
	quit()


func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c
