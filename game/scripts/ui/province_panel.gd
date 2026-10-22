extends VBoxContainer
## Ficha de la provincia seleccionada, hecha de símbolos: cifras clave con icono, avisos, existencias,
## edificios agrupados por tipo, obras, ejército y botones para construir. El texto queda para una
## línea de detalle que aparece al pulsar una ficha (nombre y valores exactos).
##
## Las fichas se actualizan en su sitio (no se reconstruyen) para que un botón no desaparezca entre que
## el dedo lo pulsa y lo suelta. Solo la zona de detalle se rehace, y solo cuando cambia su contenido.

signal changed

const CalendarScript := preload("res://scripts/sim/calendar.gd")
const Texts := preload("res://scripts/ui/texts.gd")
const Tile := preload("res://scripts/ui/tile.gd")
const Icons := preload("res://scripts/ui/icons.gd")

const COLOR_DANGER := Color("#ee6b57")
const COLOR_WARNING := Color("#e8b94e")
const COLOR_MUTED := Color("#b9a98e")
const COLOR_OK := Color("#6cc08b")
const COLOR_IDLE := Color("#8f8574")
## Soldados que se reclutan o licencian con cada pulsación.
const LOTE_SOLDADOS := 5

## Icono de cada aviso de provincia (ver Texts.ALERT_TEXT).
const ALERT_ICON := {
	"hunger_warning": "bread", "starvation": "bread", "unrest": "face", "storage_full": "storage",
	"no_workers": "people", "waste": "storage", "soldiers_unpaid": "helmet", "cold": "snow",
}

var _data = null
var _province = null
var _neighbor_names: Array = []

var _hint: Label
var _body: VBoxContainer
var _stat_tiles := {}
var _alert_tiles := {}
var _stock_header: Button
var _stock_tiles := {}
var _detail_box: PanelContainer
var _detail_content: VBoxContainer
var _detail_key: String = ""
var _detail_signature: String = ""
var _detail_text: String = ""
var _detail_label: Label = null
var _buildings_grid: GridContainer
var _building_tiles := {}
var _projects_header: Button
var _projects_grid: GridContainer
var _project_tiles: Array = []
var _army_header: Button
var _army_costs: HBoxContainer
var _feedback: Label
var _recruit_button: Button
var _release_button: Button
var _build_header: Button
var _build_buttons := {}
var _army_info := {}
var _upgrade_button: Button = null
var _army_costs_key: String = ""
var _caravan_header: Tile
var _caravan_grid: GridContainer
var _caravan_tiles := {}
## Lo que viaja hacia o desde la provincia ({"in": {mercancía: cantidad}, "out": {...}}, ver trade.gd); lo pone main.
var _caravans := {"in": {}, "out": {}}


