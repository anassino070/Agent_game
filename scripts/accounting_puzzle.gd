# accounting_puzzle.gd — minigame "De boekhoudpuzzel" (event: boekhoud_puzzel).
# Een legitiem, risicoloos alternatief voor de fiscale schikking: los een 5×5
# Latijns vierkant op (elke rij en kolom bevat 1-5 precies één keer — geen
# 2×2/vakconstructie zoals bij 4×4-sudoku, want 5 is een priemgetal) binnen
# een beperkt aantal controles. Seizoen 1-7: meer startvakjes ingevuld;
# seizoen 8-15: minder hints, dus lastiger.
class_name AccountingPuzzle
extends RefCounted

const SIZE := 5
const CELLS := 25

var solution: Array = []
var grid: Array = []       # 0 = leeg, anders 1-5
var fixed: Array = []      # true = gegeven, niet aan te passen
var attempts_left := 3
var finished := false
var success := false
var log: Array = []


func setup(rng: RandomNumberGenerator, season: int = 1) -> void:
	# Basis-Latijns-vierkant via cyclische shift, dan symbolen én rijen/
	# kolommen door elkaar husselen voor variatie (blijft geldig).
	var base: Array = []
	for i in range(CELLS):
		base.append(((i / SIZE + i % SIZE) % SIZE) + 1)

	var perm: Array = [1, 2, 3, 4, 5]
	for i in range(perm.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = perm[i]
		perm[i] = perm[j]
		perm[j] = tmp
	for i in range(CELLS):
		base[i] = perm[int(base[i]) - 1]

	var row_order: Array = [0, 1, 2, 3, 4]
	var col_order: Array = [0, 1, 2, 3, 4]
	for i in range(row_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = row_order[i]
		row_order[i] = row_order[j]
		row_order[j] = tmp
	for i in range(col_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = col_order[i]
		col_order[i] = col_order[j]
		col_order[j] = tmp

	solution = []
	for i in range(CELLS):
		var r := i / SIZE
		var c := i % SIZE
		solution.append(base[int(row_order[r]) * SIZE + int(col_order[c])])

	var reveal_count := 11 if season <= 7 else 8
	var idx: Array = []
	for i in range(CELLS):
		idx.append(i)
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	var revealed := {}
	for i in range(reveal_count):
		revealed[idx[i]] = true

	grid = []
	fixed = []
	for i in range(CELLS):
		if revealed.has(i):
			fixed.append(true)
			grid.append(solution[i])
		else:
			fixed.append(false)
			grid.append(0)


func cycle_cell(i: int) -> void:
	if fixed[i] or finished:
		return
	# Cyclus loopt 0 (leeg) → 1 → 2 → 3 → 4 → 5 → 0 → …: na de 5 komt weer een
	# lege stand, zodat je een vakje kunt legen voor overzicht i.p.v. gedwongen
	# altijd een cijfer te laten staan.
	grid[i] = (int(grid[i]) + 1) % (SIZE + 1)


func check() -> bool:
	# Geen vergelijking meer met de ene gegenereerde solution — een Latijns
	# vierkant heeft meerdere geldige oplossingen. We valideren generiek: elke
	# rij en kolom moet 1..SIZE bevatten, elk precies één keer (dus ook geen
	# lege vakjes meer). Zolang het logisch klopt, is het goed.
	attempts_left -= 1
	var ok := _is_valid_grid()
	if ok:
		finished = true
		success = true
		log.append("Perfect. Elke rij en kolom klopt.")
	elif attempts_left <= 0:
		finished = true
		success = false
		log.append("Het rooster klopt nog steeds niet — geen pogingen meer.")
	else:
		log.append("Nog niet helemaal goed. Nog %d poging(en)." % attempts_left)
	return ok


func _is_valid_grid() -> bool:
	for r in range(SIZE):
		var seen: Dictionary = {}
		for c in range(SIZE):
			var v := int(grid[r * SIZE + c])
			if v < 1 or v > SIZE or seen.has(v):
				return false
			seen[v] = true
	for c in range(SIZE):
		var seen: Dictionary = {}
		for r in range(SIZE):
			var v := int(grid[r * SIZE + c])
			if v < 1 or v > SIZE or seen.has(v):
				return false
			seen[v] = true
	return true


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
