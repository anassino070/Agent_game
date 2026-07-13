# sponsor_pitch.gd — minigame "Sponsorpitch" (event: sponsorpitch).
# Verkorte variant van het onderhandelingssysteem, gericht op een merk in
# plaats van een club: geen weerstand van een TD maar "terughoudendheid" van
# een merkenteam, in 3 rondes te verslaan met 3 tactieken.
class_name SponsorPitch
extends RefCounted

const BASE_VALUE := 12000

var reluctance: float = 40.0
var rounds_left := 3
var finished := false
var success := false
var trust_penalty := 0
var log: Array = []


func play(action: String, rng: RandomNumberGenerator) -> void:
	rounds_left -= 1
	match action:
		"cijfers":
			if rng.randf() < 0.70:
				reluctance -= 15.0
				log.append("De cijfers overtuigen. Terughoudendheid daalt.")
			else:
				log.append("Ze vinden de cijfers niet overtuigend genoeg.")
		"exclusiviteit":
			if rng.randf() < 0.55:
				reluctance -= 22.0
				trust_penalty += 4
				log.append("Exclusiviteit beloofd — groot effect, maar hij levert vrijheid in.")
			else:
				log.append("Ze willen zich nog niet vastleggen op exclusiviteit.")
		"prestatiebonus":
			if rng.randf() < 0.85:
				reluctance -= 10.0
				log.append("Een prestatiebonus stelt iedereen gerust. Veilige stap.")
			else:
				log.append("Ze willen eerst de rest van het voorstel zien.")
	reluctance = maxf(reluctance, 0.0)
	if reluctance <= 0.0:
		finished = true
		success = true
		log.append("Ze steken hun hand uit. Deal.")
	elif rounds_left <= 0:
		finished = true
		success = reluctance < 90.0


func outcome(money_scale: float = 1.0) -> Dictionary:
	# money_scale komt van Game.event_money_scale(): tekst en effect gebruiken
	# hetzelfde al-geschaalde bedrag, zodat preview en werkelijkheid kloppen.
	if success and reluctance <= 0.0:
		var value := int(round(float(BASE_VALUE + rounds_left * 3000) * money_scale))
		var effects := {"money": value, "trust": 5 - trust_penalty}
		return {"effects": effects,
			"txt": "Topdeal binnen: %s. %s" % [_eur(value),
				"Wel iets minder blij met de kleine lettertjes." if trust_penalty > 0 else "Hij is dolblij."]}
	if success:
		var value := int(round(float(maxi(int(BASE_VALUE * (1.0 - reluctance / 100.0)), 3000)) * money_scale))
		return {"effects": {"money": value, "trust": 2 - trust_penalty},
			"txt": "Ze tekenen, maar met een lager bod dan gehoopt: %s." % _eur(value)}
	return {"effects": {"trust": -5},
		"txt": "Geen deal. Alleen tijdverlies — en een teleurgestelde cliënt."}


func _eur(n: int) -> String:
	var v := n
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-€" if v < 0 else "€") + out