func setup(game_data) -> void:
	_data = game_data
	add_theme_constant_override("separation", 12)
	_hint = Label.new()
	_hint.text = "Toca una provincia del mapa para ver su ficha."
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	add_child(_body)

	# Cifras clave: población, trabajo, edificios, descontento, velocidad de trabajo, consumo de alimento.
	var stats := _grid(3)
	for entry in [["people", "people"], ["work", "hammer"], ["town", "town"], ["unrest", "face"], ["speed", "bolt"], ["food", "bread"]]:
		stats.add_child(_make_stat(entry[0], entry[1]))
	# Avisos: solo aparecen los activos.
	var alerts := _grid(4)
	for code in Texts.ALERT_TEXT.keys():
		var tile := _make_tile("chip", 64)
		tile.kind = ALERT_ICON.get(code, "warning")
		tile.pressed.connect(_select_detail.bind("alert:" + code))
		tile.visible = false
		alerts.add_child(tile)
		_alert_tiles[code] = tile

	_stock_header = _header("storage")
	var stock := _grid(4)
	for good_id in _data.goods.keys():
		var tile := _make_tile("chip", 68)
		tile.kind = good_id
		tile.pressed.connect(_select_detail.bind("stock:" + good_id))
		stock.add_child(tile)
		_stock_tiles[good_id] = tile

	_detail_box = PanelContainer.new()
	_detail_box.visible = false
	_body.add_child(_detail_box)
	_detail_content = VBoxContainer.new()
	_detail_content.add_theme_constant_override("separation", 6)
	_detail_box.add_child(_detail_content)

	# Caravanas del reparto entre provincias del reino: solo se ve si algo viaja hacia o desde la provincia.
	_caravan_header = _header("caravan")
	_caravan_grid = _grid(4)
	for good_id in _data.rules.get("trade_goods", []):
		for way in ["in", "out"]:
			var caravan_tile := _make_tile("chip", 64)
			caravan_tile.kind = good_id
			caravan_tile.flat = true
			caravan_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caravan_tile.visible = false
			_caravan_grid.add_child(caravan_tile)
			_caravan_tiles["%s:%s" % [way, good_id]] = caravan_tile

	_header("town")
	_buildings_grid = _grid(5)

	_projects_header = _header("hammer")
	_projects_grid = _grid(5)

	_army_header = _header("helmet")
	_army_costs = HBoxContainer.new()
	_army_costs.add_theme_constant_override("separation", 8)
	_body.add_child(_army_costs)
	var army_row := HBoxContainer.new()
	army_row.add_theme_constant_override("separation", 10)
	_body.add_child(army_row)
	_recruit_button = _make_tile("chip", 88)
	_recruit_button.kind = "helmet"
	_recruit_button.pressed.connect(_on_recruit_pressed)
	army_row.add_child(_recruit_button)
	_release_button = _make_tile("chip", 88)
	_release_button.kind = "helmet"
	_release_button.pressed.connect(_on_release_pressed)
	army_row.add_child(_release_button)

	_build_header = _header("hammer")
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_feedback)
	var build := _grid(3)
	for type_id in _data.buildings.keys():
		var tile := _make_tile("card", 176)
		tile.kind = type_id
		tile.pressed.connect(_on_build_pressed.bind(type_id))
		build.add_child(tile)
		_build_buttons[type_id] = tile
	_body.visible = false


func show_province(province, neighbor_names: Array) -> void:
	_province = province
	_neighbor_names = neighbor_names
	_feedback.text = ""
	_detail_key = ""
	refresh()


## Caravanas en camino de esta provincia (resultado de Trade.summary_for); se muestran en el próximo refresh().
func set_caravans(summary: Dictionary) -> void:
	_caravans = {"in": summary.get("in", {}), "out": summary.get("out", {})}


## Ficha de una mercancía que llega ("in") o sale ("out") en caravana, para las pruebas (null si no se muestra).
func caravan_tile(way: String, good_id: String) -> Button:
	return _caravan_tiles.get("%s:%s" % [way, good_id], null)


func current_province_id() -> String:
	return "" if _province == null else _province.id


## Ficha de construcción de un tipo (es un botón; su `tooltip_text` dice el estado), para las pruebas.
func build_button(type_id: String) -> Button:
	return _build_buttons.get(type_id, null)


## Botón «Mejorar» del detalle del edificio seleccionado (null si ese detalle no lo muestra), para las pruebas.
func upgrade_button() -> Button:
	if _upgrade_button != null and not is_instance_valid(_upgrade_button):
		return null
	return _upgrade_button


func recruit_button() -> Button:
	return _recruit_button


func release_button() -> Button:
	return _release_button


func feedback_text() -> String:
	return _feedback.text


## Datos del ejército que se ven en la ficha, para las pruebas.
func army_info() -> Dictionary:
	return _army_info


## Texto de la línea de detalle (vacío si no hay ninguna), para las pruebas.
func detail_text() -> String:
	return _detail_text if _detail_box.visible else ""


## Color del número de una cabecera ("projects", "build", "army"), para las pruebas.
func header_color(which: String) -> Color:
	match which:
		"projects":
			return _projects_header.text_color
		"build":
			return _build_header.text_color
		"army":
			return _army_header.text_color
	return Color(0, 0, 0, 0)


## Texto de la etiqueta que de verdad se ve en el detalle (no el interno), para las pruebas.
func detail_label_text() -> String:
	return "" if _detail_label == null or not _detail_box.visible else _detail_label.text


