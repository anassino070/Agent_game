# meta.gd — Autoload "Meta".
# Persistente meta-progressie die runs overleeft (user://meta.json), los van
# Game.state (die met elke nieuwe run wordt overschreven). Elke afgeronde run
# — ook een game over — levert "legacy points" op, te besteden aan permanente
# perks die de volgende run beïnvloeden.
extends Node

const SAVE_PATH := "user://meta.json"

# Hoeveel niveaus je in een rij moet kopen om de volgende rij te ontgrendelen.
const TIER_REQ := 5

# Beloningscurve: een gewonnen run levert exact 1% van de volledige boom op;
# elk seizoen mínder overleefd deelt de beloning door REWARD_BASE.
const RUN_SEASONS := 15
const REWARD_BASE := 1.45
const WIN_REWARD_PCT := 1.0

# De ∞-upgrade: vaste (nooit stijgende) prijs, oneindig te kopen, elk niveau
# geeft +0,1% op alle verdiende legacy points.
const INF_COST := 200
const INF_STEP := 0.01

# Kampioensbonus: bij een gewonnen run krijg je BOVENOP de normale beloning
# in één klap dit percentage van je bestaande carrière-puntensaldo erbij —
# een erkenning voor een lange, succesvolle carrière, niet alleen voor deze
# ene run. Berekend over het saldo VÓÓR deze run se punten worden bijgeschreven.
const CHAMPION_BONUS_PCT := 0.12

# Ondergrens: bij een vroege winst (klein bestaand saldo) zou 12% van dat
# saldo bijna niets voorstellen naast de normale winbeloning. Daarom is de
# bonus ALTIJD minstens dit percentage van de winbeloning zelf — pas als je
# carrière-saldo groot genoeg is, wordt de 12%-over-saldo-berekening hierboven
# groter en neemt die het over.
const CHAMPION_BONUS_MIN_PCT_OF_WIN := 0.25

# De OVERPOWERED extra's: peperduur (30–50% van de boomkosten), tellen NIET
# mee voor de 100%-voortgang.
const OP_PERKS := ["superprovisie", "ijzeren_stal", "helderziend", "vaste_kern"]

# Prestige: na een gewonnen run kun je vrijwillig je hele perkboom resetten
# — GEEN puntenrefund (in tegenstelling tot reset_perks()) — in ruil voor
# 1 Prestige-ster. Sterren kopen Erfenis-perks: bonussen die je NOOIT met
# gewone legacy points kunt kopen, hoeveel je er ook opspaart. Dat is het
# hele punt van prestigen: niet "punten wegdoen", maar toegang tot iets dat
# anders onbereikbaar blijft.
const LEGACY_PERKS := {
	"kroonjuweel_netwerk": {
		"name": "Kroonjuweel-netwerk", "stars": 1,
		"desc": "Je begint elke run met een extra startcliënt.",
	},
	"kantoorvoorsprong": {
		"name": "Kantoorvoorsprong", "stars": 2,
		"desc": "Je begint elke run standaard op kantoorniveau 2 i.p.v. niveau 1.",
	},
	"eeuwige_gunst": {
		"name": "Eeuwige gunst", "stars": 3,
		"desc": "Je begint elke run met +2 extra gunsten.",
	},
}

