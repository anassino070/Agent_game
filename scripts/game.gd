# game.gd — Autoload "Game".
# Bevat de volledige spelstaat (als plain Dictionary, dus JSON-opslaanbaar)
# en alle spellogica. De UI (main.gd) roept alleen functies hier aan.
extends Node

const SAVE_PATH := "user://save.json"

# ---- Balansknoppen: hier draai je aan de moeilijkheid ----
const START_MONEY := 15000
const MAX_SEASONS := 15       # de volledige run
const CLIENT_CAP := 4
const SCOUT_POINTS := 3
const BASE_COSTS := 10000     # kantoorkosten seizoen 1
const COSTS_MULT := 1.8       # kosten vermenigvuldigen elk seizoen met deze factor
const FEE_CUT := 0.10         # standaard fee-percentage
const LEAVE_TRUST := 30       # onder dit vertrouwen kan een cliënt vertrekken
const LEAVE_CHANCE := 0.5
const RIVAL_NAMES := ["Bureau Marchetti", "Star XI Management", "Agentschap De Wolf", "GoalGetters Int."]

var rng := RandomNumberGenerator.new()
var state: Dictionary = {}


# ---------------------------------------------------------------- run setup

func new_run() -> void:
	rng.randomize()
	var world: Dictionary = WorldGen.generate(rng)
	state = {
		"season": 1,
		"money": START_MONEY + Meta.perk_bonus("startkapitaal") + Meta.perk_bonus("onderpand"),
		"rep": clampi(50 + Meta.perk_bonus("netwerk") + Meta.perk_bonus("iconenstatus"), 0, 100),
		"scandal": 0,
		"favors": 1 + Meta.perk_bonus("gunsten"),
		"scout_points": scout_points_per_season(),
		"players": world.players,
		"clubs": world.clubs,
		"clients": [],
		"news": "Je opent je kantoor boven een snackbar. Eén cliënt gelooft in je.",
		"used_events": [],
		"total_fees": 0,
		"game_over": "",
		"meta_awarded": false,
	}
	# Startcliënt: een jong, beloftevol maar betaalbaar talent.
	var pool: Array = []
	for pid in state.players:
		var p: Dictionary = state.players[pid]
		if int(p.age) <= 21 and int(p.rating) >= 52 and int(p.rating) <= 62:
			pool.append(pid)
	if pool.is_empty():
		pool = state.players.keys()
	var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
	_make_client(pick, 65)


func _make_client(pid: String, trust: int) -> void:
	state.players[pid]["trust"] = clampi(trust + Meta.perk_bonus("vertrouwenspersoon"), 0, 100)
	state.clients.append(pid)


func ensure_test_client() -> void:
	# Developer-only: garandeert minstens één cliënt, zodat needs_client-events
	# ook in de eventtest kunnen worden getoond.
	if not state.clients.is_empty():
		return
	var pool: Array = state.players.keys()
	if pool.is_empty():
		return
	_make_client(pool[0], 70)


# ---------------------------------------------------------------- helpers

func value(p: Dictionary) -> int:
	# Marktwaarde: kwadratisch in rating, zodat toppers écht lonen.
	var r: float = float(p.rating)
	var v := pow(maxf(r - 40.0, 5.0), 2.0) * 650.0
	v *= 1.0 + float(Meta.perk_bonus("waardestijging")) / 100.0
	return int(v)


func scout_points_per_season() -> int:
	return SCOUT_POINTS + Meta.perk_bonus("scouting")


func client_cap() -> int:
	return CLIENT_CAP + Meta.perk_bonus("kantoor")


func fee_cut() -> float:
	# Commissiekunst-perk: +0,2% fee per niveau (value staat in tienden van %).
	return FEE_CUT + float(Meta.perk_bonus("commissie")) / 1000.0


func poach_chance(p: Dictionary) -> float:
	# Rivalen kapen ook cliënten met redelijk vertrouwen weg: hoe hoger de
	# rating, hoe aantrekkelijker; hoog vertrouwen beschermt.
	if Meta.perk_level("ijzeren_stal") > 0:
		return 0.0
	var c := 0.03 + (float(p.rating) - 50.0) * 0.005 - (float(p.trust) - 50.0) * 0.004
	c -= float(Meta.perk_bonus("binding")) * 0.01
	return clampf(c, 0.0, 0.35)