func stat_tile(id: String) -> Button:
	return _stat_tiles.get(id, null)


func stock_tile(good_id: String) -> Button:
	return _stock_tiles.get(good_id, null)


func building_tile(type_id: String) -> Button:
	return _building_tiles.get(type_id, null)


func alert_tile(code: String) -> Button:
	return _alert_tiles.get(code, null)


func project_tile_count() -> int:
	var n := 0
	for tile in _project_tiles:
		if tile.visible:
			n += 1
	return n


## Pulsa (por código) la ficha de detalle de `key`: "stock:wheat", "building:farm" o "alert:unrest".
func select_detail(key: String) -> void:
	_select_detail(key)


func refresh() -> void:
	_hint.visible = _province == null
	_body.visible = _province != null
	if _province == null:
		return
	var p = _province
	_update_stats(p)
	_update_alerts(p)
	_update_stock(p)
	_update_caravans()
	_update_buildings(p)
	_update_projects(p)
	_update_army(p)
	_update_build_buttons(p)
	_feedback.visible = _feedback.text != ""
	_update_detail(p)


# --- Cifras clave -----------------------------------------------------------------------------------------

func _make_stat(id: String, icon: String) -> Button:
	var tile := _make_tile("chip", 68)
	tile.kind = icon
	tile.pressed.connect(_select_detail.bind("stat:" + id))
	_stat_tiles[id] = tile
	return tile


func _update_stats(p) -> void:
	var rules: Dictionary = _data.rules
	var pop: Tile = _stat_tiles["people"]
	pop.caption = "%d/%d" % [p.population, p.housing_capacity()]
	pop.text_color = Tile.COLOR_BAD if p.population >= p.housing_capacity() else Tile.COLOR_TEXT
	var work: Tile = _stat_tiles["work"]
	work.caption = "%d/%d" % [p.assigned_labor(), p.labor_force()]
	var town: Tile = _stat_tiles["town"]
	town.caption = "%d/%d" % [p.buildings.size() + p.projects.size(), rules["max_buildings"]]
	town.text_color = Tile.COLOR_WARN if p.buildings.size() + p.projects.size() >= rules["max_buildings"] else Tile.COLOR_TEXT
	var unrest: Tile = _stat_tiles["unrest"]
	var unrest_max: int = rules["unrest_max"]
	unrest.caption = "%d%%" % (p.unrest * 100 / maxi(1, unrest_max))
	unrest.ratio = float(p.unrest) / float(maxi(1, unrest_max))
	unrest.bar_color = COLOR_DANGER if p.unrest >= rules["unrest_slow_threshold"] else COLOR_WARNING
	var speed: Tile = _stat_tiles["speed"]
	speed.caption = "%d%%" % p.productivity_percent()
	speed.text_color = Tile.COLOR_BAD if p.productivity_percent() < 100 else Tile.COLOR_TEXT
	var food: Tile = _stat_tiles["food"]
	food.caption = Texts.compact(p.population * rules["food_per_person"])
	food.text_color = Tile.COLOR_BAD if p.hunger_steps > 0 else Tile.COLOR_TEXT
	for tile in _stat_tiles.values():
		tile.refresh()


func _update_alerts(p) -> void:
	for code in _alert_tiles.keys():
		var tile: Tile = _alert_tiles[code]
		var active: bool = code in p.alerts
		tile.visible = active
		if active:
			var severity := Texts.alert_severity([code])
			tile.dot = COLOR_DANGER if severity == 2 else (COLOR_WARNING if severity == 1 else COLOR_IDLE)
			tile.caption = "!" if severity == 2 else ("·" if severity == 0 else "!")
			tile.text_color = COLOR_DANGER if severity == 2 else (COLOR_WARNING if severity == 1 else COLOR_MUTED)
			tile.refresh()


# --- Existencias ------------------------------------------------------------------------------------------

