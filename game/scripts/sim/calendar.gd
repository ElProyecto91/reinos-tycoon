extends RefCounted
## Calendario del juego, derivado del contador de pasos (nunca se guarda): un paso es una hora, un día
## son 24 pasos y un año son 365 días (8760 pasos) sin años bisiestos (D-022, D-031).
##
## El año, el día de partida y la longitud de los meses son convenciones de juego. Las estaciones por mes
## también (primavera marzo–mayo, verano junio–agosto, otoño septiembre–noviembre, invierno
## diciembre–febrero): la fuente de las labores agrícolas (H-10) no da fechas de inicio de estación.

const STEPS_PER_DAY := 24
const DAYS_PER_YEAR := 365
const STEPS_PER_YEAR := STEPS_PER_DAY * DAYS_PER_YEAR
const MONTH_DAYS: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const MONTH_NAMES: Array[String] = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
const MONTH_SHORT: Array[String] = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
const SEASON_OF_MONTH: Array[String] = ["winter", "winter", "spring", "spring", "spring", "summer", "summer", "summer", "autumn", "autumn", "autumn", "winter"]
const SEASON_NAMES := {"winter": "Invierno", "spring": "Primavera", "summer": "Verano", "autumn": "Otoño"}
## Icono de cada estación (ver icons.gd).
const SEASON_ICONS := {"winter": "snow", "spring": "sprout", "summer": "sun", "autumn": "leaf"}


## Fecha de un paso. `start_year` y `start_day` (día del año de 0 a 364) son del inicio de la partida.
## Devuelve {year, month (0 a 11), day (desde 1), hour, day_of_year (0 a 364), season}.
static func at(step: int, start_year: int, start_day: int) -> Dictionary:
	var total_hours: int = maxi(step, 0)
	var days: int = total_hours / STEPS_PER_DAY
	var hour: int = total_hours % STEPS_PER_DAY
	var absolute_day: int = clampi(start_day, 0, DAYS_PER_YEAR - 1) + days
	var year: int = start_year + absolute_day / DAYS_PER_YEAR
	var day_of_year: int = absolute_day % DAYS_PER_YEAR
	var month := 0
	var left := day_of_year
	while month < 11 and left >= MONTH_DAYS[month]:
		left -= MONTH_DAYS[month]
		month += 1
	return {"year": year, "month": month, "day": left + 1, "hour": hour, "day_of_year": day_of_year, "season": SEASON_OF_MONTH[month]}


## Mes (0 a 11) de un paso, para tablas por mes.
static func month_at(step: int, start_day: int) -> int:
	return at(step, 0, start_day)["month"]


## "15 jul 1000 · 07:00"
static func text(date: Dictionary) -> String:
	return "%d %s %d · %02d:00" % [date["day"], MONTH_SHORT[date["month"]], date["year"], date["hour"]]
