# press_conference.gd — minigame "Persconferentie" (event: persconferentie_druk).
# Vijf rondes van steeds scherpere vragen. Een spanningsmeter (0-100) loopt op
# bij zwakke antwoorden; blijft hij laag, dan loop je met eer weg — schiet hij
# door het dak, dan ontspoort de persconferentie volledig.
class_name PressConference
extends RefCounted

var tension: float = 30.0
var questions_left := 5
var finished := false
var blew_up := false
var log: Array = []


func _shift(delta: float) -> void:
	tension = clampf(tension + delta, 0.0, 100.0)


func play(action: String, rng: RandomNumberGenerator) -> void:
	questions_left -= 1
	match action:
		"ontwijken":
			_shift(8.0)
			log.append("Je ontwijkt de vraag. De zaal wordt ongeduldig.")
		"toegeven":
			if rng.randf() < 0.7:
				_shift(-15.0)
				log.append("Een eerlijk antwoord landt goed. De sfeer klaart op.")
			else:
				_shift(5.0)
				log.append("Je eerlijkheid wordt uitgelegd als een bekentenis.")
		"aanvallen":
			if rng.randf() < 0.45:
				_shift(-25.0)
				log.append("Een sterk weerwoord. Applaus van de achterste rijen.")
			else:
				_shift(20.0)
				log.append("Het klinkt defensief. Het filmpje gaat al rond.")
	if tension >= 100.0:
		finished = true
		blew_up = true
		log.append("De zaal ontspoort volledig. Dit wordt het nieuws van morgen.")
	elif questions_left <= 0:
		finished = true


func outcome() -> Dictionary:
	# Geeft {effects, txt} terug voor Game.apply_effects().
	if blew_up:
		return {"effects": {"scandal": 15, "rep": -8, "trust": -10},
			"txt": "De persconferentie ontspoort. Grote imagoschade, voor jullie beiden."}
	if tension <= 20.0:
		return {"effects": {"rep": 8, "trust": 6},
			"txt": "Meesterlijk gehanteerd. De pers roemt zijn kalmte — en jouw coaching."}
	if tension <= 50.0:
		return {"effects": {"rep": 3},
			"txt": "Prima doorstaan. Geen kop, geen gedoe."}
	if tension <= 80.0:
		return {"effects": {"rep": -2},
			"txt": "Wat rommelig, maar overleefd."}
	return {"effects": {"scandal": 6, "rep": -4},
		"txt": "Hij komt gehavend uit de zaal. Niet je beste avond."}
