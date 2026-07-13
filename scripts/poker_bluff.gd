# poker_bluff.gd — minigame "Pokerbluf tegen een rivaal" (event: rivaal_poker).
# Vereenvoudigde pokerinzet om de rechten op een gedeeld toptalent: jij kent
# je eigen "handsterkte", die van de rivaal blijft verborgen tot de showdown
# (of tot hij/jij eerder past). Bluffen werkt vaker naarmate je het minder
# gebruikt — herhaling wordt doorzien.
class_name PokerBluff
extends RefCounted

var my_strength := 0
var rival_strength := 0
var pot := 0
var ante := 0
var rounds_left := 3
var bluffs_used := 0
var finished := false
var folded_by_me := false
var folded_by_rival := false
var won := false
var log: Array = []


func setup(rng: RandomNumberGenerator, money_scale: float = 1.0) -> void:
	my_strength = rng.randi_range(1, 100)
	rival_strength = rng.randi_range(1, 100)
	ante = int(round(600.0 * money_scale))


func play(action: String, rng: RandomNumberGenerator) -> void:
	match action:
		"passen":
			finished = true
			folded_by_me = true
			won = false
			log.append("Je legt je kaarten neer. De pot is voor de rivaal.")
			return
		"meegaan":
			pot += ante
			log.append("Je gaat mee. Pot: %s." % _eur(pot))
		"verhogen":
			pot += ante * 2
			var fold_chance := clampf(float(my_strength) / 150.0, 0.05, 0.6)
			if rng.randf() < fold_chance:
				finished = true
				folded_by_rival = true
				won = true
				log.append("De rivaal legt zijn kaarten neer. Jij incasseert de pot.")
				return
			pot += ante * 2
			log.append("Hij gaat mee met je verhoging.")
		"bluffen":
			var bluff_chance := clampf(0.4 - float(bluffs_used) * 0.1, 0.05, 0.4)
			bluffs_used += 1
			pot += ante * 3
			if rng.randf() < bluff_chance:
				finished = true
				folded_by_rival = true
				won = true
				log.append("Je bluf werkt! Hij legt zich neer.")
				return
			pot += ante * 3
			log.append("Hij doorziet de bluf en gaat mee.")
	rounds_left -= 1
	if rounds_left <= 0:
		finished = true
		won = my_strength >= rival_strength
		if won:
			log.append("Showdown! Jouw hand (%d) wint van die van hem (%d)." % [my_strength, rival_strength])
		else:
			log.append("Showdown! Zijn hand (%d) wint van die van jou (%d)." % [rival_strength, my_strength])


func outcome() -> Dictionary:
	if won:
		return {"effects": {"new_client": true},
			"txt": "Je wint de rechten op het talent én de pot van %s." % _eur(pot)}
	if folded_by_me:
		return {"effects": {"money": -int(pot / 2)},
			"txt": "Je trekt je op tijd terug. Kosten: de helft van de pot."}
	return {"effects": {"money": -pot},
		"txt": "Verloren. De rivaal incasseert de volledige pot — én het talent."}


func _eur(n: int) -> String:
	var v := n
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-€" if v < 0 else "€") + out
