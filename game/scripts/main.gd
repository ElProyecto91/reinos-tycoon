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
const IconRectScript := preload("res://scripts/ui/icon_rect.gd")
const CalendarScript := preload("res://scripts/sim/calendar.gd")
const TradeScript := preload("res://scripts/sim/trade.gd")
const ProvinceViewScript := preload("res://scripts/ui/province_view.gd")
const Texts := preload("res://scripts/ui/texts.gd")
const Icons := preload("res://scripts/ui/icons.gd")
const UpdateCheck := preload("res://scripts/update/update_check.gd")

const SAVE_PATH := "user://partida.json"
const SETTINGS_PATH := "user://ajustes.json"
const AUTOSAVE_SECONDS := 15.0
## Multiplicador de tiempo real (0 = pausa). Con 60 s por paso, ×60 es un paso por segundo.
const SPEEDS: Array[int] = [0, 1, 60, 600]
const SPEED_LABELS: Array[String] = ["Pausa", "×1", "×60", "×600"]
const MAX_STEPS_PER_FRAME := 30
## Tiempo máximo (µs) dedicado a simular en un fotograma antes de dejarlo para el siguiente.
const FRAME_BUDGET_USEC := 12000
const BUTTON_HEIGHT := 88

## Colores cálidos (tierra, pergamino y oro viejo) para que la interfaz no choque con el paisaje 3D.
const COLOR_BACKGROUND := Color("#17130e")
const COLOR_PANEL := Color("#241d15")
const COLOR_BUTTON := Color("#3b3024")
const COLOR_BUTTON_PRESSED := Color("#5a4631")
const COLOR_BUTTON_DISABLED := Color("#2a221a")
const COLOR_ACCENT := Color("#d8a24a")
const COLOR_TEXT := Color("#f2e8d5")
const COLOR_TEXT_DISABLED := Color("#8d806b")
const COLOR_CHIP := Color(0.07, 0.05, 0.03, 0.66)

## Sesión de juego; si es null se crea la normal. Las pruebas inyectan la suya.
var session = null
## Hora Unix fija para pruebas; con -1 se usa la del dispositivo.
var fixed_now: int = -1
var game_version: String = "?"
## Si es false no se dibuja la vista 3D de la provincia (la usan las pruebas que no la necesitan y el
## jugador, desde el menú, si en su móvil no se ve bien o va lento).
var enable_3d: bool = true
## Sombras de la vista 3D (también se cambian desde el menú).
var shadows_enabled: bool = true
## Gente en movimiento en la vista 3D (cuesta batería; se puede quitar desde el menú).
var animation_enabled: bool = true
## Dónde se guardan los ajustes de pantalla; vacío = no se leen ni se guardan (pruebas).
var settings_path: String = SETTINGS_PATH
## Provincia que se muestra al arrancar (si existe en el mapa). Vacía: ninguna.
var start_province: String = ""

var _speed_index: int = 2
var _step_accumulator: float = 0.0
var _autosave_timer: float = 0.0
var _ready_ok: bool = false

