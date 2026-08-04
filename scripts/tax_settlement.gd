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
				# Veilig maar duur: je betaalt fors, maar nul risico/schandaal.
				var m := -int(amount * 0.40)
				r = {"post": name, "money": m, "scandal": 0,
					"txt": I18n.T("%s: netjes opgegeven. %s belasting.") % [I18n.T(name), _eur(m)]}
			1:
				# Slimme geld-keuze: laagste verwachte kosten (~-24,5%), maar
				# 35% kans op een naheffing + wat schandaal.
				if rng.randf() < 0.65:
					var m := -int(amount * 0.08)
					r = {"post": name, "money": m, "scandal": 0,
						"txt": I18n.T("%s: deels verhuld, niet opgemerkt. Slechts %s.") % [I18n.T(name), _eur(m)]}
				else:
					var m := -int(amount * 0.55)
					r = {"post": name, "money": m, "scandal": 6,
						"txt": I18n.T("%s: deels verhuld — ontdekt. Naheffing %s.") % [I18n.T(name), _eur(m)]}
			_:
				# Pure gok: 50% helemaal gratis, 50% méér dan de belasting zelf
				# (boete bovenop) plus flink schandaal. Hoge variantie.
				if rng.randf() < 0.50:
					r = {"post": name, "money": 0, "scandal": 0,
						"txt": I18n.T("%s: volledig verhuld, niemand die het ziet.") % I18n.T(name)}
				else:
					var m := -int(amount * 1.1)
					r = {"post": name, "money": m, "scandal": 14,
						"txt": I18n.T("%s: volledig verhuld — grondig ontdekt. Fikse boete %s.") % [I18n.T(name), _eur(m)]}
		results.append(r)
		total_money += int(r.money)
		total_scandal += int(r.scandal)


func preview_amounts(option: int, amount: int) -> Array:
	# [bedrag bij succes, bedrag bij mislukking] — beide 0 of negatief, want
	# het zijn kosten. Bij "open aangeven" is er maar één uitkomst, dan zijn
	# beide gelijk (de UI toont dat als één regel). De percentages hieronder
	# moeten in de pas blijven met resolve() hierboven; ze worden NIET meer op
	# de knop getoond, alleen de bedragen zelf.
	match option:
		0:
			var m := -int(amount * 0.40)
			return [m, m]
		1:
			return [-int(amount * 0.08), -int(amount * 0.55)]
		_:
			return [0, -int(amount * 1.1)]


func _eur(n: int) -> String:
	var v := n
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-€" if v < 0 else "€") + out
