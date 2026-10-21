extends Control
## Pantalla principal (fase 1): mapa de provincias, ficha de la provincia elegida,
## velocidad de la simulación, guardado automático y resumen al volver tras una ausencia.
##
## La lógica del juego vive en scripts/sim/; aquí solo se monta la interfaz y se reparte
## el tiempo. Todo está pensado para móvil en vertical: botones de al menos 88 px de alto
## (en la base de 720 px de ancho), nada depende de pasar el dedo por encima.

const SessionScript := preload("res://scripts/sim/game_session.gd")
const MapViewScript := preload("res://scripts/ui/map_view.gd")
const ProvincePanelScript := preload("res://scripts/ui/province_panel.gd")
const Texts := preload("res://scripts/ui/texts.gd")
const UpdateCheck := preload("res://scripts/update/update_check.gd")

const SAVE_PATH := "user://partida.json"
const AUTOSAVE_SECONDS := 15.0
## Multiplicador de tiempo real (0 = pausa). Con 60 s por paso, ×60 es un paso por segundo.
const SPEEDS: Array[int] = [0, 1, 60, 600]
const SPEED_LABELS: Array[String] = ["Pausa", "×1", "×60", "×600"]
const MAX_STEPS_PER_FRAME := 30
const BUTTON_HEIGHT := 88

const COLOR_BACKGROUND := Color("#161d29")
const COLOR_PANEL := Color("#202a3a")
const COLOR_BUTTON := Color("#2f3d54")
const COLOR_BUTTON_PRESSED := Color("#46597a")
const COLOR_BUTTON_DISABLED := Color("#252e3d")
const COLOR_ACCENT := Color("#e0b44c")
const COLOR_TEXT := Color("#eef2f7")
const COLOR_TEXT_DISABLED := Color("#7c8a9d")

## Sesión de juego; si es null se crea la normal. Las pruebas inyectan la suya.
var session = null
## Hora Unix fija para pruebas; con -1 se usa la del dispositivo.
var fixed_now: int = -1
var game_version: String = "?"

var _speed_index: int = 2
var _step_accumulator: float = 0.0
var _autosave_timer: float = 0.0
var _ready_ok: bool = false

var _time_label: Label
var _version_label: Label
var _speed_buttons: Array[Button] = []
var _map_view: Control
var _panel: VBoxContainer
var _scroll: ScrollContainer
var _modal_layer: Control = null
var _pending_update: HTTPRequest = null


func _ready() -> void:
	game_version = ProjectSettings.get_setting("application/config/version", "?")
	theme = _make_theme()
	var background := ColorRect.new()
	background.color = COLOR_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	if session == null:
		session = SessionScript.new(SAVE_PATH, game_version)
	if not session.start(_now()):
		_show_fatal("No se puede arrancar el juego:\n" + "\n".join(session.errors))
		return
	_build_ui()
	_ready_ok = true
	_refresh_all()
	if session.notice != "":
		_show_modal("Aviso", session.notice, [{"text": "Entendido"}])
	elif not session.last_report.is_empty() and _report_worth_showing(session.last_report):
		_show_offline_report(session.last_report)


func _now() -> int:
	return fixed_now if fixed_now >= 0 else int(Time.get_unix_time_from_system())


