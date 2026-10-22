extends RefCounted
## Reinos rivales (docs/DISENO_CONQUISTA.md, CQ6): se arman solos y atacan al jugador.
##
## Es una IA mínima y determinista, sin azar:
## - Cada día (paso 6 de cada 24) cada provincia rival con moneda para pagarles levanta `war_ai_levy_per_day`
##   soldados, hasta un `war_ai_levy_target_percent` de su población. No gasta madera ni armas: es una leva abstracta.
## - Cada `war_ai_interval` pasos, y solo pasados `war_ai_start_steps` pasos de partida, cada reino rival elige UN ataque:
##   la provincia suya colindante con una del jugador que tenga al menos `war_ai_min_soldiers` soldados y la mejor
##   relación entre su fuerza de ataque y la defensa del objetivo. Ataca solo si esa relación llega a `war_ai_ratio_percent` %.
##   Manda todos los soldados menos un `war_ai_keep_percent` % que se queda de guarnición.
## - Los rivales no se atacan entre sí y nunca quitan la última provincia al jugador.
## - Con la ausencia en curso (`world.ai_paused`, ver Offline) no atacan, pero la leva sigue: así el progreso offline es igual que jugar salvo por los ataques.
## Todas las cifras son parámetros de juego (rules.json, claves war_ai_*), no datos históricos.

const Fixed := preload("res://scripts/sim/fixed.gd")
const WarScript := preload("res://scripts/sim/war.gd")


static func enabled(world) -> bool:
	return WarScript.enabled(world) and int(world.data.rules.get("war_ai_interval", 0)) > 0


static func step(world) -> void:
	if not enabled(world):
		return
	var rules: Dictionary = world.data.rules
	if world.step_count % 24 == 6:
		_levy(world)
	if not world.ai_paused and world.step_count >= int(rules["war_ai_start_steps"]) and world.step_count % int(rules["war_ai_interval"]) == int(rules["war_ai_interval"]) / 2:
		_attacks(world)


static func _levy(world) -> void:
	var rules: Dictionary = world.data.rules
	var per_day: int = int(rules["war_ai_levy_per_day"])
	var target_pct: int = int(rules["war_ai_levy_target_percent"])
	var upkeep: int = int(rules.get("recruit_upkeep", 0))
	for province in world.provinces:
		if WarScript.is_player(world, province.id):
			continue
		var cap: int = Fixed.percent_of(province.population, target_pct)
		var wanted: int = mini(per_day, cap - province.recruits)
		# Solo si la provincia puede pagar un día de paga (24 pasos) de todos sus soldados con los nuevos.
		while wanted > 0 and province.store.stock(rules["currency"]) < (province.recruits + wanted) * upkeep * 24:
			wanted -= 1
		if wanted > 0:
			province.recruits += wanted
			province.settle_labor()


## Un ataque por reino rival, en el orden de los reinos (alfabético) para que sea determinista.
static func _attacks(world) -> void:
	var rules: Dictionary = world.data.rules
	var owned := 0
	for province in world.provinces:
		if WarScript.is_player(world, province.id):
			owned += 1
	if owned <= 1:
		return     # nunca se quita la última provincia
	var realms := {}
	for province in world.provinces:
		var owner: String = world.owners.get(province.id, "")
		if owner != "" and owner != world.player_realm:
			realms[owner] = true
	var names: Array = realms.keys()
	names.sort()
	var min_soldiers: int = int(rules["war_ai_min_soldiers"])
	var ratio: int = int(rules["war_ai_ratio_percent"])
	var keep: int = int(rules["war_ai_keep_percent"])
	for realm in names:
		var best_origin = null
		var best_target = null
		var best_score := -1
		for province in world.provinces:
			if world.owners.get(province.id, "") != realm or province.recruits < min_soldiers:
				continue
			var sending: int = province.recruits - Fixed.percent_of(province.recruits, keep)
			if sending < 1:
				continue
			var attack: int = WarScript.attack_strength(world, sending)
			for n in world.trade_links.get(province.id, {}).get("neighbors", []):
				if not WarScript.is_player(world, n) or _already_attacking(world, realm, n):
					continue
				var target = world.find_province(n)
				var defense: int = maxi(WarScript.defense_strength(world, target), 1)
				var score: int = attack * 100 / defense
				if score >= ratio and score > best_score:
					best_score = score
					best_origin = province
					best_target = target
		if best_origin != null:
			var sending: int = best_origin.recruits - Fixed.percent_of(best_origin.recruits, keep)
			if WarScript.send_as(world, realm, best_origin.id, best_target.id, sending)["ok"]:
				world.incoming_count += 1
				world.incoming_log.append({"step": world.step_count, "realm": realm, "from": best_origin.id, "to": best_target.id, "soldiers": sending})
				if world.incoming_log.size() > 20:
					world.incoming_log.pop_front()


static func _already_attacking(world, realm: String, target_id: String) -> bool:
	for army in world.armies:
		if army["to"] == target_id and army.get("realm", world.player_realm) == realm:
			return true
	return false
