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
# Was 1.8. De nieuwe transferwaarde-curve (zie VALUE_ANCHORS) maakt de hogere
# kantoorniveaus 2,7×-7,2× rijker dan voorheen — zonder compensatie zou de
# late game daardoor JUIST makkelijker worden, het omgekeerde van de bedoeling.
# 1,95 houdt de vroege seizoenen (kleine bedragen) bijna ongemoeid maar maakt
# seizoen 15 ongeveer 3× duurder (~€115mln i.p.v. ~€37,5mln), wat de extra
# fee-macht op de hogere niveaus grotendeels neutraliseert.
const COSTS_MULT := 1.95      # kosten vermenigvuldigen elk seizoen met deze factor
const FEE_CUT := 0.10         # standaard fee-percentage

# Vertrekkans is een DOORLOPENDE curve i.p.v. een harde knip bij één
# drempel — anders maakt elk punt vertrouwen bóven of onder die ene grens
# he-le-maal niets uit, en dat is precies waarom vertrouwen weinig impact
# voelde. Onder LEAVE_SAFE_TRUST loopt het risico lineair op.
const LEAVE_SAFE_TRUST := 60.0
const LEAVE_SLOPE := 0.016
const LEAVE_CHANCE_MAX := 0.85

# Schandaal deed tot nu toe NIETS tussen 0 en 99 — alleen bij exact 100 verlies
# je je licentie. Dat maakt het een binaire val i.p.v. een voelbare stat: een
# makelaar op schandaal 70 merkte er niets van totdat de teller toevallig
# verder opliep. Twee drempels geven schandaal continue, oplopende gevolgen
# (lineair van 0 bij de drempel tot het max-effect bij 100), zodat een hoog
# schandaal al vóór de 100-grens pijn doet.
const SCANDAL_TIER1 := 40.0   # "onder een vergrootglas": lagere tekenkans
const SCANDAL_TIER2 := 70.0   # "reputatie in vrije val": hogere kaapkans, minder clubinteresse
const SCANDAL_TIER1_MAX_PENALTY := 0.20   # tekenkans tot -20% bij schandaal 100
const SCANDAL_TIER2_MAX_POACH := 0.20     # kaapkans tot +20% bij schandaal 100
const SCANDAL_TIER2_MAX_INTEREST_PENALTY := 0.5   # clubinteresse-kans tot -50% bij schandaal 100


func _scandal_tier_factor(tier: float) -> float:
	# 0.0 onder de drempel, oplopend naar 1.0 bij schandaal 100.
	if float(state.scandal) < tier:
		return 0.0
	return (float(state.scandal) - tier) / (100.0 - tier)


func scandal_signing_penalty() -> float:
	return SCANDAL_TIER1_MAX_PENALTY * _scandal_tier_factor(SCANDAL_TIER1)


func scandal_poach_bonus() -> float:
	return SCANDAL_TIER2_MAX_POACH * _scandal_tier_factor(SCANDAL_TIER2)


func scandal_interest_mult() -> float:
	# Multiplier (niet een af te trekken percentage) — makkelijker te
	# combineren met de bestaande budget-penalty (×0,5) in gen_interest().
	return 1.0 - SCANDAL_TIER2_MAX_INTEREST_PENALTY * _scandal_tier_factor(SCANDAL_TIER2)

# Reputatie/vertrouwen zijn te makkelijk te winnen: positieve mutaties tellen
# maar voor een deel, negatieve tellen volledig — netto duw je dus actief
# moeite in moeten blijven steken i.p.v. eenmalig naar 100 te groeien en daar
# te blijven hangen.
const REP_GAIN_MULT := 0.6
const TRUST_GAIN_MULT := 0.6          # basisdemping op positief vertrouwen in seizoen 1
const TRUST_GAIN_PER_SEASON := 0.09   # …en die demping loopt elk seizoen terug (= meer gewicht)
const TRUST_GAIN_MAX := 1.6           # plafond zodat het niet ontspoort
const REP_DECAY_ABOVE_BASELINE := 3   # rep zakt licht terug richting 50 als je stilzit
const REP_BASELINE := 50
const RIVAL_NAMES := ["Bureau Marchetti", "Star XI Management", "Agentschap De Wolf", "GoalGetters Int."]

var rng := RandomNumberGenerator.new()
var state: Dictionary = {}
# UI-hulpvar: pid van de speler die de laatste apply_effects()-aanroep erbij
# heeft geworven (new_client/new_top_client), leeg als dat niet gebeurde.
# Zo kan main.gd na afloop het infopaneel op de NIEUWE cliënt richten i.p.v.
# alleen de kale naam in een meldingsregel te tonen.
var last_new_client_id := ""


# Duizendtal-scheiding voor getallen in de eind-van-seizoen-meldingsregels
# (`lines.append(...)` in end_of_season()) — deze teksten worden ongewijzigd
# door main.gd getoond, dus de opmaak moet hier al kloppen. Zelfde notatie
# als main.gd's eur(), maar zonder valutateken (voor gebruik ná een "€").
func fmt_thousands(n) -> String:
	var v := int(n)
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-" + out) if v < 0 else out


# ---------------------------------------------------------------- run setup

# Mega-boost (eenmalig verbruikt): een gewonnen run zet Meta's pending_boost-
# vlag, die precies deze ene keer een klapper geeft aan de allereerstvolgende
# nieuwe run — dubbel startkapitaal, flink meer startreputatie, een extra
# gunst en twee extra scoutpunten. Geen permanente perk: puur momentum.
const BOOST_MONEY_MULT := 2.0
const BOOST_REP_BONUS := 25
const BOOST_FAVORS_BONUS := 1
const BOOST_SCOUT_POINTS_BONUS := 2


