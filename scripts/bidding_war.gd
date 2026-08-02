# bidding_war.gd — minigame "Biedingsoorlog" (event: overboden).
# HERONTWORPEN: twee assen i.p.v. clubs porren tot er één toehapt.
#
# Elke club biedt een PRIJS (waar jouw fee uit komt) én VOORWAARDEN (waar het
# vertrouwen van je cliënt uit komt: speeltijd, afkoopsom, imagerechten). Die
# twee staan op gespannen voet: duw je bij een club de prijs op, dan snoeit ze
# in de voorwaarden — en omgekeerd. De kernvraag is dus niet "welke knop werkt"
# maar: HOEVEEL VAN HET GELUK VAN JE CLIËNT VERKOOP JE VOOR JE EIGEN MARGE?
#
# Waarom deze vorm: de oude versie legde alles open (biedingen, ambitie) en had
# maar één leerbare regel (bluf niet twee keer dezelfde club), waardoor de
# optimale lijn vastlag en het knopjes drukken werd. Erger: vertrouwen speelde
# géén enkele rol, terwijl dat overal elders in het spel de motor is. Nu hangt
# de minigame aan de kernspanning van het spel (fee vs. vertrouwen, met de
# vertrekkans als staart).
#
# Clubs verschillen in PROFIEL, wat bepaalt hoe duur een duw is:
# - "rijk"        : diepe zakken, maar hij wordt er een nummer
# - "ambitieus"   : basisplek en een project, minder geld
# - "gebalanceerd": middenweg, nergens uitschieter
class_name BiddingWar
extends RefCounted

const ROUNDS := 5

# Per profiel: startprijs (× marktwaarde), startvoorwaarden (0-100), en hoe hard
# prijs en voorwaarden tegen elkaar inruilen. `price_give` = hoeveel prijs je
# wint per duw (× marktwaarde), `terms_cost` = wat dat aan voorwaarden kost;
# `terms_give`/`price_cost` is dezelfde ruil de andere kant op.
const PROFILES := {
	"rijk": {
		"label": "Diepe zakken, weinig geduld — hij wordt hier een nummer.",
		"price_mult": 0.85, "terms": 30,
		"price_give": 0.14, "terms_cost": 14,
		"terms_give": 10, "price_cost": 0.08,
	},
	"ambitieus": {
		"label": "Sportief project met een basisplek, maar de kas is beperkt.",
		"price_mult": 0.60, "terms": 70,
		"price_give": 0.09, "terms_cost": 8,
		"terms_give": 14, "price_cost": 0.05,
	},
	"gebalanceerd": {
		"label": "Nette club, nergens uitschieter — in geld noch in beloftes.",
		"price_mult": 0.72, "terms": 50,
		"price_give": 0.11, "terms_cost": 11,
		"terms_give": 12, "price_cost": 0.06,
	},
}

var client_id := ""
var base_value := 0
var clubs: Array = []      # [{id, name, profile, price, terms, patience, active}]
var rounds_left := ROUNDS
var finished := false
var deal := false
var winner_id := ""
var final_price := 0
var final_terms := 0
var log: Array = []


