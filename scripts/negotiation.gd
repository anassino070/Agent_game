# negotiation.gd — het onderhandelings-minigame.
# Drie mechanieken grijpen in elkaar, zodat de VOLGORDE van je zetten telt:
# 1. STEMMING van de TD (Geïrriteerd → Zakelijk → Ontvankelijk). Opbouwzetten
#    (charmeren, clausule) verbeteren haar; payoff-zetten (bluffen, druk)
#    hebben haar nodig. Druk verslechtert de stemming ALTIJD — finisher.
# 2. Verborgen PERSOONLIJKHEID van de TD. "Aftasten" kost een ronde en
#    onthult haar; die kennis blijft per club de hele run bewaard (Game).
# 3. FLOW: twee successen op rij geven +50% effect op je volgende zet;
#    een mislukking reset de reeks. Beloont plannen, straft gokken.
class_name Negotiation
extends RefCounted

const MOODS := ["Geïrriteerd", "Zakelijk", "Ontvankelijk"]
# Persoonlijkheden werken vooral op KANSEN, mild op weerstand — zo blijven
# ze gebalanceerd.
const PERS_INFO := {
	"ijdel": "IJdel — charme slaagt altijd (en iets sterker)",
	"koppig": "Koppig — wat extra weerstand, maar zakt nooit onder Zakelijk",
	"nerveus": "Nerveus — druk slaagt veel vaker, maar hij loopt sneller weg",
	"rekenmeester": "Rekenmeester — taaie weerstand, feiten slagen iets vaker en tellen 1,15×; charme doet niets en hij is ongevoelig voor bluf en druk",
}

# Combo's: speel dit patroon van OPEENVOLGENDE SUCCESSEN en de laatste zet
# krijgt extra weerstandsschade. Eén keer per onderhandeling per combo.
# "req_pers" vereist een bevestigd (afgetast/bekend) TD-type.
const COMBOS := [
	{"id": "goede_cop", "name": "De Goede Cop",
		"pattern": ["charme", "charme", "feiten"], "bonus": 6},
	{"id": "slotklap", "name": "De Slotklap",
		"pattern": ["charme", "feiten", "charme", "druk"], "bonus": 14},
	{"id": "boekhouder", "name": "De Boekhouder",
		"pattern": ["feiten", "feiten"], "bonus": 8, "req_pers": "rekenmeester"},
	{"id": "ultimatum", "name": "Het Ultimatum",
		"pattern": ["clausule", "clausule", "druk"], "bonus": 10},
	{"id": "nerveuze_val", "name": "De Nerveuze Val",
		"pattern": ["druk", "druk"], "bonus": 16, "req_pers": "nerveus"},
	{"id": "slow_play", "name": "Slow Play",
		"pattern": ["clausule", "charme", "feiten", "bluf"], "bonus": 12},
]

const MOVE_LABELS := {
	"charme": "Charmeren", "feiten": "Feiten & cijfers", "bluf": "Bluffen",
	"druk": "Deadline-druk", "clausule": "Clausule", "aftasten": "Aftasten",
}

var resistance: float = 45.0
var deal_value: int = 0
var cut: float = 0.10       # jouw fee-percentage van de transfersom
var rounds_left: int = 5
var finished := false
var success := false
var walked := false          # TD heeft het gesprek afgebroken
var log: Array = []

var mood := 1                # 0 = Geïrriteerd, 1 = Zakelijk, 2 = Ontvankelijk
var pers := ""               # persoonlijkheid; werkt ook als hij nog verborgen is
var pers_known := false
var streak := 0              # opeenvolgende successen; 2+ = flow
var success_run: Array = []  # ids van opeenvolgende successen (voor combo's)
var combos_done: Array = []  # elke combo maximaal één keer per gesprek
var last_combo := ""         # naam van de combo die de LAATSTE zet afrondde ("" = geen)

# Perk-instelbaar (gezet door main.gd bij de start van een gesprek).
var flow_mult := 1.5         # effect-multiplier bij flow
var walk_mod := 1.0          # demping op wegloopkansen (Stalen zenuwen)
var clausule_cost := 0.02    # fee-kost per clausule (Clausulemeester)
var aftast_cost := 2         # rondes die aftasten kost (Dossierkennis)
var bluf_bonus := 0.0        # extra slagingskans op bluffen (Koelbloedig)

const RAISE_FEE_STEP := 0.02
const MAX_CUT := 0.30


func setup(value: int, start_resistance: float, personality: String, known: bool) -> void:
	deal_value = value
	resistance = start_resistance
	pers = personality
	pers_known = known
	if pers == "koppig":
		resistance += 5.0
	elif pers == "rekenmeester":
		resistance += 8.0