func new_run() -> void:
	rng.randomize()
	var world: Dictionary = WorldGen.generate(rng)
	var boost := Meta.consume_pending_boost()
	var base_money := START_MONEY
	if boost:
		base_money = int(round(float(base_money) * BOOST_MONEY_MULT))
	state = {
		"season": 1,
		"money": base_money + Meta.perk_bonus("startkapitaal") + Meta.perk_bonus("onderpand"),
		"rep": maxi(50 + (BOOST_REP_BONUS if boost else 0) + Meta.perk_bonus("netwerk") + Meta.perk_bonus("iconenstatus"), 0),
		"scandal": 0,
		"favors": 1 + (BOOST_FAVORS_BONUS if boost else 0) + (2 if Meta.has_legacy_perk("eeuwige_gunst") else 0) + Meta.perk_bonus("gunsten"),
		"scout_points": scout_points_per_season() + (BOOST_SCOUT_POINTS_BONUS if boost else 0),
		"players": world.players,
		"clubs": world.clubs,
		"clients": [],
		"news": "Je opent je kantoor met een enorme boost in de rug — je vorige triomf gonst nog na." if boost else "Je opent je kantoor boven een snackbar. Nog niemand gelooft in je — dat bewijs je zelf, deze eerste scoutingronde.",
		"used_events": [],
		"total_fees": 0,
		"game_over": "",
		"meta_awarded": false,
		"bank_deposits": [],   # [{"amount": int, "seasons_left": int}] — De Bank
		"shop_owned": [],      # ids uit SHOP_UPGRADES die je deze run al kocht
		"noodfonds_used": false,
		# Erfenis-perk "Kantoorvoorsprong": start op niveau 2 i.p.v. 1.
		"office_level": 2 if Meta.has_legacy_perk("kantoorvoorsprong") else 1,
		"candidate_ids": [],   # pids van de verse scoutingkandidaten dit seizoen
		"candidate_counter": 0, # oplopende teller voor unieke kandidaat-pids
		"bonus_scout_points": 0, # permanente scoutpunten-bonus uit events (scout_points_permanent)
	}
	# Geen startcliënt meer: je begint met een lege stal, en moet in de eerste
	# scoutingronde zelf je eerste cliënt werven — een bewust moeilijker begin
	# (met 0 of 1 cliënten slaat het verplichte-ontslag-scherm gewoon over,
	# en de "lege stal"-fail-check triggert pas aan het EINDE van seizoen 1,
	# dus je hebt de hele eerste ronde de tijd).
	# Erfenis-perk "Kroonjuweel-netwerk": start toch met één cliënt.
	if Meta.has_legacy_perk("kroonjuweel_netwerk"):
		var pool: Array = []
		for pid in state.players:
			var p: Dictionary = state.players[pid]
			if int(p.age) <= 21 and int(p.rating) >= 52 and int(p.rating) <= 62:
				pool.append(pid)
		if pool.is_empty():
			pool = state.players.keys()
		if not pool.is_empty():
			var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
			_make_client(pick, 65)


func _make_client(pid: String, trust: int) -> void:
	state.players[pid]["trust"] = clampi(trust + Meta.perk_bonus("vertrouwenspersoon"), 0, 100)
	state.players[pid]["client_since"] = int(state.season)
	state.clients.append(pid)


# ---------------------------------------------------------------- de bank
# Stort geld weg; na 3 seizoenen krijg je het verdubbeld terug. Een simpel,
# gegarandeerd spaarmiddel tegenover de exponentieel stijgende kosten — de
# prijs is dat het geld 3 seizoenen lang vaststaat en dus niet inzetbaar is
# (was 2 — iets trager compound-sparen, in lijn met een moeilijker begin).

const BANK_MATURITY_SEASONS := 3
const BANK_MULTIPLIER := 2.0

# Voorbereide transfer (event 'clubarts_geheim'): 65% kans dat de insider-
# info klopt en de mysterieuze koper toehapt; als het lukt betaalt hij 80%
# van de reguliere marktwaarde (een snelle, schimmige deal onder de prijs).
const PREPARED_TRANSFER_CHANCE := 0.65
const PREPARED_TRANSFER_VALUE_PCT := 0.80

# Clubbudgetten groeien dit percentage per seizoen (tv-gelden/sponsoring),
# zodat ze de stijgende spelerswaarde (rating-ontwikkeling × value()) kunnen
# bijbenen. Zonder groei bevriezen budgetten op hun seizoen-1-waarde terwijl
# spelers duurder worden — met een harde muur van "nul interesse" tot gevolg.
# Was 0,12: de nieuwe VALUE_ANCHORS-curve maakt de top (niveau 5-6) 2,8×-7,2×
# duurder dan voorheen — zonder deze verhoging zouden zelfs de rijkste clubs
# (ambitie 5) tegen seizoen 15 nooit meer dan ~16mln kunnen ophoesten, ver
# onder de nieuwe €54mln-gemiddelde op het topniveau. Bij 0,20 komt de
# rijkste club op ~€77mln uit — genoeg om ook de duurste toppers te kopen.
const CLUB_BUDGET_GROWTH := 0.20


func bank_deposit(amount: int) -> bool:
	if amount <= 0 or amount > int(state.money):
		return false
	if not state.has("bank_deposits"):
		state.bank_deposits = []
	state.money = int(state.money) - amount
	state.bank_deposits.append({"amount": amount, "seasons_left": BANK_MATURITY_SEASONS})
	return true


func bank_deposit_count() -> int:
	return state.get("bank_deposits", []).size()


func bank_deposits_list() -> Array:
	# Elke storting blijft een los item met zijn eigen resterende termijn —
	# gebruikt door de UI om ze apart te tonen (nooit samengevoegd).
	return state.get("bank_deposits", [])


