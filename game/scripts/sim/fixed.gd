extends RefCounted
## Aritmética entera para la simulación (ver D-012).
##
## Todas las divisiones redondean hacia abajo (o hacia arriba en div_ceil) y
## trabajan con valores no negativos. Estar aquí evita repartir por el código
## las divisiones enteras, que Godot avisa con una advertencia.


@warning_ignore("integer_division")
static func div_floor(value: int, divisor: int) -> int:
	return value / divisor


@warning_ignore("integer_division")
static func div_ceil(value: int, divisor: int) -> int:
	return (value + divisor - 1) / divisor


## value * percent / 100, redondeado hacia abajo.
static func percent_of(value: int, percent: int) -> int:
	return div_floor(value * percent, 100)


## value * percent_a * percent_b / 10000, redondeado hacia abajo (dos porcentajes encadenados).
static func percent_of_2(value: int, percent_a: int, percent_b: int) -> int:
	return div_floor(value * percent_a * percent_b, 10000)


## Convierte un número leído de JSON (que siempre llega como decimal) a entero.
## Devuelve null si no es un número entero exacto o si se sale de lo que un decimal
## representa sin pérdida (unos 9e15).
static func exact_int(value: Variant) -> Variant:
	var kind := typeof(value)
	if kind == TYPE_INT:
		return value
	if kind == TYPE_FLOAT and value == floor(value) and absf(value) < 9.0e15:
		return int(value)
	return null
