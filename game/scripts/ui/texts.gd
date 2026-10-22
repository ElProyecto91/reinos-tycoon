extends RefCounted
## Textos de la interfaz (español) y formato de cantidades. Sin nodos: se puede probar.

const Fixed := preload("res://scripts/sim/fixed.gd")

const STATUS_TEXT := {
	"idle": "Sin actividad",
	"running": "Produciendo",
	"disabled": "Desactivado",
	"no_workers": "Faltan trabajadores",
	"missing_inputs": "Faltan insumos",
	"no_upkeep": "Falta mantenimiento",
	"storage_full": "Almacén lleno",
}

## Avisos de provincia: texto y gravedad (2 = grave, 1 = atención, 0 = informativo: se
## lista en la ficha pero no marca el mapa, para que el mapa solo llame la atención cuando
## importa)
const ALERT_TEXT := {
	"hunger_warning": "Falta comida: aviso",
	"unrest": "Descontento alto: se trabaja más despacio",
	"starvation": "Hambruna: la población disminuye",
	"storage_full": "Almacén lleno: la producción se detiene",
	"no_workers": "Hay edificios sin trabajadores",
	"waste": "Se desperdicia producción por falta de espacio",
	"soldiers_unpaid": "Los soldados no cobran: sube el descontento",
}
const ALERT_SEVERITY := {
	"hunger_warning": 1, "unrest": 1, "starvation": 2, "storage_full": 0, "no_workers": 1, "waste": 0, "soldiers_unpaid": 1,
}


## Cantidad exacta en unidades, con coma decimal y sin ceros sobrantes:
## 12500 -> "12,5"; 1000 -> "1"; 50 -> "0,05"; -250 -> "-0,25". No se redondea: lo que se
## muestra es lo que hay.
static func amount(milli: int) -> String:
	var sign_text := "-" if milli < 0 else ""
	var m := absi(milli)
	var whole := Fixed.div_floor(m, 1000)
	var fraction := m % 1000
	if fraction == 0:
		return sign_text + str(whole)
	var digits := "%03d" % fraction
	while digits.ends_with("0"):
		digits = digits.substr(0, digits.length() - 1)
	return "%s%d,%s" % [sign_text, whole, digits]


## Cantidad corta para fichas pequeñas, siempre **truncada hacia abajo** (nunca redondeada hacia arriba,
## para no enseñar más de lo que hay): 123456 -> "123"; 33786 -> "33"; 2750 -> "2,7"; 20 -> "0,02"; 0 -> "0".
## El valor exacto sale al pulsar la ficha (Texts.amount).
static func compact(milli: int) -> String:
	if milli < 0:
		return "-" + compact(-milli)
	if milli >= 10000:
		return str(Fixed.div_floor(milli, 1000))
	if milli >= 1000:
		var tenths := Fixed.div_floor(milli, 100)
		return _decimal(tenths, 10)
	if milli >= 10:
		return _decimal(Fixed.div_floor(milli, 10), 100)
	if milli > 0:
		return "<0,01"
	return "0"


static func _decimal(scaled: int, scale: int) -> String:
	var whole := Fixed.div_floor(scaled, scale)
	var rest := scaled % scale
	if rest == 0:
		return str(whole)
	var digits := ("%d" % rest) if scale == 10 else ("%02d" % rest)
	if digits.ends_with("0") and scale == 100:
		digits = digits.substr(0, digits.length() - 1)
	return "%d,%s" % [whole, digits]


## Con signo explícito para variaciones: "+3", "-1,5".
static func signed_amount(milli: int) -> String:
	return ("+" if milli > 0 else "") + amount(milli)


## Clase de un estado de edificio para elegir color: "ok" (produce), "idle" (parado a propósito o sin
## actividad) o "warn" (algo le impide trabajar).
static func status_class(status: String) -> String:
	if status == "running":
		return "ok"
	if status == "idle" or status == "disabled":
		return "idle"
	return "warn"


static func status_text(status: String) -> String:
	return STATUS_TEXT.get(status, status)


static func alert_text(code: String) -> String:
	return ALERT_TEXT.get(code, code)