# ---------------------------------------------------------------- de shop
# 24 eenmalige upgrades voor déze run (géén legacy-perks — die verdwijnen
# aan het einde van de run net als de rest van Game.state). Elk seizoen na
# de afsluiting kies je uit 3 willekeurige, nog niet gekochte upgrades (of reroll).
# Prijzen schalen mee met shop_money_scale() (een MILDE, eigen groeivoet —
# zie die functie) zodat ze de hele run relevant én betaalbaar blijven, in
# plaats van in de tweede seizoenshelft onbetaalbaar te worden zoals bij de
# harde event_money_scale()-curve. Fors duurder dan de oorspronkelijke 10
# (en met 14 extra opties) zodat je tegen het einde van de run niet allang
# alles hebt kunnen kopen.
const SHOP_UPGRADES := {
	"groter_kantoor": {
		"name": "Groter kantoor", "price": 36000,
		"desc": "+1 stalplek voor de rest van deze run.",
	},
	"pr_bureau": {
		"name": "PR-bureau", "price": 28000,
		"desc": "+2 extra schandaalverval per seizoen, de rest van de run.",
	},
	"jeugdscout": {
		"name": "Eigen jeugdscout", "price": 42000,
		"desc": "+1 scoutpunt per seizoen, de rest van de run.",
	},
	"juridisch_adviseur": {
		"name": "Juridisch adviseur", "price": 32000,
		"desc": "Schandaal-stijgingen 1 lager (minimaal 1), de rest van de run.",
	},
	"mediatrainer_stal": {
		"name": "Media-trainer voor je stal", "price": 24000,
		"desc": "Eenmalig: +15 vertrouwen bij al je huidige cliënten.",
	},
	"netwerkdiner": {
		"name": "Netwerkdiner-abonnement", "price": 46000,
		"desc": "+1 gunst per seizoen, de rest van de run.",
	},
	"kantoorrenovatie": {
		"name": "Kantoorrenovatie", "price": 38000,
		"desc": "Eenmalig +8 reputatie, plus +3 op je scouting-plafond voor de rest van de run.",
	},
	"data_analytics": {
		"name": "Data-analytics abonnement", "price": 38000,
		"desc": "Effect van 1 scoutpunt verdubbelt, de rest van de run.",
	},
	"noodfonds": {
		"name": "Noodfonds (lifeline)", "price": 52000,
		"desc": "Eén keer per run: kom je onder €0, dan reset je saldo naar €0 en ga je door.",
	},
	"onderhandelcoach": {
		"name": "Onderhandelaar-coach", "price": 34000,
		"desc": "+3% slagingskans op alle onderhandeltactieken, de rest van de run.",
	},
	"veiligheidsnet": {
		"name": "Veiligheidsnet", "price": 34000,
		"desc": "Rivalen kapen 5 procentpunt minder vaak een cliënt weg (lagere kaapkans), de rest van de run.",
	},
	"psycholoog": {
		"name": "Sportpsycholoog", "price": 30000,
		"desc": "Vertrekkans van je cliënten daalt (alsof hun vertrouwen 8 hoger is), de rest van de run.",
	},
	"belastingadviseur": {
		"name": "Fiscalist", "price": 36000,
		"desc": "+2% fee-percentage op elke transfer, de rest van de run.",
	},
	"breed_scoutingnetwerk": {
		"name": "Breed scoutingnetwerk", "price": 34000,
		"desc": "+4 op je scouting-plafond: betere spelers binnen bereik, de rest van de run.",
	},
	"pr_strategie": {
		"name": "Reputatiebeheerder", "price": 34000,
		"desc": "Je reputatie zakt niet meer vanzelf terug richting 50 (normaal -3/seizoen als je erboven zit), de rest van de run.",
	},
	"investeringsfonds": {
		"name": "Investeringsfonds", "price": 30000,
		"desc": "De Bank keert 2,3× uit i.p.v. 2× op elke storting, de rest van de run.",
	},
	"clubcontacten": {
		"name": "Clubcontactenboek", "price": 40000,
		"desc": "Clubbudgetten groeien +17%/seizoen i.p.v. +12% (meer clubs kunnen je spelers betalen), de rest van de run.",
	},
	"risicomanager": {
		"name": "Risicomanager", "price": 30000,
		"desc": "Schandaal kan niet meer boven de 80 uitkomen, de rest van de run.",
	},
	"contractenspecialist": {
		"name": "Contractenspecialist", "price": 32000,
		"desc": "+30% tekengeld bij elke contractverlenging, de rest van de run.",
	},
	"nog_groter_kantoor": {
		"name": "Nog groter kantoor", "price": 44000,
		"desc": "Nog eens +1 stalplek voor de rest van deze run (stapelt met Groter kantoor).",
	},
	"scoutingbudget": {
		"name": "Extra scoutingbudget", "price": 22000,
		"desc": "Eenmalig: +3 scoutpunten.",
	},
	"pr_campagne": {
		"name": "PR-campagne", "price": 24000,
		"desc": "Eenmalig: +10 reputatie.",
	},
	"clubarts_netwerk": {
		"name": "Clubarts-netwerk", "price": 26000,
		"desc": "Eenmalig: -15 schandaal.",
	},
	"vip_netwerk": {
		"name": "VIP-netwerkclub", "price": 24000,
		"desc": "Eenmalig: +2 gunsten.",
	},
}


func shop_owned() -> Array:
	return state.get("shop_owned", [])


func has_shop(id: String) -> bool:
	return id in shop_owned()


# Generieke korting op alle shop-prijzen (0,55 = 45% goedkoper dan de
# basisprijzen in SHOP_UPGRADES). Eén knop om de hele shop-economie te tunen.
const SHOP_PRICE_MULT := 0.9


func shop_price(id: String) -> int:
	return int(round(float(SHOP_UPGRADES[id].price) * SHOP_PRICE_MULT * shop_money_scale()))


func can_buy_shop(id: String) -> bool:
	if has_shop(id):
		return false
	return int(state.money) >= shop_price(id)


func buy_shop_upgrade(id: String) -> bool:
	if not can_buy_shop(id):
		return false
	state.money = int(state.money) - shop_price(id)
	if not state.has("shop_owned"):
		state.shop_owned = []
	state.shop_owned.append(id)
	match id:
		"mediatrainer_stal":
			for cid in state.clients:
				var p: Dictionary = state.players[cid]
				p["trust"] = clampi(int(p.trust) + 15, 0, 100)
		"kantoorrenovatie":
			state.rep = maxi(int(state.rep) + 8, 0)
		"scoutingbudget":
			state.scout_points = int(state.scout_points) + 3
		"pr_campagne":
			state.rep = maxi(int(state.rep) + 10, 0)
		"clubarts_netwerk":
			state.scandal = maxi(int(state.scandal) - 15, 0)
		"vip_netwerk":
			state.favors = int(state.favors) + 2
	return true


func shop_offer(rng_src: RandomNumberGenerator, count: int = 3, exclude: Array = []) -> Array:
	# Trekt `count` willekeurige, nog niet gekochte upgrades. `exclude` houdt de
	# vorige aanbieding buiten de trekking (voor de reroll) zolang er genoeg
	# andere overblijven — anders vult hij aan met de uitgesloten ids.
	var pool: Array = []
	for id in SHOP_UPGRADES:
		if not has_shop(id) and not (id in exclude):
			pool.append(id)
	var fallback: Array = []
	for id in exclude:
		if not has_shop(id):
			fallback.append(id)
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var i := rng_src.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	# Te weinig verse upgrades over? Vul aan met de zojuist uitgesloten set.
	while out.size() < count and not fallback.is_empty():
		var i := rng_src.randi_range(0, fallback.size() - 1)
		out.append(fallback[i])
		fallback.remove_at(i)
	return out


