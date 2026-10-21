extends RefCounted
## Guardado y carga de partidas.
##
## Formato: un JSON con versión de formato, versión del juego, el estado como texto
## (`payload`) y la suma de control SHA-256 de ese texto. Comprobar la suma antes de
## interpretar nada detecta archivos truncados o alterados.
##
## Escritura segura: se escribe un archivo temporal, se relee y se compara; solo
## entonces el guardado anterior pasa a `.bak` y el nuevo ocupa su sitio. Un corte a
## mitad de escritura deja intacto el guardado anterior. Al leer, si el principal falla
## se prueba la copia `.bak`.
##
## Los números del estado son enteros (D-012), pero JSON los entrega como decimales:
## al cargar se convierten y se rechazan los que no sean enteros exactos.

const FORMAT_VERSION := 1

const Fixed := preload("res://scripts/sim/fixed.gd")
const WorldScript := preload("res://scripts/sim/world.gd")


static func encode(world, game_version: String, saved_at: int = 0) -> String:
	return pack(world.to_dict(), game_version, saved_at)


## Envuelve un estado ya convertido en diccionario. Separado de encode() para poder
## probar la carga de estados alterados con suma de control correcta.
static func pack(payload: Dictionary, game_version: String, saved_at: int = 0) -> String:
	var payload_text := JSON.stringify(payload, "", true)
	var envelope := {
		"format_version": FORMAT_VERSION,
		"game_version": game_version,
		"saved_at": saved_at,
		"checksum": payload_text.sha256_text(),
		"payload": payload_text,
	}
	return JSON.stringify(envelope, "\t", true)


## Interpreta un texto de guardado. Devuelve {ok, world, error, game_version, saved_at}.
## `saved_at` es la hora Unix del guardado (0 si falta o no es válida: el progreso offline
## trata un 0 como «hora desconocida» y no da recompensa). La hora está fuera del estado
## de la simulación a propósito: la simulación no depende del reloj.
static func decode(data, text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return _failure("El archivo de guardado está incompleto o dañado (JSON no válido en la línea %d)." % json.get_error_line())
	var envelope = json.data
	if typeof(envelope) != TYPE_DICTIONARY:
		return _failure("El archivo de guardado no tiene el formato esperado.")
	var version = Fixed.exact_int(envelope.get("format_version", null))
	if version == null:
		return _failure("Al guardado le falta la versión de formato.")
	if version > FORMAT_VERSION:
		return _failure("Este guardado es de una versión más nueva (%d) que la que entiende el juego (%d). Actualiza el juego." % [version, FORMAT_VERSION])
	if version < 1:
		return _failure("La versión de formato del guardado (%d) no es válida." % version)
	# Aquí irán las migraciones cuando exista una versión 2: se convierte el estado de
	# la versión n a la n+1 hasta llegar a FORMAT_VERSION.
	var payload_text = envelope.get("payload", null)
	var checksum = envelope.get("checksum", null)
	if typeof(payload_text) != TYPE_STRING or typeof(checksum) != TYPE_STRING:
		return _failure("Al guardado le falta el contenido o la suma de control.")
	if payload_text.sha256_text() != checksum:
		return _failure("La suma de control no coincide: el archivo de guardado está dañado.")
	var payload_json := JSON.new()
	if payload_json.parse(payload_text) != OK:
		return _failure("El contenido del guardado no es JSON válido.")
	var world = WorldScript.new(data)
	if not world.load_dict(payload_json.data):
		return _failure("El guardado no es coherente: %s." % world.last_error)
	var game_version = envelope.get("game_version", "")
	if typeof(game_version) != TYPE_STRING:
		game_version = ""
	var saved_at = Fixed.exact_int(envelope.get("saved_at", null))
	if saved_at == null or saved_at < 0:
		saved_at = 0
	return {"ok": true, "world": world, "error": "", "game_version": game_version, "saved_at": saved_at}


## Guarda de forma segura. Devuelve "" si salió bien o el motivo del fallo.
static func write_file(world, path: String, game_version: String, saved_at: int = 0) -> String:
	var text := encode(world, game_version, saved_at)
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK and error != ERR_ALREADY_EXISTS:
		return "No se pudo crear la carpeta de guardado (código %d)." % error
	var temp_path := path + ".tmp"
	var backup_path := path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return "No se pudo abrir el archivo temporal (código %d)." % FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	file.close()
	if FileAccess.get_file_as_string(temp_path) != text:
		DirAccess.remove_absolute(temp_path)
		return "Lo escrito no coincide con lo que se quería guardar; se conserva el guardado anterior."
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		error = DirAccess.rename_absolute(path, backup_path)
		if error != OK:
			return "No se pudo conservar el guardado anterior (código %d)." % error
	error = DirAccess.rename_absolute(temp_path, path)
	if error != OK:
		return "No se pudo colocar el guardado nuevo (código %d); el anterior sigue en la copia .bak." % error
	return ""


## Lee un guardado. Si el principal falla, prueba la copia .bak.
## Devuelve {ok, world, error, game_version, saved_at, used_backup, warning}.
static func read_file(data, path: String) -> Dictionary:
	var main := _read_one(data, path)
	if main["ok"]:
		main["used_backup"] = false
		main["warning"] = ""
		return main
	var backup := _read_one(data, path + ".bak")
	if backup["ok"]:
		backup["used_backup"] = true
		backup["warning"] = "No se pudo leer el guardado principal (%s) Se cargó la copia anterior." % main["error"]
		return backup
	main["used_backup"] = false
	main["warning"] = ""
	return main


static func _read_one(data, path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("No hay archivo de guardado en %s." % path)
	return decode(data, FileAccess.get_file_as_string(path))


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "world": null, "error": message, "game_version": "", "saved_at": 0}
