extends RefCounted
## Guerra y conquista (docs/DISENO_CONQUISTA.md, piezas CQ1 a CQ4 y la defensa de CQ6).
##
## Cada provincia tiene un propietario (un reino); el jugador manda un reino (`world.player_realm`).
## Los soldados salen de una provincia propia (`recruits`) hacia una colindante: si es propia se suman a su guarnición;
## si es de otro reino, al llegar hay batalla. Todo es entero y determinista (sin azar): mismos datos, mismo resultado.
##
## Batalla: fuerza de ataque = soldados × war_attack_percent; defensa = (soldados de la guarnición + milicia, un
## war_militia_percent de la población) × war_defense_percent. En cada ronda cada bando pierde war_round_loss_percent de la
## fuerza del contrario (al menos 1). Gana el atacante si la defensa llega a 0 con él en pie; en cualquier otro caso
## (empate, o sin decidirse tras war_max_rounds) aguanta el defensor.
## Los rivales, por ahora, solo defienden: no atacan.
##
## Todas las cifras son parámetros de juego (rules.json, claves war_*), no datos históricos.

const Fixed := preload("res://scripts/sim/fixed.gd")
const StoreScript := preload("res://scripts/sim/store.gd")

const MAX_ARMIES := 200


static func enabled(world) -> bool:
	return world.player_realm != "" and not world.owners.is_empty() and int(world.data.rules.get("war_march_steps_per_hop", 0)) > 0


## ¿Manda el jugador en esta provincia? Sin reino de jugador (mundos de prueba sueltos) mandan en todas.
static func is_player(world, province_id: String) -> bool:
	if world.player_realm == "":
		return true
	return world.owners.get(province_id, "") == world.player_realm


## Soldados que defienden una provincia: guarnición propia más milicia.
static func garrison_of(world, province) -> int:
	var rules: Dictionary = world.data.rules
	return province.recruits + Fixed.percent_of(province.population, int(rules.get("war_militia_percent", 0)))


## Fuerza de defensa que se enfrentaría a un ataque (guarnición × factor de defensa).
static func defense_strength(world, province) -> int:
	return Fixed.percent_of(garrison_of(world, province), int(world.data.rules.get("war_defense_percent", 100)))


## Fuerza de un ejército atacante de `soldiers` soldados.
static func attack_strength(world, soldiers: int) -> int:
	return Fixed.percent_of(soldiers, int(world.data.rules.get("war_attack_percent", 100)))


## Resuelve una batalla sin tocar nada: devuelve {won, attacker_left, defender_left, rounds}. Función pura, para poder probarla.
static func resolve(attackers: int, garrison: int, rules: Dictionary) -> Dictionary:
	var att_pct: int = int(rules.get("war_attack_percent", 100))
	var def_pct: int = int(rules.get("war_defense_percent", 100))
	var loss_pct: int = int(rules.get("war_round_loss_percent", 15))
	var max_rounds: int = int(rules.get("war_max_rounds", 60))
	var a: int = Fixed.percent_of(maxi(attackers, 0), att_pct)
	var d: int = Fixed.percent_of(maxi(garrison, 0), def_pct)
	var rounds := 0
	while a > 0 and d > 0 and rounds < max_rounds:
		var lose_a: int = maxi(1, Fixed.percent_of(d, loss_pct))
		var lose_d: int = maxi(1, Fixed.percent_of(a, loss_pct))
		a = maxi(a - lose_a, 0)
		d = maxi(d - lose_d, 0)
		rounds += 1
	var won: bool = a > 0 and d <= 0
	var attacker_left: int = mini(attackers, Fixed.div_ceil(a * 100, att_pct)) if (a > 0 and att_pct > 0) else 0
	var defender_left: int = mini(garrison, Fixed.div_ceil(d * 100, def_pct)) if (d > 0 and def_pct > 0) else 0
	return {"won": won, "attacker_left": attacker_left, "defender_left": defender_left, "rounds": rounds}


## ¿Puede el jugador mandar soldados de `from_id` a `to_id`? Devuelve "" si sí o el motivo.
static func order_problem(world, from_id: String, to_id: String, count: int) -> String:
	if not enabled(world):
		return "no hay guerra en esta partida"
	var origin = world.find_province(from_id)
	var target = world.find_province(to_id)
	if origin == null or target == null or from_id == to_id:
		return "provincias no válidas"
	if not is_player(world, from_id):
		return "la provincia de salida no es tuya"
	if not world.trade_links.has(from_id) or not (to_id in world.trade_links[from_id]["neighbors"]):
		return "solo se marcha a una provincia colindante"
	if count < 1 or count > origin.recruits:
		return "no hay tantos soldados"
	if world.armies.size() >= MAX_ARMIES:
		return "demasiados ejércitos en marcha"
	return ""


