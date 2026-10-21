extends VBoxContainer
## Ficha de la provincia seleccionada: población, trabajo, descontento, avisos, existencias,
## edificios con su estado y motivo, obras, y botones para construir.
##
## Los textos se actualizan en su sitio (no se reconstruyen los controles) para que un
## botón no desaparezca entre que el dedo lo pulsa y lo suelta.

signal changed

const Texts := preload("res://scripts/ui/texts.gd")

const COLOR_DANGER := "#e5654f"
const COLOR_WARNING := "#e0b44c"
const COLOR_MUTED := "#9fb0c3"
const COLOR_OK := "#6cc08b"

var _data = null
var _province = null
var _neighbor_names: Array = []

var _hint: Label
var _body: VBoxContainer
var _title: Label
var _summary: RichTextLabel
var _alerts: RichTextLabel
var _stock: RichTextLabel
var _buildings: RichTextLabel
var _projects: RichTextLabel
var _feedback: Label
var _build_buttons := {}


func setup(game_data) -> void:
	_data = game_data
	add_theme_constant_override("separation", 14)
	_hint = Label.new()
	_hint.text = "Toca una provincia del mapa para ver su ficha."
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	add_child(_body)
	_title = _heading("", 34)
	_summary = _text_block()
	_alerts = _text_block()
	_heading("Existencias", 28)
	_stock = _text_block()
	_heading("Edificios", 28)
	_buildings = _text_block()
	_heading("Obras en curso", 28)
	_projects = _text_block()
	_heading("Construir", 28)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_feedback)
	for type_id in _data.buildings.keys():
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 96)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = false
		button.pressed.connect(_on_build_pressed.bind(type_id))
		_body.add_child(button)
		_build_buttons[type_id] = button
	_body.visible = false


func show_province(province, neighbor_names: Array) -> void:
	_province = province
	_neighbor_names = neighbor_names
	_feedback.text = ""
	refresh()


func current_province_id() -> String:
	return "" if _province == null else _province.id


## Texto de los botones de construcción y su estado, para las pruebas.
func build_button(type_id: String) -> Button:
	return _build_buttons.get(type_id, null)


func feedback_text() -> String:
	return _feedback.text


func refresh() -> void:
	_hint.visible = _province == null
	_body.visible = _province != null
	if _province == null:
		return
	var p = _province
	var rules: Dictionary = _data.rules
	_title.text = p.display_name
	var lines: Array[String] = []
	lines.append("Población: %d (vivienda para %d)" % [p.population, p.housing_capacity()])
	lines.append("Trabajo: %d asignados de %d de mano de obra" % [p.assigned_labor(), p.labor_force()])
	lines.append("Edificios: %d de %d posibles (incluidas las obras)" % [p.buildings.size() + p.projects.size(), rules["max_buildings"]])
	lines.append("Consumo de alimento: %s por paso" % Texts.amount(p.population * rules["food_per_person"]))
	lines.append("Descontento: %d de %d · velocidad de trabajo %d %%" % [p.unrest, rules["unrest_max"], p.productivity_percent()])
	if p.hunger_steps > 0:
		lines.append("Pasos seguidos sin comida suficiente: %d" % p.hunger_steps)
	if not _neighbor_names.is_empty():
		lines.append("[color=%s]Vecinas: %s[/color]" % [COLOR_MUTED, ", ".join(_neighbor_names)])
	_summary.text = "\n".join(lines)
	_alerts.visible = not p.alerts.is_empty()
	var alert_lines: Array[String] = []
	for code in p.alerts:
		var severity := Texts.alert_severity([code])
		var color := COLOR_DANGER if severity == 2 else (COLOR_WARNING if severity == 1 else COLOR_MUTED)
		alert_lines.append("[color=%s]%s %s[/color]" % [color, "!" if severity > 0 else "·", Texts.alert_text(code)])
	_alerts.text = "\n".join(alert_lines)
	_feedback.visible = _feedback.text != ""
	_stock.text = _stock_text(p)
	_buildings.text = _buildings_text(p)
	_projects.text = _projects_text(p)
	_update_build_buttons(p)


