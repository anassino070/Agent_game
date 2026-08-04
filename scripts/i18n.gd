# i18n.gd — Autoload "I18n". Vertaallaag voor alle speler-zichtbare tekst.
#
# OPZET: de NEDERLANDSE string is zelf de sleutel. Dus in de code staat
# `T("Naar events →")` en de tabel hieronder mapt die naar het Engels. Waarom
# zo, en niet met abstracte sleutels als `EVENTS_NEXT`:
#   * de broncode blijft leesbaar (je ziet meteen wat er op het scherm komt);
#   * een ontbrekende vertaling valt automatisch terug op het Nederlands
#     i.p.v. een lege string of een sleutelnaam te tonen;
#   * er is geen aparte sleutel-administratie die uit de pas kan lopen.
#
# BELANGRIJK bij format-strings: vertaal ALTIJD vóór het interpoleren, dus
# `T("Seizoen %d/%d") % [a, b]` en NIET `T("Seizoen %d/%d" % [a, b])` — dat
# laatste zoekt een al-ingevulde string op en mist dus altijd. De placeholders
# (%s, %d) moeten in de vertaling in dezelfde ORDE staan, want GDScript's
# %-operator kent geen genummerde argumenten.
extends Node

const DEFAULT_LANG := "nl"

# Talen die daadwerkelijk (deels) bestaan. Arabisch staat er bewust NIET bij:
# dat vraagt naast vertaling ook een gespiegelde RTL-layout (badges rechts,
# → -pijlen, HBox-ordening), en dat is een aparte klus.
const LANGS := {
	"nl": "Nederlands",
	"en": "English",
}

var _lang := DEFAULT_LANG
var _table: Dictionary = {}


func _ready() -> void:
	_table = {"en": _table_en()}
	# I18n staat in project.godot NA Meta geregistreerd, dus Meta bestaat hier
	# gegarandeerd al en we kunnen de opgeslagen taalkeuze direct oppikken.
	refresh_from_settings()


func refresh_from_settings() -> void:
	set_lang(str(Meta.setting("lang")))


func set_lang(l: String) -> void:
	_lang = l if LANGS.has(l) else DEFAULT_LANG


func lang() -> String:
	return _lang


func lang_name(l: String) -> String:
	return str(LANGS.get(l, l))


# De vertaalfunctie. Kort van naam omdat hij honderden keren voorkomt.
func T(nl: String) -> String:
	if _lang == DEFAULT_LANG:
		return nl
	var t: Dictionary = _table.get(_lang, {})
	return str(t.get(nl, nl))


