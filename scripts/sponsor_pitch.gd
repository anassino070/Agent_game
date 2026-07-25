# sponsor_pitch.gd — minigame "Sponsorpitch" (event: sponsorpitch).
# Verkorte variant van het onderhandelingssysteem, gericht op een merk in
# plaats van een club: geen weerstand van een TD maar "terughoudendheid" van
# een merkenteam, in 3 rondes te verslaan met 3 tactieken.
#
# Elk merk heeft een verborgen PROFIEL dat bepaalt welke tactiek het beste
# werkt. De openingszin geeft een impliciete hint (geen directe "gebruik X" —
# je moet 'm interpreteren) en de exacte kansen blijven verborgen in de UI:
# zonder dat zou je toch gewoon de knop met het hoogste getal spammen. Zo
# wordt het lezen-en-kiezen, niet klikken-op-het-beste-percentage.
class_name SponsorPitch
extends RefCounted

const BASE_VALUE := 12000

const BRAND_PROFILES := {
	"cijfermerk": {
		"label": "Cijfermerk",
		"intro": "Hun marketingteam werkt met keiharde ROI-modellen — ze wantrouwen grote beloftes zonder onderbouwing.",
		"best": "cijfers",
	},
	"imagomerk": {
		"label": "Imagomerk",
		"intro": "Ze zijn geobsedeerd met exclusiviteit — een concurrent die dezelfde speler sponsort is hun grootste angst.",
		"best": "exclusiviteit",
	},
	"voorzichtig": {
		"label": "Voorzichtig merk",
		"intro": "Hun budget is dit kwartaal krap — pas bij bewezen resultaat maken ze geld vrij.",
		"best": "prestatiebonus",
	},
}

var brand := ""
var reluctance: float = 40.0
var rounds_left := 3
var finished := false
var success := false
var trust_penalty := 0
var log: Array = []


func setup(rng: RandomNumberGenerator) -> void:
	var keys: Array = BRAND_PROFILES.keys()
	brand = str(keys[rng.randi_range(0, keys.size() - 1)])
	log.append(str(BRAND_PROFILES[brand].intro))


func _is_best(action: String) -> bool:
	return str(BRAND_PROFILES[brand].best) == action


func play(action: String, rng: RandomNumberGenerator) -> void:
	rounds_left -= 1
	var best := _is_best(action)
	match action:
		"cijfers":
			var chance: float = 0.88 if best else 0.55
			var drop: float = 19.0 if best else 10.0
			if rng.randf() < chance:
				reluctance -= drop
				log.append("De cijfers overtuigen. Terughoudendheid daalt.%s" % (
					" Ze knikken enthousiast — precies waar ze op zaten te wachten." if best else ""))
			else:
				log.append("Ze vinden de cijfers niet overtuigend genoeg.")
		"exclusiviteit":
			var chance: float = 0.82 if best else 0.40
			var drop: float = 27.0 if best else 15.0
			if rng.randf() < chance:
				reluctance -= drop
				trust_penalty += 4
				log.append("Exclusiviteit beloofd%s, maar hij levert vrijheid in." % (
					" — schot in de roos, hier zaten ze op te wachten" if best else " — groot effect"))
			else:
				log.append("Ze willen zich nog niet vastleggen op exclusiviteit.")
		"prestatiebonus":
			var chance: float = 0.95 if best else 0.65
			var drop: float = 17.0 if best else 8.0
			if rng.randf() < chance:
				reluctance -= drop
				log.append("Een prestatiebonus stelt iedereen gerust.%s" % (
					" Precies de zekerheid die ze zochten." if best else " Veilige stap."))
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