func _update_stock(p) -> void:
	_stock_header.caption = "%s/%s" % [Texts.compact(p.store.used_space()), Texts.compact(p.store.capacity)]
	_stock_header.ratio = float(p.store.used_space()) / float(maxi(1, p.store.capacity))
	_stock_header.bar_color = COLOR_WARNING if _stock_header.ratio > 0.9 else COLOR_OK
	_stock_header.refresh()
	for good_id in _stock_tiles.keys():
		var tile: Tile = _stock_tiles[good_id]
		var amount: int = p.store.stock(good_id)
		tile.caption = Texts.compact(amount)
		if _data.is_physical(good_id):
			var limit: int = p.store.limit(good_id)
			tile.ratio = float(amount) / float(maxi(1, limit))
			var full: bool = amount >= limit and limit > 0
			tile.bar_color = COLOR_WARNING if full else COLOR_OK
			tile.dot = COLOR_WARNING if full else Color(0, 0, 0, 0)
		else:
			tile.ratio = -1.0
		tile.text_color = Tile.COLOR_BAD if amount == 0 and good_id in ["wheat", "bread", "coin"] else Tile.COLOR_TEXT
		tile.refresh()


func _update_caravans() -> void:
	var any := false
	var kinds := 0
	for key in _caravan_tiles.keys():
		var way: String = key.get_slice(":", 0)
		var good_id: String = key.get_slice(":", 1)
		var tile: Tile = _caravan_tiles[key]
		var amount: int = int(_caravans[way].get(good_id, 0))
		tile.visible = amount > 0
		if amount > 0:
			any = true
			kinds += 1
			tile.caption = ("+" if way == "in" else "-") + Texts.compact(amount)
			tile.text_color = COLOR_OK if way == "in" else COLOR_MUTED
			tile.refresh()
	_caravan_header.visible = any
	_caravan_grid.visible = any
	if any:
		_caravan_header.caption = str(kinds)
		_caravan_header.refresh()


# --- Edificios agrupados por tipo -----------------------------------------------------------------------

func _group_buildings(p) -> Dictionary:
	var groups := {}
	for b in p.buildings:
		var type_id: String = b["type"]
		if not groups.has(type_id):
			groups[type_id] = {"count": 0, "workers": 0, "statuses": {}, "missing": {}, "upgraded": 0, "upgradable": 0}
		var g: Dictionary = groups[type_id]
		g["count"] += 1
		g["workers"] += b["workers"]
		if int(b.get("level", 1)) > 1:
			g["upgraded"] += 1
		if int(b.get("level", 1)) < int(_data.buildings[type_id].get("max_level", 1)) and not p.is_upgrading(b["uid"]):
			g["upgradable"] += 1
		g["statuses"][b["status"]] = int(g["statuses"].get(b["status"], 0)) + 1
		for good_id in b["missing"].keys():
			g["missing"][good_id] = true
	return groups


func _group_color(g: Dictionary) -> Color:
	var running := false
	for status in g["statuses"].keys():
		var cls := Texts.status_class(status)
		if cls == "warn":
			return COLOR_WARNING
		if cls == "ok":
			running = true
	return COLOR_OK if running else COLOR_IDLE


func _update_buildings(p) -> void:
	var groups := _group_buildings(p)
	for type_id in groups.keys():
		if not _building_tiles.has(type_id):
			var tile := _make_tile("card", 124)
			tile.kind = type_id
			tile.pressed.connect(_select_detail.bind("building:" + type_id))
			_buildings_grid.add_child(tile)
			_building_tiles[type_id] = tile
	# Orden estable: el del archivo de edificios.
	var index := 0
	for type_id in _data.buildings.keys():
		if _building_tiles.has(type_id):
			_buildings_grid.move_child(_building_tiles[type_id], index)
			index += 1
	for type_id in _building_tiles.keys():
		var tile: Tile = _building_tiles[type_id]
		var g: Dictionary = groups.get(type_id, {})
		tile.visible = not g.is_empty()
		if g.is_empty():
			continue
		var t: Dictionary = _data.buildings[type_id]
		tile.badge = "×%d" % g["count"] if g["count"] > 1 else ""
		tile.dot = _group_color(g)
		tile.tooltip_text = t["name"]
		tile.footer = []
		if t["workers"] > 0:
			var wanted: int = t["workers"] * g["count"]
			tile.footer.append({"icon": "people", "text": "%d/%d" % [g["workers"], wanted], "bad": g["workers"] < wanted})
		if g["upgraded"] > 0:
			tile.footer.append({"icon": "star", "text": str(g["upgraded"]), "bad": false})
		tile.refresh()


