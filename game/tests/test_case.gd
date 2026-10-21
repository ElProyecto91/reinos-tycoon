extends RefCounted
## Base común de las pruebas. Cada archivo de prueba hereda de este
## y define métodos cuyo nombre empieza por "test_".

var failures: Array[String] = []
## Cada prueba debe llamar a done() como última línea. Si no llega (por un error de
## ejecución a mitad de la prueba), el ejecutor la cuenta como fallo en vez de darla por buena.
var finished: bool = false


func done() -> void:
	finished = true


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (esperado: %s, obtenido: %s)" % [message, str(expected), str(actual)])
