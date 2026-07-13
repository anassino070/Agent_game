# anagram_hunt.gd — minigame "Anagramjacht" (event: anagram_jacht).
# Drie gehusselde woorden uit een gelekt clubdocument; kies steeds het juiste
# woord uit vier opties voordat een rivaal-makelaar het document doorheeft.
class_name AnagramHunt
extends RefCounted

const WORD_BANK := ["CONTRACT", "CLAUSULE", "BUDGET", "TRANSFER", "SPONSOR", "RESERVE", "SCOUTING", "SEIZOEN"]

var rounds: Array = []     # [{scrambled, answer, options}]
var round_idx := 0
var correct_count := 0
var finished := false
var log: Array = []


func setup(rng: RandomNumberGenerator) -> void:
	var pool: Array = WORD_BANK.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var targets: Array = pool.slice(0, 3)
	for t in targets:
		var word: String = str(t)
		var letters: Array = []
		for i in range(word.length()):
			letters.append(word[i])
		for i in range(letters.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = letters[i]
			letters[i] = letters[j]
			letters[j] = tmp
		var scrambled: String = "".join(letters)
		var decoys: Array = []
		for w in pool:
			if w != t and decoys.size() < 3:
				decoys.append(w)
		var options: Array = decoys + [t]
		for i in range(options.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = options[i]
			options[i] = options[j]
			options[j] = tmp
		rounds.append({"scrambled": scrambled, "answer": t, "options": options})


func current() -> Dictionary:
	return rounds[round_idx]


func guess(word: String) -> bool:
	var correct: bool = word == str(rounds[round_idx].answer)
	if correct:
		correct_count += 1
		log.append("Juist! Het was %s." % str(rounds[round_idx].answer))
	else:
		log.append("Mis — het was %s." % str(rounds[round_idx].answer))
	round_idx += 1
	if round_idx >= rounds.size():
		finished = true
	return correct


func outcome(money_scale: float = 1.0) -> Dictionary:
	match correct_count:
		3:
			var v := int(round(6000.0 * money_scale))
			return {"effects": {"money": v, "rep": 4},
				"txt": "Alle drie geraden! Het volledige document is van jou."}
		2:
			var v := int(round(2500.0 * money_scale))
			return {"effects": {"money": v},
				"txt": "Twee van de drie. Bruikbare fragmenten."}
		1:
			return {"effects": {},
				"txt": "Eén treffer. Te weinig om er iets mee te doen."}
		_:
			return {"effects": {"rep": -2},
				"txt": "Niets geraden. Tijd verspild — en het lekt uit dat je zocht."}
