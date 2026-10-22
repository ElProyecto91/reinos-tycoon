extends "res://tests/province_case.gd"
## Ficha de provincia hecha de símbolos (UI1): cifras cortas, cobertura de iconos y que cada ficha
## refleje el estado real de la provincia (no solo que exista).

const PANEL := "res://scripts/ui/province_panel.gd"
const Texts = preload("res://scripts/ui/texts.gd")
const Icons = preload("res://scripts/ui/icons.gd")


func _panel(data, province):
	var panel = load(PANEL).new()
	panel.setup(data)
	panel.show_province(province, [])
	return panel


func test_compact_amounts_are_truncated_never_rounded_up() -> void:
	assert_eq(Texts.compact(0), "0", "cero")
	assert_eq(Texts.compact(5), "<0,01", "casi nada no se enseña como cero")
	assert_eq(Texts.compact(20), "0,02", "centésimas")
	assert_eq(Texts.compact(100), "0,1", "una décima sin ceros sobrantes")
	assert_eq(Texts.compact(150), "0,15", "dos decimales")
	assert_eq(Texts.compact(999), "0,99", "no sube a 1")
	assert_eq(Texts.compact(1000), "1", "uno")
	assert_eq(Texts.compact(2750), "2,7", "2,75 se corta a 2,7")
	assert_eq(Texts.compact(9999), "9,9", "no sube a 10")
	assert_eq(Texts.compact(10000), "10", "diez")
	assert_eq(Texts.compact(33786), "33", "entero desde 10")
	assert_eq(Texts.compact(123456), "123", "tres cifras")
	assert_eq(Texts.compact(-2750), "-2,7", "negativos")
	done()


func test_every_good_building_symbol_and_alert_has_an_icon() -> void:
	var data = new_data()
	for good_id in data.goods.keys():
		assert_true(Icons.is_kind(good_id), "mercancía %s con icono" % good_id)
	for type_id in data.buildings.keys():
		assert_true(Icons.is_kind(type_id), "edificio %s con icono" % type_id)
	var panel = load(PANEL).new()
	for code in Texts.ALERT_TEXT.keys():
		assert_true(panel.ALERT_ICON.has(code) and Icons.is_kind(panel.ALERT_ICON[code]), "aviso %s con icono" % code)
	assert_true(not Icons.is_kind("marte"), "un nombre desconocido no es un icono")
	for kind in Icons.GOODS + Icons.BUILDINGS + Icons.SYMBOLS:
		assert_true(Icons.is_kind(kind), kind)
	panel.free()
	done()


func test_status_classes() -> void:
	assert_eq(Texts.status_class("running"), "ok", "produce")
	assert_eq(Texts.status_class("idle"), "idle", "sin actividad")
	assert_eq(Texts.status_class("disabled"), "idle", "desactivado")
	for status in ["no_workers", "missing_inputs", "no_upkeep", "storage_full"]:
		assert_eq(Texts.status_class(status), "warn", status)
	done()


func test_key_figures_follow_the_province() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.add_building("house")
	var panel = _panel(data, p)
	assert_eq(panel.stat_tile("people").caption, "%d/%d" % [p.population, p.housing_capacity()], "población y vivienda")
	assert_eq(panel.stat_tile("town").caption, "1/%d" % data.rules["max_buildings"], "edificios sobre el tope")
	assert_eq(panel.stat_tile("speed").caption, "100%", "velocidad de trabajo")
	assert_eq(panel.stat_tile("unrest").caption, "0%", "sin descontento")
	p.unrest = 500
	panel.refresh()
	assert_eq(panel.stat_tile("unrest").caption, "50%", "descontento a la mitad")
	assert_true(absf(panel.stat_tile("unrest").ratio - 0.5) < 0.001, "y su barra")
	panel.free()
	done()


func test_stock_tiles_show_truncated_amounts_and_full_goods() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.add_building("granary")
	p.store.seed_initial("wheat", 2750)
	var panel = _panel(data, p)
	assert_eq(panel.stock_tile("wheat").caption, "2,7", "trigo truncado")
	assert_eq(panel.stock_tile("flour").caption, "0", "harina a cero")
	assert_true(panel.stock_tile("wheat").ratio > 0.0 and panel.stock_tile("wheat").ratio < 1.0, "barra parcial")
	var limit: int = p.store.limit("wheat")
	p.store.seed_initial("wheat", limit)
	panel.refresh()
	assert_true(panel.stock_tile("wheat").ratio >= 0.999, "lleno: barra completa")
	assert_true(panel.stock_tile("wheat").dot.a > 0.0, "y punto de aviso")
	assert_eq(panel.stock_tile("coin").ratio, -1.0, "la moneda no tiene barra (no ocupa espacio)")
	panel.free()
	done()