# Reroll: tegen betaling een nieuwe set upgrades in de shop.
const SHOP_REROLL_BASE := 8000


func shop_reroll_cost() -> int:
	return int(round(float(SHOP_REROLL_BASE) * shop_money_scale()))


func can_reroll_shop() -> bool:
	return int(state.money) >= shop_reroll_cost()


func pay_shop_reroll() -> bool:
	if not can_reroll_shop():
		return false
	state.money = int(state.money) - shop_reroll_cost()
	return true


func try_shop_bailout() -> bool:
	# Noodfonds-upgrade: dekt één keer per run een negatief saldo.
	if int(state.money) >= 0:
		return false
	if not has_shop("noodfonds"):
		return false
	if bool(state.get("noodfonds_used", false)):
		return false
	state.noodfonds_used = true
	state.money = 0
	return true


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

# Transferwaarde-ankerpunten (rating → gem. marktwaarde op dat kantoorniveau),
# log-lineair geïnterpoleerd per segment — vervangt de oude kwadratische
# formule (pow(r-40,5)^2*3000), die veel te traag groeide om de gewenste
# waardesprong tussen kantoorniveaus te halen. Doelwaarden per niveau-gem.:
# N1(28)=€45k, N2(40)=€330k, N3(55)=€880k, N4(70)=€3,8mln, N5(84)=€16mln,
# N6(90)=€54mln. De eerste/laatste ankers (18 en 94) zijn de uiterste ratings
# die het spel kan opleveren (niveau 1-floor resp. de wereldwijde 94-cap in
# world_gen.gd) — erbuiten wordt geclampt, dus nooit geëxtrapoleerd.
const VALUE_ANCHORS := [
	[18.0, 8548.0],
	[28.0, 45000.0],
	[40.0, 330000.0],
	[55.0, 880000.0],
	[70.0, 3800000.0],
	[84.0, 16000000.0],
	[90.0, 54000000.0],
	[94.0, 121500000.0],
]


func _value_for_rating(r: float) -> float:
	var rc := clampf(r, VALUE_ANCHORS[0][0], VALUE_ANCHORS[VALUE_ANCHORS.size() - 1][0])
	for i in range(VALUE_ANCHORS.size() - 1):
		var r0: float = VALUE_ANCHORS[i][0]
		var r1: float = VALUE_ANCHORS[i + 1][0]
		if rc <= r1:
			var v0: float = VALUE_ANCHORS[i][1]
			var v1: float = VALUE_ANCHORS[i + 1][1]
			var t := (rc - r0) / (r1 - r0)
			return v0 * pow(v1 / v0, t)
	return VALUE_ANCHORS[VALUE_ANCHORS.size() - 1][1]


func value(p: Dictionary) -> int:
	var v := _value_for_rating(float(p.rating))
	v *= 1.0 + float(Meta.perk_bonus("waardestijging")) / 100.0
	return int(v)


func scout_points_per_season() -> int:
	return SCOUT_POINTS + Meta.perk_bonus("scouting") + (1 if has_shop("jeugdscout") else 0) + int(state.get("bonus_scout_points", 0))


func client_cap() -> int:
	return CLIENT_CAP + Meta.perk_bonus("kantoor") + (1 if has_shop("groter_kantoor") else 0) + (1 if has_shop("nog_groter_kantoor") else 0)


func fee_cut() -> float:
	# Commissiekunst-perk: +0,2% fee per niveau (value staat in tienden van %).
	var c := FEE_CUT + float(Meta.perk_bonus("commissie")) / 1000.0
	if has_shop("belastingadviseur"):
		c += 0.02
	return c


func trust_gain_mult() -> float:
	# Het gewicht van OPGEBOUWD vertrouwen groeit over de seizoenen heen: in
	# seizoen 1 valt er nog weinig op te bouwen (basisdemping 0,6), maar elk
	# volgend seizoen telt een positieve vertrouwensmutatie zwaarder mee, tot
	# een plafond. Zo wordt vertrouwen een investering die zich over de run
	# opbouwt i.p.v. een stat die meteen al vaststaat. (Negatieve mutaties
	# blijven altijd voluit tellen — die lopen hier niet langs.)
	return minf(TRUST_GAIN_MULT + (float(state.season) - 1.0) * TRUST_GAIN_PER_SEASON, TRUST_GAIN_MAX)


func poach_chance(p: Dictionary) -> float:
	# Rivalen kapen ook cliënten met redelijk vertrouwen weg: hoe hoger de
	# rating, hoe aantrekkelijker; hoog vertrouwen beschermt — sterker dan
	# voorheen, zodat vertrouwen hier ook echt voor elk punt iets doet.
	# Onaantastbaar tijdens zijn eerste 2 seizoenen bij je: een net getekende
	# cliënt is nog niet interessant genoeg voor een rivaal om over te stappen
	# — pas vanaf zijn 3e seizoen loopt hij risico.
	if Meta.perk_level("ijzeren_stal") > 0:
		return 0.0
	var since := int(p.get("client_since", state.season))
	if int(state.season) - since < 2:
		return 0.0
	var c := 0.03 + (float(p.rating) - 50.0) * 0.005 - (float(p.trust) - 50.0) * 0.006
	c -= float(Meta.perk_bonus("binding")) * 0.01
	if has_shop("veiligheidsnet"):
		c -= 0.05
	# Vanaf schandaal 70 ruiken rivalen bloed: een omstreden makelaar is een
	# makkelijker doelwit (zie scandal_poach_bonus()).
	c += scandal_poach_bonus()
	return clampf(c, 0.0, 0.35)


func leave_chance(p: Dictionary) -> float:
	# Doorlopende curve i.p.v. een harde knip: onder LEAVE_SAFE_TRUST loopt
	# het vertrekrisico lineair op naarmate vertrouwen lager wordt.
	var trust := float(p.trust) + float(Meta.perk_bonus("empathie"))
	if has_shop("psycholoog"):
		trust += 8.0
	var c := (LEAVE_SAFE_TRUST - trust) * LEAVE_SLOPE
	return clampf(c, 0.0, LEAVE_CHANCE_MAX)


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


const MYSTERY_CLUB_ID := "__mystery__"


func club_name(club_id: String) -> String:
	if club_id == MYSTERY_CLUB_ID:
		return "Mysterieuze buitenlandse club"
	if club_id == "" or not state.clubs.has(club_id):
		return "clubloos"
	return str(state.clubs[club_id]["name"])


