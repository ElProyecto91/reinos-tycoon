extends SceneTree
## Captura de la interfaz para revisarla a ojo (no es una prueba automática).
## Uso, con ventana virtual y dibujado por software:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path game --rendering-driver opengl3 \
##     --resolution 1080x2400 -s ../tools/captura_ui.gd -- salida.png [escenario] [provincia] [pasos] [desplazamiento]
## Escenarios: inicio | hambre | obra | informe
## Limitación: es el mismo código y motor que el APK, pero no es un móvil: no muestra barra de
## navegación, cámara frontal ni bordes redondeados, y el dibujado por software puede diferir
## en detalles menores. Para comprobar de verdad hay que instalar el APK.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var scenario: String = args[1] if args.size() > 1 else "inicio"
	var province_id: String = args[2] if args.size() > 2 else ""
	var steps: int = int(args[3]) if args.size() > 3 else 0
	var scroll_to: int = int(args[4]) if args.size() > 4 else 0
	var dir := "user://captura"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.open(dir).get_files():
		DirAccess.remove_absolute(dir + "/" + f)
	var session = load("res://scripts/sim/game_session.gd").new(dir + "/partida.json", "0.0.captura")
	var main = load("res://main.tscn").instantiate()
	main.fixed_now = 1800000000
	main.session = session
	if scenario == "informe":
		# Guardar una partida y volver 3 h 20 min después
		session.start(1800000000)
		session.world.run_steps(40)
		session.save(1800000000)
		session = load("res://scripts/sim/game_session.gd").new(dir + "/partida.json", "0.0.captura")
		main.session = session
		main.fixed_now = 1800000000 + 200 * 60
	root.add_child(main)
	await process_frame
	if scenario != "informe":
		main._speed_index = 0
		session.world.run_steps(steps)
		if scenario == "hambre":
			var p = session.world.find_province(province_id)
			for good in ["bread", "wheat", "flour"]:
				p.store.remove(good, p.store.stock(good), "consumed")
			for b in p.buildings:
				p.set_enabled(b["uid"], false)
			session.world.run_steps(40)
		if scenario == "obra":
			var p = session.world.find_province(province_id)
			p.start_construction("house")
			p.start_construction("granary")
			session.world.run_steps(2)
		if province_id != "":
			main._map_view.select(province_id)
		main._refresh_all()
	for i in range(4):
		await process_frame
	main._scroll.scroll_vertical = scroll_to
	for i in range(4):
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("guardada ", out)
	quit()
