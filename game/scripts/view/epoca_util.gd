extends RefCounted
## Paleta y utilidades comunes de los edificios de época (ver docs/REGION_IBERIA_1000.md,
## sección «Aspecto urbano y arquitectónico»). Todo es determinista: sin azar.
##
## Unidades: una casilla hexagonal tiene 2,0 de ancho (apotema 1,0). Nada está a escala real.

# --- Paleta (sRGB). Los nombres dicen el material, no la región. ---------------------------------
const TAPIAL := Color(0.72, 0.58, 0.41)        # tierra apisonada
const CAL := Color(0.86, 0.81, 0.70)           # cal o yeso (Zaragoza: H-23)
const OCRE := Color(0.77, 0.63, 0.44)
const CALIZA := Color(0.78, 0.69, 0.53)        # sillería clara (Córdoba, Madinat al-Zahra: H-21)
const PIEDRA_NORTE := Color(0.56, 0.53, 0.48)
const LADRILLO := Color(0.64, 0.39, 0.27)
const TEJA := Color(0.66, 0.35, 0.23)
const TEJA_OSCURA := Color(0.50, 0.28, 0.20)
const MADERA := Color(0.44, 0.31, 0.21)
const MADERA_CLARA := Color(0.62, 0.48, 0.32)
const PAJA := Color(0.77, 0.65, 0.39)
const SUELO_PATIO := Color(0.55, 0.45, 0.32)
const TIERRA := Color(0.50, 0.40, 0.28)
const SOMBRA := Color(0.24, 0.19, 0.15)        # interior oscuro de arcos y puertas
const AGUA := Color(0.36, 0.54, 0.60)
const VERDE_HUERTA := Color(0.33, 0.48, 0.23)
const VERDE_HUERTA_2 := Color(0.42, 0.55, 0.27)
const TRIGO := Color(0.76, 0.63, 0.31)
const BARBECHO := Color(0.60, 0.48, 0.31)
const OLIVO_COPA := Color(0.44, 0.49, 0.33)
const ENCINA_COPA := Color(0.23, 0.35, 0.19)
const ROBLE_COPA := Color(0.29, 0.43, 0.21)
const CIPRES := Color(0.15, 0.27, 0.19)
const PINO_COPA := Color(0.21, 0.37, 0.21)
const TRONCO := Color(0.40, 0.30, 0.22)
const TOLDOS: Array[Color] = [
	Color(0.68, 0.30, 0.22), Color(0.80, 0.66, 0.38), Color(0.38, 0.48, 0.58), Color(0.80, 0.77, 0.68),
]


## Número en [0, 1) que depende solo de (semilla, k): mismo resultado siempre.
static func rnd(seed: int, k: int) -> float:
	var x: int = (seed * 73856093) ^ (k * 19349663) ^ 0x5bd1e995
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return float(x & 0xffff) / 65536.0


## Semilla estable de una casilla.
static func seed_of(q: int, r: int) -> int:
	return posmod(q * 7919 + r * 104729 + 17, 1000003)


## Mitad del ancho de la casilla a la distancia z del centro (hexágono con la punta hacia ±z).
static func hex_half_width(z: float) -> float:
	var az := absf(z)
	if az <= 0.57735:
		return 1.0
	return maxf(0.0, 1.0 - (az - 0.57735) * 1.7320508)


## ¿Está el punto (x, z) dentro de la casilla con un margen? (apotema 1,0)
static func in_hex(x: float, z: float, margin: float = 0.0) -> bool:
	var a := 1.0 - margin
	return absf(x) <= a and absf(0.5 * x + 0.8660254 * z) <= a and absf(-0.5 * x + 0.8660254 * z) <= a


## Color con un poco de variación (amount ~0.04) según la semilla.
static func jit(col: Color, amount: float, seed: int, k: int = 0) -> Color:
	var d := (rnd(seed, k) - 0.5) * 2.0 * amount
	return Color(clampf(col.r + d, 0, 1), clampf(col.g + d * 0.9, 0, 1), clampf(col.b + d * 0.8, 0, 1), 1.0)


## Dirección (x, z) del borde e de la casilla (0 = este, 1 = noreste… sentido antihorario visto desde arriba).
static func edge_dir(e: int) -> Vector3:
	var a := deg_to_rad(60.0 * float(e))
	return Vector3(cos(a), 0.0, -sin(a))