# ---------------------------------------------------------------- Engels
# Gegroepeerd per gebied, in dezelfde volgorde als de schermen in het spel.
func _table_en() -> Dictionary:
	var d := {}

	# ---- algemeen / navigatie ----
	d["← Terug"] = "← Back"
	d["Verder →"] = "Continue →"
	d["Naar events →"] = "To events →"
	d["Beginnen →"] = "Start →"
	d["Annuleer"] = "Cancel"
	d["Doorgaan naar volgend seizoen →"] = "Continue to next season →"
	d["Bekijk het einde →"] = "See the ending →"
	d["🪙 Naar de shop →"] = "🪙 To the shop →"
	d["Laten lopen →"] = "Let it go →"
	d["Terug naar het window →"] = "Back to the window →"
	d["Incasseren →"] = "Collect →"

	# ---- startscherm ----
	d["VOETBALMAKELAAR"] = "FOOTBALL AGENT"
	d["Van kelderkantoor naar superagent."] = "From basement office to superagent."
	d["Overleef %d seizoenen. Ga niet failliet, houd je schandaalmeter onder de 100 en zorg dat je cliënten je niet verlaten."] = "Survive %d seasons. Don't go bankrupt, keep your scandal meter under 100, and make sure your clients don't walk out on you."
	d["LEGACY — %d runs gespeeld  |  beste run: %s (seizoen %d)  |  totale carrièrefees: %s"] = "LEGACY — %d runs played  |  best run: %s (season %d)  |  total career fees: %s"
	d["Perkboom (%s legacy points te besteden) →"] = "Perk tree (%s legacy points to spend) →"
	d["🚀 MEGA-BOOST KLAAR: je volgende nieuwe run start met dubbel startkapitaal, +25 reputatie, +1 gunst en +2 scoutpunten."] = "🚀 MEGA BOOST READY: your next new run starts with double starting capital, +25 reputation, +1 favour and +2 scout points."
	d["NIEUWE RUN"] = "NEW RUN"
	d["Doorgaan met vorige run"] = "Continue previous run"
	d["🏆 HALL OF FAME"] = "🏆 HALL OF FAME"
	d["  %s — %s (seizoen %d)"] = "  %s — %s (season %d)"
	d["Naamloze topper"] = "Nameless star"
	d["⚙ Instellingen →"] = "⚙ Settings →"

	# ---- instellingen ----
	d["⚙ INSTELLINGEN"] = "⚙ SETTINGS"
	d["Instellingen gelden voor alle runs en worden bewaard in je meta-save."] = "Settings apply to all runs and are stored in your meta save."
	d["TAAL"] = "LANGUAGE"
	d["Kies je taal. Ontbrekende vertalingen vallen terug op het Nederlands."] = "Choose your language. Missing translations fall back to Dutch."
	d["WEERGAVE"] = "DISPLAY"
	d["%s  —  %s"] = "%s  —  %s"
	d["AAN"] = "ON"
	d["UIT"] = "OFF"
	d["Confetti & animaties"] = "Confetti & animations"
	d["Confetti bij een combo of geslaagde tekening, en het rode puffje bij een afwijzing."] = "Confetti on a combo or a successful signing, and the small red puff on a rejection."
	d["Kantoor-achtergrond"] = "Office background"
	d["Het beeld/sfeerkleur per kantoorniveau. Uit = effen donkere achtergrond, rustiger te lezen."] = "The image/mood colour per office level. Off = flat dark background, easier to read."
	d["Spelerkaart onderaan"] = "Player card at the bottom"
	d["Het paneel met de spelerkaart bij events en minigames. Uit = meer schermruimte."] = "The panel with the player card during events and minigames. Off = more screen space."
	d["PROGRESSIE"] = "PROGRESSION"
	d["Perkboom: nog niets gekocht om te resetten."] = "Perk tree: nothing bought yet to reset."
	d["Weet je het zeker? Alle perks (ook de ★-extra's) gaan naar 0; je krijgt %s punten terug."] = "Are you sure? All perks (including the ★ extras) go to 0; you get %s points back."
	d["JA — reset perkboom"] = "YES — reset perk tree"
	d["Reset perkboom (geeft %s punten terug)"] = "Reset perk tree (refunds %s points)"
	d["Weet je het zeker? Al je Erfenis-perks gaan naar 0; je krijgt %d %s terug."] = "Are you sure? All your Legacy perks go to 0; you get %d %s back."
	d["JA — reset Erfenis-perks"] = "YES — reset Legacy perks"
	d["Reset Erfenis-perks (geeft %d %s terug)"] = "Reset Legacy perks (refunds %d %s)"
	d["ster"] = "star"
	d["sterren"] = "stars"
	d["OPSLAG"] = "SAVE DATA"
	d["Je huidige run wordt definitief verwijderd. Je legacy points en perks blijven staan."] = "Your current run will be permanently deleted. Your legacy points and perks are kept."
	d["JA — verwijder huidige run"] = "YES — delete current run"
	d["Verwijder huidige run"] = "Delete current run"
	d["Geen lopende run opgeslagen."] = "No run in progress saved."
	d["ALLES WISSEN: punten, perks, Erfenis-perks, sterren, ∞-upgrade, carrièrestats, Hall of Fame én de niveau-6-ontgrendeling. Dit kan NIET ongedaan worden gemaakt. Je instellingen blijven staan."] = "WIPE EVERYTHING: points, perks, Legacy perks, stars, ∞ upgrade, career stats, Hall of Fame and the level 6 unlock. This CANNOT be undone. Your settings are kept."
	d["JA, WIS ALLES"] = "YES, WIPE EVERYTHING"
	d["Alles wissen (volledige reset)"] = "Wipe everything (full reset)"

	# ---- kantoorniveaus (sfeernamen) ----
	d["Boven de Snackbar"] = "Above the Chip Shop"
	d["De Portacabin"] = "The Portacabin"
	d["Het Grachtenpand"] = "The Canal House"
	d["De Glazen Toren"] = "The Glass Tower"
	d["Monaco"] = "Monaco"
	d["De Kampioenssuite"] = "The Champions Suite"

	# ---- shop ----
	d["🪙 DE SHOP"] = "🪙 THE SHOP"
	d["Elke seizoenswissel liggen hier 3 willekeurige upgrades voor de rest van deze run. Koop wat je wilt, reroll voor een andere set, of loop gewoon door — niets verplicht."] = "At every season change three random upgrades are on offer for the rest of this run. Buy what you like, reroll for a different set, or just walk on — nothing is required."
	d["Niets (meer) te koop deze keer."] = "Nothing (left) for sale this time."
	d["✔ Gekocht"] = "✔ Purchased"
	d["Kopen (%s)"] = "Buy (%s)"
	d["🎲 Reroll — andere upgrades (%s)"] = "🎲 Reroll — different upgrades (%s)"
	d["%s gekocht!"] = "%s purchased!"

	d["Groter kantoor"] = "Bigger office"
	d["+1 stalplek voor de rest van deze run."] = "+1 roster slot for the rest of this run."
	d["PR-bureau"] = "PR agency"
	d["+2 extra schandaalverval per seizoen, de rest van de run."] = "+2 extra scandal decay per season, for the rest of the run."
	d["Eigen jeugdscout"] = "In-house youth scout"
	d["+1 scoutpunt per seizoen, de rest van de run."] = "+1 scout point per season, for the rest of the run."
	d["Juridisch adviseur"] = "Legal adviser"
	d["Schandaal-stijgingen 1 lager (minimaal 1), de rest van de run."] = "Scandal increases are 1 lower (minimum 1), for the rest of the run."
	d["Media-trainer voor je stal"] = "Media coach for your roster"
	d["Eenmalig: +15 vertrouwen bij al je huidige cliënten."] = "One-off: +15 trust with all your current clients."
	d["Netwerkdiner-abonnement"] = "Networking dinner subscription"
	d["+1 gunst per seizoen, de rest van de run."] = "+1 favour per season, for the rest of the run."
	d["Kantoorrenovatie"] = "Office renovation"
	d["Eenmalig +8 reputatie, plus +3 op je scouting-plafond voor de rest van de run."] = "One-off +8 reputation, plus +3 to your scouting ceiling for the rest of the run."
	d["Data-analytics abonnement"] = "Data analytics subscription"
	d["Effect van 1 scoutpunt verdubbelt, de rest van de run."] = "The effect of 1 scout point is doubled, for the rest of the run."
	d["Noodfonds (lifeline)"] = "Emergency fund (lifeline)"
	d["Eén keer per run: kom je onder €0, dan reset je saldo naar €0 en ga je door."] = "Once per run: if you drop below €0, your balance resets to €0 and you carry on."
	d["Onderhandelaar-coach"] = "Negotiation coach"
	d["+3% slagingskans op alle onderhandeltactieken, de rest van de run."] = "+3% success chance on all negotiation tactics, for the rest of the run."
	d["Veiligheidsnet"] = "Safety net"
	d["Rivalen kapen 5 procentpunt minder vaak een cliënt weg (lagere kaapkans), de rest van de run."] = "Rivals poach a client 5 percentage points less often (lower poach chance), for the rest of the run."
	d["Sportpsycholoog"] = "Sports psychologist"
	d["Vertrekkans van je cliënten daalt (alsof hun vertrouwen 8 hoger is), de rest van de run."] = "Your clients' chance of leaving drops (as if their trust were 8 higher), for the rest of the run."
	d["Fiscalist"] = "Tax specialist"
	d["+2% fee-percentage op elke transfer, de rest van de run."] = "+2% fee percentage on every transfer, for the rest of the run."
	d["Breed scoutingnetwerk"] = "Wide scouting network"
	d["+4 op je scouting-plafond: betere spelers binnen bereik, de rest van de run."] = "+4 to your scouting ceiling: better players within reach, for the rest of the run."
	d["Reputatiebeheerder"] = "Reputation manager"
	d["Je reputatie zakt niet meer vanzelf terug richting 50 (normaal -3/seizoen als je erboven zit), de rest van de run."] = "Your reputation no longer drifts back towards 50 on its own (normally -3/season when you're above it), for the rest of the run."
	d["Investeringsfonds"] = "Investment fund"
	d["De Bank keert 2,3× uit i.p.v. 2× op elke storting, de rest van de run."] = "The Bank pays out 2.3× instead of 2× on every deposit, for the rest of the run."
	d["Clubcontactenboek"] = "Club contact book"
	d["Clubbudgetten groeien +17%/seizoen i.p.v. +12% (meer clubs kunnen je spelers betalen), de rest van de run."] = "Club budgets grow +17%/season instead of +12% (more clubs can afford your players), for the rest of the run."
	d["Risicomanager"] = "Risk manager"
	d["Schandaal kan niet meer boven de 80 uitkomen, de rest van de run."] = "Scandal can no longer rise above 80, for the rest of the run."
	d["Contractenspecialist"] = "Contract specialist"
	d["+30% tekengeld bij elke contractverlenging, de rest van de run."] = "+30% signing fee on every contract extension, for the rest of the run."
	d["Nog groter kantoor"] = "Even bigger office"
	d["Nog eens +1 stalplek voor de rest van deze run (stapelt met Groter kantoor)."] = "Another +1 roster slot for the rest of this run (stacks with Bigger office)."
	d["Extra scoutingbudget"] = "Extra scouting budget"
	d["+2 scoutpunten per seizoen, de rest van de run."] = "+2 scout points per season, for the rest of the run."
	d["PR-campagne"] = "PR campaign"
	d["Eenmalig: +10 reputatie."] = "One-off: +10 reputation."
	d["Clubarts-netwerk"] = "Club doctor network"
	d["Eenmalig: -15 schandaal."] = "One-off: -15 scandal."
	d["VIP-netwerkclub"] = "VIP networking club"
	d["Eenmalig: +2 gunsten."] = "One-off: +2 favours."

	# ---- perkboom: namen ----
	d["Startkapitaal"] = "Starting capital"
	d["Kantoorkorting"] = "Office discount"
	d["Oud geld"] = "Old money"
	d["Commissiekunst"] = "Commission craft"
	d["Kleine lettertjes"] = "Fine print"
	d["Gunsteneconomie"] = "Favour economy"
	d["Reserves"] = "Reserves"
	d["Laatste redmiddel"] = "Last resort"
	d["Waardestijging"] = "Value growth"
	d["Onderpand"] = "Collateral"
	d["Schuldpapier"] = "Debt paper"
	d["Netwerk"] = "Network"
	d["Vlotte babbel"] = "Smooth talker"
	d["Vertrouwenspersoon"] = "Confidant"
	d["Bindingskracht"] = "Loyalty pull"
	d["Mediatraining"] = "Media training"
	d["PR-machine"] = "PR machine"
	d["Talentmagneet"] = "Talent magnet"
	d["Grote naam"] = "Big name"
	d["Gunstenfabriek"] = "Favour factory"
	d["Iconenstatus"] = "Icon status"
	d["Spelersfluisteraar"] = "Player whisperer"
	d["Empathie"] = "Empathy"
	d["Onderhandelaar"] = "Negotiator"
	d["Talentenoog"] = "Eye for talent"
	d["Flowmeester"] = "Flow master"
	d["Stalen zenuwen"] = "Nerves of steel"
	d["Clausulemeester"] = "Clause master"
	d["Scoutingdienst"] = "Scouting service"
	d["Dossierkennis"] = "Dossier knowledge"
	d["Breed netwerk"] = "Wide network"
	d["Crisismanagement"] = "Crisis management"
	d["Koelbloedig"] = "Cold-blooded"
	d["Voorwerk"] = "Groundwork"
	d["Geluksvogel"] = "Lucky streak"
	d["★ Superprovisie"] = "★ Super commission"
	d["★ IJzeren contracten"] = "★ Iron contracts"
	d["★ Helderziend"] = "★ Clairvoyant"
	d["★ Vaste kern"] = "★ Untouchable core"

	# ---- perkboom: beschrijvingen (let op: %s blijft op dezelfde plek) ----
	d["+%s bij de start van elke run"] = "+%s at the start of every run"
	d["-%s%% kantoorkosten"] = "-%s%% office costs"
	d["+%s%% rente op je saldo per seizoen"] = "+%s%% interest on your balance per season"
	d["+%s fee op elke transfer"] = "+%s fee on every transfer"
	d["+%s%% tekengeld bij verlengingen"] = "+%s%% signing fee on extensions"
	d["+%s startgunst(en)"] = "+%s starting favour(s)"
	d["+%s stalplek(ken)"] = "+%s roster slot(s)"
	d["+%s onderhandelronde in elk gesprek"] = "+%s negotiation round in every talk"
	d["%s× per run dekt een oude vriend je tekort (saldo naar €0)"] = "%s× per run an old friend covers your shortfall (balance to €0)"
	d["+%s%% marktwaarde voor al je cliënten"] = "+%s%% market value for all your clients"
	d["+%s extra startkapitaal"] = "+%s extra starting capital"
	d["%s vaste korting op de kantoorkosten"] = "%s flat discount on office costs"
	d["+%s startreputatie"] = "+%s starting reputation"
	d["+%s%% tekenkans bij het benaderen van spelers"] = "+%s%% signing chance when approaching players"
	d["+%s startvertrouwen bij nieuwe cliënten"] = "+%s starting trust with new clients"
	d["-%s%% kans dat rivalen je cliënten wegkapen"] = "-%s%% chance rivals poach your clients"
	d["+%s extra schandaalverval per seizoen"] = "+%s extra scandal decay per season"
	d["+%s reputatie bij elke afgeronde transfer"] = "+%s reputation on every completed transfer"
	d["+%s op je rating-plafond voor jonge spelers"] = "+%s to your rating ceiling for young players"
	d["+%s op je rating-plafond voor gevestigde spelers"] = "+%s to your rating ceiling for established players"
	d["+%s gunst(en) elk 3e seizoen"] = "+%s favour(s) every 3rd season"
	d["+%s extra startreputatie"] = "+%s extra starting reputation"
	d["+%s vertrouwen voor ál je cliënten, elk seizoen"] = "+%s trust for ALL your clients, every season"
	d["cliënten overwegen pas vertrek onder vertrouwen %s lager"] = "clients only consider leaving at %s lower trust"
	d["+%s%% slagingskans op onderhandeltactieken"] = "+%s%% success chance on negotiation tactics"
	d["scouten verlaagt de onzekerheid %s extra"] = "scouting reduces uncertainty by %s more"
	d["+%s%% extra flow-effect (bovenop de +50%%)"] = "+%s%% extra flow effect (on top of the +50%%)"
	d["-%s%% kans dat een TD wegloopt"] = "-%s%% chance a director walks out"
	d["clausules kosten %s minder fee"] = "clauses cost %s less fee"
	d["+%s extra scoutpunt per seizoen"] = "+%s extra scout point per season"
	d["aftasten kost %s ronde minder"] = "probing costs %s round less"
	d["+%s extra kandidaat in elke scoutinglijst"] = "+%s extra candidate in every scouting list"
	d["schandaal-stijgingen %s lager (minimaal 1)"] = "scandal increases %s lower (minimum 1)"
	d["+%s%% slagingskans op bluffen"] = "+%s%% success chance when bluffing"
	d["TD's starten met %s minder weerstand"] = "directors start with %s less resistance"
	d["+%s%% slagingskans op alle kans-opties bij events"] = "+%s%% success chance on all chance options in events"
	d["alle transfer-inkomsten tellen dubbel"] = "all transfer income counts double"
	d["cliënten vertrekken nooit meer en kunnen niet worden weggekaapt"] = "clients never leave and cannot be poached"
	d["alle TD-persoonlijkheden zijn direct bekend en elk gesprek start Ontvankelijk"] = "all director personalities are known immediately and every talk starts Receptive"
	d["je bent de uitzondering op de regel: nooit meer verplicht een cliënt wegsturen"] = "you are the exception to the rule: never forced to release a client again"

	# ---- Erfenis-perks ----
	d["Kroonjuweel-netwerk"] = "Crown jewel network"
	d["Je begint elke run met een startcliënt i.p.v. met een lege stal."] = "You start every run with one client instead of an empty roster."
	d["Kantoorvoorsprong"] = "Office head start"
	d["Je begint elke run standaard op kantoorniveau 2 i.p.v. niveau 1."] = "You start every run at office level 2 instead of level 1."
	d["Eeuwige gunst"] = "Eternal favour"
	d["Je begint elke run met +2 extra gunsten."] = "You start every run with +2 extra favours."

	# ---- seizoensrapport (regels uit game.gd's end_of_season) ----
	d["Kantoorkosten: -€%s"] = "Office costs: -€%s"
	d["De bank keert uit: je storting van €%s wordt €%s."] = "The bank pays out: your deposit of €%s becomes €%s."
	d["Voorbereide transfer: %s naar een mysterieuze buitenlandse club — jouw fee €%s."] = "Prepared transfer: %s to a mysterious foreign club — your fee €%s."
	d["Voorbereide transfer van %s ging niet door — de prognose bleek onjuist."] = "The prepared transfer of %s fell through — the prognosis turned out to be wrong."
	d["%s verlengt bij zijn club; tekengeld €%s voor jou."] = "%s extends at his club; €%s signing fee for you."
	d["Rente op je vermogen: +€%s."] = "Interest on your capital: +€%s."
	d["Je gunstenfabriek draait: +%d gunst(en)."] = "Your favour factory is running: +%d favour(s)."
	d["Je netwerkdiner levert weer een gunst op."] = "Your networking dinner earns you another favour."
	d["!! Een oude vriend dekt je tekort. 'Eén keer. Daarna sta je er alleen voor.'"] = "!! An old friend covers your shortfall. 'Once. After that you're on your own.'"
	d["!! Je noodfonds springt bij en zet je saldo op €0. Dat was 'm dan."] = "!! Your emergency fund steps in and sets your balance to €0. That was the one."

	return d