# --- Obras --------------------------------------------------------------------------------------------------

func _update_projects(p) -> void:
	_projects_header.caption = "%d/%d" % [p.projects.size(), _data.rules["max_projects"]]
	_projects_header.text_color = COLOR_DANGER if p.projects.size() >= _data.rules["max_projects"] else Tile.COLOR_TEXT
	_projects_header.refresh()
	while _project_tiles.size() < p.projects.size():
		var tile := _make_tile("card", 124)
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		_projects_grid.add_child(tile)
		_project_tiles.append(tile)
	for i in _project_tiles.size():
		var tile: Tile = _project_tiles[i]
		tile.visible = i < p.projects.size()
		if not tile.visible:
			continue
		var project: Dictionary = p.projects[i]
		var t: Dictionary = _data.buildings[project["type"]]
		var is_upgrade: bool = int(project.get("upgrade_uid", 0)) > 0
		var total_steps: int = p.upgrade_steps(project["type"]) if is_upgrade else t["build_steps"]
		tile.kind = project["type"]
		tile.badge = "★" if is_upgrade else ""
		tile.tooltip_text = "%s%s: faltan %d pasos" % ["Mejora de " if is_upgrade else "", t["name"], project["remaining"]]
		tile.footer = [{"icon": "clock", "text": str(project["remaining"]), "bad": false}]
		tile.ratio = 1.0 - float(project["remaining"]) / float(maxi(1, total_steps))
		tile.bar_color = COLOR_OK if project["workers"] > 0 else COLOR_WARNING
		tile.dot = Color(0, 0, 0, 0) if project["workers"] > 0 else COLOR_WARNING
		tile.refresh()
	_projects_grid.visible = not p.projects.is_empty()


# --- Ejército -------------------------------------------------------------------------------------------------

func _update_army(p) -> void:
	var rules: Dictionary = _data.rules
	var per: int = int(rules.get("recruits_per_barracks", 0))
	var weapons: int = int(rules.get("recruit_weapons", 0))
	var upkeep: int = int(rules.get("recruit_upkeep", 0))
	var capacity: int = p.recruit_capacity() if per > 0 else -1
	_army_info = {"soldiers": p.recruits, "capacity": capacity, "barracks": p.count_buildings("barracks"), "unpaid": p.soldiers_unpaid}
	_army_header.caption = ("%d/%d" % [p.recruits, capacity]) if per > 0 else str(p.recruits)
	_army_header.text_color = Tile.COLOR_TEXT
	_army_header.dot = COLOR_WARNING if p.soldiers_unpaid else Color(0, 0, 0, 0)
	_army_header.refresh()
	var costs_key := "%d|%d|%s" % [weapons, upkeep, str(p.soldiers_unpaid)]
	if costs_key != _army_costs_key:
		_army_costs_key = costs_key
		for child in _army_costs.get_children():
			_army_costs.remove_child(child)
			child.queue_free()
		if weapons > 0:
			_army_costs.add_child(_info_chip("weapons", Texts.compact(weapons)))
		if upkeep > 0:
			_army_costs.add_child(_info_chip("coin", Texts.compact(upkeep)))
			_army_costs.add_child(_info_chip("clock", "1"))
		if p.soldiers_unpaid:
			_army_costs.add_child(_info_chip("danger", "", true))
	var lote: int = LOTE_SOLDADOS
	_recruit_button.caption = "+%d" % lote
	_release_button.caption = "−%d" % lote
	_recruit_button.tooltip_text = "Reclutar %d" % lote
	_release_button.tooltip_text = "Licenciar %d" % lote
	_recruit_button.disabled = false
	_release_button.disabled = p.recruits < lote
	_recruit_button.refresh()
	_release_button.refresh()


