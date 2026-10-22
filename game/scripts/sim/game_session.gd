extends RefCounted
## Sesión de juego: junta datos, mapa, mundo, guardado y progreso offline. Sin pantalla y
## sin reloj propio (quien llama pasa la hora), para poder probarla entera.
##
## Arranque: si hay guardado se carga y se aplica la ausencia; si no hay ninguno, partida
## nueva desde el mapa. Si hay guardado pero no se puede leer (ni la copia .bak), los
## archivos dañados se apartan con otro nombre —no se borran— y se empieza una partida
## nueva avisando al jugador.

const GameDataScript := preload("res://scripts/sim/game_data.gd")
const GameMapScript := preload("res://scripts/sim/game_map.gd")
const SaveGameScript := preload("res://scripts/sim/save_game.gd")
const OfflineScript := preload("res://scripts/sim/offline.gd")
const CalendarScript := preload("res://scripts/sim/calendar.gd")

var data = null
var map = null
var world = null
var save_path: String
var game_version: String
## Hora (Unix) hasta la que el mundo está al día
var stamp: int = 0
## Aviso para el jugador (copia anterior usada, guardado dañado apartado…); "" si no hay
var notice: String = ""
## Resultado de la última aplicación de ausencia (ver Offline.settle); vacío si no hubo
var last_report: Dictionary = {}
## Errores que impiden jugar (datos de juego inválidos…)
var errors: Array[String] = []


func _init(path: String, version: String) -> void:
	save_path = path
	game_version = version


## Carga datos y mapa y arranca la partida. Devuelve false si no se puede jugar (ver `errors`).
func start(now: int) -> bool:
	errors = []
	notice = ""
	last_report = {}
	data = GameDataScript.new()
	if not data.load_defaults():
		for e in data.errors:
			errors.append(e)
		return false
	map = GameMapScript.new()
	if not map.load_defaults(data):
		for e in map.errors:
			errors.append(e)
		return false
	var any_file := FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")
	if any_file:
		var loaded: Dictionary = SaveGameScript.read_file(data, save_path, map.trade_links())
		if loaded["ok"]:
			var mismatch := _map_mismatch(loaded["world"])
			if mismatch == "":
				world = loaded["world"]
				notice = loaded["warning"]
				last_report = OfflineScript.settle(world, loaded["saved_at"], now)
				stamp = last_report["new_saved_at"]
				return true
			# Un guardado de otro mapa no se puede mostrar (las provincias no coinciden):
			# se aparta entero, sin borrarlo, y se empieza una partida nueva.
			var kept_old := _set_aside_files(now, "mapa-anterior")
			notice = "La partida guardada es de otro mapa (%s). Se conservó una copia en %s y se empezó una partida nueva." % [mismatch, kept_old]
			return new_game(now)
		var kept := _set_aside_files(now, "danada")
		notice = "No se pudo leer la partida guardada (%s). Se conservó una copia en %s y se empezó una partida nueva." % [loaded["error"], kept]
	return new_game(now)


func new_game(now: int) -> bool:
	var created: Dictionary = map.new_world(data)
	if not created["ok"]:
		errors.append(created["error"])
		return false
	world = created["world"]
	last_report = {}
	stamp = now
	return true


## Guarda la partida. Devuelve "" si salió bien o el motivo del fallo.
func save(now: int) -> String:
	var error: String = SaveGameScript.write_file(world, save_path, game_version, now)
	if error == "":
		stamp = now
	return error


## Al volver a la aplicación tras una pausa: aplica la ausencia desde la última marca.
func resume(now: int) -> Dictionary:
	last_report = OfflineScript.settle(world, stamp, now)
	stamp = last_report["new_saved_at"]
	return last_report


## Mide cuánto tarda la simulación en este dispositivo (criterio A12). Usa una partida
## nueva aparte: no toca la partida en curso. Devuelve {steps, provinces, microseconds}.
func measure_speed(steps: int) -> Dictionary:
	var created: Dictionary = map.new_world(data)
	if not created["ok"]:
		return {"steps": 0, "provinces": 0, "microseconds": 0}
	var scratch = created["world"]
	var started := Time.get_ticks_usec()
	scratch.run_steps(steps)
	return {"steps": steps, "provinces": scratch.provinces.size(), "microseconds": Time.get_ticks_usec() - started}


## Fecha actual del juego (ver calendar.gd), derivada del contador de pasos.
func date() -> Dictionary:
	var year: int = int(data.rules.get("calendar_start_year", 0))
	return CalendarScript.at(world.step_count, year if year > 0 else 1000, int(data.rules.get("calendar_start_day", 0)))


## "15 jul 1000 · 07:00" a partir del contador de pasos (un paso = una hora de juego).
func time_text() -> String:
	return CalendarScript.text(date())


## Texto vacío si las provincias del guardado son exactamente las del mapa; si no, cuáles difieren.
func _map_mismatch(saved_world) -> String:
	var saved_ids: Array[String] = []
	for province in saved_world.provinces:
		saved_ids.append(province.id)
	var map_ids: Array[String] = []
	for entry in map.provinces:
		map_ids.append(entry["id"])
	saved_ids.sort()
	map_ids.sort()
	if saved_ids == map_ids:
		return ""
	return "provincias guardadas: %s; provincias del mapa: %s" % [", ".join(saved_ids), ", ".join(map_ids)]


## Aparta los archivos de guardado con otro nombre (no se borran). `label` va en el nombre.
func _set_aside_files(now: int, label: String) -> String:
	var target := "%s.%s-%d" % [save_path, label, now]
	for suffix in ["", ".bak"]:
		var source: String = save_path + suffix
		if FileAccess.file_exists(source):
			var text := FileAccess.get_file_as_string(source)
			var file := FileAccess.open(target + suffix, FileAccess.WRITE)
			if file != null:
				file.store_string(text)
				file.close()
			DirAccess.remove_absolute(source)
	return target.get_file()