func event_money_scale() -> float:
	# Vaste event-/minigame-bedragen (€8.000 hier, €5.000 daar) schalen op
	# EXACT dezelfde manier als de kantoorkosten (COSTS_MULT, ×1,8/seizoen) —
	# anders lopen ze uit de pas met de rest van de economie en voelen ze
	# na een paar seizoenen als zakgeld naast de exponentieel stijgende kosten.
	return pow(COSTS_MULT, float(state.season) - 1.0)


const SHOP_MONEY_GROWTH := 1.15   # milde groeivoet, los van event_money_scale()


func shop_money_scale() -> float:
	# Shop-upgrades zijn OPTIONEEL, geen verplichte kosten zoals de kantoor-
	# huur. Zouden ze met dezelfde harde ×1,8/seizoen-curve als event_money_
	# scale() meegroeien, dan worden ze in de tweede seizoenshelft absurd
	# duur (seizoen 15 ≈ ×728) terwijl je inkomen (clubbudgetten groeien maar
	# 12-17%/seizoen) daar nooit bij in de buurt komt — dan koop je ze
	# gewoon nooit meer. Eigen, veel mildere groeivoet (seizoen 15 ≈ ×6) zodat
	# ze de hele run door haalbaar blijven, terwijl vroeg kopen nog steeds
	# goedkoper is dan laat kopen.
	return pow(SHOP_MONEY_GROWTH, float(state.season) - 1.0)


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
	last_new_client_id = ""
	for key in effects:
		var v = effects[key]
		match key:
			"money":
				state.money = int(state.money) + int(v)
			"rep":
				var rv := int(v)
				if rv > 0:
					rv = int(ceil(float(rv) * REP_GAIN_MULT))
				state.rep = maxi(int(state.rep) + rv, 0)
			"scandal":
				var sv := int(v)
				# Crisismanagement-perk en Juridisch adviseur (shop) dempen
				# stijgingen samen (nooit onder 1).
				if sv > 0:
					var reduction := Meta.perk_bonus("crisismanagement")
					if has_shop("juridisch_adviseur"):
						reduction += 1
					sv = maxi(sv - reduction, 1)
				var scandal_cap := 80 if has_shop("risicomanager") else 100
				state.scandal = clampi(int(state.scandal) + sv, 0, scandal_cap)
			"favors":
				state.favors = maxi(int(state.favors) + int(v), 0)
			"scout_points":
				state.scout_points = maxi(int(state.scout_points) + int(v), 0)
			"scout_points_permanent":
				# In tegenstelling tot "scout_points" (eenmalig, alleen dit
				# seizoen) verhoogt dit ook scout_points_per_season() zelf —
				# voor events die expliciet "voortaan meer scoutpunten"
				# beloven, niet alleen "deze ronde".
				state.bonus_scout_points = maxi(int(state.get("bonus_scout_points", 0)) + int(v), 0)
				state.scout_points = maxi(int(state.scout_points) + int(v), 0)
			"trust":
				if client_id != "" and state.players.has(client_id):
					var p: Dictionary = state.players[client_id]
					var tv := int(v)
					if tv > 0:
						tv = int(ceil(float(tv) * trust_gain_mult()))
					p["trust"] = clampi(int(p.trust) + tv, 0, 100)
			"all_trust":
				var atv := int(v)
				if atv > 0:
					atv = int(ceil(float(atv) * trust_gain_mult()))
				for cid in state.clients:
					var pc: Dictionary = state.players[cid]
					pc["trust"] = clampi(int(pc.trust) + atv, 0, 100)
			"new_client":
				var nm := _sign_event_talent()
				if nm != "":
					notes.append("%s sluit zich aan bij jouw stal." % nm)
			"new_top_client":
				var nmt := _sign_top_talent()
				if nmt != "":
					notes.append("%s (topspeler) sluit zich aan bij jouw stal." % nmt)
			"prepare_transfer":
				if client_id != "" and state.players.has(client_id):
					if not state.has("prepared_transfers"):
						state.prepared_transfers = []
					state.prepared_transfers.append({"client_id": client_id})
	return notes


func _best_of_sample(pool: Array, sample_size: int) -> String:
	# Kiest niet zomaar willekeurig uit de pool, maar de BESTE (hoogste
	# rating) uit een kleine willekeurige steekproef zonder teruglegging —
	# zodat kaap-events stelselmatig naar de bovenkant van de pool trekken
	# i.p.v. een gemiddelde uitkomst op te leveren.
	var work: Array = pool.duplicate()
	var n := mini(sample_size, work.size())
	var best := ""
	for i in range(n):
		var idx := rng.randi_range(0, work.size() - 1)
		var candidate: String = work[idx]
		work.remove_at(idx)
		if best == "" or int(state.players[candidate].rating) > int(state.players[best].rating):
			best = candidate
	return best


func _sign_event_talent() -> String:
	# Voegt een vrij talent toe aan de stal (voor events als 'poachen'). De
	# ondergrens schaalt mee met reputatie — maar wordt geclampt op de
	# daadwerkelijk hoogst beschikbare rating in de pool, zodat een hoge
	# reputatie nooit tot een lege pool (en dus altijd hetzelfde ~58-rating
	# resultaat, of erger: niemand) leidt. Best-of-3 boven op die vloer maakt
	# het resultaat ook echt "uitzonderlijk" i.p.v. een doorsnee scoutvondst.
	if state.clients.size() >= client_cap():
		return ""
	var pool: Array = []
	var max_rating := 0
	for pid in state.players:
		if pid in state.clients:
			continue
		var p: Dictionary = state.players[pid]
		if int(p.age) <= 26:
			pool.append(pid)
			max_rating = maxi(max_rating, int(p.rating))
	if pool.is_empty():
		for pid in state.players:
			if not (pid in state.clients):
				pool.append(pid)
				max_rating = maxi(max_rating, int(state.players[pid].rating))
	if pool.is_empty():
		return ""
	var min_rating: int = mini(58 + int(state.rep) / 3, max_rating)
	var filtered: Array = []
	for pid in pool:
		if int(state.players[pid].rating) >= min_rating:
			filtered.append(pid)
	if filtered.is_empty():
		filtered = pool
	var pick := _best_of_sample(filtered, 3)
	_make_client(pick, 60)
	last_new_client_id = pick
	return str(state.players[pick].name)