func _update_build_buttons(p) -> void:
	_build_header.caption = "%d/%d" % [p.buildings.size() + p.projects.size(), _data.rules["max_buildings"]]
	_build_header.text_color = COLOR_DANGER if p.buildings.size() + p.projects.size() >= _data.rules["max_buildings"] else Tile.COLOR_TEXT
	_build_header.refresh()
	var full: bool = p.projects.size() >= _data.rules["max_projects"]
	var no_room: bool = p.buildings.size() + p.projects.size() >= _data.rules["max_buildings"]
	for type_id in _build_buttons.keys():
		var t: Dictionary = _data.buildings[type_id]
		var tile: Tile = _build_buttons[type_id]
		var can_afford: bool = p.store.can_afford(t["build_cost"])
		var note := ""
		if no_room:
			note = "sin sitio"
		elif full:
			note = "obras al máximo"
		elif not can_afford:
			note = "faltan recursos"
		tile.tooltip_text = "Construir %s%s" % [t["name"], (" · " + note) if note != "" else ""]
		tile.caption = t["name"]
		tile.footer = []
		var costs: Array = t["build_cost"].keys()
		costs.sort()
		for good_id in costs:
			var needed: int = t["build_cost"][good_id]
			tile.footer.append({"icon": good_id, "text": Texts.compact(needed), "bad": p.store.stock(good_id) < needed})
		tile.footer.append({"icon": "clock", "text": str(t["build_steps"]), "bad": false})
		tile.disabled = no_room or full or not can_afford
		tile.refresh()


# --- Zona de detalle ----------------------------------------------------------------------------------------

func _select_detail(key: String) -> void:
	_detail_key = "" if key == _detail_key else key
	_detail_signature = ""
	if _province != null:
		_update_detail(_province)


## Contenido de la zona de detalle: [título, [filas de datos]], donde cada fila es una lista de fichas
## [{"icon", "text", "bad"}] o la palabra "arrow" para una flecha. Devuelve {} si no hay nada seleccionado.
func _detail_for(p) -> Dictionary:
	var parts := _detail_key.split(":")
	if parts.size() != 2:
		return {}
	var id: String = parts[1]
	match parts[0]:
		"stock":
			if not _data.goods.has(id):
				return {}
			var amount: int = p.store.stock(id)
			var line := "%s %s" % [Texts.good_name(_data, id), Texts.amount(amount)]
			var row: Array = []
			if _data.is_physical(id):
				line += " (máx. %s)" % Texts.amount(p.store.limit(id))
				row.append({"icon": "storage", "text": "%s/%s" % [Texts.compact(p.store.used_space()), Texts.compact(p.store.capacity)], "bad": false})
			if _data.seasons.has(id):
				var season_icon: String = CalendarScript.SEASON_ICONS[p.current_season()]
				row.append({"icon": season_icon, "text": "%d %%" % p.season_percent(id), "bad": p.season_percent(id) < 100})
			return {"icon": id, "title": line, "rows": [row] if not row.is_empty() else []}
		"stat":
			return _stat_detail(p, id)
		"alert":
			if not Texts.ALERT_TEXT.has(id) or not id in p.alerts:
				return {}
			return {"icon": ALERT_ICON.get(id, "warning"), "title": Texts.alert_text(id), "rows": []}
		"building":
			return _building_detail(p, id)
	return {}


func _stat_detail(p, id: String) -> Dictionary:
	var rules: Dictionary = _data.rules
	match id:
		"people":
			return {"icon": "people", "title": "Población %d (vivienda para %d)" % [p.population, p.housing_capacity()], "rows": []}
		"work":
			return {"icon": "hammer", "title": "Trabajo: %d asignados de %d de mano de obra" % [p.assigned_labor(), p.labor_force()], "rows": []}
		"town":
			return {"icon": "town", "title": "Edificios y obras: %d de %d posibles" % [p.buildings.size() + p.projects.size(), rules["max_buildings"]], "rows": []}
		"unrest":
			return {"icon": "face", "title": "Descontento %d de %d" % [p.unrest, rules["unrest_max"]], "rows": []}
		"speed":
			return {"icon": "bolt", "title": "Velocidad de trabajo %d %%" % p.productivity_percent(), "rows": []}
		"food":
			var title := "Consumo de alimento: %s por paso" % Texts.amount(p.population * rules["food_per_person"])
			if p.hunger_steps > 0:
				title += " · %d pasos sin comida suficiente" % p.hunger_steps
			return {"icon": "bread", "title": title, "rows": []}
	return {}