# --- Construcción de la interfaz ---------------------------------------------------

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	top.add_child(title_box)
	var title := Label.new()
	title.text = "Reinos Tycoon"
	title.add_theme_font_size_override("font_size", 32)
	title_box.add_child(title)
	_time_label = Label.new()
	_time_label.add_theme_color_override("font_color", COLOR_ACCENT)
	title_box.add_child(_time_label)
	var menu_button := Button.new()
	menu_button.text = "Menú"
	menu_button.custom_minimum_size = Vector2(170, BUTTON_HEIGHT)
	menu_button.pressed.connect(_on_menu_pressed)
	top.add_child(menu_button)

	var speed_bar := HBoxContainer.new()
	speed_bar.add_theme_constant_override("separation", 8)
	root.add_child(speed_bar)
	for i in range(SPEEDS.size()):
		var button := Button.new()
		button.text = SPEED_LABELS[i]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_speed_pressed.bind(i))
		speed_bar.add_child(button)
		_speed_buttons.append(button)
	_update_speed_buttons()

	_map_view = MapViewScript.new()
	_map_view.custom_minimum_size = Vector2(0, 420)
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_stretch_ratio = 10.0
	_map_view.setup(session.map, session.world)
	_map_view.province_selected.connect(_on_province_selected)
	root.add_child(_map_view)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 300)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_stretch_ratio = 10.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_panel = ProvincePanelScript.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_panel)
	_panel.setup(session.data)
	_panel.changed.connect(_on_panel_changed)

	_version_label = Label.new()
	_version_label.text = "v%s · prototipo: provincias históricas, cifras de ejemplo" % game_version
	_version_label.add_theme_font_size_override("font_size", 20)
	_version_label.add_theme_color_override("font_color", COLOR_TEXT_DISABLED)
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_version_label)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	t.set_color("font_color", "Label", COLOR_TEXT)
	t.set_color("default_color", "RichTextLabel", COLOR_TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 26)
	for state in ["normal", "hover", "focus"]:
		t.set_stylebox(state, "Button", _box(COLOR_BUTTON))
	t.set_stylebox("pressed", "Button", _box(COLOR_BUTTON_PRESSED))
	t.set_stylebox("disabled", "Button", _box(COLOR_BUTTON_DISABLED))
	var checked := _box(COLOR_BUTTON_PRESSED)
	checked.border_color = COLOR_ACCENT
	checked.set_border_width_all(4)
	t.set_stylebox("hover_pressed", "Button", checked)
	t.set_color("font_color", "Button", COLOR_TEXT)
	t.set_color("font_hover_color", "Button", COLOR_TEXT)
	t.set_color("font_pressed_color", "Button", COLOR_TEXT)
	t.set_color("font_hover_pressed_color", "Button", COLOR_TEXT)
	t.set_color("font_focus_color", "Button", COLOR_TEXT)
	t.set_color("font_disabled_color", "Button", COLOR_TEXT_DISABLED)
	t.set_stylebox("panel", "PanelContainer", _box(COLOR_PANEL))
	return t


func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(14)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


# --- Tiempo ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _ready_ok:
		return
	var speed: int = SPEEDS[_speed_index]
	if speed > 0:
		_step_accumulator += delta * float(speed)
		var step_seconds: float = float(session.data.rules["step_seconds"])
		var due := int(_step_accumulator / step_seconds)
		if due > 0:
			_step_accumulator -= float(due) * step_seconds
			if due > MAX_STEPS_PER_FRAME:
				due = MAX_STEPS_PER_FRAME
				_step_accumulator = 0.0
			session.world.run_steps(due)
			_refresh_all()
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_SECONDS:
		_autosave_timer = 0.0
		_save_now(false)


