extends SceneTree
## Captura de la pantalla principal REAL del juego (main.tscn) para revisarla a ojo; no es una prueba.
## Uso:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path game --rendering-driver opengl3 \
##     --resolution 1080x2400 -s ../tools/captura_juego.gd -- salida.png [provincia] [construidos] [obras] [mapa:0|1] [pasos]
## construidos / obras: tipos separados por comas (house,farm,farm…) que se añaden ya terminados o como obra.
## pasos: pasos de simulación que se avanzan antes de la captura.
## Limitación: dibujado por software (llvmpipe), con la partida de prueba en user://captura; no mide el
## rendimiento del móvil.

const SESSION := "res://scripts/sim/game_session.gd"
const DIR := "user://captura"
const T0 := 1800000000


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var provincia: String = args[1] if args.size() > 1 else "cordoba"
	var extra: String = args[2] if args.size() > 2 else ""
	var obras: String = args[3] if args.size() > 3 else ""
	var mapa: bool = (args[4] == "1") if args.size() > 4 else false
	var pasos: int = int(args[5]) if args.size() > 5 else 0
	var soldados: int = int(args[6]) if args.size() > 6 else 0
	var desplazar: int = int(args[7]) if args.size() > 7 else 0
	var detalle: String = args[8] if args.size() > 8 else ""

	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.open(DIR).get_files():
		DirAccess.remove_absolute(DIR + "/" + f)
	var main = load("res://main.tscn").instantiate()
	main.session = load(SESSION).new(DIR + "/partida.json", "captura")
	main.fixed_now = T0
	main.start_province = provincia
	root.add_child(main)
	await process_frame
	var p = main.session.world.find_province(provincia)
	if p == null:
		printerr("Provincia desconocida: ", provincia)
		quit(1)
		return
	for tipo in extra.split(",", false):
		p.add_building(tipo)
	for tipo in obras.split(",", false):
		p.store.seed_initial("wood", 20000)
		p.store.seed_initial("coin", 50000)
		if not p.start_construction(tipo):
			printerr("No se pudo empezar la obra ", tipo, ": ", p.last_error)
	if soldados > 0:
		p.store.seed_initial("weapons", 3000)
		if not p.recruit(soldados):
			printerr("No se pudo reclutar: ", p.last_error)
	if pasos > 0:
		main.session.world.run_steps(pasos)
	main._refresh_all()
	if mapa:
		main._show_map(true)
	if detalle != "":
		main._panel.select_detail(detalle)
	for i in range(8):
		await process_frame
	main._scroll.scroll_vertical = desplazar
	for i in range(4):
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("guardada ", out, "  3D: ", main._province_view.aspecto(), " triángulos propios: ", main._province_view.triangulos(), " ocultos: ", main._province_view.ocultos())
	quit()
