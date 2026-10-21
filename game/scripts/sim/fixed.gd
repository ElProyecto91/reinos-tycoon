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
