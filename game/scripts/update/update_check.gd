extends RefCounted
## Aviso de versión nueva. Solo lógica, sin red: interpreta la respuesta de GitHub y
## decide si hay una versión más reciente. La petición HTTP se conecta aparte, en la
## pantalla de ajustes (tarea 1.9), y es opcional: el juego funciona sin conexión.
##
## No instala nada. Android no permite actualizar una app en silencio fuera de Google
## Play (D-015): el juego solo avisa y abre la página de la versión; el usuario descarga
## el APK y Android le pide confirmar la instalación.
##
## Seguridad: nunca se abre una dirección que no sea del repositorio del proyecto,
## aunque la respuesta (que puede estar alterada o ser basura) diga otra cosa.

const LATEST_URL := "https://api.github.com/repos/ElProyecto91/reinos-tycoon/releases/latest"
const TRUSTED_PREFIX := "https://github.com/ElProyecto91/reinos-tycoon/"


## "v0.1.2" o "0.1.2" -> [0, 1, 2]. Cualquier otra cosa -> [] (versión no válida).
static func parse_version(text: Variant) -> Array:
	if typeof(text) != TYPE_STRING:
		return []
	var regex := RegEx.new()
	regex.compile("^v?(0|[1-9][0-9]{0,5})\\.(0|[1-9][0-9]{0,5})\\.(0|[1-9][0-9]{0,5})\\z")
	var found := regex.search(text)
	if found == null:
		return []
	return [int(found.get_string(1)), int(found.get_string(2)), int(found.get_string(3))]


## -1 si a < b, 0 si son iguales, 1 si a > b. Se compara número a número, no como texto
## (0.0.10 es posterior a 0.0.9). Ambas deben ser versiones válidas.
static func compare(a: Array, b: Array) -> int:
	for i in range(3):
		if a[i] < b[i]:
			return -1
		if a[i] > b[i]:
			return 1
	return 0


## Interpreta el texto devuelto por GitHub para «última versión publicada».
## Devuelve {ok, error, newer, tag, page_url, apk_url, apk_size, notes}.
## `ok` solo dice que la respuesta se entendió; `newer` dice si hay algo nuevo.
static func evaluate(response_text: String, current_version: String) -> Dictionary:
	var current := parse_version(current_version)
	if current.is_empty():
		return _failure("La versión instalada («%s») no tiene el formato n.n.n." % current_version)
	var json := JSON.new()
	if json.parse(response_text) != OK:
		return _failure("La respuesta del servidor no es JSON válido.")
	var release = json.data
	if typeof(release) != TYPE_DICTIONARY:
		return _failure("La respuesta del servidor no tiene el formato esperado.")
	if release.get("draft", false) == true or release.get("prerelease", false) == true:
		return _failure("La última publicación es un borrador o una versión de prueba; se ignora.")
	var tag = release.get("tag_name", null)
	var remote := parse_version(tag)
	if remote.is_empty():
		return _failure("La etiqueta de la última versión no tiene el formato n.n.n.")
	var page_url := ""
	var html_url = release.get("html_url", null)
	if typeof(html_url) == TYPE_STRING and html_url.begins_with(TRUSTED_PREFIX):
		page_url = html_url
	var apk_url := ""
	var apk_size := 0
	var assets = release.get("assets", [])
	if typeof(assets) == TYPE_ARRAY:
		for asset in assets:
			if typeof(asset) != TYPE_DICTIONARY:
				continue
			var name = asset.get("name", "")
			var url = asset.get("browser_download_url", "")
			if typeof(name) == TYPE_STRING and name.ends_with(".apk") and typeof(url) == TYPE_STRING and url.begins_with(TRUSTED_PREFIX):
				apk_url = url
				var size = asset.get("size", 0)
				apk_size = int(size) if typeof(size) == TYPE_FLOAT or typeof(size) == TYPE_INT else 0
				break
	var notes := ""
	var body = release.get("body", "")
	if typeof(body) == TYPE_STRING:
		notes = body.substr(0, 600)
	return {
		"ok": true, "error": "", "newer": compare(current, remote) < 0,
		"tag": str(tag), "page_url": page_url, "apk_url": apk_url, "apk_size": apk_size,
		"notes": notes,
	}


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false, "error": message, "newer": false, "tag": "", "page_url": "",
		"apk_url": "", "apk_size": 0, "notes": "",
	}
