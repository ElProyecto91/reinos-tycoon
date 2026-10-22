extends "res://tests/test_case.gd"
## Calendario derivado del contador de pasos (fase 2.1, D-031): un paso = una hora, 365 días por año,
## nada se guarda. Las estaciones por mes son una convención del juego.

const Cal = preload("res://scripts/sim/calendar.gd")
const SESSION := "res://scripts/sim/game_session.gd"
const PATH := "user://pruebas_calendario/partida.json"


func test_month_lengths_add_up_to_a_year() -> void:
	var total := 0
	for d in Cal.MONTH_DAYS:
		total += d
	assert_eq(total, 365, "los meses suman 365 días")
	assert_eq(Cal.STEPS_PER_YEAR, 8760, "un año son 8760 pasos")
	assert_eq(Cal.MONTH_NAMES.size(), 12, "doce nombres")
	assert_eq(Cal.MONTH_SHORT.size(), 12, "doce abreviaturas")
	assert_eq(Cal.SEASON_OF_MONTH.size(), 12, "doce estaciones por mes")
	done()


func test_known_dates() -> void:
	var d: Dictionary = Cal.at(0, 1000, 0)
	assert_eq([d["year"], d["month"], d["day"], d["hour"]], [1000, 0, 1, 0], "1 de enero del año de partida")
	d = Cal.at(0, 1000, 181)
	assert_eq([d["month"], d["day"]], [6, 1], "el día 181 es el 1 de julio")
	d = Cal.at(30 * 24, 1000, 0)
	assert_eq([d["month"], d["day"]], [0, 31], "30 días después: 31 de enero")
	d = Cal.at(31 * 24, 1000, 0)
	assert_eq([d["month"], d["day"]], [1, 1], "31 días después: 1 de febrero")
	d = Cal.at(59 * 24, 1000, 0)
	assert_eq([d["month"], d["day"]], [2, 1], "59 días después: 1 de marzo (febrero tiene 28)")
	d = Cal.at(364 * 24 + 23, 1000, 0)
	assert_eq([d["year"], d["month"], d["day"], d["hour"]], [1000, 11, 31, 23], "último paso del año")
	d = Cal.at(365 * 24, 1000, 0)
	assert_eq([d["year"], d["month"], d["day"], d["hour"]], [1001, 0, 1, 0], "un año después: 1 de enero de 1001")
	d = Cal.at(184 * 24, 1000, 181)
	assert_eq([d["year"], d["month"], d["day"]], [1001, 0, 1], "empezando en julio, a los 184 días llega el año nuevo")
	d = Cal.at(5, 1000, 181)
	assert_eq(d["hour"], 5, "la hora")
	done()


func test_every_day_of_the_year_maps_to_a_valid_unique_date() -> void:
	var seen := {}
	for day in range(365):
		var d: Dictionary = Cal.at(day * 24, 1000, 0)
		assert_true(d["month"] >= 0 and d["month"] <= 11, "mes válido el día %d" % day)
		assert_true(d["day"] >= 1 and d["day"] <= Cal.MONTH_DAYS[d["month"]], "día válido del día %d" % day)
		var key := "%d-%d" % [d["month"], d["day"]]
		assert_true(not seen.has(key), "fecha repetida %s" % key)
		seen[key] = true
		assert_eq(d["day_of_year"], day, "día del año")
	assert_eq(seen.size(), 365, "365 fechas distintas")
	done()


func test_seasons_follow_the_month_convention() -> void:
	var by_month := {0: "winter", 1: "winter", 2: "spring", 4: "spring", 5: "summer", 7: "summer", 8: "autumn", 10: "autumn", 11: "winter"}
	for month in by_month.keys():
		var start := 0
		for i in month:
			start += Cal.MONTH_DAYS[i]
		var d: Dictionary = Cal.at(start * 24, 1000, 0)
		assert_eq(d["month"], month, "mes %d" % month)
		assert_eq(d["season"], by_month[month], "estación del mes %d" % month)
	for season in ["winter", "spring", "summer", "autumn"]:
		assert_true(Cal.SEASON_NAMES.has(season) and Cal.SEASON_ICONS.has(season), "%s tiene nombre e icono" % season)
	done()


func test_invalid_start_day_and_negative_steps_never_break() -> void:
	var d: Dictionary = Cal.at(-5, 1000, 999)
	assert_true(d["month"] >= 0 and d["month"] <= 11 and d["day"] >= 1, "valores absurdos dan una fecha válida")
	assert_true(d["hour"] >= 0 and d["hour"] <= 23, "un paso negativo no da una hora negativa")
	assert_eq(Cal.at(-5, 1000, 0), Cal.at(0, 1000, 0), "un paso negativo cuenta como el paso 0")
	assert_eq(Cal.month_at(0, 181), 6, "mes de julio")
	assert_eq(Cal.text(Cal.at(7, 1000, 181)), "1 jul 1000 · 07:00", "texto")
	done()


func test_the_game_starts_on_the_reference_date_and_the_clock_follows_the_step_counter() -> void:
	DirAccess.make_dir_recursive_absolute("user://pruebas_calendario")
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	var s = load(SESSION).new(PATH, "0.0.test")
	assert_true(s.start(1800000000), "arranca")
	assert_eq(s.time_text(), "1 jul 1000 · 00:00", "la partida nueva empieza el 1 de julio de 1000")
	s.world.run_steps(24 + 5)
	assert_eq(s.time_text(), "2 jul 1000 · 05:00", "un día y cinco horas después")
	s.world.run_steps(184 * 24 - 29)
	assert_eq(s.date()["year"], 1001, "tras 184 días entra el año 1001")
	assert_eq(s.date()["season"], "winter", "en pleno invierno")
	done()


func test_the_calendar_is_not_part_of_the_save_file() -> void:
	DirAccess.make_dir_recursive_absolute("user://pruebas_calendario")
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	var s = load(SESSION).new(PATH, "0.0.test")
	s.start(1800000000)
	s.world.run_steps(1000)
	assert_eq(s.save(1800000100), "", "guarda")
	var text := FileAccess.get_file_as_string(PATH)
	assert_true(not ("calendar" in text) and not ("year" in text), "el archivo de guardado no contiene calendario")
	var again = load(SESSION).new(PATH, "0.0.test")
	again.start(1800000100)
	assert_eq(again.time_text(), s.time_text(), "al cargar, la fecha sale otra vez del contador de pasos")
	done()
