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

	return d
