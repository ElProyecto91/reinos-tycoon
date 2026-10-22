extends SceneTree
## Hoja de contacto de los iconos de la interfaz (para revisarlos a ojo; no es una prueba).
## Uso: xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 1080x1000 -s ../tools/captura_iconos.gd -- salida.png

const Icons := preload("res://scripts/ui/icons.gd")


class Hoja extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#2b211a"))
		var todos: Array = []
		todos.append_array(Icons.GOODS)
		todos.append_array(Icons.BUILDINGS)
		todos.append_array(Icons.SYMBOLS)
		var font := ThemeDB.fallback_font
		for i in todos.size():
			var col := i % 8
			var row := i / 8
			var x := 20.0 + col * 128.0
			var y := 20.0 + row * 170.0
			Icons.draw(self, todos[i], Rect2(x, y, 110, 110))
			Icons.draw(self, todos[i], Rect2(x + 40, y + 118, 40, 40))
			draw_string(font, Vector2(x, y + 168), todos[i], HORIZONTAL_ALIGNMENT_LEFT, 120, 16, Color.WHITE)


func _init() -> void:
	await process_frame
	var out: String = OS.get_cmdline_user_args()[0]
	var hoja := Hoja.new()
	hoja.size = Vector2(1080, 1000)
	root.add_child(hoja)
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("guardada ", out)
	quit()
