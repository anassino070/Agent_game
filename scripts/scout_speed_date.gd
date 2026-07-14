# scout_speed_date.gd — minigame "Speed-daten op de scoutingbeurs"
# (event: scoutingbeurs_speeddate). Vier scouts, vier talenten. Elke scout
# heeft één of twee talenten waar hij goed bij past. Een FOUT aanbod
# verbrandt die scout meteen (niet meer beschikbaar) — voorzichtig kiezen
# loont dus meer dan wild gokken.
class_name ScoutSpeedDate
extends RefCounted

const SCOUTS := ["Scout Hendriks", "Scout Okafor", "Scout Lindqvist", "Scout Pereira"]
const TALENTS := ["Talent A", "Talent B", "Talent C", "Talent D"]

var accepted: Array = []           # accepted[scout_idx] = Array van passende talent_idx
var locked: Array = [false, false, false, false]
var burned: Array = [false, false, false, false]
var attempts_left := 6
var finished := false
var log: Array = []


func setup(rng: RandomNumberGenerator) -> void:
	# Basisgarantie: elk talent heeft minstens één juiste scout (permutatie).
	var perm: Array = [0, 1, 2, 3]
	for i in range(perm.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = perm[i]
		perm[i] = perm[j]
		perm[j] = tmp
	accepted = []
	for i in range(4):
		accepted.append([int(perm[i])])
	# Sommige scouts staan open voor een tweede talent.
	for i in range(4):
		if rng.randf() < 0.5:
			var extra := rng.randi_range(0, 3)
			if not accepted[i].has(extra):
				accepted[i].append(extra)


func guess(scout_idx: int, talent_idx: int) -> bool:
	if locked[scout_idx] or burned[scout_idx] or finished:
		return false
	attempts_left -= 1
	var correct: bool = accepted[scout_idx].has(talent_idx)
	if correct:
		locked[scout_idx] = true
		log.append("%s past bij %s! Vastgezet." % [SCOUTS[scout_idx], TALENTS[talent_idx]])
	else:
		burned[scout_idx] = true
		log.append("%s voelt zich verkeerd ingeschat en haakt af — niet meer beschikbaar." % SCOUTS[scout_idx])
	_check_end()
	return correct


func _check_end() -> void:
	var all_done := true
	for i in range(4):
		if not locked[i] and not burned[i]:
			all_done = false
	if all_done or attempts_left <= 0:
		finished = true


func locked_count() -> int:
	var n := 0
	for l in locked:
		if l:
			n += 1
	return n


func outcome() -> Dictionary:
	match locked_count():
		4:
			return {"effects": {"scout_points": 3, "rep": 3},
				"txt": "Alle vier de koppels kloppen. De beurs onthoudt jouw neus voor talent."}
		3:
			return {"effects": {"scout_points": 2},
				"txt": "Drie van de vier goed. Prima resultaat."}
		2:
			return {"effects": {"scout_points": 1},
				"txt": "Twee koppels raak. Niet slecht."}
		_:
			return {"effects": {},
				"txt": "Weinig klik vandaag. Volgende keer beter."}