var _time_label: Label
var _version_label: Label
var _speed_buttons: Array[Button] = []
var _map_view: Control
var _province_view: Control
var _center: MarginContainer
var _map_button: Button
var _map_card: PanelContainer
var _card_title: Label
var _card_emblem: Control
var _card_text: Label
var _enter_button: Button
var _season_icon: Control
var _in_province := false
## Presupuesto de simulación por fotograma (µs); las pruebas lo ponen enorme para ser deterministas.
var frame_budget_usec: int = FRAME_BUDGET_USEC
var _view_title: Label
var _view_note: Label
var _chip_title: Control
var _chip_note: Control
var _selected_id: String = ""
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
	_load_settings()
	if session == null:
		session = SessionScript.new(SAVE_PATH, game_version)
	if not session.start(_now()):
		_show_fatal("No se puede arrancar el juego:\n" + "\n".join(session.errors))
		return
	_build_ui()
	_ready_ok = true
	if start_province != "" and session.world.find_province(start_province) != null:
		_on_province_selected(start_province)
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
	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override("separation", 8)
	title_box.add_child(date_row)
	_season_icon = IconRectScript.new()
	_season_icon.custom_minimum_size = Vector2(34, 34)
	date_row.add_child(_season_icon)
	_time_label = Label.new()
	_time_label.add_theme_color_override("font_color", COLOR_ACCENT)
	date_row.add_child(_time_label)
	_map_button = Button.new()
	_map_button.text = "Mapa"
	_map_button.custom_minimum_size = Vector2(150, BUTTON_HEIGHT)
	_map_button.pressed.connect(_on_map_button_pressed)
	top.add_child(_map_button)
	var menu_button := Button.new()
	menu_button.text = "Menú"
	menu_button.custom_minimum_size = Vector2(150, BUTTON_HEIGHT)
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

	# Zona central: o la vista 3D de la provincia elegida o el mapa de provincias para elegir otra.
	_center = MarginContainer.new()
	_center.custom_minimum_size = Vector2(0, 420)
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center.size_flags_stretch_ratio = 10.0
	_center.clip_contents = true
	root.add_child(_center)
	_province_view = ProvinceViewScript.new()
	_province_view.sombras = shadows_enabled
	_province_view.animar = animation_enabled
	_center.add_child(_province_view)
	_map_view = MapViewScript.new()
	_map_view.setup(session.map, session.world)
	_map_view.province_selected.connect(_on_map_province_tapped)
	_center.add_child(_map_view)
	var chips := VBoxContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("separation", 0)
	_center.add_child(chips)
	_view_title = Label.new()
	_view_title.add_theme_font_size_override("font_size", 34)
	_view_title.add_theme_color_override("font_color", COLOR_TEXT)
	_chip_title = _chip(_view_title)
	_chip_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chips.add_child(_chip_title)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_child(spacer)
	_view_note = Label.new()
	_view_note.add_theme_font_size_override("font_size", 22)
	_view_note.add_theme_color_override("font_color", COLOR_TEXT)
	_chip_note = _chip(_view_note)
	_chip_note.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chips.add_child(_chip_note)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 300)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_stretch_ratio = 10.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_build_map_card(root)
	_panel = ProvincePanelScript.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_panel)
	_panel.setup(session.data)
	_panel.changed.connect(_on_panel_changed)

	_show_map(true)
	_version_label = Label.new()
	_version_label.text = "v%s · prototipo: provincias históricas, cifras de ejemplo" % game_version
	_version_label.add_theme_font_size_override("font_size", 20)
	_version_label.add_theme_color_override("font_color", COLOR_TEXT_DISABLED)
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_version_label)


## Tarjeta de la provincia tocada en el mapa (nombre, reino, población) con el botón para entrar en ella.
func _build_map_card(root: VBoxContainer) -> void:
	_map_card = PanelContainer.new()
	_map_card.custom_minimum_size = Vector2(0, 250)
	_map_card.size_flags_vertical = Control.SIZE_SHRINK_END
	root.add_child(_map_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_map_card.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	box.add_child(title_row)
	_card_emblem = IconRectScript.new()
	_card_emblem.custom_minimum_size = Vector2(64, 64)
	title_row.add_child(_card_emblem)
	_card_title = Label.new()
	_card_title.add_theme_font_size_override("font_size", 34)
	_card_title.add_theme_color_override("font_color", COLOR_ACCENT)
	_card_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_card_title)
	_card_text = Label.new()
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_card_text)
	_enter_button = Button.new()
	_enter_button.text = "Entrar en la provincia"
	_enter_button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	_enter_button.pressed.connect(_on_enter_pressed)
	box.add_child(_enter_button)


## Pasa a la ficha lo que viaja hacia o desde la provincia mostrada.
func _sync_caravans(province_id: String = "") -> void:
	var id: String = province_id if province_id != "" else _panel.current_province_id()
	_panel.set_caravans(TradeScript.summary_for(session.world, id) if id != "" else {})