func _sign_top_talent() -> String:
	# Net als _sign_event_talent(), maar gericht op een échte topper (voor
	# events als 'topspeler_kaap') — met soepele terugvalopties zodat het
	# altijd wel iemand oplevert, en ook hier best-of-3 zodat je niet zomaar
	# de zwakste topper uit de pool treft.
	if state.clients.size() >= client_cap():
		return ""
	var pool: Array = []
	for pid in state.players:
		if pid in state.clients:
			continue
		var p: Dictionary = state.players[pid]
		if int(p.rating) >= HIGH_RATING_THRESHOLD:
			pool.append(pid)
	if pool.is_empty():
		for pid in state.players:
			if pid in state.clients:
				continue
			if int(state.players[pid].rating) >= 65:
				pool.append(pid)
	if pool.is_empty():
		return _sign_event_talent()
	var pick := _best_of_sample(pool, 3)
	_make_client(pick, 55)
	last_new_client_id = pick
	return str(state.players[pick].name)


# ---------------------------------------------------------------- het kantoor
# Je kantoorniveau (1..5) bepaalt WELKE spelers je elk seizoen te zien krijgt:
# de rating-band waaruit de verse kandidaten worden getrokken. Reputatie
# bepaalt NIET meer wie je ziet (dat deed het vroeger via rating_cap_*), maar
# alléén nog of ze bij je tekenen (zie sign_chance()). Elk niveau heeft een
# eigen sfeer/beeld zodat de achtergrond-art per niveau kan wisselen.
const OFFICE_MAX_LEVEL := 5
const CANDIDATES_PER_SEASON := 8
# Niveaus verder uit elkaar getrokken en het gemiddelde omlaag (was gem. 71,
# nu gem. ~61) — vooral het BEGIN is nu veel zwakker (niveau 1: gem. 28 i.p.v.
# 45, bijna zuiver amateurniveau). Zonder dit kon je vroeg al redelijk veel
# geld verdienen en dat compound sparen (bank/rente), waardoor de late game
# bijna vanzelf makkelijk werd. De top blijft bewust binnen de 94-cap uit
# world_gen.gd (make_candidate() capt pot/est altijd op 94) — die grens
# doorbreken zou rating > potentieel kunnen opleveren, dus niveau 6 gaat niet
# hoger dan Monaco kon, maar wél met een hogere floor (minder variantie).
const OFFICE_LEVELS := [
	{"name": "Boven de Snackbar", "avg": 28, "floor": 18, "ceiling": 40},
	{"name": "De Portacabin",     "avg": 40, "floor": 28, "ceiling": 54},
	{"name": "Het Grachtenpand",  "avg": 55, "floor": 43, "ceiling": 68},
	{"name": "De Glazen Toren",   "avg": 70, "floor": 58, "ceiling": 82},
	{"name": "Monaco",            "avg": 84, "floor": 74, "ceiling": 93},
	{"name": "De Kampioenssuite", "avg": 90, "floor": 84, "ceiling": 94},
]


func office_max_level() -> int:
	# Niveau 6 ("De Kampioenssuite") is een geheime, exclusieve trofee: hij
	# bestaat pas zodra je ooit ÉÉN run hebt gewonnen (Meta.state.has_won_ever)
	# — daarna blijft hij voor altijd beschikbaar, in elke run.
	return OFFICE_MAX_LEVEL + 1 if bool(Meta.state.get("has_won_ever", false)) else OFFICE_MAX_LEVEL


func office_level() -> int:
	return clampi(int(state.get("office_level", 1)), 1, office_max_level())


func office_band() -> Dictionary:
	return OFFICE_LEVELS[office_level() - 1]


func office_name() -> String:
	return str(office_band().name)


const OFFICE_UPGRADE_PCT_OF_VALUE := 0.4   # upgrade-kosten = 40% van de gem. spelerswaarde op het doelniveau


func office_upgrade_cost() -> int:
	# Schaalt automatisch mee met VALUE_ANCHORS in plaats van een losse vaste
	# formule (was €100.000 × doelniveau², volledig losgezongen van de
	# transferwaardes) — zo blijft de upgrade altijd "een paar transfers
	# waard" ongeacht hoe de waardecurve later nog verandert. -1 = al op het
	# hoogste niveau. Bewust duur: het kantoorniveau is de centrale
	# progressie-as van een run en mag, in tegenstelling tot de optionele
	# shop-upgrades, gewoon een forse investering blijven.
	var next_lvl := office_level() + 1
	if next_lvl > office_max_level():
		return -1
	var target_avg := float(OFFICE_LEVELS[next_lvl - 1].avg)
	return int(round(_value_for_rating(target_avg) * OFFICE_UPGRADE_PCT_OF_VALUE))


func can_upgrade_office() -> bool:
	var cost := office_upgrade_cost()
	return cost > 0 and int(state.money) >= cost


func upgrade_office() -> bool:
	if not can_upgrade_office():
		return false
	state.money = int(state.money) - office_upgrade_cost()
	state.office_level = office_level() + 1
	return true


# ---------------------------------------------------------------- scouting

func candidate_ceiling() -> int:
	# Het effectieve plafond van de kandidatenband. Basis komt van je kantoor;
	# de meta-perks die vroeger de rating_cap verhoogden (Talentmagneet,
	# Grote naam) en de shop-upgrades tillen het nog een paar punten op — zo
	# blijven die effecten relevant nu reputatie het plafond niet meer bepaalt.
	var c := int(office_band().ceiling)
	c += Meta.perk_bonus("talentmagneet") + Meta.perk_bonus("grote_naam")
	if has_shop("kantoorrenovatie"):
		c += 3
	if has_shop("breed_scoutingnetwerk"):
		c += 4
	return mini(c, 94)


func candidate_floor() -> int:
	return mini(int(office_band().floor), candidate_ceiling())


func candidate_count() -> int:
	return CANDIDATES_PER_SEASON + Meta.perk_level("extra_kandidaat")


func _clear_old_candidates() -> void:
	# Verse trekking per seizoen: ruim de ongetekende kandidaten van vorig
	# seizoen op (getekende zijn cliënt geworden en blijven bestaan). Zo
	# groeit state.players niet elk seizoen met 20 dode namen.
	for pid in state.get("candidate_ids", []):
		if not (pid in state.clients) and state.players.has(pid):
			state.players.erase(pid)
	state.candidate_ids = []


