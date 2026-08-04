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

	# ---- header ----
	d["Seizoen %d/%d  |  %s  |  Rep %d  |  Schandaal %d  |  [color=#ffd633]Gunsten %d[/color]  |  Stal %d/%d  |  🏢 Nv.%d %s"] = "Season %d/%d  |  %s  |  Rep %d  |  Scandal %d  |  [color=#ffd633]Favours %d[/color]  |  Roster %d/%d  |  🏢 Lv.%d %s"
	d["Seizoen %d/%d"] = "Season %d/%d"

	# ---- voorbereiding ----
	d["VOORBEREIDING"] = "PREPARATION"
	d["Nieuws: "] = "News: "
	d["Jouw stal (%d/%d):"] = "Your roster (%d/%d):"
	d["⚠ Schandaal %d — je staat onder een vergrootglas: nieuwe cliënten tekenen minder makkelijk bij je."] = "⚠ Scandal %d — you're under a microscope: new clients are less willing to sign with you."
	d["⚠ Schandaal %d — je reputatie is in vrije val: rivalen kapen je cliënten makkelijker weg en clubs mijden je bij transfers."] = "⚠ Scandal %d — your reputation is in free fall: rivals poach your clients more easily and clubs avoid you on transfers."
	d["🏢 KANTOOR — niveau %d/%d: %s"] = "🏢 OFFICE — level %d/%d: %s"
	d["Je ziet elk seizoen %d spelers, rating %d–%d (gemiddeld ~%d). Hoger niveau = betere spelers binnen bereik."] = "Each season you see %d players, rating %d–%d (average ~%d). Higher level = better players within reach."
	d["Upgraden tilt je naar niveau %d: %s (spelers tot ~%d)."] = "Upgrading lifts you to level %d: %s (players up to ~%d)."
	d["Kantoor upgraden — %s (%s)"] = "Upgrade office — %s (%s)"
	d["Hoogste niveau bereikt. Je onderhandelt tussen de miljardairs."] = "Highest level reached. You negotiate among billionaires."
	d["Kantoor geüpgraded naar %s! De hele tent verandert."] = "Office upgraded to %s! The whole place changes."
	d["Upgrade mislukt — niet genoeg geld."] = "Upgrade failed — not enough money."
	d["DE BANK — stort geld weg, krijg het na %d seizoenen verdubbeld terug."] = "THE BANK — stash money away, get it back doubled after %d seasons."
	d["• %s gestort — nog %d seizoen(en), dan %s terug."] = "• %s deposited — %d season(s) left, then %s back."
	d["Storten: %s"] = "Deposit: %s"
	d["Storten"] = "Deposit"
	d["Gestort: %s. Komt over %d seizoenen terug als %s."] = "Deposited: %s. Comes back in %d seasons as %s."
	d["Storting mislukt — vul een geldig bedrag in dat je ook echt hebt."] = "Deposit failed — enter a valid amount you actually have."
	d["Naar scouting →"] = "To scouting →"
	d["Naar stalbeheer →"] = "To roster management →"

	# ---- stalbeheer ----
	d["STALBEHEER — VERPLICHT ONTSLAG"] = "ROSTER MANAGEMENT — FORCED RELEASE"
	d["Selecteer wie je wegstuurt (je mag er zoveel kwijt als je wilt, zolang er minstens 1 overblijft — handig als je meteen plek wilt maken voor een kantoorupgrade) en bevestig onderaan. De rest van je stal verliest 2 vertrouwen per weggestuurde cliënt."] = "Select who you release (as many as you like, as long as at least 1 remains — handy if you want to clear space for an office upgrade right away) and confirm below. The rest of your roster loses 2 trust per released client."
	d["✗ Wegsturen"] = "✗ Release"
	d["✔ Blijft toch"] = "✔ Keep after all"
	d["Bevestig: stuur %d weg (%d blijft over)"] = "Confirm: release %d (%d remaining)"
	d["Niemand geselecteerd"] = "Nobody selected"
	d["Je moet minstens 1 cliënt overhouden."] = "You must keep at least 1 client."
	d["%s pakt zijn spullen. 'Ik dacht dat we een team waren.'"] = "%s packs his things. 'I thought we were a team.'"
	d["%d cliënten pakken hun spullen: %s."] = "%d clients pack their things: %s."

	# ---- scouting ----
	d["SCOUTING"] = "SCOUTING"
	d["Scoutpunten:"] = "Scout points:"
	d["De potentieel-band is een schátting — die kan er flink naast zitten. Scouten trekt haar naar de waarheid én maakt tekenen makkelijker (+5% per scout, max +10%)."] = "The potential band is an ESTIMATE — it can be well off. Scouting pulls it towards the truth and makes signing easier (+5% per scout, max +10%)."
	d["Kantoor niveau %d (%s) brengt spelers tot rating ~%d binnen bereik. Je reputatie (%d) bepaalt of ze tekenen."] = "Office level %d (%s) brings players up to rating ~%d within reach. Your reputation (%d) decides whether they sign."
	d["Sorteer:"] = "Sort:"
	d["Rating"] = "Rating"
	d["Leeftijd"] = "Age"
	d["Scout"] = "Scout"
	d["Benader"] = "Approach"
	d["tekenkans %d%%"] = "signing chance %d%%"
	d["al benaderd dit seizoen"] = "already approached this season"
	d["%s tekent bij jou!"] = "%s signs with you!"
	d["%s wijst je af. 'Ik hoor goede verhalen over een ander kantoor.'"] = "%s turns you down. 'I hear good things about another agency.'"
	d["✔ %s tekent!"] = "✔ %s signs!"
	d["✗ afgewezen"] = "✗ rejected"
	d["Vertrouwen is je enige verdediging: onder de 60 loopt het vertrekrisico elk punt verder op. Een cliënt die zich gezien voelt, blijft — en luistert niet naar een rivaal."] = "Trust is your only defence: below 60 the risk of leaving climbs with every point. A client who feels seen stays — and doesn't listen to a rival."

	# ---- events ----
	d["EVENT: %s"] = "EVENT: %s"
	d["UITKOMST"] = "OUTCOME"
	d["Bij succes:"] = "On success:"
	d["Bij mislukking:"] = "On failure:"
	d["  (te weinig geld)"] = "  (not enough money)"
	d["  (geen gunst beschikbaar)"] = "  (no favour available)"
	d["  [%d%% kans]"] = "  [%d%% chance]"
	d["Je kunt geen van deze opties betalen. Er zit niets anders op dan het te laten lopen."] = "You can't afford any of these options. There's nothing to do but let it go."
	d["Geld"] = "Money"
	d["Reputatie"] = "Reputation"
	d["Schandaal"] = "Scandal"
	d["Gunsten"] = "Favours"
	d["Scoutpunten"] = "Scout points"
	d["Scoutpunten (voortaan)"] = "Scout points (from now on)"
	d["Vertrouwen (%s): %s"] = "Trust (%s): %s"
	d["%s Vertrouwen (%s)"] = "%s Trust (%s)"
	d["Vertrouwen (hele stal): %s"] = "Trust (whole roster): %s"
	d["%s Vertrouwen (hele stal)"] = "%s Trust (whole roster)"

	# ---- transferwindow ----
	d["TRANSFERWINDOW"] = "TRANSFER WINDOW"
	d["  — DEADLINE DAY!"] = "  — DEADLINE DAY!"
	d["TD's zijn nerveus vandaag: onderhandelen is makkelijker."] = "Directors are jumpy today: negotiating is easier."
	d["Je hebt geen cliënten om deals voor te sluiten..."] = "You have no clients to make deals for..."
	d["%s — rating %d, %s, waarde %s, %s"] = "%s — rating %d, %s, value %s, %s"
	d["contract loopt af"] = "contract expiring"
	d["contract nog %d jaar"] = "%d years left on contract"
	d["Alle interesse voor %s is dit venster al afgehandeld."] = "All interest in %s has already been dealt with this window."
	d["Geen acties meer over voor %s dit transferwindow."] = "No actions left for %s this transfer window."
	d["Contract dit window al verlengd. Geen nieuwe clubonderhandeling meer mogelijk."] = "Contract already extended this window. No further club negotiation possible."
	d["Onderhandel met %s (TD: %s)"] = "Negotiate with %s (director: %s)"
	d["Hoge rating: verlengen blijft een optie náást beide clubgesprekken, maar het tekengeld is lager — met clubs in de rij bindt hij zich niet goedkoop."] = "High rating: extending stays an option alongside both club talks, but the signing fee is lower — with clubs queuing up he won't commit cheaply."
	d["Contract verlengen (tekengeld ~%s)"] = "Extend contract (signing fee ~%s)"
	d["Verlengen kan pas in het laatste contractjaar."] = "Extending is only possible in the final contract year."
	d["Contract verlengd. Tekengeld: %s."] = "Contract extended. Signing fee: %s."
	d["Seizoen afronden →"] = "Finish season →"

	# ---- onderhandeling ----
	d["ONDERHANDELING"] = "NEGOTIATION"
	d["%s → %s"] = "%s → %s"
	d["Transfersom: %s   |   Jouw fee: %d%%"] = "Transfer fee: %s   |   Your cut: %d%%"
	d["Weerstand van TD %s: %s"] = "Resistance of director %s: %s"
	d["Rondes:"] = "Rounds:"
	d["Stemming: %s"] = "Mood: %s"
	d["Type: %s"] = "Type: %s"
	d["Type: onbekend — 'Aftasten' onthult het (blijft deze run bekend)."] = "Type: unknown — 'Probe' reveals it (stays known this run)."
	d["FLOW (%d op rij): je volgende zet krijgt +50%% effect!"] = "FLOW (%d in a row): your next move gets +50%% effect!"
	d["Reeks: 1 succes — nog één voor flow."] = "Streak: 1 success — one more for flow."
	d["DEAL! Jouw fee: %s"] = "DEAL! Your fee: %s"
	d["Geen deal."] = "No deal."
	d["  De relatie heeft een deuk."] = "  The relationship has taken a hit."
	d["%s  [%s, %s]%s"] = "%s  [%s, %s]%s"
	d["%s  [kost %d %s]"] = "%s  [costs %d %s]"
	d["ronde"] = "round"
	d["rondes"] = "rounds"
	d["Aftasten (leer deze TD kennen)"] = "Probe (get to know this director)"
	d["Charmeren"] = "Charm"
	d["Feiten & cijfers"] = "Facts & figures"
	d["Bluffen ('Er is nog een club...')"] = "Bluff ('There's another club...')"
	d["Deadline-druk"] = "Deadline pressure"
	d["Clausule aanbieden (kost fee)"] = "Offer a clause (costs fee)"
	d["kans ?"] = "chance ?"
	d["weerstand -%d"] = "resistance -%d"
	d["weerstand ?"] = "resistance ?"
	d["  (net mislukt — probeer iets anders)"] = "  (just failed — try something else)"
	d["Percentage verhogen (+%d%%, raakt weerstand/flow niet)"] = "Raise your cut (+%d%%, doesn't affect resistance/flow)"
	d["🪙 Gunst inzetten: deal direct rond"] = "🪙 Use a favour: deal done instantly"
	d["COMBO'S (opeenvolgende successen; ×1 per gesprek):"] = "COMBOS (consecutive successes; ×1 per talk):"
	d["%s %s (+%d)%s"] = "%s %s (+%d)%s"
	d["  [alleen tegen een %s TD]"] = "  [only against a %s director]"
	d["Transfer rond! Jij incasseert %s."] = "Transfer done! You collect %s."

	# ---- biedingsoorlog ----
	d["BIEDINGSOORLOG"] = "BIDDING WAR"
	d["Prijs bepaalt JOUW fee, voorwaarden bepalen zijn vertrouwen. Duw je de een op, dan zakt de ander."] = "Price sets YOUR fee, terms set his trust. Push one up and the other drops."
	d["   Prijs: %s   (jouw fee ~%s)"] = "   Price: %s   (your fee ~%s)"
	d["   Voorwaarden: %d/100 — %s"] = "   Terms: %d/100 — %s"
	d["   Geduld: %s"] = "   Patience: %s"
	d["%s: prijs omhoog  (+%s, voorwaarden -%d)"] = "%s: raise price  (+%s, terms -%d)"
	d["%s: voorwaarden omhoog  (+%d, prijs -%s)"] = "%s: raise terms  (+%d, price -%s)"
	d["%s: hier tekenen"] = "%s: sign here"
	d["Clubs tegen elkaar uitspelen — de achterblijvers trekken bij (kost hen geduld)"] = "Play the clubs against each other — the stragglers close the gap (costs them patience)"
	d["%s — afgehaakt"] = "%s — dropped out"
	d["%s — %s, voorwaarden %s."] = "%s — %s, terms %s."
	d["Transfer uit de biedingsoorlog! Jij incasseert %s."] = "Transfer from the bidding war! You collect %s."

	# ---- persconferentie ----
	d["PERSCONFERENTIE"] = "PRESS CONFERENCE"
	d["Publiekssympathie: %d/100"] = "Public sympathy: %d/100"
	d["Vragen:"] = "Questions:"
	d["⚡ SLOTVRAAG — dubbele inzet"] = "⚡ FINAL QUESTION — double stakes"
	d["MOMENTUM: je volgende succesvolle antwoord telt +50%% zwaarder!"] = "MOMENTUM: your next successful answer counts +50%% more!"
	d["Ontwijken — 'Daar ga ik nu niet op in.'"] = "Deflect — 'I won't go into that right now.'"
	d["Toegeven — vertel het eerlijke verhaal"] = "Concede — tell the honest story"
	d["Aanvallen — de vraag zelf onterecht noemen"] = "Attack — call the question itself unfair"

	# ---- poker ----
	d["POKER OM EEN TALENT"] = "POKER FOR A TALENT"
	d["Straat: %s   |   Pot: %s"] = "Street: %s   |   Pot: %s"
	d["Jouw kaarten: %s   |   Bord: %s"] = "Your cards: %s   |   Board: %s"
	d["Jouw stack: %s   |   Tegenstander: %s%s"] = "Your stack: %s   |   Opponent: %s%s"
	d["   |   Bij te leggen: %s"] = "   |   To call: %s"
	d["Tegenstander had: %s"] = "Opponent had: %s"
	d["Meegaan"] = "Call"
	d["Checken"] = "Check"
	d["Verhogen"] = "Raise"
	d["Passen (veilig wegwezen)"] = "Fold (walk away safely)"

	# ---- dobbelen ----
	d["DOBBELEN BIJ DE BOOKMAKER"] = "DICE AT THE BOOKMAKER"
	d["Inzet: %s"] = "Stake: %s"
	d["Herkansingen:"] = "Rerolls:"
	d["Uitbetaling op je inzet: 5 gelijke ogen ×10, 4 gelijk ×4, full house ×3, 3 gelijk ×1,5, twee paar ×0,5. Niets van dit alles? Dan ben je je inzet kwijt."] = "Payout on your stake: 5 of a kind ×10, 4 of a kind ×4, full house ×3, 3 of a kind ×1.5, two pair ×0.5. None of the above? You lose your stake."
	d["Tik dobbelstenen aan om ze vast te houden, gooi dan de rest opnieuw."] = "Tap dice to hold them, then reroll the rest."
	d["Opnieuw gooien (%d over)"] = "Reroll (%d left)"
	d["Nu stoppen, uitbetalen"] = "Stop now, cash out"
	d["Nu stoppen, uitbetalen  (+%d%% bonus)"] = "Stop now, cash out  (+%d%% bonus)"

	# ---- boekhoudpuzzel / fiscale schikking ----
	d["DE BOEKHOUDPUZZEL"] = "THE BOOKKEEPING PUZZLE"
	d["Vul elke rij en kolom met de cijfers 1-5, elk precies één keer."] = "Fill every row and column with the digits 1-5, each exactly once."
	d["Pogingen:"] = "Attempts:"
	d["Controleren"] = "Check"
	d["FISCALE SCHIKKING"] = "TAX SETTLEMENT"
	d["Kies per post hoe je ermee omgaat. Pas als alle drie gekozen zijn, kun je regelen."] = "Choose how to handle each item. Only once all three are chosen can you settle."
	d["Open aangeven"] = "Declare openly"
	d["Deels verhullen"] = "Partly conceal"
	d["Volledig verhullen"] = "Fully conceal"
	d["nog niet gekozen"] = "not chosen yet"
	d["    lukt: %s"] = "    works: %s"
	d["    mislukt: %s"] = "    fails: %s"
	d["Regelen →"] = "Settle →"

	# ---- simon says / anagram / speeddate ----
	d["MEDIATRAINING: SIMON SAYS"] = "MEDIA TRAINING: SIMON SAYS"
	d["Onthoud deze reeks:"] = "Memorise this sequence:"
	d["Ik heb het onthouden →"] = "I've memorised it →"
	d["Herhaal de reeks (stap %d/%d):"] = "Repeat the sequence (step %d/%d):"
	d["HET GELEKTE DOCUMENT"] = "THE LEAKED DOCUMENT"
	d["Woord %d/3: %s"] = "Word %d/3: %s"
	d["Tijd: %ds"] = "Time: %ds"
	d["Getypt: %s"] = "Typed: %s"
	d["⌫ Wis"] = "⌫ Clear"
	d["Indienen"] = "Submit"
	d["SPEED-DATEN OP DE SCOUTINGBEURS"] = "SPEED DATING AT THE SCOUTING FAIR"
	d["Vastgezet: %d/4"] = "Locked in: %d/4"
	d["Let op: een fout aanbod verbrandt de scout — hij is dan niet meer beschikbaar."] = "Careful: a wrong pitch burns the scout — he's then no longer available."
	d["✔ %s — vastgezet"] = "✔ %s — locked in"
	d["✘ %s — afgehaakt"] = "✘ %s — dropped out"
	d["Bevestigen"] = "Confirm"

	# ---- seizoensafsluiting / vertrek / einde ----
	d["SEIZOENSAFSLUITING"] = "SEASON WRAP-UP"
	d["📈 ONTWIKKELING"] = "📈 DEVELOPMENT"
	d["💥 JE RAAKT %s KWIJT"] = "💥 YOU'RE LOSING %s"
	d["VOORBEREIDE TRANSFER"] = "PREPARED TRANSFER"
	d["Dit is het gevolg van de medische info die je eerder off-the-record kreeg en waarop je een transfer voorbereidde."] = "This is the result of the medical information you got off the record earlier, on which you prepared a transfer."
	d["%s is verkocht aan een mysterieuze buitenlandse club."] = "%s has been sold to a mysterious foreign club."
	d["Transfersom: %s"] = "Transfer fee: %s"
	d["Jouw fee: %s"] = "Your fee: %s"
	d["De transfer van %s ging niet door — de prognose bleek onjuist."] = "The transfer of %s fell through — the prognosis turned out to be wrong."
	d["GAME OVER"] = "GAME OVER"
	d["Failliet. De deurwaarder neemt zelfs je gesigneerde shirtjes mee."] = "Bankrupt. The bailiff takes even your signed shirts."
	d["Je licentie is ingetrokken. De bond stuurt een koele brief; de pers een fotograaf."] = "Your licence has been revoked. The association sends a cold letter; the press sends a photographer."
	d["Je laatste cliënt is vertrokken. Een makelaar zonder spelers is gewoon een man met een telefoon."] = "Your last client has left. An agent without players is just a man with a phone."
	d["De run is voorbij."] = "The run is over."
	d["Seizoenen overleefd: %d"] = "Seasons survived: %d"
	d["Totaal aan fees verdiend: %s"] = "Total fees earned: %s"
	d["+%s legacy points verdiend  →  totaal %s"] = "+%s legacy points earned  →  total %s"
	d["Legacy points: %s"] = "Legacy points: %s"
	d["Perks bekijken →"] = "View perks →"
	d["Nieuwe run"] = "New run"
	d["JE HEBT HET GEHAALD"] = "YOU MADE IT"
	d["Je overleefde alle %d seizoenen. Van snackbar-kantoor naar gevestigde naam."] = "You survived all %d seasons. From a chip-shop office to an established name."
	d["EINDSCORE (totaal aan fees): %s"] = "FINAL SCORE (total fees): %s"
	d["Rang: SUPERAGENT. Jouw naam gonst door elke bestuurskamer."] = "Rank: SUPERAGENT. Your name buzzes through every boardroom."
	d["Rang: Gevestigde makelaar. Netjes — maar de top lonkt."] = "Rank: Established agent. Respectable — but the top still beckons."
	d["Rang: Overlever. Je bestaat nog. Dat is niet hetzelfde als winnen."] = "Rank: Survivor. You still exist. That's not the same as winning."
	d["Waarvan %s KAMPIOENSBONUS — 12%% van je hele carrière-saldo, in één klap."] = "Of which %s CHAMPION BONUS — 12%% of your entire career balance, in one go."

	# ---- perkboom ----
	d["PERKBOOM — %s legacy points"] = "PERK TREE — %s legacy points"
	d["Boom voltooid: %s%%  (%s van %s punten)"] = "Tree completed: %s%%  (%s of %s points)"
	d["Permanente upgrades voor elke volgende run. Je verdient legacy points door te spelen — hoe verder je komt, hoe exponentieel meer (een gewonnen run = 1%% van de boom). Elke rij biedt 3 opties; koop %d niveaus in een rij om de rij eronder te ontgrendelen (of alles wat die rij te bieden heeft, als dat er minder zijn)."] = "Permanent upgrades for every following run. You earn legacy points by playing — the further you get, the exponentially more (a won run = 1%% of the tree). Each row offers 3 options; buy %d levels in a row to unlock the row below it (or everything that row has to offer, if that's fewer)."
	d["◆ TAK: %s"] = "◆ BRANCH: %s"
	d["— Rij %d —"] = "— Row %d —"
	d["🔒 Rij %d (%s) — vereist %d niveaus in rij %d (nu %d)."] = "🔒 Row %d (%s) — requires %d levels in row %d (now %d)."
	d["★ OVERPOWERED — extra's buiten de boom (tellen niet mee voor de 100%)"] = "★ OVERPOWERED — extras outside the tree (don't count towards the 100%)"
	d["nu: "] = "now: "
	d["volgend niveau: "] = "next level: "
	d["MAX bereikt."] = "MAX reached."
	d["Koop %s niveau %d  (%s punten)"] = "Buy %s level %d  (%s points)"
	d["Koop %s  (%d %s)"] = "Buy %s  (%d %s)"
	d["  %s  (%d %s)%s"] = "  %s  (%d %s)%s"
	d["  ✔ ACTIEF"] = "  ✔ ACTIVE"
	d["✦ ERFENIS-PERKS — %d Prestige-%s"] = "✦ LEGACY PERKS — %d Prestige %s"
	d["Bonussen die je NOOIT met gewone legacy points kunt kopen — alleen met Prestige-sterren. Die krijg je door te prestigen: je hele perkboom resetten NA een gewonnen run, zonder puntenrefund."] = "Bonuses you can NEVER buy with ordinary legacy points — only with Prestige stars. You get those by prestiging: resetting your entire perk tree AFTER a won run, with no point refund."
	d["✦ Prestige (perkboom weg, +1 Prestige-ster)"] = "✦ Prestige (perk tree gone, +1 Prestige star)"
	d["Weet je het zeker? Je hele perkboom (%s punten aan niveaus) gaat naar 0 — GEEN refund — in ruil voor 1 Prestige-ster."] = "Are you sure? Your entire perk tree (%s points worth of levels) goes to 0 — NO refund — in exchange for 1 Prestige star."
	d["JA — prestige nu"] = "YES — prestige now"
	d["Prestigen kan pas vanaf %s%% boomvoortgang (nu %s%%) — bij te weinig opgebouwd stelt de opoffering niets voor."] = "Prestiging only becomes available at %s%% tree progress (now %s%%) — with too little built up the sacrifice means nothing."
	d["Resetten kan via ⚙ Instellingen op het startscherm."] = "Resetting is available via ⚙ Settings on the start screen."

	# ---- developer ----
	d["DEVELOPER"] = "DEVELOPER"
	d["DEVELOPER — puntenbeheer"] = "DEVELOPER — point management"
	d["Voer het developer-wachtwoord in."] = "Enter the developer password."
	d["Huidig puntensaldo: %s legacy points."] = "Current point balance: %s legacy points."
	d["Dit wist alleen het saldo, niet de gekochte perk-niveaus (gebruik daarvoor 'Reset perkboom' in ⚙ Instellingen)."] = "This wipes only the balance, not the purchased perk levels (use 'Reset perk tree' in ⚙ Settings for that)."
	d["Weet je het zeker? Het puntensaldo gaat naar 0 en dit kan niet ongedaan worden."] = "Are you sure? The point balance goes to 0 and this cannot be undone."
	d["JA — wis puntensaldo"] = "YES — wipe point balance"
	d["Wis alle punten (naar 0)"] = "Wipe all points (to 0)"
	d["Testmodus: doorloopt ALLE %d events op volgorde, met onbeperkt geld en zonder fail-checks. Start een verse testrun in het geheugen — je opgeslagen run blijft veilig op schijf."] = "Test mode: walks through ALL %d events in order, with unlimited money and no fail checks. Starts a fresh test run in memory — your saved run stays safe on disk."
	d["Test: doorloop alle events →"] = "Test: walk through all events →"
	d["Testrun klaar: alle %d events doorlopen."] = "Test run finished: walked through all %d events."
	d["[DEV TEST] Event %d/%d — id: %s"] = "[DEV TEST] Event %d/%d — id: %s"
	d["Geheim kantoorniveau 6 (De Kampioenssuite): %s"] = "Secret office level 6 (The Champions Suite): %s"
	d["ontgrendeld"] = "unlocked"
	d["nog vergrendeld"] = "still locked"
	d["Zet uit (test)"] = "Turn off (test)"
	d["Forceer ontgrendeld (test)"] = "Force unlocked (test)"
	d["← Terug naar start"] = "← Back to start"
	d["Nieuwe upgrades ingeladen."] = "New upgrades loaded."
	d["Te weinig geld om te rerollen."] = "Not enough money to reroll."

	return d