func _notification(what: int) -> void:
	if not _ready_ok:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_now(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		var report: Dictionary = session.resume(_now())
		_refresh_all()
		if _report_worth_showing(report):
			_show_offline_report(report)


func _report_worth_showing(report: Dictionary) -> bool:
	return report.get("steps", 0) > 0 or report.get("clock_problem", "") != ""


func _save_now(show_result: bool) -> void:
	var error: String = session.save(_now())
	if error != "":
		_show_modal("No se pudo guardar", error, [{"text": "Entendido"}])
	elif show_result:
		_show_modal("Guardado", "La partida está guardada.", [{"text": "Aceptar"}])


# --- Actualización de pantalla -----------------------------------------------------

func _refresh_all() -> void:
	_time_label.text = session.time_text()
	_map_view.queue_redraw()
	_panel.refresh()


func _neighbor_names(province_id: String) -> Array:
	var names: Array = []
	for n in session.map.neighbors_of(province_id):
		names.append(session.map.find(n)["name"])
	return names


# --- Acciones ----------------------------------------------------------------------

func _on_province_selected(province_id: String) -> void:
	var province = session.world.find_province(province_id)
	if province != null:
		_panel.show_province(province, _neighbor_names(province_id))
		_scroll.scroll_vertical = 0


func _on_panel_changed() -> void:
	_map_view.queue_redraw()


func _on_speed_pressed(index: int) -> void:
	_speed_index = index
	_step_accumulator = 0.0
	_update_speed_buttons()


func _update_speed_buttons() -> void:
	for i in range(_speed_buttons.size()):
		_speed_buttons[i].button_pressed = i == _speed_index


func _on_menu_pressed() -> void:
	_show_modal("Menú", "Reinos Tycoon v%s\nPrototipo: provincias históricas aproximadas hacia el año 1000; las cifras de partida son de ejemplo.\nSe guarda solo cada %d s y al salir." % [game_version, int(AUTOSAVE_SECONDS)], [
		{"text": "Guardar ahora", "action": _on_save_pressed},
		{"text": "Buscar actualización", "action": _on_update_pressed},
		{"text": "Medir velocidad", "action": _on_measure_pressed},
		{"text": "Partida nueva", "action": _on_new_game_pressed},
		{"text": "Cerrar"},
	])


## Consulta manual de versión nueva: solo al pulsar el botón, nunca sola. Necesita Internet;
## sin conexión avisa y el juego sigue funcionando igual.
func _on_update_pressed() -> void:
	_cancel_update()
	_show_modal("Buscando actualización", "Consultando la última versión publicada…", [{"text": "Cancelar", "action": _cancel_update}])
	var request := HTTPRequest.new()
	request.timeout = 10.0
	add_child(request)
	_pending_update = request
	request.request_completed.connect(_on_update_response.bind(request))
	var error := request.request(UpdateCheck.LATEST_URL, ["User-Agent: ReinosTycoon", "Accept: application/vnd.github+json"])
	if error != OK:
		_cancel_update()
		_show_update_result(UpdateCheck.describe(0, "", game_version))


func _cancel_update() -> void:
	if _pending_update != null:
		_pending_update.cancel_request()
		_pending_update.queue_free()
		_pending_update = null


func _on_update_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	if request != _pending_update:
		request.queue_free()
		return  # el jugador canceló mientras tanto
	_pending_update = null
	request.queue_free()
	var shown_code := code if result == HTTPRequest.RESULT_SUCCESS else 0
	_show_update_result(UpdateCheck.describe(shown_code, body.get_string_from_utf8(), game_version))


func _show_update_result(outcome: Dictionary) -> void:
	var buttons: Array = []
	if outcome["kind"] == "newer" and outcome["page_url"] != "":
		buttons.append({"text": "Abrir la página de descarga", "action": OS.shell_open.bind(outcome["page_url"])})
	buttons.append({"text": "Cerrar"})
	_show_modal("Actualización", outcome["message"], buttons)


func _on_measure_pressed() -> void:
	_show_modal("Velocidad de la simulación", Texts.speed_text(session.measure_speed(600)), [{"text": "Cerrar"}])


func _on_save_pressed() -> void:
	_save_now(true)


func _on_new_game_pressed() -> void:
	_show_modal("¿Empezar de nuevo?", "Se perderá la partida actual. Esta acción no se puede deshacer.", [
		{"text": "Sí, empezar de nuevo", "action": _confirm_new_game},
		{"text": "Cancelar"},
	])


func _confirm_new_game() -> void:
	if not session.new_game(_now()):
		_show_modal("Error", "No se pudo crear la partida nueva:\n" + "\n".join(session.errors), [{"text": "Entendido"}])
		return
	_map_view.setup(session.map, session.world)
	_panel.show_province(null, [])
	_save_now(false)
	_refresh_all()


func _show_offline_report(report: Dictionary) -> void:
	_show_modal("Mientras estabas fuera", Texts.offline_text(session.data, report), [{"text": "Continuar"}])


# --- Ventanas modales ---------------------------------------------------------------

## buttons: lista de {"text": String, "action": Callable (opcional)}
func _show_modal(title: String, body: String, buttons: Array) -> void:
	_close_modal()
	_modal_layer = Control.new()
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", COLOR_ACCENT)
	box.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(560, 0)
	scroll.add_child(text)
	# La altura del texto no puede pasar del 55 % de la pantalla; si lo supera, se desplaza.
	scroll.custom_minimum_size.y = minf(text.get_combined_minimum_size().y, maxf(size.y, 1280.0) * 0.55)
	for entry in buttons:
		var button := Button.new()
		button.text = entry["text"]
		button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		button.pressed.connect(_on_modal_button.bind(entry.get("action", Callable())))
		box.add_child(button)


func _on_modal_button(action: Callable) -> void:
	_close_modal()
	if action.is_valid():
		action.call()


func _close_modal() -> void:
	if _modal_layer != null:
		_modal_layer.queue_free()
		_modal_layer = null


func has_modal() -> bool:
	return _modal_layer != null


func _show_fatal(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(label)
