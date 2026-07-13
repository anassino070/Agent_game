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
# geeft +0,01% op alle verdiende legacy points.
const INF_COST := 200
const INF_STEP := 0.0001

# De OVERPOWERED extra's: peperduur (30–50% van de boomkosten), tellen NIET
# mee voor de 100%-voortgang.
const OP_PERKS := ["superprovisie", "ijzeren_stal", "helderziend", "vaste_kern"]

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


func perk_desc(id: String, levels: int) -> String:
	# Beschrijving voor `levels` niveaus, met de juiste eenheid.
	var p: Dictionary = PERKS[id]
	if str(p.desc).find("%s") == -1:
		return str(p.desc)   # vaste tekst (de OP-perks)
	var amount: int = int(p.value) * levels
	var txt := str(amount)
	match str(p.get("fmt", "int")):
		"money":
			txt = "€%d" % amount
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
	state.legacy_points = int(state.legacy_points) + points
	state.runs_completed = int(state.runs_completed) + 1
	state.total_career_fees = int(state.total_career_fees) + total_fees
	state.best_fees = maxi(int(state.best_fees), total_fees)
	state.best_season = maxi(int(state.best_season), seasons_survived)
	save_meta()
	return points
