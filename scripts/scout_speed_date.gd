# scout_speed_date.gd — minigame "Speed-dating met scouts" (event: scoutingbeurs_speeddate).
# Vier scouts, vier talenten, een verborgen 1-op-1 klik. Raad koppels binnen
# een beperkt aantal pogingen — vastgezette koppels blijven staan.
class_name ScoutSpeedDate
extends RefCounted

const SCOUTS := ["Scout Hendriks", "Scout Okafor", "Scout Lindqvist", "Scout Pereira"]
const TALENTS := ["Talent A", "Talent B", "Talent C", "Talent D"]

var mapping: Array = []            # mapping[scout_idx] = juiste talent_idx
var locked: Array = [false, false, false, false]
var attempts_left := 6
var finished := false
var log: Array = []


func setup(rng: RandomNumberGenerator) -> void:
	var perm: Array = [0, 1, 2, 3]
	for i in range(perm.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = perm[i]
		perm[i] = perm[j]
		perm[j] = tmp
	mapping = perm


func guess(scout_idx: int, talent_idx: int) -> bool:
	if locked[scout_idx] or finished:
		return false
	attempts_left -= 1
	var correct: bool = int(mapping[scout_idx]) == talent_idx
	if correct:
		locked[scout_idx] = true
		log.append("%s past perfect bij %s! Vastgezet." % [SCOUTS[scout_idx], TALENTS[talent_idx]])
	else:
		log.append("%s en %s klikken niet." % [SCOUTS[scout_idx], TALENTS[talent_idx]])
	_check_end()
	return correct


func _check_end() -> void:
	var all_locked := true
	for l in locked:
		if not l:
			all_locked = false
	if all_locked or attempts_left <= 0:
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