func try_bailout() -> bool:
	# Laatste redmiddel-perk: dekt één keer per run een negatief saldo.
	if int(state.money) >= 0:
		return false
	if Meta.perk_level("laatste_redmiddel") <= 0:
		return false
	if bool(state.get("bailout_used", false)):
		return false
	state["bailout_used"] = true
	state.money = 0
	return true


func release_client(cid: String) -> void:
	# Verplicht seizoensontslag: de rest van je stal schrikt er licht van.
	state.clients.erase(cid)
	for other in state.clients:
		var p: Dictionary = state.players[other]
		p["trust"] = clampi(int(p.trust) - 2, 0, 100)


func club_name(club_id: String) -> String:
	if club_id == "" or not state.clubs.has(club_id):
		return "clubloos"
	return str(state.clubs[club_id]["name"])


const EVENT_MONEY_GROWTH := 0.20   # event-geldbedragen groeien 20%/seizoen mee met de economie


func event_money_scale() -> float:
	# Vaste event-bedragen (€8.000 hier, €5.000 daar) worden anders snel
	# betekenisloos naast de exponentieel stijgende kantoorkosten.
	return pow(1.0 + EVENT_MONEY_GROWTH, float(state.season) - 1.0)


func scale_money_effects(effects: Dictionary) -> Dictionary:
	# Geeft een kopie terug met de "money"-key opgeschaald naar dit seizoen;
	# andere keys blijven ongewijzigd. Gebruik dit VOORDAT je zowel toont
	# als toepast, zodat preview en werkelijkheid altijd gelijk zijn.
	if not effects.has("money"):
		return effects
	var out := effects.duplicate()
	out["money"] = int(round(float(out.money) * event_money_scale()))
	return out


func apply_effects(effects: Dictionary, client_id: String = "") -> Array:
	# Geeft extra meldingsregels terug (bijv. wie zich bij je stal voegt).
	var notes: Array = []
	for key in effects:
		var v = effects[key]
		match key:
			"money":
				state.money = int(state.money) + int(v)
			"rep":
				state.rep = clampi(int(state.rep) + int(v), 0, 100)
			"scandal":
				var sv := int(v)
				# Crisismanagement-perk dempt stijgingen (nooit onder 1).
				if sv > 0:
					sv = maxi(sv - Meta.perk_bonus("crisismanagement"), 1)
				state.scandal = clampi(int(state.scandal) + sv, 0, 100)
			"favors":
				state.favors = maxi(int(state.favors) + int(v), 0)
			"scout_points":
				state.scout_points = maxi(int(state.scout_points) + int(v), 0)
			"trust":
				if client_id != "" and state.players.has(client_id):
					var p: Dictionary = state.players[client_id]
					p["trust"] = clampi(int(p.trust) + int(v), 0, 100)
			"all_trust":
				for cid in state.clients:
					var pc: Dictionary = state.players[cid]
					pc["trust"] = clampi(int(pc.trust) + int(v), 0, 100)
			"new_client":
				var nm := _sign_event_talent()
				if nm != "":
					notes.append("%s sluit zich aan bij jouw stal." % nm)
	return notes


func _sign_event_talent() -> String:
	# Voegt een vrij talent toe aan de stal (voor events als 'poachen').
	if state.clients.size() >= client_cap():
		return ""
	var pool: Array = []
	for pid in state.players:
		if pid in state.clients:
			continue
		var p: Dictionary = state.players[pid]
		if int(p.age) <= 24 and int(p.rating) >= 58:
			pool.append(pid)
	if pool.is_empty():
		for pid in state.players:
			if not (pid in state.clients):
				pool.append(pid)
	if pool.is_empty():
		return ""
	var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
	_make_client(pick, 60)
	return str(state.players[pick].name)


# ---------------------------------------------------------------- scouting

func rating_cap_young() -> int:
	# Reputatie bepaalt wie je telefoontje beantwoordt.
	return 50 + int(state.rep) / 4 + Meta.perk_bonus("talentmagneet")


func rating_cap_older() -> int:
	return 55 + int(state.rep) / 3 + Meta.perk_bonus("grote_naam")


