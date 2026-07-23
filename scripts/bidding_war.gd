# bidding_war.gd — minigame "Biedingsoorlog" (event: overboden).
# Drie clubs denken dat er een concurrerend bod ligt op je cliënt. Echte
# tactiek zit 'm in drie dingen:
# 1. Clubambitie is zichtbaar en bepaalt hun gedrag — ambitieuze clubs zijn
#    happiger (grotere sprongen bij een geslaagde bluf) maar ook
#    prikkelbaarder (stappen sneller uit bij een mislukte bluf/druk).
# 2. Bluffen tegen dezelfde club raakt "verbrand": elke herhaling verlaagt
#    de slagingskans van die specifieke bluf — wissel dus van doelwit.
# 3. "Vergelijken" is niet gratis: de koploper kan zich ondermijnd voelen
#    (annoyed) en wordt daardoor prikkelbaarder bij een latere druk-actie.
class_name BiddingWar
extends RefCounted

var client_id := ""
var clubs: Array = []      # [{id, name, ambition, bid, budget, active, bluffed, annoyed}]
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
			"id": cid, "name": str(c.name), "ambition": int(c.ambition),
			"bid": int(float(base_value) * rng.randf_range(0.55, 0.75)),
			"budget": int(c.budget),
			"active": true, "bluffed": 0, "annoyed": false,
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


func find_club(cid: String) -> Dictionary:
	for c in clubs:
		if str(c.id) == cid:
			return c
	return {}


func ambition_label(c: Dictionary) -> String:
	var a := int(c.ambition)
	if a >= 5:
		return "torenhoge ambitie — happig, maar ook prikkelbaar"
	if a >= 4:
		return "hoge ambitie — wil graag winnen"
	if a >= 2:
		return "gematigde ambitie"
	return "lage ambitie — kalm, moeilijk op te jagen"


func play_bluf(target_id: String, rng: RandomNumberGenerator) -> void:
	rounds_left -= 1
	var c := find_club(target_id)
	var bluffed := int(c.bluffed)
	var ambition_bonus := (float(c.ambition) - 3.0) * 0.03
	var fatigue := float(bluffed) * 0.12
	var chance := clampf(0.6 + ambition_bonus - fatigue, 0.1, 0.85)
	c["bluffed"] = bluffed + 1
	if rng.randf() < chance:
		var raise_pct := rng.randf_range(0.12, 0.22) + float(c.ambition) * 0.015
		var raise := int(float(c.bid) * raise_pct)
		c["bid"] = mini(int(c.bid) + raise, int(c.budget))
		log.append("%s slikt het: bod stijgt naar %s." % [str(c.name), _eur(int(c.bid))])
	else:
		var walk_base := 0.3 + (float(c.ambition) - 3.0) * 0.05
		if bluffed > 0:
			walk_base += 0.15   # al eerder geblufd — hij is nu op zijn hoede
		if rng.randf() < walk_base:
			c["active"] = false
			log.append("%s ruikt onraad en trekt zich volledig terug." % str(c.name))
		elif bluffed > 0:
			log.append("%s heeft dit smoesje al eerder gehoord en trapt er niet meer in." % str(c.name))
		else:
			log.append("%s trapt er niet in, maar blijft in de race." % str(c.name))
	_check_end()


func play_pressure(rng: RandomNumberGenerator) -> void:
	rounds_left -= 1
	var top := top_club()
	if top.is_empty():
		_check_end()
		return
	var annoyed_penalty := 0.15 if bool(top.annoyed) else 0.0
	var raise_chance := clampf(0.5 - annoyed_penalty, 0.1, 0.9)
	if rng.randf() < raise_chance:
		var raise := int(float(top.bid) * rng.randf_range(0.08, 0.14))
		top["bid"] = mini(int(top.bid) + raise, int(top.budget))
		log.append("%s voelt de klok tikken en verhoogt naar %s." % [str(top.name), _eur(int(top.bid))])
	else:
		# Mislukt: hij tekent NU (mooi) of stapt uit (pijnlijk) — een
		# ambitieuze club is ongeduldiger en stapt sneller uit dan een kalme.
		var walk_chance := clampf(0.5 + (float(top.ambition) - 3.0) * 0.06 + annoyed_penalty, 0.15, 0.85)
		if rng.randf() < walk_chance:
			top["active"] = false
			var reason := " — hij was toch al geïrriteerd" if annoyed_penalty > 0 else ""
			log.append("%s voelt zich gehaast%s en stapt uit de onderhandeling." % [str(top.name), reason])
		else:
			finished = true
			deal = true
			winner_id = str(top.id)
			final_bid = int(top.bid)
			log.append("%s heeft er genoeg van en tekent NU voor %s." % [str(top.name), _eur(final_bid)])
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
	# Risico: de koploper voelt zich soms ondermijnd doordat zijn bod
	# rondgaat — dat maakt hem prikkelbaarder bij een latere druk-actie.
	if rng.randf() < 0.3 and not bool(top.annoyed):
		top["annoyed"] = true
		log.append("%s is not amused dat zijn bod ineens bij iedereen bekend is." % str(top.name))
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