func gen_candidates() -> Array:
	# Trekt 20 (of meer, met Breed netwerk-perk) VERSE spelers voor dit seizoen
	# binnen de rating-band van je kantoorniveau, van amateur tot het beste dat
	# je kantoor kan aantrekken. Ze worden aan state.players toegevoegd zodat
	# alle bestaande logica (estimate/scout/value/tooltip) er ongewijzigd mee
	# werkt; ongetekende exemplaren worden volgend seizoen weer opgeruimd.
	_clear_old_candidates()
	var lo := candidate_floor()
	var hi := candidate_ceiling()
	var out: Array = []
	var counter := int(state.get("candidate_counter", 0))
	for i in range(candidate_count()):
		var pid := "cand%d" % counter
		counter += 1
		var rating := rng.randi_range(lo, hi)
		state.players[pid] = WorldGen.make_candidate(rng, pid, rating)
		out.append(pid)
	state.candidate_counter = counter
	state.candidate_ids = out
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
	var scout_drop := 5 + Meta.perk_bonus("talentenoog")
	if has_shop("data_analytics"):
		scout_drop *= 2
	var new_unc := maxi(old_unc - scout_drop, 2)
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
	# Vanaf schandaal 40 vinden spelers een omstreden makelaar minder
	# aantrekkelijk om bij te tekenen (zie scandal_signing_penalty()).
	c -= scandal_signing_penalty()
	return clampf(c, 0.1, 0.85)


func attempt_sign(pid: String) -> bool:
	if state.clients.size() >= client_cap():
		return false
	if rng.randf() < sign_chance(pid):
		_make_client(pid, 55)
		state.rep = maxi(int(state.rep) + 1, 0)
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
	# Elke speler heeft ELK seizoen GEGARANDEERD 1 of 2 geïnteresseerde clubs
	# — betaalbaarheid (budget) speelt daarbij geen rol meer: een club die
	# het niet kan betalen, leent of zoekt een investeerder, maar toont
	# sowieso interesse. Ambitie bepaalt (zacht, met ruis) WELKE clubs het
	# eerst aan de beurt zijn, niet OF er interesse is.
	var p: Dictionary = state.players[client_id]
	var ids: Array = []
	for cid in state.clubs:
		if cid != str(p.club):
			ids.append(cid)
	if ids.is_empty():
		return []
	var scored: Array = []
	for cid in ids:
		var score := float(state.clubs[cid].ambition) + rng.randf_range(0.0, 3.0)
		scored.append([score, cid])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	# Hogere rating trekt vaker een 2e club; vanaf schandaal 70 remt
	# scandal_interest_mult() die kans op een 2e club af (in plaats van op
	# interesse-op-zich, die nu altijd gegarandeerd is).
	var two_chance := clampf(0.3 + (float(p.rating) - 50.0) * 0.01, 0.1, 0.8) * scandal_interest_mult()
	var want_two := rng.randf() < two_chance
	var count := mini(2 if want_two else 1, scored.size())
	var out: Array = []
	for i in range(count):
		out.append(str(scored[i][1]))
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
	p["trust"] = clampi(int(p.trust) + int(ceil(8.0 * trust_gain_mult())), 0, 100)
	var c: Dictionary = state.clubs[club_id]
	c["relation"] = clampi(int(c.relation) + 5, 0, 100)
	c["budget"] = maxi(int(c.budget) - fee, 0)
	state.rep = maxi(int(state.rep) + Meta.perk_bonus("pr_machine"), 0)
	return income


func tekengeld_mult() -> float:
	# Kleine lettertjes-perk: +10% tekengeld per niveau.
	return 1.0 + float(Meta.perk_bonus("tekengeld")) / 100.0


const HIGH_RATING_THRESHOLD := 78


func is_high_rated(p: Dictionary) -> bool:
	return int(p.rating) >= HIGH_RATING_THRESHOLD


func extend_mult(p: Dictionary) -> float:
	# Bij een hoog gewaardeerde speler is verlengen een derde optie náást
	# beide clubgesprekken (i.p.v. dat het de derde optie blokkeert), maar
	# het tekengeld is dan lager: met clubs in de rij bindt hij zich niet
	# goedkoop voor een verlenging.
	return 0.5 if is_high_rated(p) else 1.0


const EXTEND_FEE_PCT := 0.07   # tekengeld bij contractverlenging = 7% van value()