# De perkboom: 3 takken × 4 rijen × 3 opties = 36 perks. Volledig kopen kost
# ~1,4 miljoen punten — een lange grind waarin elke run iets achterlaat.
# "fmt" bepaalt hoe de waarde in de UI verschijnt: int (default), money, pct10
# (waarde in tienden van procenten, bijv. 2 → "0,2%").
const PERKS := {
	# ---- TAK KAPITAAL, rij 1 ----
	"startkapitaal": {
		"name": "Startkapitaal", "desc": "+%s bij de start van elke run",
		"value": 1000, "fmt": "money", "max_level": 10, "base_cost": 400,
	},
	"kantoorkorting": {
		"name": "Kantoorkorting", "desc": "-%s%% kantoorkosten",
		"value": 2, "max_level": 10, "base_cost": 500,
	},
	"oud_geld": {
		"name": "Oud geld", "desc": "+%s%% rente op je saldo per seizoen",
		"value": 1, "max_level": 3, "base_cost": 3000,
	},
	# ---- TAK KAPITAAL, rij 2 ----
	"commissie": {
		"name": "Commissiekunst", "desc": "+%s fee op elke transfer",
		"value": 2, "fmt": "pct10", "max_level": 10, "base_cost": 700,
	},
	"tekengeld": {
		"name": "Kleine lettertjes", "desc": "+%s%% tekengeld bij verlengingen",
		"value": 10, "max_level": 5, "base_cost": 1600,
	},
	"gunsten": {
		"name": "Gunsteneconomie", "desc": "+%s startgunst(en)",
		"value": 1, "max_level": 3, "base_cost": 4000,
	},
	# ---- TAK KAPITAAL, rij 3 ----
	"kantoor": {
		"name": "Groter kantoor", "desc": "+%s stalplek(ken)",
		"value": 1, "max_level": 2, "base_cost": 25000,
	},
	"reserves": {
		"name": "Reserves", "desc": "+%s onderhandelronde in elk gesprek",
		"value": 1, "max_level": 1, "base_cost": 40000,
	},
	"laatste_redmiddel": {
		"name": "Laatste redmiddel", "desc": "%s× per run dekt een oude vriend je tekort (saldo naar €0)",
		"value": 1, "max_level": 1, "base_cost": 35000,
	},
	# ---- TAK KAPITAAL, rij 4 ----
	"waardestijging": {
		"name": "Waardestijging", "desc": "+%s%% marktwaarde voor al je cliënten",
		"value": 2, "max_level": 5, "base_cost": 6000,
	},
	"onderpand": {
		"name": "Onderpand", "desc": "+%s extra startkapitaal",
		"value": 5000, "fmt": "money", "max_level": 4, "base_cost": 4000,
	},
	"schuldpapier": {
		"name": "Schuldpapier", "desc": "%s vaste korting op de kantoorkosten",
		"value": 500, "fmt": "money", "max_level": 5, "base_cost": 3000,
	},
	# ---- TAK RELATIES, rij 1 ----
	"netwerk": {
		"name": "Netwerk", "desc": "+%s startreputatie",
		"value": 1, "max_level": 10, "base_cost": 400,
	},
	"babbel": {
		"name": "Vlotte babbel", "desc": "+%s%% tekenkans bij het benaderen van spelers",
		"value": 1, "max_level": 10, "base_cost": 450,
	},
	"vertrouwenspersoon": {
		"name": "Vertrouwenspersoon", "desc": "+%s startvertrouwen bij nieuwe cliënten",
		"value": 2, "max_level": 5, "base_cost": 900,
	},
	# ---- TAK RELATIES, rij 2 ----
	"binding": {
		"name": "Bindingskracht", "desc": "-%s%% kans dat rivalen je cliënten wegkapen",
		"value": 1, "max_level": 10, "base_cost": 600,
	},
	"mediatraining": {
		"name": "Mediatraining", "desc": "+%s extra schandaalverval per seizoen",
		"value": 1, "max_level": 3, "base_cost": 3500,
	},
	"pr_machine": {
		"name": "PR-machine", "desc": "+%s reputatie bij elke afgeronde transfer",
		"value": 1, "max_level": 3, "base_cost": 3000,
	},
	# ---- TAK RELATIES, rij 3 ----
	"talentmagneet": {
		"name": "Talentmagneet", "desc": "+%s op je rating-plafond voor jonge spelers",
		"value": 2, "max_level": 5, "base_cost": 4000,
	},
	"grote_naam": {
		"name": "Grote naam", "desc": "+%s op je rating-plafond voor gevestigde spelers",
		"value": 2, "max_level": 5, "base_cost": 4000,
	},
	"gunstenfabriek": {
		"name": "Gunstenfabriek", "desc": "+%s gunst(en) elk 3e seizoen",
		"value": 1, "max_level": 2, "base_cost": 15000,
	},
	# ---- TAK RELATIES, rij 4 ----
	"iconenstatus": {
		"name": "Iconenstatus", "desc": "+%s extra startreputatie",
		"value": 3, "max_level": 5, "base_cost": 5000,
	},
	"spelersfluisteraar": {
		"name": "Spelersfluisteraar", "desc": "+%s vertrouwen voor ál je cliënten, elk seizoen",
		"value": 1, "max_level": 3, "base_cost": 7000,
	},
	"empathie": {
		"name": "Empathie", "desc": "cliënten overwegen pas vertrek onder vertrouwen %s lager",
		"value": 2, "max_level": 5, "base_cost": 4000,
	},
	# ---- TAK VAKWERK, rij 1 ----
	"onderhandelen": {
		"name": "Onderhandelaar", "desc": "+%s%% slagingskans op onderhandeltactieken",
		"value": 1, "max_level": 10, "base_cost": 450,
	},
	"talentenoog": {
		"name": "Talentenoog", "desc": "scouten verlaagt de onzekerheid %s extra",
		"value": 1, "max_level": 3, "base_cost": 2500,
	},
	"flow_meester": {
		"name": "Flowmeester", "desc": "+%s%% extra flow-effect (bovenop de +50%%)",
		"value": 5, "max_level": 4, "base_cost": 1800,
	},
	# ---- TAK VAKWERK, rij 2 ----
	"stalen_zenuwen": {
		"name": "Stalen zenuwen", "desc": "-%s%% kans dat een TD wegloopt",
		"value": 20, "max_level": 3, "base_cost": 3000,
	},
	"clausulemeester": {
		"name": "Clausulemeester", "desc": "clausules kosten %s minder fee",
		"value": 5, "fmt": "pct10", "max_level": 2, "base_cost": 5000,
	},
	"scouting": {
		"name": "Scoutingdienst", "desc": "+%s extra scoutpunt per seizoen",
		"value": 1, "max_level": 2, "base_cost": 12000,
	},
	# ---- TAK VAKWERK, rij 3 ----
	"dossierkennis": {
		"name": "Dossierkennis", "desc": "aftasten kost %s ronde minder",
		"value": 1, "max_level": 1, "base_cost": 30000,
	},
	"extra_kandidaat": {
		"name": "Breed netwerk", "desc": "+%s extra kandidaat in elke scoutinglijst",
		"value": 1, "max_level": 2, "base_cost": 12000,
	},
	"crisismanagement": {
		"name": "Crisismanagement", "desc": "schandaal-stijgingen %s lager (minimaal 1)",
		"value": 1, "max_level": 3, "base_cost": 5000,
	},
	# ---- TAK VAKWERK, rij 4 ----
	"koelbloedig": {
		"name": "Koelbloedig", "desc": "+%s%% slagingskans op bluffen",
		"value": 2, "max_level": 5, "base_cost": 5000,
	},
	"voorwerk": {
		"name": "Voorwerk", "desc": "TD's starten met %s minder weerstand",
		"value": 1, "max_level": 5, "base_cost": 5000,
	},
	"geluksvogel": {
		"name": "Geluksvogel", "desc": "+%s%% slagingskans op alle kans-opties bij events",
		"value": 2, "max_level": 5, "base_cost": 5000,
	},
	# ---- OVERPOWERED extra's (buiten de boom; tellen niet mee voor 100%) ----
	"superprovisie": {
		"name": "★ Superprovisie", "desc": "alle transfer-inkomsten tellen dubbel",
		"value": 1, "max_level": 1, "base_cost": 417000,
	},
	"ijzeren_stal": {
		"name": "★ IJzeren contracten", "desc": "cliënten vertrekken nooit meer en kunnen niet worden weggekaapt",
		"value": 1, "max_level": 1, "base_cost": 417000,
	},
	"helderziend": {
		"name": "★ Helderziend", "desc": "alle TD-persoonlijkheden zijn direct bekend en elk gesprek start Ontvankelijk",
		"value": 1, "max_level": 1, "base_cost": 417000,
	},
	"vaste_kern": {
		"name": "★ Vaste kern", "desc": "je bent de uitzondering op de regel: nooit meer verplicht een cliënt wegsturen",
		"value": 1, "max_level": 1, "base_cost": 250000,
	},
}