## Pone al día la tarjeta del mapa con la provincia elegida (o la ayuda si no hay ninguna).
func _refresh_card() -> void:
	if _map_card == null:
		return
	var province = session.world.find_province(_selected_id) if _selected_id != "" else null
	_enter_button.visible = province != null
	_card_emblem.kind = ""
	if province == null:
		_card_title.text = "El mapa del año 1000"
		_card_text.text = "Toca un territorio para elegirlo. Arrastra para moverte y pellizca (o usa + y −) para acercar. Los colores son los reinos; las formas son aproximadas, no fronteras históricas."
		return
	var entry: Dictionary = session.map.find(_selected_id)
	var realm: Dictionary = session.map.realm_of(_selected_id)
	_card_title.text = province.display_name
	var lines: Array[String] = []
	var emblem: String = "emblem_" + str(entry.get("realm", ""))
	_card_emblem.kind = emblem if Icons.is_kind(emblem) else ""
	lines.append("%s · emblema de juego, no histórico" % realm.get("name", ""))
	lines.append("Población: %d · Descontento: %d de %d" % [province.population, province.unrest, session.data.rules["unrest_max"]])
	if not province.alerts.is_empty():
		var names: Array[String] = []
		for code in province.alerts:
			names.append(Texts.alert_text(code))
		lines.append("! " + "; ".join(names))
	_card_text.text = "\n".join(lines)
	_enter_button.text = "Entrar en %s" % entry.get("short", province.display_name)


## Etiqueta sobre fondo oscuro semitransparente para rotular la vista 3D.
func _chip(label: Label) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_CHIP
	box.set_corner_radius_all(12)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	chip.add_theme_stylebox_override("panel", box)
	chip.add_child(label)
	return chip


## Cambia entre la pantalla del mapa (mapa grande y tarjeta de la provincia tocada) y la de la provincia
## elegida (vista 3D y ficha). Sin provincia elegida solo hay mapa.
func _show_map(show_map: bool) -> void:
	var has_selection := _selected_id != ""
	_in_province = has_selection and not show_map
	# Sin vista 3D la provincia se mira solo en la ficha; el mapa se queda en el centro.
	_map_view.visible = not _in_province or not enable_3d
	_province_view.visible = enable_3d and _in_province
	_chip_title.visible = enable_3d and _in_province
	_chip_note.visible = enable_3d and _in_province and _view_note.text != ""
	_scroll.visible = _in_province
	_map_card.visible = not _in_province
	if _map_button != null:
		_map_button.text = "Mapa" if _in_province else "Provincia"
		_map_button.disabled = not _in_province and not has_selection
	_refresh_card()


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
			# Con muchas provincias cada paso cuesta; si se agota el presupuesto del fotograma se avanza
			# menos (la simulación va más lenta que el reloj) en vez de congelar la pantalla.
			var started := Time.get_ticks_usec()
			var done_steps := 0
			while done_steps < due:
				session.world.run_steps(1)
				done_steps += 1
				if Time.get_ticks_usec() - started > frame_budget_usec:
					_step_accumulator = 0.0
					break
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
	_season_icon.kind = CalendarScript.SEASON_ICONS[session.date()["season"]]
	_season_icon.tooltip_text = CalendarScript.SEASON_NAMES[session.date()["season"]]
	_map_view.queue_redraw()
	_refresh_card()
	_sync_caravans()
	_panel.refresh()
	_refresh_view()


## Pone al día la vista 3D y sus rótulos con la provincia elegida (solo reconstruye si cambió lo que se ve).
func _refresh_view() -> void:
	if _selected_id == "":
		return
	var province = session.world.find_province(_selected_id)
	if province == null:
		return
	if enable_3d:
		_province_view.mostrar(province)
	_view_title.text = "%s · %d habitantes" % [province.display_name, province.population]
	var hidden: Dictionary = _province_view.ocultos() if enable_3d else {}
	var total := 0
	for n in hidden.values():
		total += int(n)
	_view_note.text = "" if total == 0 else "%d edificio(s) u obra(s) fuera de vista (están en la ficha)" % total
	_chip_note.visible = enable_3d and _province_view.visible and total > 0