func mood_name() -> String:
	return MOODS[mood]


func has_flow() -> bool:
	return streak >= 2


func _mood_floor() -> int:
	return 1 if pers == "koppig" else 0


func _shift_mood(delta: int) -> void:
	mood = clampi(mood + delta, _mood_floor(), 2)


# Beschikbare tactieken. Kansen en effecten hangen af van de huidige stemming
# en van de persoonlijkheid (die werkt ook zolang hij nog verborgen is —
# de logregels verklappen soft tells).
func tactics(rep: int) -> Array:
	var bonus := (rep - 50) * 0.002
	var out: Array = []

	# Opbouw: charmeren — verbetert de stemming, kleine weerstandswinst.
	var t_ch := {
		"id": "charme", "label": "Charmeren", "drop": 8,
		"chance": clampf(0.70 + bonus, 0.05, 0.95),
		"mood_ok": 1, "mood_fail": -1, "fail_res": 2,
		"ok_txt": "De TD ontdooit.",
		"fail_txt": "De TD prikt door je charmes heen. De sfeer bekoelt.",
	}
	if pers == "ijdel":
		t_ch.chance = 1.0
		t_ch.drop = 10
		t_ch.ok_txt = "De TD glimt. IJdelheid loont."
	elif pers == "rekenmeester":
		t_ch.drop = 0
		t_ch.mood_ok = 0
		t_ch.ok_txt = "De TD kijkt op zijn horloge. Charme glijdt van hem af."
	out.append(t_ch)

	# Feiten & cijfers — het sterkst bij een Zakelijke stemming.
	var f_drop := 12
	var f_chance := 0.65 + bonus
	if mood == 1:
		f_drop = 18
	if pers == "rekenmeester":
		f_drop = int(f_drop * 1.15)
		f_chance += 0.08
	out.append({
		"id": "feiten", "label": "Feiten & cijfers", "drop": f_drop,
		"chance": clampf(f_chance, 0.05, 0.95),
		"mood_ok": 0, "mood_fail": 0, "fail_res": 3,
		"ok_txt": "De cijfers kloppen. De TD knikt.",
		"fail_txt": "De TD legt een fout in je rekensom bloot.",
	})

	# Payoff: bluffen — heeft een goede stemming nodig (25/50/75%).
	var b_chance: float = [0.25, 0.50, 0.75][mood] + bonus + bluf_bonus
	if pers == "rekenmeester":
		b_chance -= 0.15
	out.append({
		"id": "bluf", "label": "Bluffen ('Er is nog een club...')", "drop": 22,
		"chance": clampf(b_chance, 0.05, 0.95),
		"mood_ok": 0, "mood_fail": -1, "fail_res": 8,
		"ok_txt": "De TD slikt het. De prijs beweegt.",
		"fail_txt": "Je bluf wordt doorzien. De TD verhardt.",
	})

	# Payoff/finisher: deadline-druk — verslechtert de stemming ÁLTIJD,
	# en bij een geïrriteerde TD riskeer je dat hij wegloopt.
	var d_chance: float = [0.40, 0.55, 0.70][mood] + bonus
	if pers == "nerveus":
		d_chance += 0.20
	elif pers == "rekenmeester":
		d_chance -= 0.10
	var d_walk := 0.0
	if mood == 0:
		d_walk = 0.8 if pers == "nerveus" else 0.5
	elif mood == 1 and pers == "nerveus":
		d_walk = 0.25
	d_walk *= walk_mod
	out.append({
		"id": "druk", "label": "Deadline-druk", "drop": 18,
		"chance": clampf(d_chance, 0.05, 0.95),
		"mood_ok": -1, "mood_fail": -1, "fail_res": 5, "walk_risk": d_walk,
		"ok_txt": "De TD voelt de klok tikken. Maar de sfeer bekoelt.",
		"fail_txt": "De TD ergert zich aan je haast.",
	})

	# Opbouw: clausule — gegarandeerd, verbetert de stemming, kost fee.
	out.append({
		"id": "clausule", "label": "Clausule aanbieden (kost fee)", "drop": 8,
		"chance": 1.0, "mood_ok": 1, "mood_fail": 0, "fail_res": 0,
		"cut_cost": clausule_cost,
		"ok_txt": "Clausule geaccepteerd; de toon wordt vriendelijker.",
	})

	# Aftasten — kost rondes (standaard 2), onthult de persoonlijkheid voor
	# de hele run. Alleen aangeboden als er daarna nog iets te spelen valt.
	if not pers_known and rounds_left > aftast_cost:
		out.append({
			"id": "aftasten", "label": "Aftasten (leer deze TD kennen)", "drop": 0,
			"chance": 1.0, "mood_ok": 0, "mood_fail": 0, "fail_res": 0,
		})
	return out


