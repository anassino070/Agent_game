# press_conference.gd — minigame "Persconferentie" (event: persconferentie_druk).
# Vijf rondes van steeds scherpere, ECHTE vragen (zichtbaar in de UI) — zodat
# Ontwijken/Toegeven/Aanvallen een reactie is op iets concreets, niet een
# abstracte knop. Een spanningsmeter (0-100) loopt op bij zwakke antwoorden;
# blijft hij laag, dan loop je met eer weg — schiet hij door het dak, dan
# ontspoort de persconferentie volledig.
#
# Elke vraag heeft een verborgen TOON die bepaalt welk antwoord echt werkt —
# leesbaar aan de formulering, niet expliciet gelabeld. Zonder dit systeem is
# er geen enkel patroon te leren (Toegeven is dan altijd wiskundig het beste,
# Ontwijken nooit) en voelt de minigame als pure willekeur.
class_name PressConference
extends RefCounted

# "beschuldigend"  → Toegeven werkt het beste (eerlijkheid ontwapent een verwijt)
# "provocerend"    → Aanvallen werkt het beste (een uitdaging vraagt om tegengas)
# "speculatief"    → Ontwijken werkt het beste (er zijn geen feiten om op te reageren)
const QUESTIONS := [
	{"text": "\"Klopt het dat er ruzie is in de kleedkamer?\"", "tone": "beschuldigend"},
	{"text": "\"Waarom duurde het weken voor u hierop reageerde?\"", "tone": "beschuldigend"},
	{"text": "\"Ligt dit aan de trainer, of aan hem?\"", "tone": "beschuldigend"},
	{"text": "\"Waarom speelde hij vandaag zo slap — heeft u daar een verklaring voor?\"", "tone": "beschuldigend"},
	{"text": "\"Is dit niet gewoon het begin van het einde voor hem hier?\"", "tone": "provocerend"},
	{"text": "\"Durft u te beweren dat dit toeval is?\"", "tone": "provocerend"},
	{"text": "\"Speelt hij zijn laatste wedstrijden voor deze club, of houdt u ons voor de gek?\"", "tone": "provocerend"},
	{"text": "\"Wil hij eigenlijk weg bij deze club?\"", "tone": "speculatief"},
	{"text": "\"Wat heeft hij te zeggen tegen de fans die vanavond boe riepen?\"", "tone": "speculatief"},
	{"text": "\"Wat zou hij nu tegen zichzelf zeggen, denkt u?\"", "tone": "speculatief"},
]

const RESPONSES := {
	"ontwijken": "'Daar ga ik nu niet verder op in.'",
	"toegeven": "'Eerlijk gezegd...' — en hij vertelt het hele verhaal.",
	"aanvallen": "'Dat is een oneerlijke vraag, en dat weet u ook.'",
}

# Per toon: welk antwoord de "beste" (good) keuze is, en de kans/effecten van
# alle drie de antwoorden tegen die toon. "good" krijgt een flinke, betrouwbare
# verlaging; de andere twee zijn zwakker — soms een gok, soms gegarandeerd
# averechts — zodat er een leerbaar patroon ontstaat i.p.v. willekeur.
const TONE_PAYOFFS := {
	"beschuldigend": {
		"toegeven": {"chance": 0.75, "ok": -18.0, "fail": 5.0,
			"ok_txt": "Een eerlijk antwoord ontwapent de beschuldiging volledig.",
			"fail_txt": "Zijn eerlijkheid wordt alsnog als een bekentenis uitgelegd."},
		"aanvallen": {"chance": 0.35, "ok": -10.0, "fail": 18.0,
			"ok_txt": "Een fel weerwoord, en het landt net.",
			"fail_txt": "Tegen een gerichte beschuldiging oogt de tegenaanval vooral defensief."},
		"ontwijken": {"chance": 0.0, "ok": 0.0, "fail": 10.0,
			"ok_txt": "", "fail_txt": "Ontwijken bij een directe beschuldiging oogt schuldig."},
	},
	"provocerend": {
		"aanvallen": {"chance": 0.70, "ok": -20.0, "fail": 15.0,
			"ok_txt": "Een scherpe uitdaging vraagt om tegengas — en dat krijgt de zaal.",
			"fail_txt": "De tegenaanval mist zijn doel en voedt de provocatie."},
		"toegeven": {"chance": 0.30, "ok": -8.0, "fail": 12.0,
			"ok_txt": "Een eerlijk antwoord haalt net de wind uit de provocatie.",
			"fail_txt": "Toegeven op een uitlokkende vraag voedt 'm alleen maar."},
		"ontwijken": {"chance": 0.0, "ok": 0.0, "fail": 8.0,
			"ok_txt": "", "fail_txt": "Wegduiken voor een provocatie oogt zwak."},
	},
	"speculatief": {
		"ontwijken": {"chance": 1.0, "ok": -12.0, "fail": 0.0,
			"ok_txt": "Er zijn geen feiten om op te reageren — niet happen is de veilige zet.",
			"fail_txt": ""},
		"toegeven": {"chance": 0.25, "ok": -5.0, "fail": 20.0,
			"ok_txt": "Toevallig raak, maar op puur giswerk 'toegeven' is link.",
			"fail_txt": "Instemmen met pure speculatie bevestigt het gerucht als feit."},
		"aanvallen": {"chance": 0.40, "ok": -8.0, "fail": 15.0,
			"ok_txt": "Fel, maar het werkt tegen een speculatieve vraag.",
			"fail_txt": "Zo fel reageren op giswerk oogt overdreven — alsof er iets te verbergen valt."},
	},
}

var questions: Array = []
var question_idx := 0
var tension: float = 30.0
var questions_left := 5
var finished := false
var blew_up := false
var log: Array = []


func setup(rng: RandomNumberGenerator) -> void:
	var pool: Array = QUESTIONS.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	questions = pool.slice(0, 5)


func current_question() -> String:
	return str(questions[question_idx].text)


func current_tone() -> String:
	return str(questions[question_idx].tone)


func _shift(delta: float) -> void:
	tension = clampf(tension + delta, 0.0, 100.0)


func play(action: String, rng: RandomNumberGenerator) -> void:
	log.append("Vraag: %s" % current_question())
	log.append("Jouw antwoord: %s" % str(RESPONSES.get(action, "...")))
	var payoff: Dictionary = TONE_PAYOFFS[current_tone()][action]
	if rng.randf() < float(payoff.chance):
		_shift(float(payoff.ok))
		log.append(str(payoff.ok_txt))
	else:
		_shift(float(payoff.fail))
		log.append(str(payoff.fail_txt))
	questions_left -= 1
	question_idx += 1
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