func _stock_text(p) -> String:
	var lines: Array[String] = []
	lines.append("[color=%s]Almacén: %s de %s usado[/color]" % [COLOR_MUTED, Texts.amount(p.store.used_space()), Texts.amount(p.store.capacity)])
	for good_id in _data.goods.keys():
		if _data.is_physical(good_id):
			lines.append("%s: %s (máx. %s)" % [Texts.good_name(_data, good_id), Texts.amount(p.store.stock(good_id)), Texts.amount(p.store.limit(good_id))])
		else:
			lines.append("%s: %s" % [Texts.good_name(_data, good_id), Texts.amount(p.store.stock(good_id))])
	return "\n".join(lines)


func _buildings_text(p) -> String:
	if p.buildings.is_empty():
		return "Ninguno."
	var lines: Array[String] = []
	for b in p.buildings:
		var t: Dictionary = _data.buildings[b["type"]]
		var status: String = b["status"]
		var color := COLOR_OK if status == "running" else (COLOR_MUTED if status in ["idle", "disabled"] else COLOR_WARNING)
		var line := "%s — [color=%s]%s[/color]" % [t["name"], color, Texts.status_text(status)]
		if t["workers"] > 0:
			line += " · trabajadores %d/%d" % [b["workers"], t["workers"]]
		if not b["missing"].is_empty():
			line += "\n    Falta: " + Texts.goods_text(_data, b["missing"])
		if not t["outputs"].is_empty():
			var recipe := "    Produce %s cada %d pasos" % [Texts.goods_text(_data, t["outputs"]), t["cycle_steps"]]
			if not t["inputs"].is_empty():
				recipe += " con " + Texts.goods_text(_data, t["inputs"])
			line += "\n[color=%s]%s[/color]" % [COLOR_MUTED, recipe]
		if t["storage_capacity"] > 0:
			line += "\n[color=%s]    Añade %s de capacidad[/color]" % [COLOR_MUTED, Texts.amount(t["storage_capacity"])]
		if t["housing"] > 0:
			line += "\n[color=%s]    Vivienda para %d[/color]" % [COLOR_MUTED, t["housing"]]
		lines.append(line)
	return "\n".join(lines)


func _projects_text(p) -> String:
	if p.projects.is_empty():
		return "Ninguna."
	var lines: Array[String] = []
	for project in p.projects:
		var line := "%s — faltan %d pasos" % [Texts.building_name(_data, project["type"]), project["remaining"]]
		if project["workers"] <= 0:
			line += " [color=%s](sin trabajadores: no avanza)[/color]" % COLOR_WARNING
		lines.append(line)
	return "\n".join(lines)


func _update_build_buttons(p) -> void:
	var full: bool = p.projects.size() >= _data.rules["max_projects"]
	var no_room: bool = p.buildings.size() + p.projects.size() >= _data.rules["max_buildings"]
	for type_id in _build_buttons.keys():
		var t: Dictionary = _data.buildings[type_id]
		var button: Button = _build_buttons[type_id]
		var can_afford: bool = p.store.can_afford(t["build_cost"])
		var note := ""
		if no_room:
			note = "  (sin sitio)"
		elif full:
			note = "  (obras al máximo)"
		elif not can_afford:
			note = "  (faltan recursos)"
		button.text = "Construir %s%s\nCoste: %s · %d pasos" % [t["name"], note, Texts.goods_text(_data, t["build_cost"]), t["build_steps"]]
		button.disabled = no_room or full or not can_afford


func _on_build_pressed(type_id: String) -> void:
	if _province == null:
		return
	if _province.start_construction(type_id):
		_feedback.text = "Obra iniciada: %s." % Texts.building_name(_data, type_id)
	else:
		_feedback.text = "No se pudo construir: %s." % _province.last_error
	refresh()
	changed.emit()


func _heading(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(label)
	return label


func _text_block() -> RichTextLabel:
	var block := RichTextLabel.new()
	block.bbcode_enabled = true
	block.fit_content = true
	block.scroll_active = false
	block.selection_enabled = false
	block.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_child(block)
	return block
