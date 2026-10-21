extends "res://tests/test_case.gd"
## Prueba que falla a propósito. Solo se ejecuta con "-- --selftest-fail".
## Sirve para comprobar que el ejecutor detecta fallos y devuelve un código de salida distinto de cero.


func test_intentional_failure() -> void:
	assert_true(false, "este fallo es intencionado")
