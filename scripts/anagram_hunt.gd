# anagram_hunt.gd — minigame "Anagramjacht" (event: anagram_jacht).
# Drie gehusselde woorden uit een gelekt clubdocument; type het juiste woord
# via een virtueel toetsenbord binnen ROUND_SECONDS per woord, voordat een
# rivaal-makelaar het document doorheeft. De echte klok loopt in main.gd
# (Godot _process); deze klasse kent alleen "tijd om" via timeout().
class_name AnagramHunt
extends RefCounted

const WORD_BANK := ["CONTRACT", "CLAUSULE", "BUDGET", "TRANSFER", "SPONSOR", "RESERVE", "SCOUTING", "SEIZOEN"]
const ROUND_SECONDS := 25.0

var rounds: Array = []     # [{scrambled, answer}]
var round_idx := 0
var typed := ""
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
		rounds.append({"scrambled": scrambled, "answer": word})


func current() -> Dictionary:
	return rounds[round_idx]


func type_letter(ch: String) -> void:
	if finished:
		return
	if typed.length() < str(current().answer).length():
		typed += ch


func backspace() -> void:
	if typed.length() > 0:
		typed = typed.substr(0, typed.length() - 1)


func can_submit() -> bool:
	return typed.length() == str(current().answer).length() and typed.length() > 0


func submit() -> void:
	var correct: bool = typed == str(current().answer)
	_advance(correct, false)


func timeout() -> void:
	log.append("Tijd is om! Het was %s." % str(current().answer))
	_advance(false, true)


func _advance(correct: bool, was_timeout: bool) -> void:
	if correct:
		correct_count += 1
		log.append("Juist! Het was %s." % str(current().answer))
	elif not was_timeout:
		log.append("Fout — het was %s." % str(current().answer))
	round_idx += 1
	typed = ""
	if round_idx >= rounds.size():
		finished = true


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
