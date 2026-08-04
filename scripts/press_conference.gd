# press_conference.gd — minigame "Persconferentie" (event: persconferentie_druk).
# Volledig herontwerp: elke vraag komt nu van een ZICHTBARE journalist met een
# eigen naam, icoon en duidelijke hint over welk antwoord bij hem werkt — in
# de vorige versie moest je die "toon" blind uit de vraagformulering raden,
# wat als pure willekeur aanvoelde. Nu is het lezen-en-koppelen: je ZIET wie
# er voor je staat, en moet zelf onthouden/afleiden welke reactie daarbij
# past — de tactiek zit in de koppeling, niet in het giswerk.
#
# Doel is nu ook positief geframed: een PUBLIEKSSYMPATHIE-meter (0-100, hoger
# is beter) i.p.v. een spanningsmeter die je moet zien te vermijden. Twee
# successen op rij geven MOMENTUM (+50% effect, net als Flow bij de
# onderhandeling) en de laatste vraag is een Slotvraag met dubbele inzet —
# een climax in plaats van gewoon "nog een ronde".
class_name PressConference
extends RefCounted

const JOURNALISTS := {
	"feitenjager": {
		"name": "De Feitenjager", "icon": "📰",
		"hint": "Wil bewijs zien — eerlijkheid ontwapent hem het best.",
		"best": "toegeven",
	},
	"provocateur": {
		"name": "De Provocateur", "icon": "🎤",
		"hint": "Zoekt een botsing — een fel weerwoord werkt het best.",
		"best": "aanvallen",
	},
	"speculant": {
		"name": "De Speculant", "icon": "🔮",
		"hint": "Vist naar een verhaal — niet happen werkt het best.",
		"best": "ontwijken",
	},
}

const QUESTIONS := {
	"feitenjager": [
		"\"Klopt het dat er ruzie is in de kleedkamer?\"",
		"\"Waarom duurde het weken voor u hierop reageerde?\"",
		"\"Ligt dit aan de trainer, of aan hem?\"",
		"\"Heeft u daar een sluitende verklaring voor?\"",
	],
	"provocateur": [
		"\"Is dit niet gewoon het begin van het einde voor hem hier?\"",
		"\"Durft u te beweren dat dit toeval is?\"",
		"\"Houdt u ons voor de gek, of speelt hij echt zijn laatste wedstrijden hier?\"",
		"\"Wordt het nu niet eens tijd voor eerlijkheid?\"",
	],
	"speculant": [
		"\"Wil hij eigenlijk weg bij deze club?\"",
		"\"Wat heeft hij te zeggen tegen de fans die vanavond boe riepen?\"",
		"\"Wat zou hij nu tegen zichzelf zeggen, denkt u?\"",
		"\"Gonst het nu al in de kleedkamer over zijn toekomst?\"",
	],
}

const RESPONSES := {
	"ontwijken": "'Daar ga ik nu niet verder op in.'",
	"toegeven": "'Eerlijk gezegd...' — en hij vertelt het hele verhaal.",
	"aanvallen": "'Dat is een oneerlijke vraag, en dat weet u ook.'",
}

# Per journalist: kans/effect van elk antwoord. "best" (uit JOURNALISTS)
# krijgt de hoogste kans en het grootste effect; de andere twee zijn zwakker
# — soms een bruikbare gok, soms bijna gegarandeerd averechts.
const PAYOFFS := {
	"feitenjager": {
		"toegeven": {"chance": 0.75, "ok": 18.0, "fail": -5.0,
			"ok_txt": "Een eerlijk antwoord ontwapent de beschuldiging volledig.",
			"fail_txt": "Zijn eerlijkheid wordt alsnog als een bekentenis uitgelegd."},
		"aanvallen": {"chance": 0.35, "ok": 10.0, "fail": -18.0,
			"ok_txt": "Een fel weerwoord, en het landt net.",
			"fail_txt": "Tegen een gerichte beschuldiging oogt de tegenaanval vooral defensief."},
		"ontwijken": {"chance": 0.15, "ok": 4.0, "fail": -10.0,
			"ok_txt": "Hij glipt eraan voorbij, maar het scheelde weinig.",
			"fail_txt": "Ontwijken bij een directe beschuldiging oogt schuldig."},
	},
	"provocateur": {
		"aanvallen": {"chance": 0.70, "ok": 20.0, "fail": -15.0,
			"ok_txt": "Een scherpe uitdaging vraagt om tegengas — en dat krijgt de zaal.",
			"fail_txt": "De tegenaanval mist zijn doel en voedt de provocatie."},
		"toegeven": {"chance": 0.30, "ok": 8.0, "fail": -12.0,
			"ok_txt": "Een eerlijk antwoord haalt net de wind uit de provocatie.",
			"fail_txt": "Toegeven op een uitlokkende vraag voedt 'm alleen maar."},
		"ontwijken": {"chance": 0.15, "ok": 4.0, "fail": -8.0,
			"ok_txt": "Hij weigert de bal op te pakken — het went net aan.",
			"fail_txt": "Wegduiken voor een provocatie oogt zwak."},
	},
	"speculant": {
		"ontwijken": {"chance": 0.90, "ok": 12.0, "fail": -3.0,
			"ok_txt": "Er zijn geen feiten om op te reageren — niet happen is de veilige zet.",
			"fail_txt": "Zelfs een simpel 'geen commentaar' wordt breed uitgemeten."},
		"toegeven": {"chance": 0.25, "ok": 5.0, "fail": -20.0,
			"ok_txt": "Toevallig raak, maar op puur giswerk 'toegeven' is link.",
			"fail_txt": "Instemmen met pure speculatie bevestigt het gerucht als feit."},
		"aanvallen": {"chance": 0.40, "ok": 8.0, "fail": -15.0,
			"ok_txt": "Fel, maar het werkt tegen een speculatieve vraag.",
			"fail_txt": "Zo fel reageren op giswerk oogt overdreven — alsof er iets te verbergen valt."},
	},
}