static func alert_severity(codes: Array) -> int:
	var worst := 0
	for code in codes:
		worst = maxi(worst, ALERT_SEVERITY.get(code, 1))
	return worst


static func good_name(data, good_id: String) -> String:
	if data.goods.has(good_id):
		return data.goods[good_id]["name"]
	return good_id


static func building_name(data, type_id: String) -> String:
	if data.buildings.has(type_id):
		return data.buildings[type_id]["name"]
	return type_id


## {"wood": 1500, "coin": 2000} -> "Madera 1,5 · Moneda 2"
static func goods_text(data, amounts: Dictionary) -> String:
	var parts: Array[String] = []
	var ids: Array = amounts.keys()
	ids.sort()
	for good_id in ids:
		parts.append("%s %s" % [good_name(data, good_id), amount(amounts[good_id])])
	return " · ".join(parts)


## 7500 -> "2 h 05 min"; 90 -> "1 min"; 30 -> "menos de 1 min"
static func duration(seconds: int) -> String:
	var minutes := Fixed.div_floor(seconds, 60)
	if minutes < 1:
		return "menos de 1 min"
	var hours := Fixed.div_floor(minutes, 60)
	if hours < 1:
		return "%d min" % minutes
	var days := Fixed.div_floor(hours, 24)
	if days >= 1:
		return "%d d %d h" % [days, hours % 24]
	return "%d h %02d min" % [hours, minutes % 60]


## Texto del resumen al volver tras una ausencia (resultado de Offline.settle).
static func offline_text(data, report: Dictionary) -> String:
	var lines: Array[String] = []
	var problem: String = report.get("clock_problem", "")
	if problem == "clock_went_back":
		return "La hora del dispositivo es anterior a la del último guardado, así que no se ha sumado tiempo. Si cambiaste el reloj, vuelve a ponerlo en hora."
	if problem == "unknown_saved_time":
		return "No se conocía la hora del último guardado, así que no se ha sumado tiempo."
	lines.append("Estuviste fuera %s." % duration(report["elapsed_seconds"]))
	lines.append("Se simularon %d pasos (%d horas de juego)." % [report["steps"], report["steps"]])
	if report["capped"]:
		lines.append("Se aplicó el límite de ausencia: lo que pasó de %s no cuenta." % duration(data.rules["offline_limit_seconds"]))
	for entry in report["provinces"]:
		lines.append("")
		lines.append(entry["name"])
		lines.append("  Población: %d → %d" % [entry["population_before"], entry["population_after"]])
		var changes: Array[String] = []
		var goods: Array = entry["stock_delta"].keys()
		goods.sort()
		for good_id in goods:
			changes.append("%s %s" % [good_name(data, good_id), signed_amount(entry["stock_delta"][good_id])])
		if not changes.is_empty():
			lines.append("  Existencias: " + ", ".join(changes))
		var built: Array[String] = []
		for type_id in entry["buildings_after"].keys():
			var gained: int = entry["buildings_after"][type_id] - entry["buildings_before"].get(type_id, 0)
			if gained > 0:
				built.append("%d %s" % [gained, building_name(data, type_id)])
		if not built.is_empty():
			lines.append("  Terminadas: " + ", ".join(built))
		if entry["worst_hunger_steps"] >= data.rules["hunger_warning_steps"]:
			lines.append("  Hubo hambre: hasta %d pasos seguidos sin comida." % entry["worst_hunger_steps"])
		for code in entry["alerts"]:
			if ALERT_SEVERITY.get(code, 1) > 0:
				lines.append("  Aviso: " + alert_text(code))
	return "\n".join(lines)


## Resultado de la medición de velocidad: milisegundos por paso con dos decimales.
static func speed_text(result: Dictionary) -> String:
	if result["steps"] <= 0:
		return "No se pudo medir."
	var centi_ms := Fixed.div_floor(result["microseconds"] * 100, result["steps"] * 1000)
	var total_ms := Fixed.div_floor(result["microseconds"], 1000)
	return "%d pasos de %d provincias en %d ms.\nCada paso tarda unos %d,%02d ms en este dispositivo.\nAnota este dato: sirve para decidir el ritmo del juego." % [result["steps"], result["provinces"], total_ms, Fixed.div_floor(centi_ms, 100), centi_ms % 100]
