# simon_media.gd — minigame "Simon Says voor mediatraining" (event: mediatraining_simon).
# Klassiek geheugenspel: een reeks "veilige" reacties groeit elke ronde met
# één stap. Bekijk de reeks, en herhaal haar daarna blind. Vijf rondes
# foutloos = volledig getraind; een fout beëindigt de sessie direct.
# Aantal beschikbare reacties groeit mee met het seizoen:
# round(4 + 0,4×seizoen), begrensd door de poolgrootte — later in de run
# moet je uit meer opties kiezen, dus wordt onthouden lastiger.
class_name SimonMedia
extends RefCounted

const MOVE_POOL := ["Rustig", "Trots", "Nederig", "Grapje", "Empathie", "Feiten", "Ontwijkend", "Zelfspot", "Dankbaar", "Strijdlust"]
const TARGET_ROUNDS := 5

var moves: Array = []
var sequence: Array = []
var player_progress := 0
var round_num := 0
var phase := "show"          # "show" of "input"
var finished := false
var failed := false
var log: Array = []


func setup(rng: RandomNumberGenerator, season: int = 1) -> void:
	var count := clampi(int(round(4.0 + 0.4 * float(season))), 4, MOVE_POOL.size())
	var pool: Array = MOVE_POOL.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	moves = pool.slice(0, count)
	_extend(rng)


func _extend(rng: RandomNumberGenerator) -> void:
	sequence.append(rng.randi_range(0, moves.size() - 1))
	player_progress = 0
	phase = "show"
	round_num += 1


func start_input() -> void:
	phase = "input"


func input_move(move_idx: int, rng: RandomNumberGenerator) -> bool:
	if int(sequence[player_progress]) != move_idx:
		finished = true
		failed = true
		log.append("Fout bij stap %d. De reeks breekt af." % (player_progress + 1))
		return false
	player_progress += 1
	if player_progress >= sequence.size():
		if round_num >= TARGET_ROUNDS:
			finished = true
			failed = false
			log.append("Perfecte reeks van %d! Hij kent zijn praatjes nu uit zijn hoofd." % TARGET_ROUNDS)
		else:
			_extend(rng)
	return true


func sequence_text() -> String:
	var parts: Array = []
	for m in sequence:
		parts.append(str(moves[int(m)]))
	return " → ".join(parts)


func outcome() -> Dictionary:
	if failed:
		return {"effects": {},
			"txt": "Bij reeks %d ging het mis. Nog niet klaar voor prime time — maar geen schade." % round_num}
	return {"effects": {"trust": 10, "scandal": -8},
		"txt": "Vlekkeloos! Hij is voortaan een stuk persvaardiger — de schandaalmeter zakt meteen wat."}