func _building_detail(p, type_id: String) -> Dictionary:
	if not _data.buildings.has(type_id):
		return {}
	var groups := _group_buildings(p)
	var g: Dictionary = groups.get(type_id, {})
	if g.is_empty():
		return {}
	var t: Dictionary = _data.buildings[type_id]
	var parts: Array[String] = []
	for status in g["statuses"].keys():
		parts.append("%d %s" % [g["statuses"][status], Texts.status_text(status).to_lower()])
	var title: String = "%s ×%d — %s" % [t["name"], g["count"], ", ".join(parts)] if g["count"] > 1 else "%s — %s" % [t["name"], ", ".join(parts)]
	var row: Array = []
	for good_id in t["inputs"].keys():
		row.append({"icon": good_id, "text": Texts.compact(t["inputs"][good_id]), "bad": g["missing"].has(good_id)})
	if not t["inputs"].is_empty() and not t["outputs"].is_empty():
		row.append("arrow")
	for good_id in t["outputs"].keys():
		row.append({"icon": good_id, "text": Texts.compact(t["outputs"][good_id]), "bad": false})
	if not t["outputs"].is_empty():
		row.append({"icon": "clock", "text": str(t["cycle_steps"]), "bad": false})
	if t["storage_capacity"] > 0:
		row.append({"icon": "storage", "text": "+" + Texts.compact(t["storage_capacity"]), "bad": false})
	if t["housing"] > 0:
		row.append({"icon": "house", "text": "+%d" % t["housing"], "bad": false})
	if t["workers"] > 0:
		row.append({"icon": "people", "text": "%d/%d" % [g["workers"], t["workers"] * g["count"]], "bad": g["workers"] < t["workers"] * g["count"]})
	var detail := {"icon": type_id, "title": title, "rows": [row] if not row.is_empty() else []}
	if int(t.get("max_level", 1)) > 1 and int(_data.rules.get("upgrade_cost_percent", 0)) > 0 and g["upgradable"] > 0:
		var cost: Dictionary = p.upgrade_cost(type_id)
		var entries: Array = []
		var affordable := true
		for good_id in cost.keys():
			var short: bool = p.store.stock(good_id) < cost[good_id]
			affordable = affordable and not short
			entries.append({"icon": good_id, "text": Texts.compact(cost[good_id]), "bad": short})
		entries.append({"icon": "clock", "text": str(p.upgrade_steps(type_id)), "bad": false})
		var room: bool = p.projects.size() < _data.rules["max_projects"]
		detail["upgrade"] = {"type": type_id, "costs": entries, "enabled": affordable and room, "full": not room, "level": int(t["max_level"])}
	return detail


