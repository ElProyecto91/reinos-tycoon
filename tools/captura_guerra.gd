extends SceneTree
## Capturas de la guerra en la pantalla principal REAL (no es una prueba). Uso:
##   xvfb-run -a -s "-screen 0 1080x2400x24" godot --path game --rendering-driver opengl3 \
##     --resolution 1080x2400 -s ../tools/captura_guerra.gd -- salida.png escena
## escena: "tarjeta" (mapa con la tarjeta de una provincia atacable y un ejército en marcha),
##         "informe" (informe de batalla tras conquistar), "conquista" (mapa tras conquistar, sin el informe), "ajena" (ficha de una provincia ajena, solo lectura), "selector" (elegir reino), "aviso" (ejército enemigo en marcha), "perdida" (informe de una provincia perdida).
## Limitación: dibujado por software (llvmpipe); no mide el rendimiento del móvil.

const SESSION := "res://scripts/sim/game_session.gd"
const WAR := "res://scripts/sim/war.gd"
const DIR := "user://captura"


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var escena: String = args[1] if args.size() > 1 else "tarjeta"
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.open(DIR).get_files():
		DirAccess.remove_absolute(DIR + "/" + f)
	var main = load("res://main.tscn").instantiate()
	main.session = load(SESSION).new(DIR + "/partida.json", "captura")
	main.fixed_now = 1800000000
	root.add_child(main)
	await process_frame
	var world = main.session.world
	var war = load(WAR)
	if escena == "selector":
		main._show_realm_picker()
		await _frames(8)
		_guardar(out)
		return
	if escena == "aviso" or escena == "perdida":
		# Un León pasivo: se avanza hasta que un rival lance su primer ataque (o hasta que caiga una provincia).
		var limite := 24 * 150
		while limite > 0 and (world.incoming_count == 0 if escena == "aviso" else world.battle_count == 0):
			world.run_steps(1)
			limite -= 1
		main._refresh_all()
		main._check_incoming() if escena == "aviso" else main._check_battles()
		main._show_map(true)
		await _frames(8)
		_guardar(out)
		return
	var target: String = war.attackable(world)[0]
	var origin := ""
	for n in world.trade_links[target]["neighbors"]:
		if world.owners[n] == "leon":
			origin = n
	world.find_province(origin).recruits = 400
	main._choose(target)
	if escena == "informe":
		main._attack_button.pressed.emit()
		main._close_modal()
		world.run_steps(int(world.data.rules["war_march_steps_per_hop"]))
		main._refresh_all()
		main._check_battles()
		main._show_map(true)
	elif escena == "conquista":
		main._attack_button.pressed.emit()
		main._close_modal()
		world.run_steps(int(world.data.rules["war_march_steps_per_hop"]))
		main._refresh_all()
		main._check_battles()
		main._close_modal()
		main._show_map(true)
	elif escena == "ajena":
		main._show_map(false)
	else:
		world.find_province(origin).recruits = 400
		war.send(world, origin, target, 150)
		world.run_steps(6)
		main._refresh_all()
		main._show_map(true)
	for i in range(8):
		await process_frame
	if escena == "ajena":
		main._scroll.scroll_vertical = 1250
		for i in range(4):
			await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("guardada ", out, " objetivo ", target, " origen ", origin)
	quit()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _guardar(out: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("guardada ", out)
	quit()
