extends SceneTree
## Captura del diorama 3D para revisarlo a ojo (no es una prueba automática).
## Uso:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path game --rendering-driver opengl3 \
##     --resolution 1080x2400 -s ../tools/captura_diorama.gd -- salida.png [sombras:0|1] [inclinacion] [distancia] [fov]
## Limitación: dibujado por software (llvmpipe); no mide el rendimiento del móvil.

const RADIUS := 4


## Diseño de muestra por coordenadas axiales (q, r): x = 2q + r. Ver el comentario de diorama.gd.
func _layout() -> Dictionary:
	var c := {}
	# Muralla en anillo de radio 2 alrededor de (0, 0); la puerta mira al sur.
	for cell in [Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(-1, 2), Vector2i(-2, 2), Vector2i(-2, 1),
			Vector2i(-2, 0), Vector2i(-1, -1), Vector2i(0, -2), Vector2i(1, -2), Vector2i(2, -2), Vector2i(2, -1)]:
		c[cell] = {"p": "m"}
	c[Vector2i(-1, 2)] = {"p": "g"}
	# Dentro de la muralla
	c[Vector2i(0, 0)] = {"p": "c", "o": "E"}
	c[Vector2i(-1, 1)] = {"p": "c", "o": "J"}
	c[Vector2i(1, 0)] = {"o": "O"}
	c[Vector2i(-1, 0)] = {"o": "O"}
	c[Vector2i(0, 1)] = {"o": "Y"}
	c[Vector2i(0, -1)] = {"o": "o"}
	c[Vector2i(1, -1)] = {"o": "O"}
	# Camino que sale por la puerta hacia el sureste
	c[Vector2i(-1, 3)] = {"p": "c"}
	c[Vector2i(-1, 4)] = {"p": "C"}
	# Meseta del castillo al norte, detrás de la muralla
	c[Vector2i(2, -4)] = {"t": "2", "o": "C"}
	c[Vector2i(1, -4)] = {"t": "2", "o": "t"}
	c[Vector2i(3, -4)] = {"t": "2", "o": "T"}
	c[Vector2i(0, -3)] = {"t": "1", "o": "T"}
	c[Vector2i(1, -3)] = {"t": "1", "o": "K"}
	c[Vector2i(2, -3)] = {"t": "1", "o": "o"}
	c[Vector2i(0, -4)] = {"t": "1", "o": "N"}
	c[Vector2i(-1, -3)] = {"t": "1", "o": "M"}
	c[Vector2i(-2, -2)] = {"t": "1", "o": "h"}
	c[Vector2i(-1, -2)] = {"o": "t"}
	# Río desde el nordeste hasta el lago, con molino de agua
	c[Vector2i(4, -4)] = {"p": "R"}
	c[Vector2i(3, -3)] = {"p": "r"}
	c[Vector2i(3, -2)] = {"p": "r"}
	c[Vector2i(3, -1)] = {"p": "r", "o": "V"}
	c[Vector2i(3, 0)] = {"p": "r"}
	for cell in [Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2)]:
		c[cell] = {"t": "w"}
	c[Vector2i(1, 3)] = {"o": "l"}
	c[Vector2i(2, 2)] = {"t": "w", "o": "l"}
	# Campos y molino de viento al este
	c[Vector2i(4, -1)] = {"o": "W"}
	c[Vector2i(4, -2)] = {"o": "F"}
	c[Vector2i(4, 0)] = {"o": "F"}
	c[Vector2i(3, 1)] = {"o": "F"}
	c[Vector2i(4, -3)] = {"o": "t"}
	# Campos al sur
	for cell in [Vector2i(-4, 3), Vector2i(-3, 3), Vector2i(-2, 3), Vector2i(0, 3), Vector2i(-2, 4), Vector2i(0, 4), Vector2i(-3, 4)]:
		c[cell] = {"o": "F"}
	c[Vector2i(-4, 4)] = {"o": "T"}
	# Bosque y aserradero al oeste
	c[Vector2i(-3, 0)] = {"o": "L"}
	c[Vector2i(-4, 0)] = {"o": "T"}
	c[Vector2i(-4, 1)] = {"o": "T"}
	c[Vector2i(-3, 1)] = {"o": "T"}
	c[Vector2i(-4, 2)] = {"o": "t"}
	c[Vector2i(-3, 2)] = {"o": "s"}
	c[Vector2i(-3, -1)] = {"o": "T"}
	c[Vector2i(-2, -1)] = {"t": "1", "o": "H"}
	# Obra y corral cerca de la muralla
	c[Vector2i(-2, 3)] = {"o": "S"}
	return c


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var shadows: bool = (args[1] == "1") if args.size() > 1 else true
	var pitch: float = float(args[2]) if args.size() > 2 else 42.0
	var dist: float = float(args[3]) if args.size() > 3 else 32.0
	var fov: float = float(args[4]) if args.size() > 4 else 34.0

	var world := Node3D.new()
	root.add_child(world)
	var diorama = load("res://scripts/view/diorama.gd").new()
	world.add_child(diorama)
	var layers: Dictionary = diorama.layers_from_cells(RADIUS, _layout())
	if not layers["errors"].is_empty():
		printerr("Diseño fuera del mapa: ", layers["errors"])
		quit(1)
		return
	if not diorama.build(layers["terrain"], layers["things"], layers["paths"]):
		quit(1)
		return
	var stage = load("res://scripts/view/stage.gd").new()
	world.add_child(stage)
	stage.setup(Vector3(0, 0.5, 0.5), shadows, pitch, dist, fov)

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