func play(t: Dictionary, rng: RandomNumberGenerator) -> void:
	last_combo = ""
	if str(t.id) == "aftasten":
		rounds_left -= aftast_cost
		pers_known = true
		log.append("Je tast af (%d ronde%s). Deze TD is %s." % [
			aftast_cost, "" if aftast_cost == 1 else "s", str(PERS_INFO[pers])])
		_check_end()
		return

	rounds_left -= 1
	var flow := has_flow()
	var drop := float(t.drop) * (flow_mult if flow else 1.0)
	if rng.randf() < float(t.chance):
		resistance -= drop
		streak += 1
		success_run.append(str(t.id))
		_shift_mood(int(t.get("mood_ok", 0)))
		if t.has("cut_cost"):
			cut = maxf(cut - float(t.cut_cost), 0.04)
			log.append("%s Weerstand -%d; jouw fee zakt naar %d%%." % [
				str(t.get("ok_txt", "")), int(drop), int(round(cut * 100))])
		else:
			log.append("%s Weerstand -%d.%s" % [
				str(t.get("ok_txt", "Het werkt.")), int(drop),
				("  (FLOW +%d%%)" % int(round((flow_mult - 1.0) * 100))) if flow else ""])
		_check_combos()
	else:
		streak = 0
		success_run.clear()
		resistance += float(t.get("fail_res", 0))
		_shift_mood(int(t.get("mood_fail", 0)))
		log.append(str(t.get("fail_txt", "Mislukt.")))
		if float(t.get("walk_risk", 0.0)) > 0.0 and rng.randf() < float(t.walk_risk):
			finished = true
			walked = true
			log.append("De TD is het zat en breekt het gesprek af.")
			return
	_check_end()


func _check_combos() -> void:
	for combo in COMBOS:
		if str(combo.id) in combos_done:
			continue
		if combo.has("req_pers") and (pers != str(combo.req_pers) or not pers_known):
			continue
		var pat: Array = combo.pattern
		if success_run.size() < pat.size():
			continue
		if success_run.slice(success_run.size() - pat.size()) == pat:
			combos_done.append(str(combo.id))
			resistance -= float(combo.bonus)
			last_combo = str(combo.name)
			log.append("COMBO — %s! Extra weerstand -%d." % [str(combo.name), int(combo.bonus)])


# Hoeveel stappen van dit patroon je al hebt gezet, met de LOPENDE reeks als
# staart. 0 = niet op koers, pattern.size() = al voltooid. Gebruikt door de
# UI om combo's te markeren die "op koers" zijn.
func combo_progress(combo: Dictionary) -> int:
	var pat: Array = combo.pattern
	if str(combo.id) in combos_done:
		return pat.size()
	if combo.has("req_pers") and (pers != str(combo.req_pers) or not pers_known):
		return 0
	for k in range(mini(success_run.size(), pat.size() - 1), 0, -1):
		if success_run.slice(success_run.size() - k) == pat.slice(0, k):
			return k
	return 0


func combo_pattern_text(combo: Dictionary) -> String:
	var labels: Array = []
	for id in combo.pattern:
		labels.append(str(MOVE_LABELS.get(id, id)))
	return " → ".join(labels)


# Gunst ingezet: een contact belt de TD persoonlijk op. Gegarandeerd succes,
# kost een ronde en telt gewoon mee voor streak/flow — maar heeft geen eigen
# tactiek-id, dus doorbreekt geen lopende combo (en voltooit er ook geen).
func halve_resistance() -> void:
	rounds_left -= 1
	resistance = maxf(resistance / 2.0, 0.0)
	streak += 1
	log.append("Je zet een gunst in: een contact belt de TD persoonlijk. Weerstand halveert naar %d." % int(resistance))
	_check_end()


# Verhoogt alleen je fee-percentage; raakt weerstand, stemming, streak en
# combo's helemaal niet — een zuivere zijstap.
func raise_fee() -> void:
	rounds_left -= 1
	cut = minf(cut + RAISE_FEE_STEP, MAX_CUT)
	log.append("Je onderhandelt een hoger percentage: jouw fee stijgt naar %d%%." % int(round(cut * 100)))
	_check_end()


func _check_end() -> void:
	if resistance <= 0.0:
		finished = true
		success = true
		log.append("De TD steekt zijn hand uit. DEAL.")
	elif rounds_left <= 0:
		finished = true
		log.append("De tijd is om; de deal ketst af.")