# De boom: 3 takken, elk 3 rijen met 3 opties. Rij 2/3 ontgrendelen zodra je
# TIER_REQ niveaus in de rij erboven hebt gekocht (binnen dezelfde tak).
const TREE := [
	{"name": "KAPITAAL", "tiers": [
		["startkapitaal", "kantoorkorting", "oud_geld"],
		["commissie", "tekengeld", "gunsten"],
		["kantoor", "reserves", "laatste_redmiddel"],
		["waardestijging", "onderpand", "schuldpapier"],
	]},
	{"name": "RELATIES", "tiers": [
		["netwerk", "babbel", "vertrouwenspersoon"],
		["binding", "mediatraining", "pr_machine"],
		["talentmagneet", "grote_naam", "gunstenfabriek"],
		["iconenstatus", "spelersfluisteraar", "empathie"],
	]},
	{"name": "VAKWERK", "tiers": [
		["onderhandelen", "talentenoog", "flow_meester"],
		["stalen_zenuwen", "clausulemeester", "scouting"],
		["dossierkennis", "extra_kandidaat", "crisismanagement"],
		["koelbloedig", "voorwerk", "geluksvogel"],
	]},
]

var state: Dictionary = {}


func _ready() -> void:
	load_meta()


func load_meta() -> void:
	state = {}
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if typeof(data) == TYPE_DICTIONARY:
				state = data
	if not state.has("legacy_points"):
		state = {
			"legacy_points": 0,
			"runs_completed": 0,
			"best_fees": 0,
			"best_season": 0,
			"total_career_fees": 0,
			"perks": {},
		}
	if not state.has("perks"):
		state.perks = {}
	for id in PERKS:
		if not state.perks.has(id):
			state.perks[id] = 0
	if not state.has("prestige_stars"):
		state.prestige_stars = 0
	if not state.has("legacy_perks"):
		state.legacy_perks = {}
	for id in LEGACY_PERKS:
		if not state.legacy_perks.has(id):
			state.legacy_perks[id] = false
	if not state.has("hall_of_fame"):
		state.hall_of_fame = []
	if not state.has("has_won_ever"):
		state.has_won_ever = false