func gen_candidates() -> Array:
	# 4 doelen om te scouten/benaderen: 2 jonge beloftes en 2 gevestigde
	# namen (23+, hogere rating maar weinig rek). Hoe hoger je reputatie,
	# hoe beter de spelers die met je willen praten.
	var young: Array = []
	var older: Array = []
	for pid in state.players:
		if pid in state.clients:
			continue
		var p: Dictionary = state.players[pid]
		var r := int(p.rating)
		if int(p.age) <= 22 and r >= 45 and r <= rating_cap_young():
			young.append(pid)
		elif int(p.age) >= 23 and int(p.age) <= 30 and r >= 50 and r <= rating_cap_older():
			older.append(pid)
	var count := 4 + Meta.perk_level("extra_kandidaat")
	var out: Array = []
	_take_random(young, 2, out)
	_take_random(older, 2, out)
	# Vul aan als een pool (bijna) leeg was of het Brede netwerk-perk actief is.
	var rest: Array = young + older
	_take_random(rest, count - out.size(), out)
	return out


func _take_random(pool: Array, n: int, out: Array) -> void:
	while n > 0 and not pool.is_empty():
		var i := rng.randi_range(0, pool.size() - 1)
		var pid = pool[i]
		pool.remove_at(i)
		if not (pid in out):
			out.append(pid)
			n -= 1


func estimate(pid: String) -> int:
	# Publieke potentieel-schatting; lazy voor saves van vóór dit veld.
	var p: Dictionary = state.players[pid]
	if not p.has("est"):
		var spread := int(float(p.unc) * 0.75)
		p["est"] = clampi(int(p.pot) + rng.randi_range(-spread, spread), int(p.rating), 94)
	return int(p.est)


func scout(pid: String) -> bool:
	if int(state.scout_points) <= 0:
		return false
	var p: Dictionary = state.players[pid]
	if int(p.unc) <= 2:
		return false
	var old_unc := int(p.unc)
	var new_unc := maxi(old_unc - (5 + Meta.perk_bonus("talentenoog")), 2)
	# De schatting kruipt richting het echte potentieel naarmate je beter
	# kijkt — maar een "70–90"-belofte kan dus een 72-dud blijken.
	var err := estimate(pid) - int(p.pot)
	p["est"] = int(p.pot) + int(round(float(err) * float(new_unc) / float(old_unc)))
	p["unc"] = new_unc
	p["scouted"] = int(p.get("scouted", 0)) + 1
	state.scout_points = int(state.scout_points) - 1
	return true


func sign_chance(pid: String) -> float:
	var p: Dictionary = state.players[pid]
	var c := 0.20 + float(state.rep) / 200.0 - (float(p.rating) - 50.0) * 0.01
	c += float(Meta.perk_bonus("babbel")) * 0.01
	# Gescoute spelers voelen zich serieus genomen: +5% per scout, max +10%.
	c += mini(int(p.get("scouted", 0)), 2) * 0.05
	return clampf(c, 0.1, 0.85)


func attempt_sign(pid: String) -> bool:
	if state.clients.size() >= client_cap():
		return false
	if rng.randf() < sign_chance(pid):
		_make_client(pid, 55)
		state.rep = clampi(int(state.rep) + 1, 0, 100)
		return true
	return false


# ---------------------------------------------------------------- events

func gen_events() -> Array:
	var evs: Array = EventsDB.get_events()
	var out: Array = []
	var n := rng.randi_range(4, 6)
	var tries := 0
	while out.size() < n and tries < 300:
		tries += 1
		var ev: Dictionary = evs[rng.randi_range(0, evs.size() - 1)]
		if ev.id in state.used_events:
			continue
		if int(ev.get("min_season", 1)) > int(state.season):
			continue
		if bool(ev.get("needs_slot", false)) and state.clients.size() >= client_cap():
			continue
		var cid := ""
		if bool(ev.get("needs_client", false)):
			if state.clients.is_empty():
				continue
			cid = state.clients[rng.randi_range(0, state.clients.size() - 1)]
		var e: Dictionary = ev.duplicate(true)
		e["client_id"] = cid
		out.append(e)
		state.used_events.append(ev.id)
	return out


# ---------------------------------------------------------------- transfers

