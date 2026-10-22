extends Control
## Un icono suelto (ver icons.gd) que se pone en cualquier contenedor. No recibe toques.

const Icons := preload("res://scripts/ui/icons.gd")

var kind: String = "":
	set(value):
		if value != kind:
			kind = value
			queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if kind == "":
		return
	var side := minf(size.x, size.y)
	Icons.draw(self, kind, Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)))