# UI-hulpvar: hoeveel van de laatst toegekende punten kampioensbonus was
# (0 als de laatste run geen winst was). Analoog aan Game.last_new_client_id
# — een aparte "wat gebeurde er net"-var i.p.v. de return-waarde te belasten.
var last_champion_bonus := 0


func save_meta() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))


func perk_level(id: String) -> int:
	return int(state.perks.get(id, 0))


func perk_bonus(id: String) -> int:
	return perk_level(id) * int(PERKS[id].value)


func perk_cost(id: String) -> int:
	var lvl := perk_level(id)
	return int(PERKS[id].base_cost) * (lvl + 1)


func _fmt_thousands(n: int) -> String:
	# Zelfde duizendtal-notatie als main.gd's eur(), zonder valutateken.
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-" + out) if n < 0 else out


func perk_desc(id: String, levels: int) -> String:
	# Beschrijving voor `levels` niveaus, met de juiste eenheid.
	var p: Dictionary = PERKS[id]
	if str(p.desc).find("%s") == -1:
		return str(p.desc)   # vaste tekst (de OP-perks)
	var amount: int = int(p.value) * levels
	var txt := str(amount)
	match str(p.get("fmt", "int")):
		"money":
			txt = "€%s" % _fmt_thousands(amount)
		"pct10":
			txt = ("%.1f%%" % (float(amount) / 10.0)).replace(".", ",")
	return str(p.desc) % txt


func tier_levels(branch: Dictionary, tier_idx: int) -> int:
	# Totaal gekochte niveaus in één rij van een tak.
	var total := 0
	for id in branch.tiers[tier_idx]:
		total += perk_level(str(id))
	return total


func tier_unlocked(branch: Dictionary, tier_idx: int) -> bool:
	if tier_idx == 0:
		return true
	return tier_levels(branch, tier_idx - 1) >= TIER_REQ


func is_unlocked(id: String) -> bool:
	for branch in TREE:
		for tier_idx in range(branch.tiers.size()):
			if id in branch.tiers[tier_idx]:
				return tier_unlocked(branch, tier_idx)
	return true


func can_buy(id: String) -> bool:
	if not is_unlocked(id):
		return false
	var lvl := perk_level(id)
	if lvl >= int(PERKS[id].max_level):
		return false
	return int(state.legacy_points) >= perk_cost(id)


func buy_perk(id: String) -> bool:
	if not can_buy(id):
		return false
	state.legacy_points = int(state.legacy_points) - perk_cost(id)
	state.perks[id] = perk_level(id) + 1
	save_meta()
	return true