func setup(client_id_: String, candidate_ids: Array, base_value_: int, all_clubs: Dictionary, rng: RandomNumberGenerator) -> void:
	client_id = client_id_
	base_value = base_value_
	# Elk profiel maximaal één keer, zodat de drie clubs echt van elkaar
	# verschillen — met twee identieke "rijke" clubs is de keuze tussen hen leeg.
	var profiles: Array = PROFILES.keys()
	for i in range(profiles.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = profiles[i]
		profiles[i] = profiles[j]
		profiles[j] = tmp
	var idx := 0
	for cid in candidate_ids:
		var c: Dictionary = all_clubs[cid]
		var prof: String = str(profiles[idx % profiles.size()])
		var p: Dictionary = PROFILES[prof]
		clubs.append({
			"id": cid, "name": str(c.name), "profile": prof,
			"price": int(float(base_value) * float(p.price_mult) * rng.randf_range(0.92, 1.08)),
			"terms": clampi(int(p.terms) + rng.randi_range(-6, 6), 5, 95),
			# Geduld: hoe vaak je bij deze club kunt duwen voor ze afhaakt.
			# Bewust ZICHTBAAR: de spanning moet in de afweging zitten, niet in
			# giswerk over wanneer iemand knapt.
			"patience": rng.randi_range(2, 3),
			"active": true,
		})
		idx += 1
	if clubs.is_empty():
		finished = true
		deal = false
		log.append("Geen enkele club meldt zich. Loos alarm.")


func active_clubs() -> Array:
	var out: Array = []
	for c in clubs:
		if c.active:
			out.append(c)
	return out


func find_club(cid: String) -> Dictionary:
	for c in clubs:
		if str(c.id) == cid:
			return c
	return {}


func profile_label(c: Dictionary) -> String:
	return str(PROFILES[str(c.profile)].label)


func terms_label(t: int) -> String:
	if t >= 80:
		return "uitstekend (basisplek, vrije afkoop)"
	if t >= 60:
		return "goed (serieuze rol)"
	if t >= 40:
		return "redelijk"
	if t >= 20:
		return "mager (bankzitter, strakke clausules)"
	return "slecht (hij wordt geparkeerd)"


func top_by_price() -> Dictionary:
	var best: Dictionary = {}
	for c in active_clubs():
		if best.is_empty() or int(c.price) > int(best.price):
			best = c
	return best


# --- De twee duwrichtingen --------------------------------------------------

func push_price(cid: String) -> void:
	# Prijs omhoog ten koste van de voorwaarden. Kost een ronde én geduld: een
	# club laat zich niet eindeloos uitknijpen.
	var c := find_club(cid)
	if c.is_empty() or not c.active or finished:
		return
	var p: Dictionary = PROFILES[str(c.profile)]
	rounds_left -= 1
	var gain := int(float(base_value) * float(p.price_give))
	c["price"] = int(c.price) + gain
	c["terms"] = clampi(int(c.terms) - int(p.terms_cost), 0, 100)
	c["patience"] = int(c.patience) - 1
	log.append("%s legt %s bij — maar snoeit in de voorwaarden (nu: %s)." % [
		str(c.name), _eur(gain), terms_label(int(c.terms))])
	_check_patience(c)
	_check_end()


func push_terms(cid: String) -> void:
	# Voorwaarden omhoog ten koste van de prijs — dus ten koste van JOUW fee.
	var c := find_club(cid)
	if c.is_empty() or not c.active or finished:
		return
	var p: Dictionary = PROFILES[str(c.profile)]
	rounds_left -= 1
	var drop := int(float(base_value) * float(p.price_cost))
	c["terms"] = clampi(int(c.terms) + int(p.terms_give), 0, 100)
	c["price"] = maxi(int(c.price) - drop, 0)
	c["patience"] = int(c.patience) - 1
	log.append("%s verbetert de voorwaarden (nu: %s) — en haalt %s van de prijs af." % [
		str(c.name), terms_label(int(c.terms)), _eur(drop)])
	_check_patience(c)
	_check_end()


func play_off(rng: RandomNumberGenerator) -> void:
	# Clubs tegen elkaar uitspelen: de achterblijvers trekken bij naar de
	# koploper. Raakt het geduld van de koploper NIET (je onderhandelt niet mét
	# hem), maar de anderen voelen zich opgejaagd en verliezen wel geduld.
	if finished:
		return
	rounds_left -= 1
	var top := top_by_price()
	if top.is_empty():
		_check_end()
		return
	var moved := false
	for c in active_clubs():
		if str(c.id) == str(top.id):
			continue
		if int(c.price) < int(top.price):
			var step := int(float(int(top.price) - int(c.price)) * rng.randf_range(0.35, 0.6))
			if step > 0:
				c["price"] = int(c.price) + step
				moved = true
				log.append("%s trekt bij tot %s." % [str(c.name), _eur(int(c.price))])
		c["patience"] = int(c.patience) - 1
		_check_patience(c)
	if not moved:
		log.append("Niemand beweegt — ze kennen elkaars grenzen.")
	_check_end()


func accept(cid: String) -> void:
	var c := find_club(cid)
	if c.is_empty() or not c.active or finished:
		return
	finished = true
	deal = true
	winner_id = str(c.id)
	final_price = int(c.price)
	final_terms = int(c.terms)
	log.append("Je tekent bij %s: %s, voorwaarden %s." % [
		str(c.name), _eur(final_price), terms_label(final_terms)])


func _check_patience(c: Dictionary) -> void:
	if int(c.patience) <= 0 and c.active:
		c["active"] = false
		log.append("%s is het zat en trekt zich terug." % str(c.name))


func _check_end() -> void:
	if finished:
		return
	if active_clubs().is_empty():
		finished = true
		deal = false
		log.append("Alle clubs zijn afgehaakt. Geen deal.")
		return
	if rounds_left <= 0:
		# Tijd om: je moet het hoogste bod nemen dat er nog ligt.
		var top := top_by_price()
		if top.is_empty():
			finished = true
			deal = false
			return
		finished = true
		deal = true
		winner_id = str(top.id)
		final_price = int(top.price)
		final_terms = int(top.terms)
		log.append("De deadline verstrijkt; %s heeft het hoogste bod." % str(top.name))


# --- Uitkomst ---------------------------------------------------------------

func trust_delta() -> int:
	# De voorwaarden bepalen wat je cliënt ervan vindt. 50 is neutraal: daarboven
	# voelt hij zich gesteund, daaronder verkocht. Dit is de hele clou van de
	# minigame — je fee maximaliseren kost je hier zichtbaar vertrouwen, en
	# vertrouwen drijft elders de vertrekkans (zie Game.leave_chance()).
	if not deal:
		return 0
	return int(round(float(final_terms - 50) / 5.0))


func outcome_text() -> String:
	if not deal:
		return "Geen deal. De bui trekt over zonder handtekening."
	var t := trust_delta()
	if t >= 6:
		return "Getekend — en hij weet dat je voor hém hebt onderhandeld, niet voor je fee."
	if t >= 1:
		return "Getekend. Nette voorwaarden, nette fee."
	if t == 0:
		return "Getekend. Zakelijk, zonder warmte."
	if t >= -5:
		return "Getekend, maar hij leest de kleine lettertjes en vraagt zich af voor wie je werkte."
	return "Getekend. Jij bent binnen; hij is verkocht, en dat weet hij."


func _eur(n: int) -> String:
	var v := n
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-€" if v < 0 else "€") + out
