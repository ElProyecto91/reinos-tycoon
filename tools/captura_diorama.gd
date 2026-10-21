extends SceneTree
## Captura del diorama 3D para revisarlo a ojo (no es una prueba automática).
## Uso:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path game --rendering-driver opengl3 \
##     --resolution 1080x2400 -s ../tools/captura_diorama.gd -- salida.png [sombras:0|1] [inclinacion] [distancia]
## Limitación: dibujado por software (llvmpipe); no mide el rendimiento del móvil.

const TERRAIN := [
	"11111",
	"111111",
	"1100000",
	"10000000",
	"000000000",
	"0000ww00",
	"0000000",
	"000000",
	"00000",
]
const THINGS := [
	"NhCHM",
	"QTYhTt",
	"TtoOoFW",
	"sTFEoFFt",
	"tTL.SoFFt",
	"tTsD..Ft",
	"KxxXxxK",
	"sFFFFs",
	"TsttT",
]

func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var shadows: bool = (args[1] == "1") if args.size() > 1 else true
	var pitch: float = float(args[2]) if args.size() > 2 else 52.0
	var dist: float = float(args[3]) if args.size() > 3 else 34.0

	var world := Node3D.new()
	root.add_child(world)
	var diorama = load("res://scripts/view/diorama.gd").new()
	world.add_child(diorama)
	if not diorama.build(TERRAIN, THINGS):
		quit(1)
		return

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.80, 0.93)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.84, 0.95)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -38, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = shadows
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	world.add_child(sun)

	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 34.0
	var target := Vector3(0, 0.5, 0.5)
	var a := deg_to_rad(pitch)
	cam.position = target + Vector3(0, sin(a), cos(a)) * dist
	world.add_child(cam)
	cam.look_at(target, Vector3.UP)
	cam.current = true

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