func spent_points() -> int:
	# Wat alle gekochte niveaus samen hebben gekost (voor de reset-refund).
	var total := 0
	for id in PERKS:
		var lvl := perk_level(id)
		total += int(PERKS[id].base_cost) * lvl * (lvl + 1) / 2
	return total


func full_perk_cost(id: String) -> int:
	var m := int(PERKS[id].max_level)
	return int(PERKS[id].base_cost) * m * (m + 1) / 2


func tree_total_cost() -> int:
	# Totale kosten van de reguliere boom (zonder de OP-extra's) = de 100%.
	var total := 0
	for id in PERKS:
		if id in OP_PERKS:
			continue
		total += full_perk_cost(id)
	return total


func tree_spent() -> int:
	var total := 0
	for id in PERKS:
		if id in OP_PERKS:
			continue
		var lvl := perk_level(id)
		total += int(PERKS[id].base_cost) * lvl * (lvl + 1) / 2
	return total


func tree_progress() -> float:
	return float(tree_spent()) / float(tree_total_cost())


func reset_perks() -> void:
	# Zet alle perks terug naar 0 en geef de bestede punten volledig terug.
	# De ∞-upgrade blijft staan; die is statisch en los van de boom.
	state.legacy_points = int(state.legacy_points) + spent_points()
	for id in PERKS:
		state.perks[id] = 0
	save_meta()


# ---- Prestige & Erfenis-perks ----

const PRESTIGE_MIN_TREE_PROGRESS := 0.5   # minstens 50% van de boom nodig om te mogen prestigen


func can_prestige() -> bool:
	# Prestigen offert je hele boom op — dat moet ook echt iets voorstellen.
	# Bij een paar losse niveaus is de "opoffering" bijna gratis, dus eisen we
	# minstens 50% voortgang op de reguliere boom (tree_progress(), exclusief
	# de OP-extra's) voordat de knop beschikbaar wordt.
	return tree_progress() >= PRESTIGE_MIN_TREE_PROGRESS


func prestige_run() -> void:
	# In tegenstelling tot reset_perks(): GEEN puntenrefund. De prijs van een
	# Prestige-ster is je opgebouwde perkboom, niet iets gratis.
	for id in PERKS:
		state.perks[id] = 0
	state.prestige_stars = int(state.prestige_stars) + 1
	save_meta()


func has_legacy_perk(id: String) -> bool:
	return bool(state.legacy_perks.get(id, false))


func can_buy_legacy_perk(id: String) -> bool:
	if has_legacy_perk(id):
		return false
	return int(state.prestige_stars) >= int(LEGACY_PERKS[id].stars)


func buy_legacy_perk(id: String) -> bool:
	if not can_buy_legacy_perk(id):
		return false
	state.prestige_stars = int(state.prestige_stars) - int(LEGACY_PERKS[id].stars)
	state.legacy_perks[id] = true
	save_meta()
	return true


func spent_stars() -> int:
	# Sterren die in gekochte Erfenis-perks vastzitten (voor de reset-refund).
	var total := 0
	for id in LEGACY_PERKS:
		if has_legacy_perk(id):
			total += int(LEGACY_PERKS[id].stars)
	return total


func reset_legacy_perks() -> void:
	# Erfenis-perks zijn bewust permanent zolang je ze niet zelf terugdraait
	# — maar zonder ENIGE reset-optie zit een speler vast aan een vroege
	# keuze. Net als reset_perks(): volledige refund van de sterren, zodat
	# herspeccen mogelijk is zonder dat het een straf wordt.
	state.prestige_stars = int(state.prestige_stars) + spent_stars()
	for id in LEGACY_PERKS:
		state.legacy_perks[id] = false
	save_meta()


# ---- Hall of Fame (puur cosmetisch, geen mechanisch effect) ----

const HALL_OF_FAME_MAX := 10


func record_win(client_name: String, total_fees: int, seasons: int) -> void:
	state.hall_of_fame.append({
		"client_name": client_name, "total_fees": total_fees, "seasons": seasons,
	})
	state.hall_of_fame.sort_custom(func(a, b): return int(a.total_fees) > int(b.total_fees))
	if state.hall_of_fame.size() > HALL_OF_FAME_MAX:
		state.hall_of_fame = state.hall_of_fame.slice(0, HALL_OF_FAME_MAX)
	# Ontgrendelt voorgoed het geheime 6e kantoorniveau (zie Game.office_max_level()).
	state.has_won_ever = true
	save_meta()