func _neighbor_names(province_id: String) -> Array:
	var names: Array = []
	for n in session.map.neighbors_of(province_id):
		names.append(session.map.find(n)["name"])
	return names


# --- Acciones ----------------------------------------------------------------------

## Entra en una provincia: ficha y vista 3D.
func _on_province_selected(province_id: String) -> void:
	if _choose(province_id):
		_show_map(false)
		_refresh_view()


## Toque en el mapa: elige la provincia (tarjeta y ficha preparadas) pero se queda en el mapa.
func _on_map_province_tapped(province_id: String) -> void:
	if _choose(province_id):
		_show_map(true)
		_refresh_view()


func _choose(province_id: String) -> bool:
	var province = session.world.find_province(province_id)
	if province == null:
		return false
	_selected_id = province_id
	_map_view.selected_id = province_id
	_map_view.queue_redraw()
	_sync_caravans(province_id)
	_panel.show_province(province, _neighbor_names(province_id))
	_scroll.scroll_vertical = 0
	_refresh_card()
	return true


func _on_enter_pressed() -> void:
	_show_map(false)
	_refresh_view()


func _on_map_button_pressed() -> void:
	_show_map(_in_province)


func _on_panel_changed() -> void:
	_map_view.queue_redraw()
	_refresh_card()
	_refresh_view()


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
		{"text": "Vista 3D: %s" % ("sí" if enable_3d else "no"), "action": _on_toggle_3d_pressed},
		{"text": "Sombras de la vista 3D: %s" % ("sí" if shadows_enabled else "no"), "action": _on_toggle_shadows_pressed},
		{"text": "Gente en movimiento: %s" % ("sí" if animation_enabled else "no"), "action": _on_toggle_animation_pressed},
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


## Ajustes de pantalla (vista 3D y sombras): un JSON pequeño aparte de la partida, para que quien no
## vea bien el 3D en su móvil pueda quitarlo sin perder nada. Un archivo ilegible se ignora.
func _load_settings() -> void:
	if settings_path == "" or not FileAccess.file_exists(settings_path):
		return
	var datos: Dictionary = interpretar_ajustes(FileAccess.get_file_as_string(settings_path))
	enable_3d = datos.get("view_3d", enable_3d)
	shadows_enabled = datos.get("shadows", shadows_enabled)
	animation_enabled = datos.get("animation", animation_enabled)


## Del texto de un archivo de ajustes devuelve solo lo válido: las claves «view_3d», «shadows» y «animation» que sean
## verdadero o falso. Texto que no es JSON, JSON que no es un objeto o valores de otro tipo se ignoran.
static func interpretar_ajustes(texto: String):  # sin tipo de retorno a propósito: si fallase por dentro, devolvería null y la prueba lo vería (con «-> Dictionary» Godot devuelve un diccionario vacío y el fallo pasaría inadvertido)
	var json := JSON.new()
	if json.parse(texto) != OK:
		return {}
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var salida := {}
	for clave in ["view_3d", "shadows", "animation"]:
		if typeof(parsed.get(clave)) == TYPE_BOOL:
			salida[clave] = parsed[clave]
	return salida


func _save_settings() -> void:
	if settings_path == "":
		return
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		return  # no es grave: el ajuste solo vale esta vez
	file.store_string(JSON.stringify({"view_3d": enable_3d, "shadows": shadows_enabled, "animation": animation_enabled}))


func _on_toggle_3d_pressed() -> void:
	enable_3d = not enable_3d
	_save_settings()
	_show_map(not _in_province)
	_refresh_view()


func _on_toggle_shadows_pressed() -> void:
	shadows_enabled = not shadows_enabled
	_save_settings()
	_province_view.set_sombras(shadows_enabled)


func _on_toggle_animation_pressed() -> void:
	animation_enabled = not animation_enabled
	_save_settings()
	_province_view.set_animacion(animation_enabled)


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
	_selected_id = ""
	_province_view.mostrar(null)
	_show_map(true)
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