func gen_interest(client_id: String) -> Array:
	# 0–2 geïnteresseerde clubs, afhankelijk van rating, budget en ambitie.
	var p: Dictionary = state.players[client_id]
	var v := value(p)
	var ids: Array = state.clubs.keys()
	# Fisher-Yates met onze eigen rng, voor determinisme per seed.
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	var out: Array = []
	for club_id in ids:
		if club_id == str(p.club):
			continue
		var c: Dictionary = state.clubs[club_id]
		if int(c.budget) < v:
			continue
		var chance := 0.10 + (float(p.rating) - 50.0) * 0.01 + float(c.ambition) * 0.04
		if rng.randf() < chance:
			out.append(club_id)
		if out.size() >= 2:
			break
	return out


const TD_PERS := ["ijdel", "koppig", "nerveus", "rekenmeester"]


func td_personality(club_id: String) -> String:
	# Lazy toegekend zodat ook oude saves een persoonlijkheid krijgen.
	var c: Dictionary = state.clubs[club_id]
	if not c.has("td_pers"):
		c["td_pers"] = TD_PERS[rng.randi_range(0, TD_PERS.size() - 1)]
		c["td_known"] = false
	return str(c.td_pers)


func td_known(club_id: String) -> bool:
	if Meta.perk_level("helderziend") > 0:
		return true
	return bool(state.clubs[club_id].get("td_known", false))


func reveal_td(club_id: String) -> void:
	# Aftast-kennis blijft de hele run bewaard.
	state.clubs[club_id]["td_known"] = true


func start_resistance(club_id: String) -> float:
	# Deadline day (elk 5e seizoen): TD's zijn nerveuzer, dus zachter.
	var base := rng.randf_range(45.0, 70.0)
	if int(state.season) % 5 == 0:
		base -= 8.0
	base -= float(Meta.perk_bonus("voorwerk"))
	return base


func luck_bonus() -> float:
	# Geluksvogel-perk: +1%-punt per bonuspunt op kans-opties bij events.
	return float(Meta.perk_bonus("geluksvogel")) * 0.01


func complete_transfer(client_id: String, club_id: String, fee: int, cut: float) -> int:
	var income := int(fee * cut)
	if Meta.perk_level("superprovisie") > 0:
		income *= 2
	state.money = int(state.money) + income
	state.total_fees = int(state.total_fees) + income
	var p: Dictionary = state.players[client_id]
	p["club"] = club_id
	p["contract"] = 3
	p["trust"] = clampi(int(p.trust) + 8, 0, 100)
	var c: Dictionary = state.clubs[club_id]
	c["relation"] = clampi(int(c.relation) + 5, 0, 100)
	c["budget"] = maxi(int(c.budget) - fee, 0)
	state.rep = clampi(int(state.rep) + Meta.perk_bonus("pr_machine"), 0, 100)
	return income


func tekengeld_mult() -> float:
	# Kleine lettertjes-perk: +10% tekengeld per niveau.
	return 1.0 + float(Meta.perk_bonus("tekengeld")) / 100.0


func extend_contract(client_id: String) -> int:
	var p: Dictionary = state.players[client_id]
	var tekengeld := int(value(p) * 0.02 * tekengeld_mult())
	state.money = int(state.money) + tekengeld
	state.total_fees = int(state.total_fees) + tekengeld
	p["contract"] = int(p.contract) + 2
	p["trust"] = clampi(int(p.trust) + 5, 0, 100)
	return tekengeld


# ---------------------------------------------------------------- seizoenseinde

