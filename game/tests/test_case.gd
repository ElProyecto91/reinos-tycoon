extends RefCounted
## Base común de las pruebas. Cada archivo de prueba hereda de este
## y define métodos cuyo nombre empieza por "test_".

var failures: Array[String] = []


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (esperado: %s, obtenido: %s)" % [message, str(expected), str(actual)])