## Manda `count` soldados de una provincia propia a otra colindante (propia: refuerzo; ajena: ataque).
## Devuelve {"ok", "error"}. No cambia nada si hay algún problema.
static func send(world, from_id: String, to_id: String, count: int) -> Dictionary:
	var problem := order_problem(world, from_id, to_id, count)
	if problem != "":
		return {"ok": false, "error": problem}
	var origin = world.find_province(from_id)
	origin.release_recruits(count)
	world.armies.append({
		"from": from_id, "to": to_id, "soldiers": count,
		"arrive": world.step_count + int(world.data.rules["war_march_steps_per_hop"]),
	})
	return {"ok": true, "error": ""}


## Provincias ajenas colindantes con alguna propia (las que se pueden atacar).
static func attackable(world) -> Array[String]:
	var out: Array[String] = []
	if not enabled(world):
		return out
	for province in world.provinces:
		if is_player(world, province.id):
			continue
		for n in world.trade_links.get(province.id, {}).get("neighbors", []):
			if is_player(world, n):
				out.append(province.id)
				break
	return out


## Un paso de la guerra: llegan los ejércitos y, una vez al día, se cobra la administración.
static func step(world) -> void:
	if not enabled(world):
		return
	if not world.armies.is_empty():
		_arrivals(world)
	if world.step_count % 24 == 0:
		_administration(world)


static func _arrivals(world) -> void:
	var pending: Array = []
	var arrived: Array = []
	for army in world.armies:
		if int(army["arrive"]) > world.step_count:
			pending.append(army)
		else:
			arrived.append(army)
	world.armies = pending
	for army in arrived:
		_arrive(world, army)


static func _arrive(world, army: Dictionary) -> void:
	var target = world.find_province(army["to"])
	if target == null:
		return
	var soldiers: int = army["soldiers"]
	if is_player(world, army["to"]):
		target.recruits += soldiers     # refuerzo (o el ejército llega a una provincia que ya es suya)
		return
	var rules: Dictionary = world.data.rules
	var garrison: int = garrison_of(world, target)
	var result := resolve(soldiers, garrison, rules)
	var report := {
		"step": world.step_count, "from": army["from"], "to": army["to"], "attacker_realm": world.player_realm,
		"defender_realm": world.owners.get(army["to"], ""), "sent": soldiers, "garrison": garrison,
		"attacker_left": result["attacker_left"], "defender_left": result["defender_left"],
		"won": result["won"], "rounds": result["rounds"],
	}
	# Bajas del defensor: primero la guarnición, después la milicia (que sale de la población).
	var defender_losses: int = garrison - result["defender_left"]
	var from_garrison := mini(defender_losses, target.recruits)
	target.recruits -= from_garrison
	var min_population: int = int(rules.get("min_population", 1))
	target.population = maxi(target.population - (defender_losses - from_garrison), mini(min_population, target.population))
	world.war_dead += (soldiers - result["attacker_left"]) + defender_losses
	if result["won"]:
		world.set_owner(army["to"], world.player_realm)
		target.recruits += result["attacker_left"]
		target.unrest = maxi(target.unrest, mini(int(rules.get("war_conquest_unrest", 0)), int(rules["unrest_max"])))
	world.battle_log.append(report)
	world.battle_count += 1
	if world.battle_log.size() > 20:
		world.battle_log.pop_front()


## Coste de administrar un imperio: cada día cada provincia propia paga war_admin_cost por cada otra provincia propia.
static func _administration(world) -> void:
	var cost_each: int = int(world.data.rules.get("war_admin_cost", 0))
	if cost_each <= 0:
		return
	var owned: Array = []
	for province in world.provinces:
		if is_player(world, province.id):
			owned.append(province)
	if owned.size() < 2:
		return
	var due: int = cost_each * (owned.size() - 1)
	for province in owned:
		province.store.remove(world.data.rules["currency"], due, StoreScript.CONSUMED)


## Soldados en total (en guarniciones y en marcha), para comprobar que no se crean ni se pierden de la nada.
static func total_soldiers(world) -> int:
	var total := 0
	for province in world.provinces:
		total += province.recruits
	for army in world.armies:
		total += int(army["soldiers"])
	return total
