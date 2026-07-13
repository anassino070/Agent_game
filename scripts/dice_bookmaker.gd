# dice_bookmaker.gd — minigame "Dobbelen bij de bookmaker" (event: bookmaker_dobbelen).
# Yahtzee-lite: gooi 5 dobbelstenen, houd wat je wilt vast, twee herkansingen.
# De einduitkomst (poker/vier gelijk/full house/drie gelijk/twee paar/niets)
# bepaalt de uitbetaling op je inzet.
class_name DiceBookmaker
extends RefCounted

var dice: Array = [0, 0, 0, 0, 0]
var held: Array = [false, false, false, false, false]
var rolls_left := 2
var stake := 0
var finished := false
var payout_mult := 0.0
var log: Array = []


func setup(rng: RandomNumberGenerator, money_scale: float = 1.0) -> void:
	stake = int(round(2000.0 * money_scale))
	_roll_unheld(rng)


func _roll_unheld(rng: RandomNumberGenerator) -> void:
	for i in range(5):
		if not held[i]:
			dice[i] = rng.randi_range(1, 6)


func toggle_hold(i: int) -> void:
	held[i] = not held[i]


func reroll(rng: RandomNumberGenerator) -> void:
	if rolls_left <= 0 or finished:
		return
	_roll_unheld(rng)
	rolls_left -= 1
	if rolls_left <= 0:
		_score()


func stop_early() -> void:
	if not finished:
		_score()


func _score() -> void:
	finished = true
	var counts := {}
	for d in dice:
		counts[d] = int(counts.get(d, 0)) + 1
	var max_count := 0
	var pair_count := 0
	for k in counts:
		max_count = maxi(max_count, int(counts[k]))
		if int(counts[k]) >= 2:
			pair_count += 1
	if max_count >= 5:
		payout_mult = 10.0
		log.append("VIJF GELIJKE OGEN! De bookmaker verbleekt.")
	elif max_count == 4:
		payout_mult = 4.0
		log.append("Vier gelijke ogen. Mooie klapper.")
	elif max_count == 3 and pair_count >= 2:
		payout_mult = 3.0
		log.append("Full house!")
	elif max_count == 3:
		payout_mult = 1.5
		log.append("Drie gelijke ogen.")
	elif pair_count >= 2:
		payout_mult = 0.5
		log.append("Twee paar — een schamele troostprijs.")
	else:
		payout_mult = -1.0
		log.append("Niets. De bookmaker glimlacht breed.")


func outcome() -> Dictionary:
	var delta := int(round(float(stake) * payout_mult))
	if payout_mult > 0.0:
		return {"effects": {"money": delta},
			"txt": "Uitbetaling op je inzet van %s: %s." % [_eur(stake), _eur(delta)]}
	return {"effects": {"money": -stake},
		"txt": "Verloren: %s." % _eur(-stake)}


func _eur(n: int) -> String:
	var v := n
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-€" if v < 0 else "€") + out