func extend_contract(client_id: String) -> int:
	var p: Dictionary = state.players[client_id]
	var coach_bonus := 1.3 if has_shop("contractenspecialist") else 1.0
	var tekengeld := int(value(p) * EXTEND_FEE_PCT * tekengeld_mult() * extend_mult(p) * coach_bonus)
	state.money = int(state.money) + tekengeld
	state.total_fees = int(state.total_fees) + tekengeld
	p["contract"] = int(p.contract) + 2
	p["trust"] = clampi(int(p.trust) + int(ceil(5.0 * trust_gain_mult())), 0, 100)
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
	lines.append("Kantoorkosten: -€%s" % fmt_thousands(costs))

	# Clubbudgetten groeien elk seizoen mee (tv-gelden, sponsoring) — anders
	# blijven ze voor altijd vastzitten op hun startwaarde uit seizoen 1,
	# terwijl spelerswaarde via ontwikkeling en value() flink doorgroeit.
	# Zonder dit kan een goed ontwikkelde cliënt tegen seizoen 10-12 letterlijk
	# duurder zijn dan élke club zich kan veroorloven — nul interesse, altijd.
	var club_growth := CLUB_BUDGET_GROWTH + (0.05 if has_shop("clubcontacten") else 0.0)
	for cid in state.clubs:
		var cl: Dictionary = state.clubs[cid]
		cl["budget"] = int(float(cl.budget) * (1.0 + club_growth))

	# De bank: rijpe stortingen keren verdubbeld uit; de rest tikt een jaar af.
	# (get() met fallback: oudere saves van vóór De Bank kennen dit veld nog niet.)
	var still_pending: Array = []
	for d in state.get("bank_deposits", []):
		var seasons_left := int(d.seasons_left) - 1
		if seasons_left <= 0:
			var bank_mult := BANK_MULTIPLIER + (0.3 if has_shop("investeringsfonds") else 0.0)
			var payout := int(round(float(d.amount) * bank_mult))
			state.money = int(state.money) + payout
			lines.append("De bank keert uit: je storting van €%s wordt €%s." % [fmt_thousands(int(d.amount)), fmt_thousands(payout)])
		else:
			still_pending.append({"amount": int(d.amount), "seasons_left": seasons_left})
	state.bank_deposits = still_pending

	# Voorbereide transfers (event 'clubarts_geheim'): de insider-info kan
	# achteraf toch onjuist blijken — dan gaat de transfer niet door.
	var prepared_results: Array = []
	for pt in state.get("prepared_transfers", []):
		var cid: String = str(pt.client_id)
		if not state.players.has(cid) or not (cid in state.clients):
			continue  # cliënt is intussen weg; niets te resolveren
		var pp: Dictionary = state.players[cid]
		if rng.randf() < PREPARED_TRANSFER_CHANCE:
			var transfer_sum := int(value(pp) * PREPARED_TRANSFER_VALUE_PCT)
			var income := int(transfer_sum * fee_cut())
			state.money = int(state.money) + income
			state.total_fees = int(state.total_fees) + income
			pp["club"] = MYSTERY_CLUB_ID
			pp["contract"] = 3
			pp["trust"] = clampi(int(pp.trust) + int(ceil(6.0 * trust_gain_mult())), 0, 100)
			lines.append("Voorbereide transfer: %s naar een mysterieuze buitenlandse club — jouw fee €%s." % [pp.name, fmt_thousands(income)])
			prepared_results.append({"name": str(pp.name), "success": true, "transfer_sum": transfer_sum, "income": income})
		else:
			lines.append("Voorbereide transfer van %s ging niet door — de prognose bleek onjuist." % pp.name)
			prepared_results.append({"name": str(pp.name), "success": false})
	state.prepared_transfers = []
	state["last_prepared_results"] = prepared_results

	var leavers: Array = []
	for cid in state.clients:
		var p: Dictionary = state.players[cid]
		var perf := rng.randi_range(1, 10)
		# Groei richting (verborgen) potentieel; vanaf 27 is de rek eruit.
		# Ontwikkeling ~30% sneller dan voorheen (was randi 0..3): spelers
		# groeien merkbaar vlotter naar hun potentieel toe.
		if int(p.age) <= 26 and int(p.rating) < int(p.pot):
			var growth := int(round(float(rng.randi_range(0, 3)) * 1.3))
			if growth > 0:
				var oud := int(p.rating)
				p["rating"] = mini(oud + growth, int(p.pot))
				lines.append("%s ontwikkelt zich: rating %d → %d." % [p.name, oud, int(p.rating)])
		# Vertrouwen drift op basis van het seizoen (licht negatief zonder aandacht).
		# Het seizoensresultaat past nog wel het vertrouwen aan, maar zonder losse
		# meldingsregel — die voegde niets toe.
		var drift := rng.randi_range(-5, 5) + Meta.perk_bonus("spelersfluisteraar")
		if perf >= 8:
			drift += 3
		elif perf <= 3:
			drift -= 3
		p["trust"] = clampi(int(p.trust) + drift, 0, 100)
		p["age"] = int(p.age) + 1
		# Alleen een speler mét club heeft een (aflopend) contract dat aftikt —
		# een clubloze speler kan per definitie geen aflopend contract hebben.
		if str(p.club) != "":
			p["contract"] = int(p.contract) - 1
			if int(p.contract) <= 0:
				p["contract"] = 2
				var tg := int(value(p) * 0.01 * tekengeld_mult())
				state.money = int(state.money) + tg
				state.total_fees = int(state.total_fees) + tg
				lines.append("%s verlengt bij zijn club; tekengeld €%s voor jou." % [p.name, fmt_thousands(tg)])
		if Meta.perk_level("ijzeren_stal") == 0 and rng.randf() < leave_chance(p):
			leavers.append(cid)
			lines.append("!! %s VERTREKT naar een andere makelaar. Het vertrouwen was op (%d)." % [p.name, int(p.trust)])
		elif rng.randf() < poach_chance(p):
			# Rivaal-makelaars azen op je stal; toppers zijn extra gewild, hoog
			# vertrouwen beschermt (zie poach_chance()) — vandaar dat cijfer erbij.
			var rivaal: String = RIVAL_NAMES[rng.randi_range(0, RIVAL_NAMES.size() - 1)]
			leavers.append(cid)
			lines.append("!! %s (vertrouwen %d) wordt WEGGEKAAPT door %s. 'Zij beloven me meer.'" % [p.name, int(p.trust), rivaal])

	for cid in leavers:
		state.clients.erase(cid)

	var scandal_decay := 3 + Meta.perk_bonus("mediatraining") + (2 if has_shop("pr_bureau") else 0)
	state.scandal = maxi(int(state.scandal) - scandal_decay, 0)

	# Reputatie zakt licht terug richting een neutrale basis als je boven
	# die basis zit — anders groei je één keer naar 100 en blijft het daar
	# hangen zonder dat je nog iets hoeft te doen om het te behouden.
	if int(state.rep) > REP_BASELINE and not has_shop("pr_strategie"):
		state.rep = maxi(int(state.rep) - REP_DECAY_ABOVE_BASELINE, REP_BASELINE)

	# Oud geld-perk: rente over een positief saldo.
	var rente_pct := Meta.perk_bonus("oud_geld")
	if rente_pct > 0 and int(state.money) > 0:
		var rente := int(float(state.money) * float(rente_pct) / 100.0)
		if rente > 0:
			state.money = int(state.money) + rente
			lines.append("Rente op je vermogen: +€%s." % fmt_thousands(rente))

	# Gunstenfabriek-perk: elk 3e seizoen extra gunsten.
	var gf := Meta.perk_bonus("gunstenfabriek")
	if gf > 0 and int(state.season) % 3 == 0:
		state.favors = int(state.favors) + gf
		lines.append("Je gunstenfabriek draait: +%d gunst(en)." % gf)

	# Netwerkdiner-upgrade (shop): elk seizoen een gratis gunst.
	if has_shop("netwerkdiner"):
		state.favors = int(state.favors) + 1
		lines.append("Je netwerkdiner levert weer een gunst op.")

	state.news = _gen_news()

	# Laatste redmiddel-perk / Noodfonds-upgrade: één keer per run wordt een
	# tekort gedekt (los van elkaar bruikbaar als je beide hebt).
	if int(state.money) < 0 and try_bailout():
		lines.append("!! Een oude vriend dekt je tekort. 'Eén keer. Daarna sta je er alleen voor.'")
	if int(state.money) < 0 and try_shop_bailout():
		lines.append("!! Je noodfonds springt bij en zet je saldo op €0. Dat was 'm dan.")

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