func test_tapping_a_stock_tile_shows_the_exact_amount_and_taps_again_hide_it() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("wheat", 2750)
	var panel = _panel(data, p)
	assert_eq(panel.detail_text(), "", "al principio no hay detalle")
	panel.stock_tile("wheat").pressed.emit()
	assert_true("Trigo 2,75" in panel.detail_text(), "valor exacto: %s" % panel.detail_text())
	p.store.seed_initial("wheat", 1000)
	panel.refresh()
	assert_true("Trigo 3,75" in panel.detail_text(), "el detalle sigue a la provincia: %s" % panel.detail_text())
	assert_true("Trigo 3,75" in panel.detail_label_text(), "y la etiqueta que se ve también: %s" % panel.detail_label_text())
	panel.stock_tile("wheat").pressed.emit()
	assert_eq(panel.detail_text(), "", "pulsar otra vez lo oculta")
	panel.free()
	done()


func test_buildings_are_grouped_by_type_with_count_workers_and_status_color() -> void:
	var data = new_data()
	var p = chain_province(data, 100)
	p.add_building("house")
	p.add_building("house")
	var panel = _panel(data, p)
	var house = panel.building_tile("house")
	assert_true(house != null and house.visible, "hay ficha de vivienda")
	assert_eq(house.badge, "×2", "dos viviendas agrupadas")
	var farm = panel.building_tile("farm")
	if farm != null:
		assert_true(farm.visible == (p.count_buildings("farm") > 0), "la granja se ve solo si hay")
	for type_id in data.buildings.keys():
		var tile = panel.building_tile(type_id)
		if tile != null:
			assert_eq(tile.visible, p.count_buildings(type_id) > 0, "%s visible solo si existe" % type_id)
	panel.select_detail("building:house")
	assert_true("Vivienda ×2" in panel.detail_text(), "detalle del grupo: %s" % panel.detail_text())
	panel.free()
	done()


func test_projects_show_progress_and_blocked_ones_warn() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("wood", 20000)
	p.store.seed_initial("coin", 50000)
	var panel = _panel(data, p)
	assert_eq(panel.project_tile_count(), 0, "sin obras, sin fichas")
	assert_true(p.start_construction("house"), "empieza una obra")
	panel.refresh()
	assert_eq(panel.project_tile_count(), 1, "una ficha de obra")
	var before: float = panel._project_tiles[0].ratio
	run_steps(p, 3)
	panel.refresh()
	assert_true(panel._project_tiles[0].ratio >= before, "el avance no retrocede")
	assert_eq(panel._projects_header.caption, "1/%d" % data.rules["max_projects"], "la cabecera cuenta las obras")
	panel.free()
	done()


func test_build_tiles_show_costs_and_flag_missing_goods() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.store.seed_initial("coin", 50000)
	p.store.seed_initial("wood", 20000)
	var panel = _panel(data, p)
	var tile = panel.build_button("house")
	var cost_icons: Array = []
	for entry in tile.footer:
		cost_icons.append(entry["icon"])
	for good_id in data.buildings["house"]["build_cost"].keys():
		assert_true(good_id in cost_icons, "el coste muestra %s" % good_id)
	assert_true("clock" in cost_icons, "y los pasos de obra")
	for entry in tile.footer:
		assert_true(not entry["bad"], "con recursos nada sale en rojo (%s)" % entry["icon"])
	p.store.remove("wood", p.store.stock("wood"), "consumed")
	panel.refresh()
	var red := 0
	for entry in tile.footer:
		if entry["bad"]:
			red += 1
			assert_eq(entry["icon"], "wood", "solo lo que falta sale en rojo")
	assert_eq(red, 1, "una mercancía en rojo")
	assert_true(tile.disabled, "y no se puede construir")
	panel.free()
	done()


func test_alert_tiles_appear_only_while_the_alert_is_active_and_explain_on_tap() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	var panel = _panel(data, p)
	for code in Texts.ALERT_TEXT.keys():
		assert_true(not panel.alert_tile(code).visible, "%s oculto sin aviso" % code)
	p.alerts.append("starvation")
	panel.refresh()
	assert_true(panel.alert_tile("starvation").visible, "hambruna visible")
	assert_true(not panel.alert_tile("unrest").visible, "y solo esa")
	panel.alert_tile("starvation").pressed.emit()
	assert_eq(panel.detail_text(), Texts.alert_text("starvation"), "al pulsar explica el aviso")
	p.alerts.clear()
	panel.refresh()
	assert_true(not panel.alert_tile("starvation").visible, "desaparece al acabar")
	assert_eq(panel.detail_text(), "", "y su detalle también")
	panel.free()
	done()


# --- Fase 2: mejoras, estaciones y frío en la ficha ----------------------------------------------------

func _rich_province(data, day: int = 181):
	data.rules["calendar_start_day"] = day
	data.rules["food_per_person"] = 0
	var p = new_province(data, 100)
	p.store.seed_initial("coin", 60000)
	p.store.seed_initial("wood", 7800)
	return p


