extends "res://tests/test_case.gd"
## Pruebas de humo de la fase 0: comprueban que el ejecutor y el proyecto funcionan.
## No prueban ninguna regla del juego.


func test_basic_arithmetic() -> void:
	assert_eq(2 + 2, 4, "2 + 2 debe ser 4")


func test_project_version_defined() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	assert_true(version != "", "application/config/version debe estar definida")
