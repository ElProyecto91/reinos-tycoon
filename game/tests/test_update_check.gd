extends "res://tests/test_case.gd"
## Aviso de versión nueva (lógica pura). Los textos de respuesta de estas pruebas están
## escritos a mano siguiendo el formato documentado por GitHub («Get the latest
## release»: tag_name, html_url, draft, prerelease, body, assets[].name,
## browser_download_url, size); no son una respuesta real del repositorio, que todavía
## no tiene ninguna versión publicada.

const UPDATE_CHECK := "res://scripts/update/update_check.gd"
const REPO := "https://github.com/ElProyecto91/reinos-tycoon/"


func _release(overrides: Dictionary = {}) -> String:
	var release := {
		"tag_name": "v0.1.0", "name": "Reinos Tycoon 0.1.0", "draft": false, "prerelease": false,
		"html_url": REPO + "releases/tag/v0.1.0", "body": "Notas de la versión.",
		"assets": [
			{"name": "notas.txt", "browser_download_url": REPO + "releases/download/v0.1.0/notas.txt", "size": 10},
			{"name": "reinos-tycoon.apk", "browser_download_url": REPO + "releases/download/v0.1.0/reinos-tycoon.apk", "size": 25000000},
		],
	}
	for key in overrides.keys():
		release[key] = overrides[key]
	return JSON.stringify(release)


func test_parse_version_accepts_only_three_numbers() -> void:
	var script = load(UPDATE_CHECK)
	assert_eq(script.parse_version("0.0.3"), [0, 0, 3], "0.0.3")
	assert_eq(script.parse_version("v1.12.30"), [1, 12, 30], "con v delante")
	for bad in ["", "1", "1.2", "1.2.3.4", "v", "a.b.c", "1.2.x", "01.2.3", "1.2.3-beta", " 1.2.3", "1.2.3\n", "-1.2.3", "1.2.3000000"]:
		assert_eq(script.parse_version(bad), [], "no válida: «%s»" % bad)
	assert_eq(script.parse_version(null), [], "null")
	assert_eq(script.parse_version(3), [], "número")
	done()


func test_compare_is_numeric_not_textual() -> void:
	var script = load(UPDATE_CHECK)
	assert_eq(script.compare([0, 0, 10], [0, 0, 9]), 1, "0.0.10 es posterior a 0.0.9")
	assert_eq(script.compare([0, 9, 0], [0, 10, 0]), -1, "0.9.0 es anterior a 0.10.0")
	assert_eq(script.compare([1, 0, 0], [0, 99, 99]), 1, "la versión mayor manda")
	assert_eq(script.compare([1, 2, 3], [1, 2, 3]), 0, "iguales")
	done()


func test_newer_release_is_reported_with_trusted_links() -> void:
	var script = load(UPDATE_CHECK)
	var result: Dictionary = script.evaluate(_release(), "0.0.3")
	assert_true(result["ok"], "debe entenderse: %s" % result["error"])
	assert_true(result["newer"], "0.1.0 es más nueva que 0.0.3")
	assert_eq(result["tag"], "v0.1.0", "etiqueta")
	assert_eq(result["page_url"], REPO + "releases/tag/v0.1.0", "página de la versión")
	assert_eq(result["apk_url"], REPO + "releases/download/v0.1.0/reinos-tycoon.apk", "elige el APK, no las notas")
	assert_eq(result["apk_size"], 25000000, "tamaño")
	done()


func test_same_or_older_release_is_not_newer() -> void:
	var script = load(UPDATE_CHECK)
	assert_true(script.evaluate(_release(), "0.1.0")["ok"], "se entiende")
	assert_true(not script.evaluate(_release(), "0.1.0")["newer"], "misma versión: nada nuevo")
	assert_true(not script.evaluate(_release(), "0.2.0")["newer"], "versión instalada posterior: nada nuevo")
	done()


func test_drafts_and_prereleases_are_ignored() -> void:
	var script = load(UPDATE_CHECK)
	assert_true(not script.evaluate(_release({"draft": true}), "0.0.3")["ok"], "borrador")
	assert_true(not script.evaluate(_release({"prerelease": true}), "0.0.3")["ok"], "versión de prueba")
	done()


func test_untrusted_links_are_dropped() -> void:
	var script = load(UPDATE_CHECK)
	var hostile := _release({
		"html_url": "https://ejemplo.invalid/pagina",
		"assets": [{"name": "reinos.apk", "browser_download_url": "https://ejemplo.invalid/reinos.apk", "size": 1}],
	})
	var result: Dictionary = script.evaluate(hostile, "0.0.3")
	assert_true(result["ok"], "la respuesta se entiende")
	assert_true(result["newer"], "la versión es más nueva")
	assert_eq(result["page_url"], "", "no se acepta una página de otro sitio")
	assert_eq(result["apk_url"], "", "no se acepta un APK de otro sitio")
	var lookalike := _release({"html_url": "https://github.com/ElProyecto91/reinos-tycoon-falso/releases"})
	assert_eq(script.evaluate(lookalike, "0.0.3")["page_url"], "", "un nombre parecido no vale")
	done()


func test_garbage_responses_fail_cleanly() -> void:
	var script = load(UPDATE_CHECK)
	for text in ["", "no es json", "[]", "42", "{}", "{\"tag_name\": 5}", "{\"tag_name\": \"final\"}", "{\"message\": \"Not Found\"}", "{\"tag_name\": \"v1.0.0\", \"assets\": 7}"]:
		var result: Dictionary = script.evaluate(text, "0.0.3")
		if text == "{\"tag_name\": \"v1.0.0\", \"assets\": 7}":
			assert_true(result["ok"], "assets raro: la versión se entiende, sin APK")
			assert_eq(result["apk_url"], "", "sin APK")
		else:
			assert_true(not result["ok"], "debe fallar: «%s»" % text)
			assert_true(result["error"] != "", "con mensaje: «%s»" % text)
			assert_true(not result["newer"], "no hay nada nuevo si falla")
	assert_true(not script.evaluate(_release(), "versión rara")["ok"], "versión instalada no válida")
	done()
