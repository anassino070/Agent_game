# accounting_puzzle.gd — minigame "Cijferpuzzel voor de boekhouding"
# (event: boekhoud_puzzel). Een legitiem, risicoloos alternatief voor de
# fiscale schikking: los een 4×4 mini-sudoku op (elke rij, kolom en 2×2-vak
# bevat 1-4 precies één keer) binnen een beperkt aantal controles.
class_name AccountingPuzzle
extends RefCounted

const BASE_SOLUTION := [1, 2, 3, 4, 3, 4, 1, 2, 2, 1, 4, 3, 4, 3, 2, 1]

var solution: Array = []
var grid: Array = []       # 0 = leeg, anders 1-4
var fixed: Array = []      # true = gegeven, niet aan te passen
var attempts_left := 3
var finished := false
var success := false
var log: Array = []


func setup(rng: RandomNumberGenerator) -> void:
	var perm: Array = [1, 2, 3, 4]
	for i in range(perm.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = perm[i]
		perm[i] = perm[j]
		perm[j] = tmp
	solution = []
	for v in BASE_SOLUTION:
		solution.append(perm[int(v) - 1])

	var idx: Array = []
	for i in range(16):
		idx.append(i)
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	var revealed := {}
	for i in range(7):
		revealed[idx[i]] = true

	grid = []
	fixed = []
	for i in range(16):
		if revealed.has(i):
			fixed.append(true)
			grid.append(solution[i])
		else:
			fixed.append(false)
			grid.append(0)


func cycle_cell(i: int) -> void:
	if fixed[i] or finished:
		return
	grid[i] = int(grid[i]) % 4 + 1


func check() -> bool:
	attempts_left -= 1
	var ok := true
	for i in range(16):
		if int(grid[i]) != int(solution[i]):
			ok = false
			break
	if ok:
		finished = true
		success = true
		log.append("Perfect. Elke rij, kolom en vak klopt.")
	elif attempts_left <= 0:
		finished = true
		success = false
		log.append("Het rooster klopt nog steeds niet — geen pogingen meer.")
	else:
		log.append("Nog niet helemaal goed. Nog %d poging(en)." % attempts_left)
	return ok


func outcome(money_scale: float = 1.0) -> Dictionary:
	if success:
		var savings := int(round(4000.0 * money_scale))
		return {"effects": {"money": savings},
			"txt": "Het rooster klopt helemaal. Legale besparing: %s." % _eur(savings)}
	return {"effects": {},
		"txt": "Geen besparing dit keer — maar ook geen enkel risico gelopen."}


func _eur(n: int) -> String:
	var v := n
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-€" if v < 0 else "€") + out
