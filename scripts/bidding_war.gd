# bidding_war.gd — minigame "Biedingsoorlog" (event: overboden).
# Drie clubs denken dat er een concurrerend bod ligt op je cliënt. Jij stookt
# het vuur op met drie tactieken tot iemand tekent, wandelt weg of de tijd om is.
class_name BiddingWar
extends RefCounted

var client_id := ""
var clubs: Array = []      # [{id, name, bid, budget, active}]
var rounds_left := 4
var finished := false
var deal := false
var winner_id := ""
var final_bid := 0
var log: Array = []


func setup(client_id_: String, candidate_ids: Array, base_value: int, all_clubs: Dictionary, rng: RandomNumberGenerator) -> void:
	client_id = client_id_
	for cid in candidate_ids:
		var c: Dictionary = all_clubs[cid]
		clubs.append({
			"id": cid, "name": str(c.name),
			"bid": int(float(base_value) * rng.randf_range(0.55, 0.75)),
			"budget": int(c.budget),
			"active": true,
		})
	if clubs.is_empty():
		# Geen enkele club had het budget om mee te doen — loos alarm.
		finished = true
		deal = false
		log.append("Geen van de clubs heeft er geld voor. Loos alarm.")


func active_clubs() -> Array:
	var out: Array = []
	for c in clubs:
		if c.active:
			out.append(c)
	return out


func top_club() -> Dictionary:
	var best: Dictionary = {}
	for c in active_clubs():
		if best.is_empty() or int(c.bid) > int(best.bid):
			best = c
	return best


func _get(cid: String) -> Dictionary:
	for c in clubs:
		if str(c.id) == cid:
			return c
	return {}


func play_bluf(target_id: String, rng: RandomNumberGenerator) -> void:
	rounds_left -= 1
	var c := _get(target_id)
	if rng.randf() < 0.6:
		var raise := int(float(c.bid) * rng.randf_range(0.15, 0.25))
		c["bid"] = mini(int(c.bid) + raise, int(c.budget))
		log.append("%s slikt het: bod stijgt naar %s." % [str(c.name), _eur(int(c.bid))])
	else:
		if rng.randf() < 0.3:
			c["active"] = false
			log.append("%s ruikt onraad en trekt zich volledig terug." % str(c.name))
		else:
			log.append("%s trapt er niet in, maar blijft in de race." % str(c.name))
	_check_end()


func play_pressure(rng: RandomNumberGenerator) -> void:
	rounds_left -= 1
	var top := top_club()
	if top.is_empty():
		_check_end()
		return
	if rng.randf() < 0.5:
		var raise := int(float(top.bid) * rng.randf_range(0.08, 0.14))
		top["bid"] = mini(int(top.bid) + raise, int(top.budget))
		log.append("%s voelt de klok tikken en verhoogt naar %s." % [str(top.name), _eur(int(top.bid))])
	elif rng.randf() < 0.5:
		finished = true
		deal = true
		winner_id = str(top.id)
		final_bid = int(top.bid)
		log.append("%s heeft er genoeg van en tekent NU voor %s." % [str(top.name), _eur(final_bid)])
	else:
		top["active"] = false
		log.append("%s voelt zich gehaast en stapt uit de onderhandeling." % str(top.name))
	_check_end()


func play_compare(rng: RandomNumberGenerator) -> void:
	rounds_left -= 1
	var top := top_club()
	if top.is_empty():
		_check_end()
		return
	var any := false
	for c in active_clubs():
		if str(c.id) == str(top.id):
			continue
		if rng.randf() < 0.4:
			var new_bid := int(float(top.bid) * rng.randf_range(1.02, 1.12))
			if new_bid <= int(c.budget):
				c["bid"] = new_bid
				any = true
				log.append("%s overtreft het bod: %s." % [str(c.name), _eur(new_bid)])
	if not any:
		log.append("Niemand hapt — de clubs kennen elkaars grens.")
	_check_end()


func accept_now() -> void:
	var top := top_club()
	finished = true
	if top.is_empty():
		deal = false
	else:
		deal = true
		winner_id = str(top.id)
		final_bid = int(top.bid)
		log.append("Je kapt het gesprek af en incasseert het bod van %s." % str(top.name))
	_check_end()


func _check_end() -> void:
	if finished:
		return
	if active_clubs().is_empty():
		finished = true
		deal = false
		log.append("Alle clubs trekken zich terug. Het bod verdampt in de chaos.")
		return
	if rounds_left <= 0:
		finished = true
		var top := top_club()
		if top.is_empty():
			deal = false
		else:
			deal = true
			winner_id = str(top.id)
			final_bid = int(top.bid)
			log.append("De tijd is om. %s wint de strijd met %s." % [str(top.name), _eur(final_bid)])


func _eur(n: int) -> String:
	var v := n
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-€" if v < 0 else "€") + out