const TARGET_QUESTIONS := 5

var questions: Array = []     # [{journalist, text}]
var question_idx := 0
var sympathy: float = 50.0    # 0-100, HOGER is beter (positief geframed, was "spanning" die je moest vermijden)
var streak := 0               # opeenvolgende successen; 2+ = momentum (+50% effect)
var questions_left := TARGET_QUESTIONS
var finished := false
var blew_up := false
var log: Array = []


func setup(rng: RandomNumberGenerator) -> void:
	var jids: Array = JOURNALISTS.keys()
	questions = []
	for i in range(TARGET_QUESTIONS):
		var jid: String = jids[rng.randi_range(0, jids.size() - 1)]
		var pool: Array = QUESTIONS[jid]
		var text: String = pool[rng.randi_range(0, pool.size() - 1)]
		questions.append({"journalist": jid, "text": text})


func current_question() -> String:
	return str(questions[question_idx].text)


func current_journalist() -> String:
	return str(questions[question_idx].journalist)


func is_final_question() -> bool:
	return question_idx == questions.size() - 1


func has_momentum() -> bool:
	return streak >= 2


func play(action: String, rng: RandomNumberGenerator) -> void:
	var jid := current_journalist()
	var j: Dictionary = JOURNALISTS[jid]
	log.append(I18n.T("%s vraagt: %s") % [str(j.icon), current_question()])
	log.append(I18n.T("Jouw antwoord: %s") % I18n.T(str(RESPONSES.get(action, "..."))))
	var payoff: Dictionary = PAYOFFS[jid][action]
	# De Slotvraag (laatste ronde) heeft dubbele inzet — een climax i.p.v.
	# gewoon nog een ronde.
	var stakes := 2.0 if is_final_question() else 1.0
	var momentum := has_momentum()
	if rng.randf() < float(payoff.chance):
		var delta := float(payoff.ok) * stakes * (1.5 if momentum else 1.0)
		sympathy = clampf(sympathy + delta, 0.0, 100.0)
		streak += 1
		log.append(I18n.T("%s%s") % [I18n.T(str(payoff.ok_txt)), I18n.T("  (MOMENTUM +50%%)") if momentum else ""])
	else:
		var delta := float(payoff.fail) * stakes
		sympathy = clampf(sympathy + delta, 0.0, 100.0)
		streak = 0
		log.append(I18n.T(str(payoff.fail_txt)))
	questions_left -= 1
	question_idx += 1
	if sympathy <= 0.0:
		finished = true
		blew_up = true
		log.append(I18n.T("De zaal ontploft. Dit wordt het nieuws van morgen."))
	elif questions_left <= 0:
		finished = true


func outcome() -> Dictionary:
	# Geeft {effects, txt} terug voor Game.apply_effects().
	if blew_up:
		return {"effects": {"scandal": 15, "rep": -8, "trust": -10},
			"txt": "De persconferentie ontspoort. Grote imagoschade, voor jullie beiden."}
	if sympathy >= 80.0:
		return {"effects": {"rep": 8, "trust": 6},
			"txt": "Meesterlijk gehanteerd. De pers roemt zijn kalmte — en jouw coaching."}
	if sympathy >= 50.0:
		return {"effects": {"rep": 3},
			"txt": "Prima doorstaan. Geen kop, geen gedoe."}
	if sympathy >= 20.0:
		return {"effects": {"rep": -2},
			"txt": "Wat rommelig, maar overleefd."}
	return {"effects": {"scandal": 6, "rep": -4},
		"txt": "Hij komt gehavend uit de zaal. Niet je beste avond."}