func test_upgrade_button_shows_costs_and_starts_the_upgrade() -> void:
	var data = new_data()
	var p = _rich_province(data)
	var farm: int = p.add_building("farm")
	var panel = _panel(data, p)
	assert_true(panel.upgrade_button() == null, "sin detalle abierto no hay botón de mejora")
	panel.select_detail("building:farm")
	var button = panel.upgrade_button()
	assert_true(button != null, "al abrir la granja aparece «Mejorar»")
	assert_true(not button.disabled, "con recursos está activo")
	assert_eq(button.caption, "+50 %", "dice cuánto mejora (la regla upgrade_output_percent)")
	button.pressed.emit()
	assert_true(p.is_upgrading(farm), "pulsar inicia la mejora de la granja")
	assert_eq(p.projects.size(), 1, "hay una obra")
	assert_eq(panel.project_tile_count(), 1, "y se ve en las obras")
	var tile = panel.get("_project_tiles")[0]
	assert_eq(tile.badge, "★", "la obra de mejora lleva una estrella")
	assert_true(String(tile.tooltip_text).begins_with("Mejora de"), "y su nota dice que es una mejora")
	assert_true(panel.upgrade_button() == null or panel.upgrade_button().disabled, "con la única granja en obras ya no se puede mejorar otra")
	panel.free()
	done()


func test_upgrade_button_is_disabled_without_resources_and_says_so() -> void:
	var data = new_data()
	var p = new_province(data, 100)
	p.add_building("farm")
	var panel = _panel(data, p)
	panel.select_detail("building:farm")
	var button = panel.upgrade_button()
	assert_true(button != null and button.disabled, "sin recursos el botón está desactivado")
	assert_true("faltan recursos" in String(button.tooltip_text), "y lo dice: %s" % button.tooltip_text)
	panel.free()
	done()


func test_house_detail_has_no_upgrade_button() -> void:
	var data = new_data()
	var p = _rich_province(data)
	p.add_building("house")
	var panel = _panel(data, p)
	panel.select_detail("building:house")
	assert_true(panel.upgrade_button() == null, "una vivienda no se mejora: sin botón")
	panel.free()
	done()


func test_building_tile_counts_upgraded_buildings_with_a_star() -> void:
	var data = new_data()
	var p = _rich_province(data)
	var farm: int = p.add_building("farm")
	p.add_building("farm")
	var panel = _panel(data, p)
	var has_star := func(tile) -> bool:
		for entry in tile.footer:
			if entry.get("icon", "") == "star":
				return true
		return false
	assert_true(not has_star.call(panel.building_tile("farm")), "sin mejoras no hay estrella")
	p.start_upgrade(farm)
	run_steps(p, 8)
	panel.refresh()
	assert_true(has_star.call(panel.building_tile("farm")), "con una granja mejorada aparece la estrella")
	var star_entry: Dictionary = {}
	for entry in panel.building_tile("farm").footer:
		if entry.get("icon", "") == "star":
			star_entry = entry
	assert_eq(star_entry["text"], "1", "y cuenta 1 mejorada de 2")
	panel.free()
	done()


func test_wheat_detail_shows_the_season_percentage_with_the_season_icon() -> void:
	var data = new_data_with_seasons()
	var p = _rich_province(data, 181)
	var panel = _panel(data, p)
	panel.select_detail("stock:wheat")
	var detail: Dictionary = panel._detail_for(p)
	var found := ""
	for entry in detail["rows"][0]:
		if typeof(entry) == TYPE_DICTIONARY and entry["icon"] == "sun":
			found = entry["text"]
	assert_eq(found, "145 %", "en julio el trigo rinde 145 % y se enseña con el sol")
	panel.select_detail("stock:wheat")
	panel.select_detail("stock:wood")
	var wood: Dictionary = panel._detail_for(p)
	for entry in wood["rows"][0]:
		assert_true(typeof(entry) != TYPE_DICTIONARY or entry["icon"] != "sun", "la madera no tiene estaciones")
	panel.free()
	done()


func test_cold_alert_tile_appears_in_winter_without_firewood_only() -> void:
	var data = new_data()
	var p = _rich_province(data, 0)
	var panel = _panel(data, p)
	assert_true(not panel.alert_tile("cold").visible, "al empezar no hay aviso de frío")
	p.step()
	panel.refresh()
	assert_true(panel.alert_tile("cold").visible, "en invierno sin leña aparece el aviso")
	assert_eq(panel.alert_tile("cold").kind, "snow", "con el copo de nieve")
	p.store.seed_initial("firewood", 7800)
	p.step()
	panel.refresh()
	assert_true(not panel.alert_tile("cold").visible, "con leña desaparece")
	panel.free()
	done()
