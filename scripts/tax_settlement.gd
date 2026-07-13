# tax_settlement.gd — minigame "Fiscale schikking" (event: fiscale_schikking).
# Risicoverdeling in plaats van één worp: drie boekhoudposten, elk met een
# eigen keuze tussen open, deels of volledig verhullen. Meer verhullen =
# grotere besparing bij succes, maar hoger en duurder ontdekkingsrisico.
class_name TaxSettlement
extends RefCounted

const POSTS := [
	{"name": "Buitenlandse rekening", "amount": 9000},
	{"name": "Contante betalingen", "amount": 6000},
	{"name": "Overige aftrekposten", "amount": 5000},
]

var choices: Array = [-1, -1, -1]   # per post: 0=open, 1=deels, 2=volledig
var resolved := false
var results: Array = []             # [{post, txt, money, scandal}]
var total_money := 0
var total_scandal := 0


func choose(post_idx: int, option: int) -> void:
	choices[post_idx] = option


func all_chosen() -> bool:
	for c in choices:
		if int(c) == -1:
			return false
	return true


func resolve(rng: RandomNumberGenerator, money_scale: float = 1.0) -> void:
	# money_scale komt van Game.event_money_scale(): elke postbedrag schaalt
	# vóór de percentages worden berekend, zodat tekst en totaal altijd kloppen.
	resolved = true
	total_money = 0
	total_scandal = 0
	for i in range(POSTS.size()):
		var post: Dictionary = POSTS[i]
		var amount: int = int(round(float(post.amount) * money_scale))
		var name: String = str(post.name)
		var r: Dictionary
		match int(choices[i]):
			0:
				var m := -int(amount * 0.35)
				r = {"post": name, "money": m, "scandal": 0,
					"txt": "%s: netjes opgegeven. %s belasting." % [name, _eur(m)]}
			1:
				if rng.randf() < 0.70:
					var m := -int(amount * 0.15)
					r = {"post": name, "money": m, "scandal": 0,
						"txt": "%s: deels verhuld, niet opgemerkt. %s." % [name, _eur(m)]}
				else:
					var m := -int(amount * 0.6)
					r = {"post": name, "money": m, "scandal": 5,
						"txt": "%s: deels verhuld — ontdekt. Naheffing %s." % [name, _eur(m)]}
			_:
				if rng.randf() < 0.45:
					r = {"post": name, "money": 0, "scandal": 0,
						"txt": "%s: volledig verhuld, niemand die het ziet." % name}
				else:
					var m := -amount
					r = {"post": name, "money": m, "scandal": 12,
						"txt": "%s: volledig verhuld — grondig ontdekt. Fikse boete %s." % [name, _eur(m)]}
		results.append(r)
		total_money += int(r.money)
		total_scandal += int(r.scandal)


func _eur(n: int) -> String:
	var v := n
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-€" if v < 0 else "€") + out
