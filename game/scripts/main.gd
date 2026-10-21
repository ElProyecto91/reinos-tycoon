extends Control
## Pantalla de arranque de la fase 0.
## Solo comprueba que el proyecto abre y muestra la versión. No contiene lógica de juego.


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "?")
	var label := Label.new()
	label.text = "Reinos Tycoon\nv%s (fase 0)\nArranque correcto" % version
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