# ---- De ∞-upgrade (statisch, oneindig, vaste prijs) ----

func inf_level() -> int:
	return int(state.get("inf_level", 0))


func inf_multiplier() -> float:
	return 1.0 + float(inf_level()) * INF_STEP


func buy_inf() -> bool:
	if int(state.legacy_points) < INF_COST:
		return false
	state.legacy_points = int(state.legacy_points) - INF_COST
	state["inf_level"] = inf_level() + 1
	save_meta()
	return true


func dev_wipe_points() -> void:
	# Developer-only: wist alleen het puntensaldo (niet de gekochte perks).
	state.legacy_points = 0
	save_meta()


func dev_toggle_won_ever() -> void:
	# Developer-only: schakelt het geheime 6e kantoorniveau (De Kampioenssuite)
	# handmatig aan/uit, zodat je 'm kunt testen zonder een volledige 15-
	# seizoenen-run te winnen.
	state.has_won_ever = not bool(state.get("has_won_ever", false))
	save_meta()


# Beloning na afloop van een run (game over of gewonnen). Exponentiële
# curve: elk seizoen verder vermenigvuldigt de beloning met REWARD_BASE,
# met als plafond precies WIN_REWARD_PCT% van de volledige boom voor een
# gewonnen run. Werkt de career-stats bij en geeft het aantal verdiende
# punten terug.
func award_run(total_fees: int, seasons_survived: int, won: bool) -> int:
	var full := float(tree_total_cost()) * (WIN_REWARD_PCT / 100.0)
	var points: int
	if won:
		points = int(round(full))
	else:
		points = maxi(int(round(full * pow(REWARD_BASE, float(seasons_survived - RUN_SEASONS)))), 10)
	# De ∞-upgrade vermenigvuldigt alles wat binnenkomt.
	points = int(round(float(points) * inf_multiplier()))
	# Kampioensbonus: alleen bij winst, in één klap CHAMPION_BONUS_PCT van je
	# bestaande carrière-saldo erbij — berekend VÓÓR deze run se punten worden
	# bijgeschreven, zodat het een bonus op je carrière is, niet op jezelf.
	# Met een minimum van CHAMPION_BONUS_MIN_PCT_OF_WIN van de winbeloning
	# zelf, zodat ook een vroege winst (nog weinig carrière-saldo) een
	# merkbare bonus geeft — pas bij een groot saldo neemt de 12%-berekening
	# het vanzelf over.
	if won:
		var bonus_over_saldo := int(round(float(state.legacy_points) * CHAMPION_BONUS_PCT))
		var bonus_min := int(round(float(points) * CHAMPION_BONUS_MIN_PCT_OF_WIN))
		last_champion_bonus = maxi(bonus_over_saldo, bonus_min)
	else:
		last_champion_bonus = 0
	state.legacy_points = int(state.legacy_points) + points + last_champion_bonus
	state.runs_completed = int(state.runs_completed) + 1
	state.total_career_fees = int(state.total_career_fees) + total_fees
	state.best_fees = maxi(int(state.best_fees), total_fees)
	state.best_season = maxi(int(state.best_season), seasons_survived)
	# Mega-boost: een winst zet een eenmalige vlag die je ALLEEN in je
	# eerstvolgende nieuwe run een klapper geeft (zie Game.new_run()) — geen
	# permanente perk, puur momentum voor de volgende poging.
	if won:
		state.pending_boost = true
	save_meta()
	return points + last_champion_bonus


func has_pending_boost() -> bool:
	return bool(state.get("pending_boost", false))


func consume_pending_boost() -> bool:
	# Geeft true terug (en wist de vlag meteen) als er een mega-boost
	# klaarstond. Aangeroepen door Game.new_run() bij het opzetten van een
	# nieuwe run — verbruikt zich dus vanzelf, ongeacht hoe die run afloopt.
	var had := has_pending_boost()
	if had:
		state.pending_boost = false
		save_meta()
	return had