func end_of_season() -> Array:
	var lines: Array = []
	var costs := int(BASE_COSTS * pow(COSTS_MULT, int(state.season) - 1))
	var discount := Meta.perk_bonus("kantoorkorting")
	if discount > 0:
		costs = int(costs * (1.0 - float(discount) / 100.0))
	costs = maxi(costs - Meta.perk_bonus("schuldpapier"), 0)
	state.money = int(state.money) - costs
	lines.append("Kantoorkosten: -€%d" % costs)

	var leavers: Array = []
	for cid in state.clients:
		var p: Dictionary = state.players[cid]
		var perf := rng.randi_range(1, 10)
		# Groei richting (verborgen) potentieel; vanaf 27 is de rek eruit.
		if int(p.age) <= 26 and int(p.rating) < int(p.pot):
			var growth := rng.randi_range(0, 3)
			if growth > 0:
				var oud := int(p.rating)
				p["rating"] = mini(oud + growth, int(p.pot))
				lines.append("%s ontwikkelt zich: rating %d → %d." % [p.name, oud, int(p.rating)])
		# Vertrouwen drift op basis van het seizoen (licht negatief zonder aandacht).
		var drift := rng.randi_range(-5, 5) + Meta.perk_bonus("spelersfluisteraar")
		if perf >= 8:
			drift += 3
			lines.append("%s had een topseizoen." % p.name)
		elif perf <= 3:
			drift -= 3
			lines.append("%s had een seizoen om te vergeten." % p.name)
		p["trust"] = clampi(int(p.trust) + drift, 0, 100)
		p["age"] = int(p.age) + 1
		p["contract"] = int(p.contract) - 1
		if int(p.contract) <= 0 and str(p.club) != "":
			p["contract"] = 2
			var tg := int(value(p) * 0.01 * tekengeld_mult())
			state.money = int(state.money) + tg
			state.total_fees = int(state.total_fees) + tg
			lines.append("%s verlengt bij zijn club; tekengeld €%d voor jou." % [p.name, tg])
		if Meta.perk_level("ijzeren_stal") == 0 and int(p.trust) < LEAVE_TRUST - Meta.perk_bonus("empathie") and rng.randf() < LEAVE_CHANCE:
			leavers.append(cid)
			lines.append("!! %s VERTREKT naar een andere makelaar. Het vertrouwen was op." % p.name)
		elif rng.randf() < poach_chance(p):
			# Rivaal-makelaars azen op je stal; toppers zijn extra gewild.
			var rivaal: String = RIVAL_NAMES[rng.randi_range(0, RIVAL_NAMES.size() - 1)]
			leavers.append(cid)
			lines.append("!! %s wordt WEGGEKAAPT door %s. 'Zij beloven me meer.'" % [p.name, rivaal])

	for cid in leavers:
		state.clients.erase(cid)

	state.scandal = maxi(int(state.scandal) - (3 + Meta.perk_bonus("mediatraining")), 0)

	# Oud geld-perk: rente over een positief saldo.
	var rente_pct := Meta.perk_bonus("oud_geld")
	if rente_pct > 0 and int(state.money) > 0:
		var rente := int(float(state.money) * float(rente_pct) / 100.0)
		if rente > 0:
			state.money = int(state.money) + rente
			lines.append("Rente op je vermogen: +€%d." % rente)

	# Gunstenfabriek-perk: elk 3e seizoen extra gunsten.
	var gf := Meta.perk_bonus("gunstenfabriek")
	if gf > 0 and int(state.season) % 3 == 0:
		state.favors = int(state.favors) + gf
		lines.append("Je gunstenfabriek draait: +%d gunst(en)." % gf)

	state.news = _gen_news()

	# Laatste redmiddel-perk: één keer per run wordt een tekort gedekt.
	if int(state.money) < 0 and try_bailout():
		lines.append("!! Een oude vriend dekt je tekort. 'Eén keer. Daarna sta je er alleen voor.'")

	# Fail states — in volgorde van drama.
	if int(state.money) < 0:
		state.game_over = "failliet"
	elif int(state.scandal) >= 100:
		state.game_over = "licentie"
	elif state.clients.is_empty():
		state.game_over = "leeg"
	else:
		state.season = int(state.season) + 1
	return lines


func _gen_news() -> String:
	var keys: Array = state.clubs.keys()
	match rng.randi_range(0, 3):
		0:
			var c: Dictionary = state.clubs[keys[rng.randi_range(0, keys.size() - 1)]]
			c["budget"] = int(float(c.budget) * 1.5)
			return "%s krijgt een rijke investeerder: het transferbudget gaat flink omhoog." % c.name
		1:
			var c2: Dictionary = state.clubs[keys[rng.randi_range(0, keys.size() - 1)]]
			c2["budget"] = int(float(c2.budget) * 0.7)
			return "%s zit financieel krap en moet verkopen." % c2.name
		2:
			return "Rustige zomer op de transfermarkt. Iedereen wacht op de eerste dominosteen."
		_:
			return "Een groot eindtoernooi komt eraan; spelers willen zich in de kijker spelen."


# ---------------------------------------------------------------- save/load

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return false
	state = data
	rng.randomize()
	return true


func delete_save() -> void:
	if has_save():
		var d := DirAccess.open("user://")
		if d:
			d.remove("save.json")