func _update_detail(p) -> void:
	var d := _detail_for(p) if _detail_key != "" else {}
	_detail_box.visible = not d.is_empty()
	if d.is_empty():
		_detail_text = ""
		_detail_signature = ""
		_upgrade_button = null
		return
	var signature := JSON.stringify(d)
	_detail_text = d["title"]
	if signature == _detail_signature:
		return
	_detail_signature = signature
	for child in _detail_content.get_children():
		_detail_content.remove_child(child)
		child.queue_free()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_detail_content.add_child(head)
	var big := _make_tile("chip", 64)
	big.kind = d["icon"]
	big.custom_minimum_size = Vector2(64, 64)
	big.flat = true
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(big)
	var label := Label.new()
	label.text = d["title"]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(label)
	_detail_label = label
	for row in d["rows"]:
		var line := HFlowContainer.new()
		line.add_theme_constant_override("h_separation", 8)
		_detail_content.add_child(line)
		for entry in row:
			if typeof(entry) == TYPE_STRING:
				var arrow := _make_tile("chip", 56)
				arrow.kind = "arrow"
				arrow.custom_minimum_size = Vector2(56, 56)
				arrow.flat = true
				arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
				line.add_child(arrow)
			else:
				line.add_child(_info_chip(entry["icon"], entry["text"], entry.get("bad", false)))
	_upgrade_button = null
	if d.has("upgrade"):
		var up: Dictionary = d["upgrade"]
		var line := HFlowContainer.new()
		line.add_theme_constant_override("h_separation", 8)
		_detail_content.add_child(line)
		var button := _make_tile("chip", 64)
		button.kind = "star"
		button.caption = "+%d %%" % int(_data.rules["upgrade_output_percent"])
		button.custom_minimum_size = Vector2(130, 64)
		button.disabled = not up["enabled"]
		button.tooltip_text = "Mejorar %s%s" % [Texts.building_name(_data, up["type"]), " · obras al máximo" if up["full"] else (" · faltan recursos" if not up["enabled"] else "")]
		button.pressed.connect(_on_upgrade_pressed.bind(up["type"]))
		button.refresh()
		line.add_child(button)
		_upgrade_button = button
		for entry in up["costs"]:
			line.add_child(_info_chip(entry["icon"], entry["text"], entry.get("bad", false)))


# --- Acciones --------------------------------------------------------------------------------------------------------

func _on_recruit_pressed() -> void:
	if _province == null:
		return
	if _province.recruit(LOTE_SOLDADOS):
		_feedback.text = "Reclutados %d soldados." % LOTE_SOLDADOS
	else:
		_feedback.text = "No se pudo reclutar: %s." % _province.last_error
	refresh()
	changed.emit()


func _on_release_pressed() -> void:
	if _province == null:
		return
	if _province.release_recruits(LOTE_SOLDADOS):
		_feedback.text = "Licenciados %d soldados." % LOTE_SOLDADOS
	else:
		_feedback.text = "No se pudo licenciar: %s." % _province.last_error
	refresh()
	changed.emit()


func _on_upgrade_pressed(type_id: String) -> void:
	if _province == null:
		return
	for b in _province.buildings:
		if b["type"] == type_id and b["level"] < _data.buildings[type_id]["max_level"] and not _province.is_upgrading(b["uid"]):
			if _province.start_upgrade(b["uid"]):
				_feedback.text = "Mejora iniciada: %s." % Texts.building_name(_data, type_id)
			else:
				_feedback.text = "No se pudo mejorar: %s." % _province.last_error
			break
	refresh()
	changed.emit()


func _on_build_pressed(type_id: String) -> void:
	if _province == null:
		return
	if _province.start_construction(type_id):
		_feedback.text = "Obra iniciada: %s." % Texts.building_name(_data, type_id)
	else:
		_feedback.text = "No se pudo construir: %s." % _province.last_error
	refresh()
	changed.emit()


# --- Construcción de controles ---------------------------------------------------------------------------------------

func _grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(grid)
	return grid


func _make_tile(layout: String, height: float) -> Tile:
	var tile := Tile.new()
	tile.layout = layout
	tile.custom_minimum_size = Vector2(0, height)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tile


## Cabecera de sección: un icono, un número corto y una barra; no se pulsa.
func _header(kind: String, caption: String = "") -> Tile:
	var tile := _make_tile("chip", 56)
	tile.kind = kind
	tile.caption = caption
	tile.flat = true
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(tile)
	return tile


## Ficha informativa (no se pulsa) para filas de detalle y costes.
func _info_chip(kind: String, text: String, bad: bool = false) -> Tile:
	var tile := _make_tile("chip", 56)
	tile.kind = kind
	tile.caption = text
	tile.text_color = Tile.COLOR_BAD if bad else Tile.COLOR_TEXT
	tile.custom_minimum_size = Vector2(118 if text != "" else 56, 56)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tile.flat = true
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tile
