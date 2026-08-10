# main.gd — de volledige UI, programmatisch opgebouwd.
# Elke fase van een seizoen is een "scherm": prep → scouting → events →
# transferwindow → afsluiting. Game (autoload) bevat alle logica en staat.
extends Control

var header: RichTextLabel   # BBCode aan, zodat "Gunsten" er goudkleurig uit kan springen
var content: VBoxContainer

# Achtergrond die per kantoorniveau wisselt. Standaard een procedureel
# sfeerverloop (OFFICE_BG_GRADIENTS) — geen assets nodig. Wil je echte art: leg
# office_1.png t/m office_6.png in res://art/ en die gaat automatisch vóór het
# verloop. Een halfdoorzichtige scrim eroverheen houdt de tekst altijd leesbaar.
var office_bg: TextureRect
var office_bg_fallback: ColorRect
var office_scrim: ColorRect
var _bg_level := -1
const OFFICE_BG_COLORS := [
	Color(0.15, 0.09, 0.07),   # 1 Boven de Snackbar — warm bruin/patatneon
	Color(0.10, 0.12, 0.11),   # 2 De Portacabin — tl-grijsgroen
	Color(0.09, 0.13, 0.11),   # 3 Het Grachtenpand — hout/grachtgroen
	Color(0.07, 0.10, 0.16),   # 4 De Glazen Toren — koel glasblauw
	Color(0.06, 0.13, 0.15),   # 5 Monaco — turquoise Middellandse Zee
	Color(0.16, 0.12, 0.03),   # 6 De Kampioenssuite — donker champagnegoud
]

# Sfeerverloop per kantoorniveau: [boven, horizon-accent, onder]. Een effen
# kleur alleen maakte niveau 1 en 6 in de praktijk bijna niet te onderscheiden;
# een verticaal verloop met een lichtere band op ~55% leest als "een ruimte met
# een raam" en geeft elk niveau een eigen gezicht — zónder art-assets.
# Bewust allemaal DONKER: er ligt een scrim van 45% zwart over en de tekst moet
# leesbaar blijven. Zodra res://art/office_<n>.png bestaat gaat die hier vóór.
const OFFICE_BG_GRADIENTS := [
	[Color(0.10, 0.06, 0.05), Color(0.28, 0.13, 0.06), Color(0.08, 0.05, 0.04)],  # 1 patatneon
	[Color(0.09, 0.11, 0.10), Color(0.16, 0.20, 0.18), Color(0.07, 0.09, 0.08)],  # 2 tl-licht
	[Color(0.07, 0.11, 0.09), Color(0.13, 0.19, 0.15), Color(0.09, 0.08, 0.06)],  # 3 gracht + hout
	[Color(0.05, 0.08, 0.14), Color(0.10, 0.16, 0.26), Color(0.06, 0.07, 0.11)],  # 4 stad onder glas
	[Color(0.05, 0.11, 0.14), Color(0.09, 0.24, 0.26), Color(0.14, 0.12, 0.09)],  # 5 zee + kust
	[Color(0.10, 0.08, 0.03), Color(0.30, 0.22, 0.06), Color(0.08, 0.06, 0.02)],  # 6 champagnegoud
]

var event_queue: Array = []
var interest: Dictionary = {}      # client_id -> Array van (nog niet gebruikte) club_ids
var interest_total: Dictionary = {} # client_id -> oorspronkelijk aantal geïnteresseerde clubs
var candidates: Array = []         # scouting/tekendoelen dit seizoen
var approached: Array = []         # al benaderd dit seizoen (één poging p.p.)
var release_selection: Array = []  # cid's die je in stalbeheer hebt geselecteerd om weg te sturen
var extended: Array = []           # contract al verlengd dit window
var flash := ""                    # korte statusmelding bovenin een scherm
var flash_color = null             # optionele kleur voor de flash (Color of null)
var scout_sort := "rating"         # sorteersleutel scoutinglijst: "rating" of "age"
var scout_sort_desc := true        # true = hoog→laag

var nego: Negotiation = null
var nego_client := ""
var nego_club := ""

# Event-minigames: precies één van deze is actief tijdens een minigame-event.
var mg_ev: Dictionary = {}          # het originerende event (voor client_id, terugkeer)
var press: PressConference = null
var tax: TaxSettlement = null
var poker: PokerBluff = null
var poker_notes: Array = []
var poker_applied := false
var dice: DiceBookmaker = null
var accounting: AccountingPuzzle = null
var anagram: AnagramHunt = null
var scoutdate: ScoutSpeedDate = null
var simon: SimonMedia = null

# Anagramjacht heeft een ECHTE klok (Godot _process), geen beurt-gebaseerde
# ronde — vandaar deze aparte trackingvariabelen.
var anagram_active := false
var anagram_round_started_idx := -1
var anagram_time_left := 0.0
var anagram_timer_label: Label = null

var home_btn: Button
var inf_btn: Button                # ∞-upgrade, klein vierkant rechtsboven op het perkscherm
var confirm_prestige := false      # tweestaps-bevestiging voor prestigen (perkboom weg, GEEN refund)

# Permanent info-schermpje onderaan: hover werkt niet betrouwbaar (o.a. op
# touch/mobiel), dus toont dit gewoon altijd de stats van de relevante
# cliënt zodra een event/minigame een speler noemt.
var player_info_panel: PanelContainer
var player_info_holder: VBoxContainer

# Het infopaneel ZWEEFT onderaan over de content heen (het hangt aan de root,
# niet in de scroll-layout). Zonder compensatie verdwijnt de onderste knop van
# een lang event dus achter dat paneel. `root_margin` krijgt daarom een grotere
# ondermarge zolang het paneel zichtbaar is, zodat de scrollbare content boven
# het paneel eindigt i.p.v. eronder door te lopen.
var root_margin: MarginContainer
const MARGIN_BOTTOM_BASE := 28
# Paneel loopt van 156px tot 12px boven de onderkant; +8 lucht ertussen.
const MARGIN_BOTTOM_WITH_PANEL := 164

# Vaste (niet-scrollende) balk vlak boven de scrollende content: toont de
# beurten/pogingen/scoutpunten-blokjes zodat ze altijd zichtbaar blijven,
# ook als je in een lange log naar beneden scrollt.
var turn_bar: Control

# ---- Developer-only puntenreset: verborgen achter een tik-sequentie + wachtwoord.
# Geen echte beveiliging (GDScript-bronnen zijn leesbaar), maar voorkomt dat
# spelers of testers er per ongeluk tegenaan lopen.
const DEV_PASSWORD := "wachtwoord"
const DEV_TAPS_NEEDED := 7
var dev_taps := 0
var dev_unlocked := false
var dev_confirm := false

# ---- Developer-only eventtest: doorloopt ALLE events achter elkaar, met
# onbeperkt geld en zonder fail-checks, zodat je elke tekst/minigame kunt zien.
const DEV_TEST_MONEY := 999999999
var dev_test_mode := false
var dev_test_index := 0
var dev_test_total := 0
var dev_test_all: Array = []
var dev_jump_input: LineEdit = null

var bank_deposit_slider: HSlider = null
var bank_deposit_label: Label = null

var shop_offers: Array = []


# ---------------------------------------------------------------- opbouw

func _process(delta: float) -> void:
	if not anagram_active or anagram == null or anagram.finished:
		return
	anagram_time_left -= delta
	if anagram_time_left <= 0.0:
		anagram_time_left = 0.0
		_anagram_timeout()
	elif anagram_timer_label != null and is_instance_valid(anagram_timer_label):
		anagram_timer_label.text = T("Tijd: %ds") % int(ceil(anagram_time_left))


func _ready() -> void:
	var th := Theme.new()
	th.default_font_size = 30
	theme = th

	# Achtergrondlagen, helemaal achteraan (vóór de margin/inhoud toegevoegd):
	# effen sfeerkleur → optionele art-texture → donkere scrim voor leesbaarheid.
	office_bg_fallback = ColorRect.new()
	office_bg_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	office_bg_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	office_bg_fallback.color = OFFICE_BG_COLORS[0]
	add_child(office_bg_fallback)
	office_bg = TextureRect.new()
	office_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	office_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	office_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	office_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	office_bg.visible = false
	add_child(office_bg)
	office_scrim = ColorRect.new()
	office_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	office_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	office_scrim.color = Color(0.0, 0.0, 0.0, 0.45)
	add_child(office_scrim)

	root_margin = MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 28)
	root_margin.add_theme_constant_override("margin_right", 28)
	root_margin.add_theme_constant_override("margin_top", 28)
	root_margin.add_theme_constant_override("margin_bottom", MARGIN_BOTTOM_BASE)
	add_child(root_margin)
	var margin := root_margin

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	header = RichTextLabel.new()
	header.bbcode_enabled = true
	header.fit_content = true
	header.scroll_active = false
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("normal_font_size", 24)
	vbox.add_child(header)

	turn_bar = HBoxContainer.new()
	turn_bar.add_theme_constant_override("separation", 10)
	turn_bar.visible = false
	vbox.add_child(turn_bar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	# Home-knop rechtsonder, zweeft boven alles; verborgen op het startscherm.
	home_btn = Button.new()
	home_btn.text = "🏠"
	home_btn.add_theme_font_size_override("font_size", 36)
	# Anker en offsets: zie _apply_layout_direction() — die klapt ze om bij RTL.
	home_btn.pressed.connect(_go_home)
	add_child(home_btn)

	# Permanent speler-infopaneel onderaan (vervangt hover, die niet overal
	# betrouwbaar werkt). Laat ruimte vrij voor de home-knop rechtsonder.
	player_info_panel = PanelContainer.new()
	player_info_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	player_info_panel.offset_left = 12
	player_info_panel.offset_right = -140
	# Hoger dan voorheen (was -100): er staat nu een volledige spelerkaart in
	# i.p.v. één regel tekst met twee kleine badges.
	player_info_panel.offset_top = -156
	player_info_panel.offset_bottom = -12
	player_info_panel.visible = false
	player_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.08, 0.08, 0.11, 0.94)
	info_style.set_corner_radius_all(10)
	info_style.content_margin_left = 12
	info_style.content_margin_right = 12
	info_style.content_margin_top = 8
	info_style.content_margin_bottom = 8
	player_info_panel.add_theme_stylebox_override("panel", info_style)
	add_child(player_info_panel)

	# Houder waarin _show_player_info() de échte spelerkaart (_player_card())
	# neerzet, zodat een speler er bij een event/minigame precies zo uitziet
	# als in de scoutinglijst en je stal.
	player_info_holder = VBoxContainer.new()
	player_info_panel.add_child(player_info_holder)

	# ∞-upgrade: klein vierkantje rechtsboven, alleen zichtbaar op het
	# perkscherm. Vaste prijs, oneindig te kopen, +0,1% punten per niveau.
	inf_btn = Button.new()
	inf_btn.add_theme_font_size_override("font_size", 18)
	# Anker en offsets: zie _apply_layout_direction().
	inf_btn.pressed.connect(_buy_inf)
	inf_btn.visible = false
	add_child(inf_btn)

	_apply_layout_direction()
	show_start()


# RTL-talen (nu alleen Arabisch). We zetten layout_direction op de ROOT: elke
# Control erft dat standaard, dus Godot spiegelt zelf de ordening in HBox- en
# GridContainers en de tekstuitlijning van Labels/Buttons. Wat het NIET doet is
# ankers spiegelen — die zijn absoluut. Daarom worden de twee zwevende knoppen
# hieronder met de hand omgeklapt. De → -pijlen zitten in de vertaaltabel (het
# Arabisch gebruikt ←), dus die hoeven hier niet.
func _apply_layout_direction() -> void:
	var rtl := I18n.is_rtl()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
	# Home-knop: 80×80, 24 px uit de hoek, onderaan.
	if rtl:
		home_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		home_btn.offset_left = 24
		home_btn.offset_right = 104
	else:
		home_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		home_btn.offset_left = -104
		home_btn.offset_right = -24
	home_btn.offset_top = -104
	home_btn.offset_bottom = -24
	# ∞-knop: 136×136, 24 px uit de hoek, bovenaan.
	if rtl:
		inf_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		inf_btn.offset_left = 24
		inf_btn.offset_right = 160
	else:
		inf_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		inf_btn.offset_left = -160
		inf_btn.offset_right = -24
	inf_btn.offset_top = 24
	inf_btn.offset_bottom = 160


func _go_home() -> void:
	# Terug naar het startscherm. Een run wordt alleen aan het eind van een
	# seizoen opgeslagen; "Doorgaan" pakt dus het begin van dit seizoen op.
	show_start()


# ---------------------------------------------------------------- helpers

# Korte alias voor de vertaallaag. Vertaal ALTIJD vóór het interpoleren:
#   goed:  lbl(T("Seizoen %d/%d") % [a, b])
#   fout:  lbl(T("Seizoen %d/%d" % [a, b]))   <- zoekt een ingevulde string op
func T(nl: String) -> String:
	return I18n.T(nl)


func clear() -> void:
	for c in content.get_children():
		c.queue_free()
	if home_btn:
		home_btn.visible = true
	if inf_btn:
		inf_btn.visible = false
	_show_player_info("")
	# De turn-bar is scherm-specifiek: elk scherm dat 'm nodig heeft, zet 'm
	# opnieuw via _set_turn_bar(). Zonder deze reset zou de balk van het
	# vorige scherm blijven hangen op een scherm zonder eigen teller.
	if turn_bar:
		for c in turn_bar.get_children():
			c.queue_free()
		turn_bar.visible = false


func lbl(text: String, size := 28) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(l)
	return l


func btn(text: String, cb: Callable, enabled := true, font_size := 0) -> Button:
	# font_size 0 = themastandaard. Alleen opgeven waar de knop in een smalle
	# kolom staat (de tactieken in de onderhandeling), want daar wrapt de
	# standaardgrootte over drie regels.
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size > 0:
		b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(0, 72 if font_size == 0 else 60)
	b.pressed.connect(cb)
	content.add_child(b)
	return b


# Kansbalk op een keuzeknop: de knop ZELF is de meter. Groen vanaf de leidende
# rand tot de slaagkans, rood daarna. Vervangt de oude "[65% kans]"-tekst — een
# balk laat je in één blik zien hoe groot het risico is, zonder te rekenen.
const CHANCE_GREEN := Color(0.16, 0.42, 0.21)
const CHANCE_RED := Color(0.46, 0.15, 0.15)


func _chance_style(ratio: float, tint := 0.0) -> StyleBoxTexture:
	var p := clampf(ratio, 0.0, 1.0)
	var green := CHANCE_GREEN
	var red := CHANCE_RED
	if tint > 0.0:
		green = green.lightened(tint)
		red = red.lightened(tint)
	elif tint < 0.0:
		green = green.darkened(-tint)
		red = red.darkened(-tint)
	var g := Gradient.new()
	# Twee stops vlak naast elkaar i.p.v. exact op dezelfde offset: dat geeft een
	# harde grens zonder te leunen op hoe Gradient met dubbele offsets omgaat. De
	# overgang is 0,002 breed — op 256 px is dat een halve pixel.
	g.offsets = PackedFloat32Array([0.0, maxf(p - 0.001, 0.0), minf(p + 0.001, 1.0), 1.0])
	g.colors = PackedColorArray([green, green, red, red])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR
	# In een RTL-taal vult de balk vanaf RECHTS, zodat hij dezelfde leesrichting
	# volgt als de tekst erop.
	if I18n.is_rtl():
		t.fill_from = Vector2(1.0, 0.0)
		t.fill_to = Vector2(0.0, 0.0)
	else:
		t.fill_from = Vector2(0.0, 0.0)
		t.fill_to = Vector2(1.0, 0.0)
	t.width = 256
	t.height = 8
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.set_content_margin_all(10)
	return sb


func _style_chance_button(b: Button, ratio: float) -> void:
	# Alle states zetten, anders valt de balk weg zodra je de knop aanraakt of
	# hij uitgeschakeld is (dan pakt Godot weer de themastijl).
	b.add_theme_stylebox_override("normal", _chance_style(ratio))
	b.add_theme_stylebox_override("hover", _chance_style(ratio, 0.15))
	b.add_theme_stylebox_override("pressed", _chance_style(ratio, -0.15))
	b.add_theme_stylebox_override("focus", _chance_style(ratio, 0.08))
	b.add_theme_stylebox_override("disabled", _chance_style(ratio, -0.5))


# Uitkomsten van een kansoptie NAAST elkaar i.p.v. gestapeld: succes aan de
# leidende kant, mislukking aan de andere. Zo staat elke kolom aan dezelfde kant
# als de kleur op de kansbalk erboven (groen links, rood rechts) en is de
# afweging in één blik te maken zonder te scrollen.
#
# Beide kolommen krijgen EXPAND_FILL, ook een lege: anders schuift de gevulde
# kolom naar het midden zodra de andere kant geen effecten heeft.
func _outcome_columns(succ_rows: Array, fail_rows: Array) -> void:
	if succ_rows.is_empty() and fail_rows.is_empty():
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	# In een RTL-taal spiegelt Godot de kindorde van een HBoxContainer zelf; door
	# de uitlijning mee te spiegelen blijft elke kolom tegen de buitenrand staan.
	var lead := HORIZONTAL_ALIGNMENT_RIGHT if I18n.is_rtl() else HORIZONTAL_ALIGNMENT_LEFT
	var trail := HORIZONTAL_ALIGNMENT_LEFT if I18n.is_rtl() else HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_outcome_column(T("Bij succes:"), succ_rows, lead))
	row.add_child(_outcome_column(T("Bij mislukking:"), fail_rows, trail))


func _outcome_column(header: String, rows: Array, align: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	if rows.is_empty():
		return col
	var h := Label.new()
	h.text = header
	h.add_theme_font_size_override("font_size", 18)
	h.horizontal_alignment = align
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(h)
	for r in rows:
		var l := Label.new()
		l.text = str(r.text)
		l.add_theme_font_size_override("font_size", 19)
		l.horizontal_alignment = align
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Color(0.35, 0.9, 0.4) if bool(r.good) else Color(1.0, 0.35, 0.35))
		col.add_child(l)
	return col


func sep() -> void:
	content.add_child(HSeparator.new())


func eur(n) -> String:
	var v := int(n)
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-€" if v < 0 else "€") + out


# ---------------------------------------------------------------- speler-tooltip
# Je hoeft niet te onthouden welke speler welke stats heeft: bij elke naam in
# een event/minigame kun je hoveren voor een schermpje met zijn kerngegevens.
# Gebruikt Control.tooltip_text op een los Label i.p.v. een BBCode-hint-tag
# (die bleek niet betrouwbaar op hover te reageren) — tooltip_text is een
# kernfunctie van elke Control en werkt dus altijd.

func _player_tooltip(pid: String) -> String:
	if pid == "" or not Game.state.players.has(pid):
		return ""
	var p: Dictionary = Game.state.players[pid]
	# Zit iemand in je stal, dan ken je zijn echte potentieel — geen schatting/band
	# meer, gewoon de exacte waarde. Voor de rest blijft het een geschatte band.
	var pot_str := ""
	if pid in Game.state.clients:
		pot_str = T("potentieel %d") % int(p.pot)
	else:
		var lo := maxi(Game.estimate(pid) - int(p.unc), int(p.rating))
		var hi := mini(Game.estimate(pid) + int(p.unc), 95)
		pot_str = T("potentieel ca. %d–%d") % [lo, hi]
	# Clubs staan voorlopig buiten beeld (cosmetisch) — geen waarde momenteel.
	return T("%s — %s, %d jr\nRating %d (%s)\nVertrouwen %d\nWaarde %s") % [
		str(p.name), str(p.pos), int(p.age), int(p.rating), pot_str,
		int(p.trust), eur(Game.value(p)),
	]


# Vult het permanente infopaneel onderaan met de kerngegevens van pid, of
# verbergt het als er geen (bekende) speler relevant is. Dit is de
# betrouwbare vervanging voor hover (die niet overal werkt, bijv. op touch).
func _reserve_panel_space(reserve: bool) -> void:
	# Houdt de onderkant van de scrollbare content vrij van het zwevende
	# infopaneel, zodat de laatste knop van een event nooit onbereikbaar is.
	if root_margin == null:
		return
	root_margin.add_theme_constant_override("margin_bottom",
		MARGIN_BOTTOM_WITH_PANEL if reserve else MARGIN_BOTTOM_BASE)


func _show_player_info(pid: String) -> void:
	if player_info_panel == null:
		return
	# Uit te zetten via Instellingen: scheelt schermruimte bij events/minigames.
	if pid == "" or not Game.state.players.has(pid) or not bool(Meta.setting("player_panel")):
		player_info_panel.visible = false
		_reserve_panel_space(false)
		return
	player_info_panel.visible = true
	_reserve_panel_space(true)
	if player_info_holder == null:
		return
	# Kaart opnieuw opbouwen. remove_child vóór queue_free(): queue_free is
	# uitgesteld tot einde frame, dus zonder remove zou de oude kaart deze
	# frame nog meetellen voor de layout en het paneel opblazen.
	for c in player_info_holder.get_children():
		player_info_holder.remove_child(c)
		c.queue_free()
	var p: Dictionary = Game.state.players[pid]
	var sub := T("%s, %d jr") % [str(p.pos), int(p.age)]
	if pid in Game.state.clients:
		sub += T(" · vertrouwen %d") % int(p.trust)
	sub += T(" · waarde %s") % eur(Game.value(p))
	player_info_holder.add_child(_player_card(pid, sub))


# Rij tekst met de spelernaam als apart, gekleurd Label tussen een voor- en
# nastuk platte tekst — allemaal met autowrap, anders loopt een lange
# event-paragraaf zo van het scherm af. In een HFlowContainer zodat het als
# lopende zin blijft aanvoelen. Stats staan in het infopaneel onderaan
# (_show_player_info), niet meer via hover.
func _name_row(before: String, pid: String, after: String, size := 24) -> void:
	# Alleen voor KORTE statusregels (naam + wat cijfers) — geen autowrap
	# nodig of gewenst: binnen een HFlowContainer duwt autowrap een Label
	# zonder vaste breedte terug naar zijn minimale (soms 1 letter brede)
	# grootte, waardoor de tekst verticaal, letter voor letter, uiteenvalt.
	# Lange lopende tekst (event-paragrafen) gaat via een gewone lbl().
	_show_player_info(pid)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	content.add_child(flow)

	if before != "":
		var lb := Label.new()
		lb.text = before
		lb.add_theme_font_size_override("font_size", size)
		flow.add_child(lb)

	var known: bool = pid != "" and Game.state.players.has(pid)
	var name_lbl := Label.new()
	name_lbl.text = str(Game.state.players[pid].name) if known else "?"
	name_lbl.add_theme_font_size_override("font_size", size)
	if known:
		name_lbl.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
	flow.add_child(name_lbl)

	if after != "":
		var la := Label.new()
		la.text = after
		la.add_theme_font_size_override("font_size", size)
		flow.add_child(la)


func refresh_header() -> void:
	var s: Dictionary = Game.state
	header.text = T("Seizoen %d/%d  |  %s  |  Rep %d  |  Schandaal %d  |  [color=#ffd633]Gunsten %d[/color]  |  Stal %d/%d  |  🏢 Nv.%d %s") % [
		int(s.season), Game.MAX_SEASONS, eur(s.money),
		int(s.rep), int(s.scandal), int(s.favors),
		s.clients.size(), Game.client_cap(),
		Game.office_level(), Game.office_name(),
	]
	_update_office_background()


func _update_office_background() -> void:
	# Wisselt de achtergrond bij een niveauwissel (en niet vaker — texture
	# laden is niet gratis). Laadt res://art/office_<niveau>.png als die bestaat,
	# anders de effen sfeerkleur van dat niveau.
	if office_bg == null:
		return
	# Uit te zetten via Instellingen: dan een effen donkere achtergrond, geen
	# beeld en geen sfeerkleur per niveau (rustiger te lezen).
	if not bool(Meta.setting("office_bg")):
		_bg_level = -1
		office_bg.texture = null
		office_bg.visible = false
		office_bg_fallback.color = Color(0.07, 0.07, 0.09)
		return
	var lvl := Game.office_level()
	if lvl == _bg_level:
		return
	_bg_level = lvl
	# Defensief geclampt: mocht Game.OFFICE_LEVELS ooit meer niveaus tellen dan
	# er kleuren gedefinieerd zijn, dan valt dit terug op de laatste kleur
	# i.p.v. te crashen op een out-of-bounds index (zoals eerder gebeurde bij
	# het geheime niveau 6 vóórdat deze array werd bijgewerkt).
	office_bg_fallback.color = OFFICE_BG_COLORS[clampi(lvl - 1, 0, OFFICE_BG_COLORS.size() - 1)]
	var path := "res://art/office_%d.png" % lvl
	if ResourceLoader.exists(path):
		# Echte art: aspect bewaren en de randen laten afsnijden.
		office_bg.texture = load(path)
		office_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		office_bg.visible = true
	else:
		# Geen art: procedureel verloop. Dat mag juist wél uitgerekt worden —
		# een verticaal verloop heeft geen aspect om te bewaren.
		office_bg.texture = _office_gradient(lvl)
		office_bg.stretch_mode = TextureRect.STRETCH_SCALE
		office_bg.visible = true


func _office_gradient(lvl: int) -> GradientTexture2D:
	var stops: Array = OFFICE_BG_GRADIENTS[clampi(lvl - 1, 0, OFFICE_BG_GRADIENTS.size() - 1)]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([stops[0], stops[1], stops[2]])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.0, 0.0)   # van boven…
	t.fill_to = Vector2(0.0, 1.0)     # …naar onder
	# 4 px breed volstaat: er zit geen horizontale variatie in en de TextureRect
	# rekt hem toch op. Hoog genoeg voor een vloeiend verloop zonder banding.
	t.width = 4
	t.height = 512
	return t


func show_flash() -> void:
	if flash != "":
		var l := lbl(T(">> ") + flash, 24)
		if flash_color != null:
			l.add_theme_color_override("font_color", flash_color as Color)
		flash = T("")
		flash_color = null


func _discard_flash() -> void:
	# Voor schermen waar we de meldingsregel bewust niet tonen (het resultaat
	# is al zichtbaar via de bijgewerkte staat zelf): leegt flash zonder 'm te
	# tonen, zodat een oude melding niet alsnog opduikt zodra je naar een
	# scherm gaat dat wél show_flash() aanroept.
	flash = T("")
	flash_color = null


# ---------------------------------------------------------------- startscherm

func show_start() -> void:
	clear()
	home_btn.visible = false
	header.text = T("VOETBALMAKELAAR")
	lbl(T("Van kelderkantoor naar superagent."), 34)
	lbl(T("Overleef %d seizoenen. Ga niet failliet, houd je schandaalmeter onder de 100 en zorg dat je cliënten je niet verlaten.") % Game.MAX_SEASONS, 26)
	sep()
	lbl(T("LEGACY — %d runs gespeeld  |  beste run: %s (seizoen %d)  |  totale carrièrefees: %s") % [
		int(Meta.state.runs_completed), eur(Meta.state.best_fees), int(Meta.state.best_season),
		eur(Meta.state.total_career_fees),
	], 21)
	btn(T("Perkboom (%s legacy points te besteden) →") % _pts(Meta.state.legacy_points), show_perks)
	if Meta.has_pending_boost():
		var boost_lbl := lbl(T("🚀 MEGA-BOOST KLAAR: je volgende nieuwe run start met dubbel startkapitaal, +25 reputatie, +1 gunst en +2 scoutpunten per seizoen."), 21)
		boost_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	sep()
	btn(T("NIEUWE RUN"), _on_new_run)
	if Game.has_save():
		btn(T("Doorgaan met vorige run"), _on_continue)
	if not Meta.state.hall_of_fame.is_empty():
		sep()
		lbl(T("🏆 HALL OF FAME"), 26)
		for entry in Meta.state.hall_of_fame:
			var cname: String = str(entry.client_name)
			# Geen seizoen erbij: je komt hier alleen in met een gewonnen run, en
			# winnen kan pas ná MAX_SEASONS — dat cijfer is dus altijd 15.
			lbl(T("  %s — %s") % [
				cname if cname != "" else T("Naamloze topper"), eur(int(entry.total_fees)),
			], 20)
	sep()
	btn(T("⚙ Instellingen →"), show_settings)
	var dev_tap := btn(T("v1.0"), _on_dev_tap)
	dev_tap.add_theme_font_size_override("font_size", 14)
	dev_tap.modulate = Color(1, 1, 1, 0.25)
	dev_tap.custom_minimum_size = Vector2(0, 36)


# ---------------------------------------------------------------- instellingen

var settings_confirm := ""   # welke gevaarlijke actie op bevestiging wacht ("" = geen)


func _setting_toggle_btn(key: String, label: String, hint := "") -> void:
	var on := bool(Meta.setting(key))
	var b := btn(T("%s  —  %s") % [T(label), T("AAN") if on else T("UIT")], func(): _toggle_setting(key))
	b.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85) if on else Color(0.7, 0.7, 0.72))
	if hint != "":
		lbl(T("    ") + T(hint), 18)


func _toggle_setting(key: String) -> void:
	Meta.toggle_setting(key)
	# Achtergrond direct toepassen, anders zie je de wissel pas een scherm later.
	if key == "office_bg":
		_bg_level = -1
		_update_office_background()
	show_settings()


func show_settings() -> void:
	clear()
	home_btn.visible = false
	header.text = T("⚙ INSTELLINGEN")
	lbl(T("Instellingen gelden voor alle runs en worden bewaard in je meta-save."), 20)
	sep()

	lbl(T("TAAL"), 26)
	lbl(T("Kies je taal. Ontbrekende vertalingen vallen terug op het Nederlands."), 20)
	for code in I18n.LANGS:
		var lc := str(code)
		var active := I18n.lang() == lc
		var lb := btn(T("%s%s") % [I18n.lang_name(lc), "  ✔" if active else ""],
			func(): _set_lang(lc), not active)
		if active:
			lb.add_theme_color_override("font_disabled_color", Color(0.85, 0.95, 0.85))
	sep()

	lbl(T("WEERGAVE"), 26)
	_setting_toggle_btn("confetti", "Confetti & animaties",
		"Confetti bij een combo of geslaagde tekening, en het rode puffje bij een afwijzing.")
	_setting_toggle_btn("office_bg", "Kantoor-achtergrond",
		"Het beeld/sfeerkleur per kantoorniveau. Uit = effen donkere achtergrond, rustiger te lezen.")
	_setting_toggle_btn("player_panel", "Spelerkaart onderaan",
		"Het paneel met de spelerkaart bij events en minigames. Uit = meer schermruimte.")
	sep()

	lbl(T("PROGRESSIE"), 26)
	var spent := Meta.spent_points()
	if spent > 0:
		if settings_confirm == "perks":
			lbl(T("Weet je het zeker? Alle perks (ook de ★-extra's) gaan naar 0; je krijgt %s punten terug.") % _pts(spent), 21)
			btn(T("JA — reset perkboom"), _do_settings_reset_perks)
			btn(T("Annuleer"), func(): _set_settings_confirm(""))
		else:
			btn(T("Reset perkboom (geeft %s punten terug)") % _pts(spent), func(): _set_settings_confirm("perks"))
	else:
		lbl(T("Perkboom: nog niets gekocht om te resetten."), 20)
	var stars := Meta.spent_stars()
	if stars > 0:
		if settings_confirm == "legacy":
			lbl(T("Weet je het zeker? Al je Erfenis-perks gaan naar 0; je krijgt %d %s terug.") % [stars, _stars_word(stars)], 21)
			btn(T("JA — reset Erfenis-perks"), _do_settings_reset_legacy)
			btn(T("Annuleer"), func(): _set_settings_confirm(""))
		else:
			btn(T("Reset Erfenis-perks (geeft %d %s terug)") % [stars, _stars_word(stars)], func(): _set_settings_confirm("legacy"))
	sep()

	lbl(T("OPSLAG"), 26)
	if Game.has_save():
		if settings_confirm == "run":
			lbl(T("Je huidige run wordt definitief verwijderd. Je legacy points en perks blijven staan."), 21)
			btn(T("JA — verwijder huidige run"), _do_settings_delete_run)
			btn(T("Annuleer"), func(): _set_settings_confirm(""))
		else:
			btn(T("Verwijder huidige run"), func(): _set_settings_confirm("run"))
	else:
		lbl(T("Geen lopende run opgeslagen."), 20)
	if settings_confirm == "all":
		var warn := lbl(T("ALLES WISSEN: punten, perks, Erfenis-perks, sterren, ∞-upgrade, carrièrestats, Hall of Fame én de niveau-6-ontgrendeling. Dit kan NIET ongedaan worden gemaakt. Je instellingen blijven staan."), 21)
		warn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		btn(T("JA, WIS ALLES"), _do_settings_wipe_all)
		btn(T("Annuleer"), func(): _set_settings_confirm(""))
	else:
		var wipe := btn(T("Alles wissen (volledige reset)"), func(): _set_settings_confirm("all"))
		wipe.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	sep()
	btn(T("← Terug"), func(): _set_settings_confirm_and_go(""))


func _stars_word(n: int) -> String:
	# Pluralisering met HELE woorden i.p.v. een aangeplakt achtervoegsel:
	# "ster"/"ster+ren" werkt niet in andere talen ("star"+"ren" = "starren").
	return T("ster") if n == 1 else T("sterren")


func _rounds_word(n: int) -> String:
	return T("ronde") if n == 1 else T("rondes")


func _set_lang(code: String) -> void:
	Meta.set_setting("lang", code)
	I18n.set_lang(code)
	_apply_layout_direction()
	show_settings()


func _set_settings_confirm(v: String) -> void:
	settings_confirm = v
	show_settings()


func _set_settings_confirm_and_go(v: String) -> void:
	settings_confirm = v
	show_start()


func _do_settings_reset_perks() -> void:
	Meta.reset_perks()
	_set_settings_confirm("")


func _do_settings_reset_legacy() -> void:
	Meta.reset_legacy_perks()
	_set_settings_confirm("")


func _do_settings_delete_run() -> void:
	Game.delete_save()
	_set_settings_confirm("")


func _do_settings_wipe_all() -> void:
	Meta.wipe_everything()
	Game.delete_save()
	_set_settings_confirm("")


# ---------------------------------------------------------------- developer-only

func _on_dev_tap() -> void:
	dev_taps += 1
	if dev_taps >= DEV_TAPS_NEEDED:
		dev_taps = 0
		_show_dev_login()


func _show_dev_login(error := "") -> void:
	clear()
	header.text = T("DEVELOPER")
	if error != "":
		var e := lbl(error, 20)
		e.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	lbl(T("Voer het developer-wachtwoord in."), 22)
	var input := LineEdit.new()
	input.placeholder_text = "wachtwoord"
	input.secret = true
	input.custom_minimum_size = Vector2(0, 56)
	content.add_child(input)
	btn(T("Bevestigen"), func(): _check_dev_password(input.text))
	btn(T("← Terug"), show_start)


func _check_dev_password(pw: String) -> void:
	if pw == DEV_PASSWORD:
		dev_unlocked = true
		dev_confirm = false
		show_dev_panel()
	else:
		_show_dev_login("Onjuist wachtwoord. Probeer opnieuw.")


func show_dev_panel() -> void:
	if not dev_unlocked:
		show_start()
		return
	clear()
	header.text = T("DEVELOPER — puntenbeheer")
	lbl(T("Huidig puntensaldo: %s legacy points.") % _pts(Meta.state.legacy_points), 26)
	lbl(T("Dit wist alleen het saldo, niet de gekochte perk-niveaus (gebruik daarvoor 'Reset perkboom' in ⚙ Instellingen)."), 20)
	sep()
	if dev_confirm:
		lbl(T("Weet je het zeker? Het puntensaldo gaat naar 0 en dit kan niet ongedaan worden."), 22)
		btn(T("JA — wis puntensaldo"), _do_dev_wipe)
		btn(T("Annuleer"), func(): dev_confirm = false; show_dev_panel())
	else:
		btn(T("Wis alle punten (naar 0)"), func(): dev_confirm = true; show_dev_panel())
	sep()
	lbl(T("Testmodus: doorloopt ALLE %d events op volgorde, met onbeperkt geld en zonder fail-checks. Start een verse testrun in het geheugen — je opgeslagen run blijft veilig op schijf.") % EventsDB.get_events().size(), 20)
	btn(T("Test: doorloop alle events →"), _start_event_test)
	sep()
	var won_ever := bool(Meta.state.get("has_won_ever", false))
	lbl(T("Geheim kantoorniveau 6 (De Kampioenssuite): %s") % ("ontgrendeld" if won_ever else "nog vergrendeld"), 20)
	btn(T("Zet uit (test)") if won_ever else T("Forceer ontgrendeld (test)"), func(): Meta.dev_toggle_won_ever(); show_dev_panel())
	sep()
	btn(T("← Terug naar start"), func(): dev_unlocked = false; dev_confirm = false; show_start())


func _do_dev_wipe() -> void:
	Meta.dev_wipe_points()
	dev_confirm = false
	show_dev_panel()


# ---- Developer-only eventtest ----

func _dev_test_banner() -> void:
	if not dev_test_mode:
		return
	var l := lbl(T("[DEV TEST] Event %d/%d — id: %s") % [dev_test_index, dev_test_total, str(mg_ev.get("id", "?"))], 18)
	l.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	dev_jump_input = LineEdit.new()
	dev_jump_input.placeholder_text = "nr"
	dev_jump_input.custom_minimum_size = Vector2(70, 40)
	row.add_child(dev_jump_input)
	var jump_btn := Button.new()
	jump_btn.text = T("Ga naar event")
	jump_btn.pressed.connect(_dev_jump_to_event)
	row.add_child(jump_btn)


func _start_event_test() -> void:
	Game.new_run()
	Game.ensure_test_client()
	Game.state.money = DEV_TEST_MONEY
	dev_test_mode = true
	dev_test_all = []
	for ev in EventsDB.get_events():
		var e: Dictionary = ev.duplicate(true)
		if bool(e.get("needs_client", false)):
			e["client_id"] = Game.state.clients[0] if not Game.state.clients.is_empty() else ""
		else:
			e["client_id"] = ""
		dev_test_all.append(e)
	event_queue = dev_test_all.duplicate()
	dev_test_total = event_queue.size()
	dev_test_index = 0
	_next_event()


func _dev_jump_to_event() -> void:
	if dev_jump_input == null:
		return
	var n := int(dev_jump_input.text)
	if n < 1 or n > dev_test_all.size():
		return
	_dev_cleanup_minigames()
	event_queue = dev_test_all.duplicate().slice(n - 1)
	dev_test_index = n - 1
	_next_event()


func _dev_cleanup_minigames() -> void:
	# Sluit een eventueel actieve minigame af zonder de effecten toe te
	# passen — puur navigatie tijdens het testen, geen echte uitkomst.
	press = null
	tax = null
	poker = null
	poker_notes = []
	poker_applied = false
	dice = null
	accounting = null
	anagram = null
	anagram_active = false
	anagram_round_started_idx = -1
	anagram_timer_label = null
	scoutdate = null
	simon = null


func _finish_event_test() -> void:
	dev_test_mode = false
	flash = T("Testrun klaar: alle %d events doorlopen.") % dev_test_total
	show_dev_panel()


# ---------------------------------------------------------------- meta: perks

func show_perks() -> void:
	clear()
	_refresh_inf_btn()
	inf_btn.visible = true
	header.text = T("PERKBOOM — %s legacy points") % _pts(Meta.state.legacy_points)
	lbl(T("Boom voltooid: %s%%  (%s van %s punten)") % [
		("%.1f" % (Meta.tree_progress() * 100.0)).replace(".", ","),
		_pts(Meta.tree_spent()), _pts(Meta.tree_total_cost()),
	], 26)
	lbl(T("Permanente upgrades voor elke volgende run. Je verdient legacy points door te spelen — hoe verder je komt, hoe exponentieel meer (een gewonnen run = 1%% van de boom). Elke rij biedt 3 opties; koop %d niveaus in een rij om de rij eronder te ontgrendelen (of alles wat die rij te bieden heeft, als dat er minder zijn).") % Meta.TIER_REQ, 22)
	for branch in Meta.TREE:
		sep()
		lbl(T("◆ TAK: %s") % T(str(branch.name)), 30)
		for tier_idx in range(branch.tiers.size()):
			var unlocked: bool = Meta.tier_unlocked(branch, tier_idx)
			if unlocked:
				lbl(T("— Rij %d —") % (tier_idx + 1), 22)
				for id in branch.tiers[tier_idx]:
					_perk_node(str(id))
			else:
				var names: Array = []
				for id in branch.tiers[tier_idx]:
					names.append(Meta.perk_name(id))
				# De échte eis opvragen i.p.v. de kale TIER_REQ: in een rij met
				# minder dan 5 koopbare niveaus is de eis lager (zie
				# Meta.tier_req_for()), en dan moet de melding dat ook zeggen.
				lbl(T("🔒 Rij %d (%s) — vereist %d niveaus in rij %d (nu %d).") % [
					tier_idx + 1, ", ".join(names),
					Meta.tier_req_for(branch, tier_idx - 1), tier_idx,
					Meta.tier_levels(branch, tier_idx - 1),
				], 20)
	sep()
	lbl(T("★ OVERPOWERED — extra's buiten de boom (tellen niet mee voor de 100%)"), 26)
	for id in Meta.OP_PERKS:
		_perk_node(str(id))
	sep()
	var pstars := int(Meta.state.prestige_stars)
	lbl(T("✦ ERFENIS-PERKS — %d Prestige-%s") % [pstars, _stars_word(pstars)], 26)
	lbl(T("Bonussen die je NOOIT met gewone legacy points kunt kopen — alleen met Prestige-sterren. Die krijg je door te prestigen: je hele perkboom resetten NA een gewonnen run, zonder puntenrefund."), 20)
	for id in Meta.LEGACY_PERKS:
		_legacy_perk_node(str(id))
	if Meta.can_prestige():
		if confirm_prestige:
			lbl(T("Weet je het zeker? Je hele perkboom (%s punten aan niveaus) gaat naar 0 — GEEN refund — in ruil voor 1 Prestige-ster.") % _pts(Meta.spent_points()), 22)
			btn(T("JA — prestige nu"), _do_prestige)
			btn(T("Annuleer"), func(): _set_confirm_prestige(false))
		else:
			btn(T("✦ Prestige (perkboom weg, +1 Prestige-ster)"), func(): _set_confirm_prestige(true))
	else:
		lbl(T("Prestigen kan pas vanaf %s%% boomvoortgang (nu %s%%) — bij te weinig opgebouwd stelt de opoffering niets voor.") % [
			("%.0f" % (Meta.PRESTIGE_MIN_TREE_PROGRESS * 100.0)),
			("%.1f" % (Meta.tree_progress() * 100.0)).replace(".", ","),
		], 19)
	sep()
	# De reset-knoppen (perkboom én Erfenis-perks) staan in ⚙ Instellingen —
	# dit scherm is al lang genoeg, en het zijn geen aankoop-acties.
	lbl(T("Resetten kan via ⚙ Instellingen op het startscherm."), 19)
	btn(T("← Terug"), show_start)


func _legacy_perk_node(id: String) -> void:
	var perk: Dictionary = Meta.LEGACY_PERKS[id]
	var owned := Meta.has_legacy_perk(id)
	var stars := int(perk.stars)
	lbl(T("  %s  (%d %s)%s") % [
		Meta.legacy_perk_name(id), stars, _stars_word(stars),
		T("  ✔ ACTIEF") if owned else "",
	], 24)
	lbl(T("       ") + Meta.legacy_perk_desc(id), 20)
	if not owned:
		btn(T("Koop %s  (%d %s)") % [Meta.legacy_perk_name(id), stars, _stars_word(stars)],
			func(): _buy_legacy_perk(id), Meta.can_buy_legacy_perk(id))


func _buy_legacy_perk(id: String) -> void:
	Meta.buy_legacy_perk(id)
	show_perks()


func _set_confirm_prestige(v: bool) -> void:
	confirm_prestige = v
	show_perks()


func _do_prestige() -> void:
	Meta.prestige_run()
	confirm_prestige = false
	show_perks()


func _pts(n) -> String:
	# Zelfde duizendtal-notatie als eur(), zonder valutateken.
	return eur(n).replace("€", "")


func _perk_node(id: String) -> void:
	var perk: Dictionary = Meta.PERKS[id]
	var lvl := Meta.perk_level(id)
	var maxlvl := int(perk.max_level)
	var bar := "●".repeat(lvl) + "○".repeat(maxlvl - lvl)
	lbl(T("  %s  %s") % [Meta.perk_name(id), bar], 25)
	if lvl > 0:
		lbl(T("       ") + T("nu: ") + Meta.perk_desc(id, lvl), 21)
	if lvl < maxlvl:
		lbl(T("       ") + T("volgend niveau: ") + Meta.perk_desc(id, 1), 21)
		btn(T("Koop %s niveau %d  (%s punten)") % [Meta.perk_name(id), lvl + 1, _pts(Meta.perk_cost(id))], func(): _buy_perk(id), Meta.can_buy(id))
	else:
		lbl(T("       ") + T("MAX bereikt."), 20)


func _buy_perk(id: String) -> void:
	Meta.buy_perk(id)
	show_perks()


func _refresh_inf_btn() -> void:
	inf_btn.text = T("∞ ×%s\n+1%%\nkoop: %d pt") % [
		("%.3f" % Meta.inf_multiplier()).replace(".", ","), Meta.INF_COST,
	]
	inf_btn.disabled = int(Meta.state.legacy_points) < Meta.INF_COST


func _buy_inf() -> void:
	if Meta.buy_inf():
		# Alleen de knop en de header verversen; de boom hoeft niet opnieuw.
		header.text = T("PERKBOOM — %s legacy points") % _pts(Meta.state.legacy_points)
	_refresh_inf_btn()


# Kent legacy points toe voor de afgelopen run, maar hoogstens één keer per
# run (anders zou opnieuw naar hetzelfde game-over-scherm gaan dubbel uitbetalen).
func _finish_run_meta(won: bool) -> int:
	if bool(Game.state.get("meta_awarded", false)):
		return 0
	var seasons := mini(int(Game.state.season), Game.MAX_SEASONS)
	# Rauwe total_fees, NIET gedeeld: award_run() rekent er geen punten mee (die
	# komen uit tree_total_cost()) en zet het bedrag alleen in best_fees en
	# total_career_fees, en die worden als euro's getoond.
	var earned := Meta.award_run(int(Game.state.total_fees), seasons, won)
	if won:
		Meta.record_win(_best_client_name(), int(Game.state.total_fees), seasons)
	Game.state.meta_awarded = true
	Game.save_game()
	return earned


func _best_client_name() -> String:
	# Hall of Fame: de meest waardevolle cliënt in je stal op het moment van
	# winnen — puur cosmetisch, geen mechanisch effect.
	var best_name := ""
	var best_value := -1
	for cid in Game.state.clients:
		var p: Dictionary = Game.state.players[cid]
		var v := Game.value(p)
		if v > best_value:
			best_value = v
			best_name = str(p.name)
	return best_name


func _on_new_run() -> void:
	Game.new_run()
	show_prep()


func _on_continue() -> void:
	if Game.load_game():
		if str(Game.state.game_over) != "":
			show_gameover()
		else:
			show_prep()


# ---------------------------------------------------------------- fase 1: prep

func show_prep() -> void:
	refresh_header()
	clear()
	lbl(T("VOORBEREIDING"), 34)
	if str(Game.state.news) != "":
		lbl(T("Nieuws: ") + str(Game.state.news), 24)
	# Geen show_flash() hier — de resultaten van acties op dit scherm (storten,
	# upgraden) zijn al zichtbaar via de bijgewerkte staat zelf (lopende
	# bankstortingen-lijst, kantoorniveau), een losse meldingsregel erbovenop
	# voelde overbodig. Wel legen, anders duikt hij later ergens anders op.
	_discard_flash()
	# Schandaal doet vanaf niveau 40/70 daadwerkelijk iets (zie scandal_*() in
	# game.gd) — deze waarschuwing maakt dat zichtbaar, anders merk je alleen
	# een lagere tekenkans/hogere kaapkans zonder te snappen waarom.
	if int(Game.state.scandal) >= 70:
		var l := lbl(T("⚠ Schandaal %d — je reputatie is in vrije val: rivalen kapen je cliënten makkelijker weg en clubs mijden je bij transfers.") % int(Game.state.scandal), 20)
		l.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	elif int(Game.state.scandal) >= 40:
		var l := lbl(T("⚠ Schandaal %d — je staat onder een vergrootglas: nieuwe cliënten tekenen minder makkelijk bij je.") % int(Game.state.scandal), 20)
		l.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	sep()
	lbl(T("Jouw stal (%d/%d):") % [Game.state.clients.size(), Game.client_cap()], 28)
	var stal_grid := _card_grid()
	for cid in Game.state.clients:
		var p: Dictionary = Game.state.players[cid]
		# Clubs staan voorlopig buiten beeld (cosmetisch) — contractstatus
		# blijft wel zichtbaar (relevant voor tekengeld-timing), los van de
		# clubnaam zelf. Compacte subregel: in een halve kolom is er geen ruimte
		# voor een lange opsomming.
		var sub := T("%s, %d jr · vert. %d") % [str(p.pos), int(p.age), int(p.trust)]
		if str(p.club) != "":
			sub += T(" · %d jr contract") % int(p.contract)
		sub += "\n%s" % eur(Game.value(p))
		_stat_card(cid, sub, false, stal_grid)
	sep()
	# ---- Het kantoor: niveau, band en upgrade ----
	var band: Dictionary = Game.office_band()
	lbl(T("🏢 KANTOOR — niveau %d/%d: %s") % [Game.office_level(), Game.office_max_level(), Game.office_name()], 28)
	lbl(T("Je ziet elk seizoen %d spelers, rating %d–%d (gemiddeld ~%d). Hoger niveau = betere spelers binnen bereik.") % [
		Game.candidate_count(), Game.candidate_floor(), Game.candidate_ceiling(), int(band.avg),
	], 20)
	if Game.office_level() < Game.office_max_level():
		var next_band: Dictionary = Game.OFFICE_LEVELS[Game.office_level()]
		var cost := Game.office_upgrade_cost()
		var l := lbl(T("Upgraden tilt je naar niveau %d: %s (spelers tot ~%d).") % [
			Game.office_level() + 1, T(str(next_band.name)), int(next_band.ceiling),
		], 19)
		l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		btn(T("Kantoor upgraden — %s (%s)") % [T(str(next_band.name)), eur(cost)], _upgrade_office, Game.can_upgrade_office())
	else:
		lbl(T("Hoogste niveau bereikt. Je onderhandelt tussen de miljardairs."), 20)
	sep()
	lbl(T("DE BANK — stort geld weg, krijg het na %d seizoenen verdubbeld terug.") % Game.BANK_MATURITY_SEASONS, 20)
	if Game.bank_deposit_count() > 0:
		# Elke storting loopt onafhankelijk af — dus ook los getoond, niet
		# als één opgeteld bedrag met één gedeelde termijn.
		for d in Game.bank_deposits_list():
			lbl(T("• %s gestort — nog %d seizoen(en), dan %s terug.") % [
				eur(int(d.amount)), int(d.seasons_left), eur(int(round(float(d.amount) * Game.BANK_MULTIPLIER))),
			], 19)
	var max_deposit := maxi(int(Game.state.money), 0)
	bank_deposit_label = lbl(T("Storten: %s") % eur(0), 22)
	bank_deposit_slider = HSlider.new()
	bank_deposit_slider.min_value = 0
	bank_deposit_slider.max_value = max_deposit
	bank_deposit_slider.step = 1000
	bank_deposit_slider.value = 0
	bank_deposit_slider.custom_minimum_size = Vector2(0, 36)
	bank_deposit_slider.editable = max_deposit > 0
	bank_deposit_slider.value_changed.connect(_on_bank_slider_changed)
	content.add_child(bank_deposit_slider)
	var deposit_btn := Button.new()
	deposit_btn.text = T("Storten")
	deposit_btn.custom_minimum_size = Vector2(0, 48)
	deposit_btn.disabled = max_deposit <= 0
	deposit_btn.pressed.connect(_do_bank_deposit)
	content.add_child(deposit_btn)
	sep()
	var skip_release := Meta.perk_level("vaste_kern") > 0 or int(Game.state.season) == 1
	btn(T("Naar scouting →") if skip_release else T("Naar stalbeheer →"), _goto_release)


func _upgrade_office() -> void:
	if Game.upgrade_office():
		flash = T("Kantoor geüpgraded naar %s! De hele tent verandert.") % Game.office_name()
		_update_office_background()
	else:
		flash = T("Upgrade mislukt — niet genoeg geld.")
	show_prep()


func _on_bank_slider_changed(value: float) -> void:
	if bank_deposit_label != null:
		bank_deposit_label.text = T("Storten: %s") % eur(int(value))


func _do_bank_deposit() -> void:
	if bank_deposit_slider == null:
		return
	var amount := int(bank_deposit_slider.value)
	if Game.bank_deposit(amount):
		var payout := int(round(float(amount) * (Game.BANK_MULTIPLIER + (0.3 if Game.has_shop("investeringsfonds") else 0.0))))
		flash = T("Gestort: %s. Komt over %d seizoenen terug als %s.") % [eur(amount), Game.BANK_MATURITY_SEASONS, eur(payout)]
	else:
		flash = T("Storting mislukt — vul een geldig bedrag in dat je ook echt hebt.")
	show_prep()


# ---------------------------------------------------------------- fase 1b: stalbeheer

func _goto_release() -> void:
	# ★ Vaste kern-perk: jij bent de uitzondering op de ontslagregel.
	if Meta.perk_level("vaste_kern") > 0:
		_goto_scouting()
		return
	# Seizoen 1 slaat het verplichte ontslag altijd over — anders zou de
	# Erfenis-perk Kroonjuweel-netwerk (extra startcliënt) meteen weer
	# ongedaan worden gemaakt vóór je ook maar één seizoen hebt gespeeld.
	if int(Game.state.season) == 1:
		_goto_scouting()
		return
	# Met 0 of 1 cliënten is ontslaan direct game over ("leeg") — dan slaan
	# we de verplichting over.
	if Game.state.clients.size() <= 1:
		_goto_scouting()
		return
	release_selection = []
	show_release()


func show_release() -> void:
	refresh_header()
	clear()
	lbl(T("STALBEHEER — VERPLICHT ONTSLAG"), 34)
	lbl(T("Selecteer wie je wegstuurt (je mag er zoveel kwijt als je wilt, zolang er minstens 1 overblijft — handig als je meteen plek wilt maken voor een kantoorupgrade) en bevestig onderaan. De rest van je stal verliest 2 vertrouwen per weggestuurde cliënt."), 22)
	show_flash()
	sep()
	var rel_grid := _card_grid()
	for cid in Game.state.clients:
		var p: Dictionary = Game.state.players[cid]
		var selected: bool = cid in release_selection
		var sub := T("%s, %d jr · vert. %d\n%s") % [
			str(p.pos), int(p.age), int(p.trust), eur(Game.value(p)),
		]
		var info := _stat_card(cid, sub, selected, rel_grid)
		info.add_child(_mini_btn(T("✗ Wegsturen") if not selected else T("✔ Blijft toch"), func(): _toggle_release(cid)))
	sep()
	var remaining: int = Game.state.clients.size() - release_selection.size()
	var confirm_txt := ("Bevestig: stuur %d weg (%d blijft over)" % [release_selection.size(), remaining]) if not release_selection.is_empty() else "Niemand geselecteerd"
	btn(confirm_txt, _confirm_release, not release_selection.is_empty() and remaining >= 1)


func _toggle_release(cid: String) -> void:
	if cid in release_selection:
		release_selection.erase(cid)
	else:
		# Je moet er minstens 1 overhouden — de laatste kan niet geselecteerd worden.
		if Game.state.clients.size() - release_selection.size() > 1:
			release_selection.append(cid)
		else:
			flash = T("Je moet minstens 1 cliënt overhouden.")
	show_release()


func _confirm_release() -> void:
	var names: Array = []
	for cid in release_selection:
		names.append(str(Game.state.players[cid].name))
		Game.release_client(cid)
	release_selection = []
	if names.size() == 1:
		flash = T("%s pakt zijn spullen. 'Ik dacht dat we een team waren.'") % str(names[0])
	else:
		flash = T("%d cliënten pakken hun spullen: %s.") % [names.size(), ", ".join(names)]
	_goto_scouting()


# ---------------------------------------------------------------- fase 2: scouting

func _goto_scouting() -> void:
	Game.state.scout_points = Game.scout_points_per_season()
	candidates = Game.gen_candidates()
	approached = []
	show_scouting()


func show_scouting() -> void:
	refresh_header()
	clear()
	lbl(T("SCOUTING"), 34)
	_set_turn_bar("Scoutpunten:", int(Game.state.scout_points), Game.scout_points_per_season())
	# Geen show_flash() hier — scout-/benaderresultaten zijn al zichtbaar via
	# de kaart zelf (confetti bij tekenen, rood puffje bij afwijzing, of de
	# bijgewerkte tekenkans/onzekerheid). Wel legen, anders duikt hij later op.
	_discard_flash()
	lbl(T("De potentieel-band is een schátting — die kan er flink naast zitten. Scouten trekt haar naar de waarheid én maakt tekenen makkelijker (+5% per scout, max +10%)."), 22)
	lbl(T("Kantoor niveau %d (%s) brengt spelers tot rating ~%d binnen bereik. Je reputatie (%d) bepaalt of ze tekenen.") % [
		Game.office_level(), Game.office_name(), Game.candidate_ceiling(), int(Game.state.rep),
	], 20)
	# Sorteerknoppen — tik nogmaals op dezelfde sleutel om de richting te draaien.
	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 8)
	content.add_child(sort_row)
	var sl := Label.new()
	sl.text = T("Sorteer:")
	sl.add_theme_font_size_override("font_size", 20)
	sort_row.add_child(sl)
	sort_row.add_child(_sort_button("Rating", "rating"))
	sort_row.add_child(_sort_button("Leeftijd", "age"))
	var cand_grid := _card_grid()
	for pid in _sorted_candidates():
		cand_grid.add_child(_candidate_card(pid))
	sep()
	btn(T("Naar events →"), _goto_events)


func _candidate_card(pid: String) -> Control:
	# Scoutingvariant van de spelerkaart: dezelfde basisopmaak als overal
	# (_player_card), met de tekenkans en de Scout/Benader-knoppen eronder.
	var p: Dictionary = Game.state.players[pid]
	var is_client: bool = pid in Game.state.clients
	# club staat voorlopig buiten beeld (cosmetisch)
	var card := _player_card(pid, "%s, %d jr" % [str(p.pos), int(p.age)], false, true)
	var info: VBoxContainer = card.get_meta("info_col")

	if not is_client and not approached.has(pid):
		var chance := Label.new()
		chance.text = T("tekenkans %d%%") % int(round(Game.sign_chance(pid) * 100))
		chance.add_theme_font_size_override("font_size", 18)
		chance.add_theme_color_override("font_color", Color(0.7, 0.82, 0.95))
		info.add_child(chance)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	info.add_child(btn_row)
	# Scout- én benaderknop verdwijnen zodra je hem dit seizoen hebt benaderd
	# (afgewezen): dan valt er niets meer te doen tot volgend seizoen.
	if not is_client and approached.has(pid):
		var al := Label.new()
		al.text = T("al benaderd dit seizoen")
		al.add_theme_font_size_override("font_size", 18)
		al.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		btn_row.add_child(al)
	elif not is_client:
		if int(Game.state.scout_points) > 0 and int(p.unc) > 2:
			btn_row.add_child(_mini_btn(T("Scout"), func(): _scout(pid)))
		if Game.state.clients.size() < Game.client_cap():
			btn_row.add_child(_mini_btn(T("Benader"), func(): _try_sign(pid)))

	return card


func _player_card(pid: String, sub_text := "", highlighted := false, client_tag := false, prev_rating := -1, known_pot := false) -> PanelContainer:
	# DÉ spelerkaart — één centrale opmaak die overal wordt hergebruikt waar een
	# speler genoemd wordt: scouting, je stal (voorbereiding), stalbeheer, het
	# infopaneel bij events/minigames en het weggekaapt-nieuwsscherm. Naam +
	# subregel links, POT-badge rechtsboven en RAT-badge rechtsonder.
	# De info-kolom hangt als meta "info_col" aan de kaart, zodat een aanroeper
	# er nog eigen regels/knoppen aan kan toevoegen zonder dat deze functie
	# elke variant hoeft te kennen. Voegt zelf NIETS toe aan `content` — de
	# aanroeper bepaalt waar de kaart terechtkomt.
	var p: Dictionary = Game.state.players[pid]
	var card := PanelContainer.new()
	# Vult de beschikbare breedte — in een 2-kolomsraster dus precies een halve
	# kolom, buiten een raster de volle breedte.
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.45, 0.15, 0.15, 0.85) if highlighted else Color(0.13, 0.13, 0.17, 0.85)
	st.set_corner_radius_all(10)
	st.content_margin_left = 12
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", st)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	card.add_child(hb)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hb.add_child(info)
	var name_lbl := Label.new()
	# De [CLIËNT]-tag alleen waar hij informatie toevoegt (scoutinglijst) — in
	# je eigen stal is het overbodige ruis.
	name_lbl.text = "%s%s" % [str(p.name), T("   [CLIËNT]") if (client_tag and pid in Game.state.clients) else ""]
	name_lbl.add_theme_font_size_override("font_size", 22)
	# Wrappen is nodig sinds de kaarten in een halve kolom staan: een lange naam
	# of subregel past daar niet meer op één regel.
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name_lbl)
	if sub_text != "":
		var sub := Label.new()
		sub.text = sub_text
		sub.add_theme_font_size_override("font_size", 17)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
		info.add_child(sub)
	# Tags: puur visuele markeringen (favoriet / slot) om je eigen plannen te
	# onthouden — geen mechanisch effect. Op een eigen compacte rij i.p.v. naast
	# de naam, want in een halve kolom houdt de naam dan zijn volle breedte.
	var tag_row := HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 4)
	tag_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.add_child(tag_row)
	tag_row.add_child(_tag_btn(pid, "fav", "★"))
	tag_row.add_child(_tag_btn(pid, "lock", "🔒"))
	# Compactere badges dan voorheen (was 96x52 / 64x64): in een halve kolom
	# moet er naast de badges nog genoeg breedte over zijn voor naam en subregel.
	var badges := VBoxContainer.new()
	# Breder als er een "was"-badge met pijl bij komt (48 + pijl/groeicijfer + 54).
	badges.custom_minimum_size = Vector2((144 if prev_rating >= 0 else 74), 0)
	badges.add_theme_constant_override("separation", 6)
	hb.add_child(badges)
	badges.add_child(_stat_badge("POT", _pot_badge_text(pid, known_pot), Color(0.16, 0.55, 0.28), Vector2(74, 46), Control.SIZE_SHRINK_END))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	badges.add_child(spacer)
	if prev_rating >= 0:
		# Ontwikkeling zichtbaar maken: [oude rating] → [nieuwe rating].
		var rat_row := HBoxContainer.new()
		rat_row.add_theme_constant_override("separation", 4)
		rat_row.size_flags_horizontal = Control.SIZE_SHRINK_END
		rat_row.add_child(_stat_badge("WAS", str(prev_rating), Color(0.30, 0.30, 0.34), Vector2(48, 54)))
		# Het groeicijfer staat BOVEN de pijl (i.p.v. als losse zin in de
		# subregel): "+3" met daaronder "→", zodat je in één blik ziet hoeveel
		# hij vooruit is gegaan.
		var arrow_col := VBoxContainer.new()
		arrow_col.add_theme_constant_override("separation", 0)
		arrow_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var gain_lbl := Label.new()
		gain_lbl.text = "+%d" % (int(p.rating) - prev_rating)
		gain_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gain_lbl.add_theme_font_size_override("font_size", 20)
		gain_lbl.add_theme_color_override("font_color", Color(0.35, 0.9, 0.4))
		arrow_col.add_child(gain_lbl)
		var arrow := Label.new()
		arrow.text = "→"
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow.add_theme_font_size_override("font_size", 22)
		arrow.add_theme_color_override("font_color", Color(0.35, 0.9, 0.4))
		arrow_col.add_child(arrow)
		rat_row.add_child(arrow_col)
		rat_row.add_child(_stat_badge("RAT", str(int(p.rating)), Color(0.18, 0.42, 0.78), Vector2(54, 54)))
		badges.add_child(rat_row)
	else:
		badges.add_child(_stat_badge("RAT", str(int(p.rating)), Color(0.18, 0.42, 0.78), Vector2(54, 54), Control.SIZE_SHRINK_END))
	card.set_meta("info_col", info)
	return card


const TAG_ON_COLOR := Color(1.0, 0.85, 0.2)
const TAG_OFF_COLOR := Color(1.0, 1.0, 1.0, 0.28)


func _tag_btn(pid: String, key: String, icon: String) -> Button:
	# Aan/uit-tag op een speler (`fav` / `lock` op de speler-dictionary, dus hij
	# gaat mee in de save). Werkt zichzelf bij i.p.v. het hele scherm te
	# hertekenen — zo hoeft deze knop niet te weten op welk scherm hij staat, en
	# blijft je scrollpositie staan.
	var b := Button.new()
	b.text = icon
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(40, 34)
	b.modulate = TAG_ON_COLOR if bool(Game.state.players[pid].get(key, false)) else TAG_OFF_COLOR
	b.pressed.connect(_toggle_player_tag.bind(pid, key, b))
	return b


func _toggle_player_tag(pid: String, key: String, b: Button) -> void:
	if not Game.state.players.has(pid):
		return
	var p: Dictionary = Game.state.players[pid]
	var now := not bool(p.get(key, false))
	p[key] = now
	b.modulate = TAG_ON_COLOR if now else TAG_OFF_COLOR
	Game.save_game()


func _card_grid() -> GridContainer:
	# 2-kolomsraster voor spelerkaarten (scouting, stal, stalbeheer), zodat elke
	# kaart een halve schermbreedte krijgt i.p.v. een volle rij.
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(g)
	return g


func _stat_card(pid: String, sub_text: String, highlighted := false, parent: Node = null) -> VBoxContainer:
	# Spelerkaart in `parent` (of `content` als die niet is opgegeven) — stal en
	# stalbeheer geven hun 2-kolomsraster mee. Geeft de info-kolom terug, zodat
	# de aanroeper er nog een knop aan kan hangen.
	var card := _player_card(pid, sub_text, highlighted)
	(parent if parent != null else content).add_child(card)
	return card.get_meta("info_col") as VBoxContainer


func _pot_badge_text(pid: String, force_known := false) -> String:
	# Potentieel voor de badge: exact bekend zodra iemand in je stal zit, anders
	# de geschatte band (est ± onzekerheid). Gedeeld door scoutingkaart,
	# stalbeheer en het infobalkje, zodat de weergave overal identiek is.
	# `force_known` is voor kaarten over spelers die dit seizoen NOG van jou
	# waren maar inmiddels uit state.clients zijn gehaald (ontwikkeling van
	# iemand die daarna vertrok/weggekaapt werd, en het wegkaap-nieuwsscherm):
	# je kende zijn potentieel, dus daar hoort geen vage band te staan.
	var p: Dictionary = Game.state.players[pid]
	if force_known or pid in Game.state.clients:
		return str(int(p.pot))
	var est := Game.estimate(pid)
	var lo := maxi(est - int(p.unc), int(p.rating))
	var hi := mini(est + int(p.unc), 95)
	return "%d–%d" % [lo, hi]


func _stat_badge(caption: String, value: String, bg: Color, min_size: Vector2, halign := Control.SIZE_SHRINK_CENTER) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = min_size
	pc.size_flags_horizontal = halign
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	pc.add_child(vb)
	var cap := Label.new()
	cap.text = caption
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	vb.add_child(cap)
	var val := Label.new()
	val.text = value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 26)
	val.add_theme_color_override("font_color", Color(1, 1, 1))
	vb.add_child(val)
	return pc


func _sort_button(label: String, key: String) -> Button:
	var b := Button.new()
	var arrow := ""
	if scout_sort == key:
		arrow = "  ↓" if scout_sort_desc else "  ↑"
	b.text = T(label) + arrow
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(func(): _toggle_sort(key))
	return b


func _toggle_sort(key: String) -> void:
	if scout_sort == key:
		scout_sort_desc = not scout_sort_desc
	else:
		scout_sort = key
		scout_sort_desc = true
	show_scouting()


func _sorted_candidates() -> Array:
	var arr: Array = candidates.duplicate()
	var key := scout_sort
	var desc := scout_sort_desc
	arr.sort_custom(func(a, b):
		var pa: Dictionary = Game.state.players[a]
		var pb: Dictionary = Game.state.players[b]
		var va := int(pa.rating) if key == "rating" else int(pa.age)
		var vb := int(pb.rating) if key == "rating" else int(pb.age)
		if desc:
			return va > vb
		return va < vb
	)
	return arr


func _mini_btn(text: String, cb: Callable, enabled := true) -> Button:
	# Compacte knop binnen een spelerkaart — kleiner dan de standaard btn().
	# Geen vaste breedte (was 130px): sinds de kaarten in een halve kolom staan
	# moeten twee knoppen naast elkaar (Scout + Benader) in ~200px passen, dus
	# laten we ze de beschikbare ruimte verdelen i.p.v. buiten de kaart te lopen.
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 19)
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.pressed.connect(cb)
	return b


func _set_turn_bar(label: String, current: int, max_turns: int) -> void:
	# Vult de VASTE balk vlak boven de scrollende content met de beurten/
	# pogingen/scoutpunten-blokjes — blijft daardoor altijd zichtbaar, ook als
	# je in een lange log naar beneden scrollt (i.t.t. content.add_child()).
	# HP-bar-achtig: fel blokje = nog beschikbaar, dof = al opgebruikt.
	for c in turn_bar.get_children():
		c.queue_free()
	turn_bar.visible = true
	if label != "":
		var l := Label.new()
		l.text = T(label)
		l.add_theme_font_size_override("font_size", 20)
		turn_bar.add_child(l)
	var blocks := HBoxContainer.new()
	blocks.add_theme_constant_override("separation", 4)
	turn_bar.add_child(blocks)
	# Defensief: als current ooit boven max_turns uitkomt (bijv. een perk die
	# na aanvang nog bijtelt), tekenen we toch genoeg blokjes om het te tonen.
	var shown_max := maxi(max_turns, current)
	for i in range(shown_max):
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(20, 20)
		block.color = Color(0.95, 0.75, 0.15) if i < current else Color(0.22, 0.22, 0.26)
		blocks.add_child(block)


func _scout(pid: String) -> void:
	Game.scout(pid)
	show_scouting()


func _try_sign(pid: String) -> void:
	var p: Dictionary = Game.state.players[pid]
	approached.append(pid)
	var signed := Game.attempt_sign(pid)
	if signed:
		flash = T("%s tekent bij jou!") % p.name
		flash_color = Color(0.35, 0.9, 0.4)
	else:
		flash = T("%s wijst je af. 'Ik hoor goede verhalen over een ander kantoor.'") % p.name
		flash_color = Color(1.0, 0.5, 0.5)
	show_scouting()
	# Feedback ná het herbouwen van het scherm (confetti/puff hangen aan de
	# root, niet aan `content`, dus ze overleven de clear() in show_scouting()).
	if signed:
		_confetti(T("✔ %s tekent!") % p.name, Color(0.35, 0.9, 0.4))
	else:
		_small_negative_puff("✗ afgewezen")


# ---------------------------------------------------------------- fase 3: events

func _goto_events() -> void:
	event_queue = Game.gen_events()
	_next_event()


func _next_event() -> void:
	if not dev_test_mode:
		# Tussentijdse fail-check (events kunnen je nu al de das omdoen).
		if int(Game.state.scandal) >= 100:
			Game.state.game_over = "licentie"
			Game.save_game()
			show_gameover()
			return
		if int(Game.state.money) < 0:
			Game.state.game_over = "failliet"
			Game.save_game()
			show_gameover()
			return
	if event_queue.is_empty():
		if dev_test_mode:
			_finish_event_test()
		else:
			_goto_window()
		return
	if dev_test_mode:
		Game.state.money = maxi(int(Game.state.money), DEV_TEST_MONEY)
		dev_test_index += 1
	var ev: Dictionary = event_queue.pop_front()
	show_event(ev)


func show_event(ev: Dictionary) -> void:
	mg_ev = ev
	refresh_header()
	clear()
	_dev_test_banner()
	var cname := ""
	if str(ev.client_id) != "":
		cname = str(Game.state.players[ev.client_id].name)
	lbl(T("EVENT: %s") % T(str(ev.title)), 32)
	# Events met een concreet geldbedrag in hun flavor-tekst gebruiken een
	# "amount"-key (ongeschaalde basiswaarde) i.p.v. het bedrag hard te coderen
	# — anders klopt de tekst na seizoen 1 niet meer met het WERKELIJK
	# geschaalde effect (Game.event_money_scale()).
	var text := T(str(ev.text))
	if ev.has("amount"):
		text = text.replace("{amount}", eur(int(round(float(ev.amount) * Game.event_money_scale()))))
	if str(ev.client_id) != "":
		_show_player_info(str(ev.client_id))
		lbl(text.replace("{client}", cname), 26)
	else:
		lbl(text, 26)
	sep()
	if ev.has("minigame"):
		btn(T("Beginnen →"), func(): _start_minigame(ev))
		return
	var em_ctx := _event_emphasis_context(ev)
	var any_enabled := false
	for opt in ev.options:
		var enabled := true
		var suffix := ""
		if opt.has("req_money") and int(Game.state.money) < int(round(float(opt.req_money) * Game.event_money_scale())):
			enabled = false
			suffix = "  (te weinig geld)"
		if opt.has("req_favors") and int(Game.state.favors) < int(opt.req_favors):
			enabled = false
			suffix = T("  (geen gunst beschikbaar)")
		# Generieke vangnet bovenop req_money: nooit een optie kunnen kiezen die
		# je gegarandeerd onder €0 zet (zie _option_certain_bankrupt()).
		if enabled and _option_certain_bankrupt(opt):
			enabled = false
			suffix = "  (te weinig geld)"
		if enabled:
			any_enabled = true
		var label := T(str(opt.label))
		if opt.has("chance"):
			# Geluksvogel-perk telt mee in de getoonde én de echte kans.
			var shown := clampf(float(opt.chance) + Game.luck_bonus(), 0.0, 0.98)
			# Geen "[65% kans]" meer in de tekst: de knop wordt zelf de balk.
			_style_chance_button(btn(label + suffix, func(): _resolve(ev, opt), enabled), shown)
			var succ_eff := Game.scale_money_effects(opt.get("success", {}))
			var fail_eff := Game.scale_money_effects(opt.get("fail", {}))
			var succ_rows := _effect_rows(succ_eff, "", false, _emphasis_for(succ_eff, em_ctx.max_abs, em_ctx.distinct_counts, em_ctx.min_abs))
			var fail_rows := _effect_rows(fail_eff, "", false, _emphasis_for(fail_eff, em_ctx.max_abs, em_ctx.distinct_counts, em_ctx.min_abs))
			_outcome_columns(succ_rows, fail_rows)
		else:
			btn(label + suffix, func(): _resolve(ev, opt), enabled)
			var eff := Game.scale_money_effects(opt.get("effects", {}))
			_show_effect_rows(eff, "", false, _emphasis_for(eff, em_ctx.max_abs, em_ctx.distinct_counts, em_ctx.min_abs))
	# Anti-softlock: zijn ALLE opties onbetaalbaar/geblokkeerd, dan moet je nog
	# steeds verder kunnen. Zonder deze uitweg zou een event met uitsluitend
	# geldkostende opties je bij een leeg saldo vastzetten op dit scherm.
	if not any_enabled:
		sep()
		lbl(T("Je kunt geen van deze opties betalen. Er zit niets anders op dan het te laten lopen."), 20)
		btn(T("Laten lopen →"), _next_event)


func _resolve(ev: Dictionary, opt: Dictionary) -> void:
	var txt := ""
	var notes: Array = []
	var used: Dictionary = {}
	if opt.has("chance"):
		if Game.rng.randf() < clampf(float(opt.chance) + Game.luck_bonus(), 0.0, 0.98):
			used = Game.scale_money_effects(opt.get("success", {}))
			notes = Game.apply_effects(used, str(ev.client_id))
			txt = T(str(opt.get("success_txt", "Het pakt goed uit.")))
		else:
			used = Game.scale_money_effects(opt.get("fail", {}))
			notes = Game.apply_effects(used, str(ev.client_id))
			txt = T(str(opt.get("fail_txt", "Het mislukt.")))
	else:
		used = Game.scale_money_effects(opt.get("effects", {}))
		notes = Game.apply_effects(used, str(ev.client_id))
		txt = T(str(opt.get("txt", "Gedaan.")))
	refresh_header()
	clear()
	lbl(T("UITKOMST"), 32)
	lbl(txt, 26)
	var cname := ""
	if str(ev.client_id) != "" and Game.state.players.has(ev.client_id):
		cname = str(Game.state.players[ev.client_id].name)
	_show_effect_lines(used, cname)
	for n in notes:
		lbl(T(">> ") + str(n), 24)
	if Game.last_new_client_id != "":
		# Een kaap-event leverde een nieuwe cliënt op — toon zijn/haar echte
		# stats onderaan i.p.v. alleen de naam in de meldingsregel hierboven.
		_show_player_info(Game.last_new_client_id)
	elif str(ev.client_id) != "":
		_show_player_info(str(ev.client_id))
	sep()
	btn(T("Verder →"), _next_event)


# ---------------------------------------------------------------- effect-samenvatting
# Vertaalt een effects-Dictionary (money/rep/scandal/favors/trust/all_trust/
# scout_points) naar leesbare regels, zodat je na élk event/minigame precies
# ziet wat er veranderd is — los van het verhaaltje.

func _fmt_delta(v: int) -> String:
	return ("+%d" % v) if v > 0 else str(v)


func _money_delta(v: int) -> String:
	return ("+" + eur(v)) if v > 0 else eur(v)


# Welke kant van een effect "goed" is voor de speler — schandaal is omgekeerd
# (hoger = slechter), de rest is hoger = beter.
const EFFECT_LABELS := {
	"money": "Geld", "rep": "Reputatie", "scandal": "Schandaal",
	"favors": "Gunsten", "scout_points": "Scoutpunten",
	"scout_points_permanent": "Scoutpunten (voortaan)",
}
const EFFECT_GOOD_HIGH := {
	"money": true, "rep": true, "scandal": false, "favors": true, "scout_points": true,
	"scout_points_permanent": true,
}


const NEGO_BTN_FONT := 19   # tactiekknoppen staan in een smalle kolom, dus kleiner dan standaard
const EMPHASIS_MIN_RATIO := 2.0   # pas 4 tekens als de waarde ÉCHT ≥2× de kleinste is

# Absolute drempel voor GELD (seizoen-1-bedrag, schaalt mee met de economie).
# De gewone emphasis-regel is puur RELATIEF binnen één event, en dat viel bij de
# corruptie-events verkeerd uit: bij "De weldoener" (€20.000 smeergeld) heeft de
# nette optie helemaal geen geldeffect, dus was er niets om mee te vergelijken en
# bleef het bij "++geld" — terwijl €20.000 objectief een smak geld is. Boven deze
# drempel krijgt een bedrag dus altijd de zware markering, ongeacht de rest van
# het event. Werkt op de absolute waarde, dus een fikse STRAF krijgt net zo goed
# "----geld".
const EMPHASIS_BIG_MONEY := 10000


func _big_money_threshold() -> int:
	return int(round(float(EMPHASIS_BIG_MONEY) * Game.event_money_scale()))


func _emphasis_symbol(key: String, emphasize: Dictionary, v: int) -> String:
	var sym := "+" if v > 0 else "-"
	# 2 tekens = normaal, 4 tekens = dubbel zo zwaar. Was 3, maar het verschil
	# tussen "++" en "+++" was visueel én inhoudelijk te klein: de markering
	# betekende alleen "grootste binnen dit event", ook als dat 5 vs. 6 was.
	var reps := 4 if bool(emphasize.get(key, false)) else 2
	return sym.repeat(reps)


func _effect_rows(effects: Dictionary, client_name: String = "", show_numbers: bool = true, emphasize: Dictionary = {}) -> Array:
	# Eén rij per gewijzigde variabele, altijd gekleurd (groen = goed voor
	# jou, rood = slecht). show_numbers=false geeft de kwalitatieve preview
	# (++/-- normaal, of ++++/---- als `emphasize` deze variabele als de
	# zwaarste impact aanmerkt — dat vereist zowel de grootste waarde binnen
	# dit event ALS minstens 2× de kleinste variant, zie _emphasis_for());
	# show_numbers=true geeft de exacte bedragen voor het uitkomstscherm ná
	# een keuze.
	var rows: Array = []
	for key in ["money", "rep", "scandal", "favors", "scout_points", "scout_points_permanent"]:
		if effects.has(key) and int(effects[key]) != 0:
			var v := int(effects[key])
			var good: bool = (v > 0) == bool(EFFECT_GOOD_HIGH[key])
			var label := T(str(EFFECT_LABELS[key]))
			var text: String
			if show_numbers:
				var amount := eur(v) if key == "money" else _fmt_delta(v)
				text = "%s: %s" % [label, amount]
			else:
				text = "%s %s" % [_emphasis_symbol(key, emphasize, v), label]
			rows.append({"text": text, "good": good, "key": key})
	if effects.has("trust") and int(effects.trust) != 0:
		var v := int(effects.trust)
		var who := client_name if client_name != "" else T("cliënt")
		var text := (T("Vertrouwen (%s): %s") % [who, _fmt_delta(v)]) if show_numbers else (T("%s Vertrouwen (%s)") % [_emphasis_symbol("trust", emphasize, v), who])
		rows.append({"text": text, "good": v > 0})
	if effects.has("all_trust") and int(effects.all_trust) != 0:
		var v := int(effects.all_trust)
		var text := (T("Vertrouwen (hele stal): %s") % _fmt_delta(v)) if show_numbers else (T("%s Vertrouwen (hele stal)") % _emphasis_symbol("all_trust", emphasize, v))
		rows.append({"text": text, "good": v > 0})
	# new_client/new_top_client zijn geen getal maar wél de belangrijkste
	# uitkomst van een optie — anders lees je alleen "Reputatie -5" en mis
	# je dat je hier een HELE NIEUWE CLIËNT kunt winnen.
	if bool(effects.get("new_client", false)):
		rows.append({"text": T("★ Kans op een NIEUWE CLIËNT"), "good": true})
	if bool(effects.get("new_top_client", false)):
		rows.append({"text": T("★ Kans op een NIEUWE TOPSPELER als cliënt"), "good": true})
	return rows


const GUNST_GOLD := Color(1.0, 0.84, 0.2)


func _show_effect_rows(effects: Dictionary, client_name: String = "", show_numbers: bool = true, emphasize: Dictionary = {}) -> void:
	var rows := _effect_rows(effects, client_name, show_numbers, emphasize)
	for row in rows:
		var l := lbl(str(row.text), 24 if show_numbers else 20)
		# Gunsten krijgen altijd hun herkenbare goud, ongeacht of de mutatie
		# positief of negatief is — consistent met de goudkleurige "Gunsten"
		# in de header.
		var col: Color
		if str(row.get("key", "")) == "favors":
			col = GUNST_GOLD
		else:
			col = Color(0.35, 0.9, 0.4) if bool(row.good) else Color(1.0, 0.35, 0.35)
		l.add_theme_color_override("font_color", col)


# ---------------------------------------------------------------- preview-nadruk
# Vergelijkt alle mogelijke uitkomsten van een event (alle opties, succes én
# mislukking) en merkt per variabele de GROOTSTE impact aan — die krijgt in
# de preview 3 tekens (+++/---) i.p.v. 2, zodat het zwaarder weegt in de
# afweging. Alleen relevant als er ook daadwerkelijk variatie is (anders
# is "grootst" zinloos).

const EFFECT_KEYS_FOR_EMPHASIS := ["money", "rep", "scandal", "favors", "scout_points", "scout_points_permanent", "trust", "all_trust"]


func _option_certain_bankrupt(opt: Dictionary) -> bool:
	# Zou deze optie je saldo ZEKER onder €0 duwen? Veel events hebben een
	# negatief geldeffect zonder expliciete `req_money`-poortwachter (bijv.
	# "Alvast een transfer voorbereiden"), waardoor je jezelf failliet kon
	# klikken. Dit vangt dat generiek af voor élk event, zonder dat elke
	# optie een eigen req_money hoeft te krijgen.
	# Bij een gok geldt het alleen als BEIDE uitkomsten je eronder brengen: een
	# gok die je pas bij mislukking kopt is een legitiem risico (en de preview
	# toont dat bedrag), geen ontwerpfout.
	var money := int(Game.state.money)
	if opt.has("chance"):
		var s := int(Game.scale_money_effects(opt.get("success", {})).get("money", 0))
		var f := int(Game.scale_money_effects(opt.get("fail", {})).get("money", 0))
		return money + s < 0 and money + f < 0
	var e := int(Game.scale_money_effects(opt.get("effects", {})).get("money", 0))
	return money + e < 0


func _collect_branches(ev: Dictionary) -> Array:
	var branches: Array = []
	for opt in ev.options:
		if opt.has("chance"):
			branches.append(Game.scale_money_effects(opt.get("success", {})))
			branches.append(Game.scale_money_effects(opt.get("fail", {})))
		else:
			branches.append(Game.scale_money_effects(opt.get("effects", {})))
	return branches


func _emphasis_for(effects: Dictionary, max_abs: Dictionary, distinct_counts: Dictionary, min_abs: Dictionary = {}) -> Dictionary:
	var em := {}
	for key in EFFECT_KEYS_FOR_EMPHASIS:
		if not effects.has(key) or int(effects[key]) == 0:
			continue
		var av := absi(int(effects[key]))
		# Absolute uitzondering voor geld: een écht groot bedrag verdient de
		# zware markering ook als er binnen dit event niets is om het mee te
		# vergelijken (zie EMPHASIS_BIG_MONEY).
		if key == "money" and av >= _big_money_threshold():
			em[key] = true
			continue
		var seen: Dictionary = distinct_counts.get(key, {})
		if av != int(max_abs.get(key, 0)) or seen.size() <= 1:
			continue
		# Alleen de zwaarste markering als die ook ÉCHT minstens dubbel zo
		# groot is als de kleinste variant binnen dit event — anders zou
		# "++++" naast "++" staan bij een verschil van bijv. 5 vs. 6, wat de
		# markering betekenisloos maakt.
		var lo := int(min_abs.get(key, av))
		if lo > 0 and float(av) < EMPHASIS_MIN_RATIO * float(lo):
			continue
		em[key] = true
	return em


func _event_emphasis_context(ev: Dictionary) -> Dictionary:
	var max_abs: Dictionary = {}
	var min_abs: Dictionary = {}
	var distinct_counts: Dictionary = {}
	for eff in _collect_branches(ev):
		for key in EFFECT_KEYS_FOR_EMPHASIS:
			if eff.has(key) and int(eff[key]) != 0:
				var av := absi(int(eff[key]))
				max_abs[key] = maxi(int(max_abs.get(key, 0)), av)
				min_abs[key] = av if not min_abs.has(key) else mini(int(min_abs[key]), av)
				var seen: Dictionary = distinct_counts.get(key, {})
				seen[av] = true
				distinct_counts[key] = seen
	return {"max_abs": max_abs, "min_abs": min_abs, "distinct_counts": distinct_counts}


func _show_effect_lines(effects: Dictionary, client_name: String = "") -> void:
	# Uitkomstscherm: mét bedragen, mét kleur.
	var rows := _effect_rows(effects, client_name, true)
	if rows.is_empty():
		return
	sep()
	_show_effect_rows(effects, client_name, true)


# ---------------------------------------------------------------- event-minigames

func _start_minigame(ev: Dictionary) -> void:
	mg_ev = ev
	match str(ev.minigame):
		"persconferentie":
			press = PressConference.new()
			press.setup(Game.rng)
			show_press()
		"fiscale_schikking":
			tax = TaxSettlement.new()
			show_tax()
		"pokerbluf":
			poker = PokerBluff.new()
			poker.setup(Game.rng, Game.event_money_scale())
			show_poker()
		"dobbelen":
			dice = DiceBookmaker.new()
			dice.setup(Game.rng, Game.event_money_scale())
			show_dice()
		"boekhoudpuzzel":
			accounting = AccountingPuzzle.new()
			accounting.setup(Game.rng, int(Game.state.season))
			show_accounting()
		"anagramjacht":
			anagram = AnagramHunt.new()
			anagram.setup(Game.rng)
			show_anagram()
		"scoutspeeddate":
			scoutdate = ScoutSpeedDate.new()
			scoutdate.setup(Game.rng)
			show_scoutdate()
		"simonmedia":
			simon = SimonMedia.new()
			simon.setup(Game.rng, int(Game.state.season))
			show_simon()


# -- Persconferentie --

func show_press() -> void:
	refresh_header()
	clear()
	_dev_test_banner()
	var cid := str(mg_ev.client_id)
	lbl(T("PERSCONFERENTIE"), 32)
	_name_row("", cid, "", 24)
	var sym_lbl := lbl(T("Publiekssympathie: %d/100") % int(press.sympathy), 24)
	sym_lbl.add_theme_color_override("font_color",
		Color(0.35, 0.9, 0.4) if press.sympathy >= 50.0 else Color(1.0, 0.55, 0.3))
	_set_turn_bar("Vragen:", press.questions_left, PressConference.TARGET_QUESTIONS)
	if not press.log.is_empty():
		sep()
		# Alleen de meest recente uitkomst (vraag + antwoord + resultaat, 3
		# regels per zet) i.p.v. de hele geschiedenis — zelfde principe als
		# bij de onderhandeling.
		var start := maxi(press.log.size() - 3, 0)
		for i in range(start, press.log.size()):
			lbl(T("· ") + str(press.log[i]), 20)
	sep()
	if press.finished:
		var o := press.outcome()
		lbl(T(str(o.txt)), 26)
		_show_effect_lines(o.effects, str(Game.state.players[cid].name))
		btn(T("Verder →"), func(): _finish_press(o))
	else:
		var jid := press.current_journalist()
		var j: Dictionary = PressConference.JOURNALISTS[jid]
		if press.is_final_question():
			var final_lbl := lbl(T("⚡ SLOTVRAAG — dubbele inzet"), 22)
			final_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		var j_lbl := lbl(T("%s %s") % [str(j.icon), I18n.T(str(j.name))], 24)
		j_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
		lbl(T(str(j.hint)), 19)
		if press.has_momentum():
			var mom_lbl := lbl(T("MOMENTUM: je volgende succesvolle antwoord telt +50%% zwaarder!"), 19)
			mom_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		var q := lbl(T(press.current_question()), 26)
		q.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		sep()
		btn(T("Ontwijken — 'Daar ga ik nu niet op in.'"), func(): _play_press("ontwijken"))
		btn(T("Toegeven — vertel het eerlijke verhaal"), func(): _play_press("toegeven"))
		btn(T("Aanvallen — de vraag zelf onterecht noemen"), func(): _play_press("aanvallen"))


func _play_press(action: String) -> void:
	press.play(action, Game.rng)
	show_press()


func _finish_press(o: Dictionary) -> void:
	Game.apply_effects(o.effects, str(mg_ev.client_id))
	press = null
	_next_event()


# -- Fiscale schikking --

func show_tax() -> void:
	refresh_header()
	clear()
	_dev_test_banner()
	lbl(T("FISCALE SCHIKKING"), 32)
	if not tax.resolved:
		lbl(T("Kies per post hoe je ermee omgaat. Pas als alle drie gekozen zijn, kun je regelen."), 22)
		for i in range(TaxSettlement.POSTS.size()):
			sep()
			var post: Dictionary = TaxSettlement.POSTS[i]
			var chosen := int(tax.choices[i])
			var labels := ["Open aangeven", "Deels verhullen", "Volledig verhullen"]
			var scaled_amount := int(round(float(post.amount) * Game.event_money_scale()))
			lbl(T("%s (%s)  —  %s") % [T(str(post.name)), eur(scaled_amount),
				labels[chosen] if chosen >= 0 else T("nog niet gekozen")], 24)
			for opt_i in range(3):
				if opt_i != chosen:
					var post_idx := i
					var option_idx := opt_i
					btn(str(labels[opt_i]), func(): _choose_tax(post_idx, option_idx))
					# Geen percentages meer op de knop — alleen de bedragen, groen
					# bij succes en rood bij mislukking (zelfde kleurconventie als
					# de event-previews).
					var amounts: Array = tax.preview_amounts(opt_i, scaled_amount)
					var good := int(amounts[0])
					var bad := int(amounts[1])
					if good == bad:
						# Eén zekere uitkomst (open aangeven): geen succes/mislukking.
						var lc := lbl(T("    %s") % eur(good), 19)
						lc.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
					else:
						var lg := lbl(T("    lukt: %s") % eur(good), 19)
						lg.add_theme_color_override("font_color", Color(0.35, 0.9, 0.4))
						var lb := lbl(T("    mislukt: %s") % eur(bad), 19)
						lb.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		sep()
		btn(T("Regelen →"), _resolve_tax, tax.all_chosen())
	else:
		for r in tax.results:
			lbl(T("· ") + str(r.txt), 22)
		_show_effect_lines({"money": tax.total_money, "scandal": tax.total_scandal})
		sep()
		btn(T("Verder →"), _finish_tax)


func _choose_tax(post_idx: int, option: int) -> void:
	tax.choose(post_idx, option)
	show_tax()


func _resolve_tax() -> void:
	tax.resolve(Game.rng, Game.event_money_scale())
	show_tax()


func _finish_tax() -> void:
	Game.apply_effects({"money": tax.total_money, "scandal": tax.total_scandal}, "")
	tax = null
	_next_event()


# -- Pokerbluf tegen een rivaal --

func show_poker() -> void:
	refresh_header()
	clear()
	_dev_test_banner()
	lbl(T("POKER OM EEN TALENT"), 32)
	lbl(T("Straat: %s   |   Pot: %s") % [str(poker.street).capitalize(), eur(poker.pot)], 26)
	lbl(T("Jouw kaarten: %s   |   Bord: %s") % [
		poker.cards_text(poker.my_hole),
		poker.cards_text(poker.community) if not poker.community.is_empty() else "—",
	], 24)
	lbl(T("Jouw stack: %s   |   Tegenstander: %s%s") % [
		eur(poker.my_stack), eur(poker.opp_stack),
		"   |   Bij te leggen: %s" % eur(poker.to_call) if poker.to_call > 0 else "",
	], 22)
	if not poker.log.is_empty():
		sep()
		for line in poker.log:
			lbl(T("· ") + str(line), 20)
	sep()
	if poker.finished:
		lbl(T("Tegenstander had: %s") % poker.cards_text(poker.opp_hole), 22)
		var o := poker.outcome()
		lbl(T(str(o.txt)), 26)
		_show_effect_lines(o.effects)
		for n in poker_notes:
			lbl(T(">> ") + str(n), 24)
		if Game.last_new_client_id != "":
			_show_player_info(Game.last_new_client_id)
		btn(T("Verder →"), _finish_poker)
	else:
		btn(T("Meegaan") if poker.to_call > 0 else T("Checken"), func(): _play_poker("meegaan"))
		# Na een re-raise van de tegenstander mag je alleen nog meegaan of
		# passen — geen re-re-raise, om het simpel en overzichtelijk te houden.
		if not poker.awaiting_my_response:
			btn(T("Verhogen"), func(): _play_poker("verhogen"))
		btn(T("Passen (veilig wegwezen)"), func(): _play_poker("passen"))


func _play_poker(action: String) -> void:
	poker.play(action, Game.rng)
	# Effecten (incl. eventuele nieuwe cliënt) direct toepassen zodra het
	# spel eindigt, zodat de melding op het uitkomstscherm klopt met de
	# werkelijk toegepaste staat — en niet dubbel wordt toegepast op "Verder".
	if poker.finished and not poker_applied:
		poker_applied = true
		poker_notes = Game.apply_effects(poker.outcome().effects, "")
	show_poker()


func _finish_poker() -> void:
	poker = null
	poker_notes = []
	poker_applied = false
	_next_event()


# -- Dobbelen bij de bookmaker --

func show_dice() -> void:
	refresh_header()
	clear()
	_dev_test_banner()
	lbl(T("DOBBELEN BIJ DE BOOKMAKER"), 32)
	lbl(T("Inzet: %s") % eur(dice.stake), 24)
	_set_turn_bar("Herkansingen:", dice.rolls_left, 2)
	lbl(T("Uitbetaling op je inzet: 5 gelijke ogen ×10, 4 gelijk ×4, full house ×3, 3 gelijk ×1,5, twee paar ×0,5. Niets van dit alles? Dan ben je je inzet kwijt."), 19)
	sep()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	for i in range(5):
		var b := Button.new()
		b.text = "%d%s" % [int(dice.dice[i]), "\n🔒" if dice.held[i] else ""]
		b.custom_minimum_size = Vector2(72, 72)
		b.disabled = dice.finished
		var idx := i
		b.pressed.connect(func(): _toggle_die(idx))
		row.add_child(b)
	if not dice.log.is_empty():
		sep()
		for line in dice.log:
			lbl(T("· ") + str(line), 20)
	sep()
	if dice.finished:
		var o := dice.outcome()
		lbl(T(str(o.txt)), 26)
		_show_effect_lines(o.effects)
		btn(T("Verder →"), func(): _finish_dice(o))
	else:
		lbl(T("Tik dobbelstenen aan om ze vast te houden, gooi dan de rest opnieuw."), 20)
		btn(T("Opnieuw gooien (%d over)") % dice.rolls_left, _reroll_dice, dice.rolls_left > 0)
		var bonus_pct := int(round((dice.early_stop_bonus_for(dice.rolls_left) - 1.0) * 100))
		var stop_label := ("Nu stoppen, uitbetalen  (+%d%% bonus)" % bonus_pct) if bonus_pct > 0 else "Nu stoppen, uitbetalen"
		btn(stop_label, _stop_dice)


func _toggle_die(i: int) -> void:
	dice.toggle_hold(i)
	show_dice()


func _reroll_dice() -> void:
	dice.reroll(Game.rng)
	show_dice()


func _stop_dice() -> void:
	dice.stop_early()
	show_dice()


func _finish_dice(o: Dictionary) -> void:
	Game.apply_effects(o.effects, "")
	dice = null
	_next_event()


# -- Cijferpuzzel voor de boekhouding --

func show_accounting() -> void:
	refresh_header()
	clear()
	_dev_test_banner()
	lbl(T("DE BOEKHOUDPUZZEL"), 32)
	lbl(T("Vul elke rij en kolom met de cijfers 1-5, elk precies één keer."), 22)
	_set_turn_bar("Pogingen:", accounting.attempts_left, 3)
	sep()
	var grid := GridContainer.new()
	grid.columns = AccountingPuzzle.SIZE
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	for i in range(AccountingPuzzle.CELLS):
		var b := Button.new()
		var v := int(accounting.grid[i])
		b.text = str(v) if v > 0 else "·"
		b.custom_minimum_size = Vector2(56, 56)
		b.disabled = bool(accounting.fixed[i]) or accounting.finished
		if bool(accounting.fixed[i]):
			b.modulate = Color(1, 1, 1, 0.5)
		var idx := i
		b.pressed.connect(func(): _cycle_accounting(idx))
		grid.add_child(b)
	if not accounting.log.is_empty():
		sep()
		for line in accounting.log:
			lbl(T("· ") + str(line), 20)
	sep()
	if accounting.finished:
		var o := accounting.outcome(Game.event_money_scale())
		lbl(T(str(o.txt)), 26)
		_show_effect_lines(o.effects)
		btn(T("Verder →"), func(): _finish_accounting(o))
	else:
		btn(T("Controleren"), _check_accounting)


func _cycle_accounting(i: int) -> void:
	accounting.cycle_cell(i)
	show_accounting()


func _check_accounting() -> void:
	accounting.check()
	show_accounting()


func _finish_accounting(o: Dictionary) -> void:
	Game.apply_effects(o.effects, "")
	accounting = null
	_next_event()


# -- Anagramjacht --

func show_anagram() -> void:
	refresh_header()
	clear()
	_dev_test_banner()
	lbl(T("HET GELEKTE DOCUMENT"), 32)
	if not anagram.finished:
		var r: Dictionary = anagram.current()
		if anagram_round_started_idx != anagram.round_idx:
			anagram_round_started_idx = anagram.round_idx
			anagram_time_left = AnagramHunt.ROUND_SECONDS
			anagram_active = true
		lbl(T("Woord %d/3: %s") % [anagram.round_idx + 1, str(r.scrambled)], 28)
		anagram_timer_label = lbl(T("Tijd: %ds") % int(ceil(anagram_time_left)), 22)
		lbl(T("Getypt: %s") % (str(anagram.typed) if str(anagram.typed) != "" else "_"), 26)
		sep()
		# 5 kolommen → 6 rijen voor 26 letters (was 13 kolommen / 2 rijen met
		# 40×40-toetsen). Veel grotere, beter aan te tikken toetsen die de volle
		# schermbreedte gebruiken.
		var kb := GridContainer.new()
		kb.columns = 5
		kb.add_theme_constant_override("h_separation", 6)
		kb.add_theme_constant_override("v_separation", 6)
		kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(kb)
		# Het alfabet komt uit I18n: niet elke taal is Latijns (zie
		# I18n.keyboard_letters()). 5 kolommen geeft 6 rijen bij zowel de 26
		# Latijnse als de 30 Arabische letters.
		for letter in I18n.keyboard_letters():
			var ch := str(letter)
			var kbtn := Button.new()
			kbtn.text = ch
			kbtn.add_theme_font_size_override("font_size", 32)
			kbtn.custom_minimum_size = Vector2(0, 72)
			kbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			kbtn.pressed.connect(func(): _type_anagram_letter(ch))
			kb.add_child(kbtn)
		sep()
		btn(T("⌫ Wis"), _backspace_anagram)
		btn(T("Indienen"), _submit_anagram, anagram.can_submit())
	if not anagram.log.is_empty():
		sep()
		for line in anagram.log:
			lbl(T("· ") + str(line), 20)
	if anagram.finished:
		anagram_active = false
		sep()
		var o := anagram.outcome(Game.event_money_scale())
		lbl(T(str(o.txt)), 26)
		_show_effect_lines(o.effects)
		btn(T("Verder →"), func(): _finish_anagram(o))


func _type_anagram_letter(ch: String) -> void:
	anagram.type_letter(ch)
	show_anagram()


func _backspace_anagram() -> void:
	anagram.backspace()
	show_anagram()


func _submit_anagram() -> void:
	anagram.submit()
	show_anagram()


func _anagram_timeout() -> void:
	anagram_active = false
	anagram.timeout()
	show_anagram()


func _finish_anagram(o: Dictionary) -> void:
	Game.apply_effects(o.effects, "")
	anagram = null
	anagram_active = false
	anagram_round_started_idx = -1
	anagram_timer_label = null
	_next_event()


# -- Speed-dating met scouts --

func show_scoutdate() -> void:
	refresh_header()
	clear()
	_dev_test_banner()
	lbl(T("SPEED-DATEN OP DE SCOUTINGBEURS"), 32)
	lbl(T("Vastgezet: %d/4") % scoutdate.locked_count(), 24)
	_set_turn_bar("Pogingen:", scoutdate.attempts_left, 6)
	if not scoutdate.log.is_empty():
		sep()
		for line in scoutdate.log:
			lbl(T("· ") + str(line), 20)
	sep()
	if scoutdate.finished:
		var o := scoutdate.outcome()
		lbl(T(str(o.txt)), 26)
		_show_effect_lines(o.effects)
		btn(T("Verder →"), func(): _finish_scoutdate(o))
	else:
		lbl(T("Let op: een fout aanbod verbrandt de scout — hij is dan niet meer beschikbaar."), 19)
		for si in range(ScoutSpeedDate.SCOUTS.size()):
			if bool(scoutdate.locked[si]):
				lbl(T("✔ %s — vastgezet") % str(ScoutSpeedDate.SCOUTS[si]), 22)
				continue
			if bool(scoutdate.burned[si]):
				lbl(T("✘ %s — afgehaakt") % str(ScoutSpeedDate.SCOUTS[si]), 22)
				continue
			lbl(str(ScoutSpeedDate.SCOUTS[si]), 22)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			content.add_child(row)
			for ti in range(ScoutSpeedDate.TALENTS.size()):
				var b := Button.new()
				b.text = str(ScoutSpeedDate.TALENTS[ti])
				var s := si
				var t := ti
				b.pressed.connect(func(): _guess_scoutdate(s, t))
				row.add_child(b)


func _guess_scoutdate(scout_idx: int, talent_idx: int) -> void:
	scoutdate.guess(scout_idx, talent_idx)
	show_scoutdate()


func _finish_scoutdate(o: Dictionary) -> void:
	Game.apply_effects(o.effects, "")
	scoutdate = null
	_next_event()


# -- Simon Says voor mediatraining --

func show_simon() -> void:
	refresh_header()
	clear()
	_dev_test_banner()
	var cid := str(mg_ev.client_id)
	lbl(T("MEDIATRAINING: SIMON SAYS"), 32)
	_name_row("", cid, T("   |   Reeks %d/%d") % [simon.round_num, SimonMedia.TARGET_ROUNDS], 24)
	sep()
	if simon.finished:
		var o := simon.outcome()
		lbl(T(str(o.txt)), 26)
		_show_effect_lines(o.effects, str(Game.state.players[cid].name))
		btn(T("Verder →"), func(): _finish_simon(o))
	elif simon.phase == "show":
		lbl(T("Onthoud deze reeks:"), 22)
		lbl(simon.sequence_text(), 28)
		btn(T("Ik heb het onthouden →"), _start_simon_input)
	else:
		lbl(T("Herhaal de reeks (stap %d/%d):") % [simon.player_progress + 1, simon.sequence.size()], 22)
		# Raster van 2 kolommen i.p.v. één lange lijst: bij 8-10 reacties scrol
		# je anders door het halve scherm, en naast elkaar zijn ze veel sneller
		# te scannen tijdens het herhalen van een reeks.
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(grid)
		for i in range(simon.moves.size()):
			var mv := i
			var b := Button.new()
			b.text = T(str(simon.moves[i]))
			b.add_theme_font_size_override("font_size", 24)
			b.custom_minimum_size = Vector2(0, 68)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func(): _play_simon(mv))
			grid.add_child(b)


func _start_simon_input() -> void:
	simon.start_input()
	show_simon()


func _play_simon(move_idx: int) -> void:
	simon.input_move(move_idx, Game.rng)
	show_simon()


func _finish_simon(o: Dictionary) -> void:
	Game.apply_effects(o.effects, str(mg_ev.client_id))
	simon = null
	_next_event()


# ---------------------------------------------------------------- fase 4: window

func _goto_window() -> void:
	interest = {}
	interest_total = {}
	extended = []
	for cid in Game.state.clients:
		interest[cid] = Game.gen_interest(cid)
		interest_total[cid] = interest[cid].size()
	show_window()


func show_window() -> void:
	refresh_header()
	clear()
	var deadline_day: bool = int(Game.state.season) % 5 == 0
	lbl(T("TRANSFERWINDOW") + ("  — DEADLINE DAY!" if deadline_day else ""), 34)
	if deadline_day:
		lbl(T("TD's zijn nerveus vandaag: onderhandelen is makkelijker."), 22)
	show_flash()
	if Game.state.clients.is_empty():
		lbl(T("Je hebt geen cliënten om deals voor te sluiten..."), 26)
	for cid in Game.state.clients:
		sep()
		var p: Dictionary = Game.state.players[cid]
		var contract_txt := T("contract loopt af") if int(p.contract) <= 1 else T("contract nog %d jaar") % int(p.contract)
		lbl(T("%s — rating %d, %s, waarde %s, %s") % [
			p.name, int(p.rating), Game.club_name(str(p.club)), eur(Game.value(p)), contract_txt,
		], 26)
		var ints: Array = interest.get(cid, [])
		if ints.is_empty():
			# Elke speler krijgt bij binnenkomst van dit window GEGARANDEERD
			# 1 of 2 interesses (Game.gen_interest()) — leeg hier betekent dus
			# dat je die al hebt afgehandeld (onderhandeld/afgewezen), niet
			# dat er nooit interesse was.
			lbl(T("Alle interesse voor %s is dit venster al afgehandeld.") % p.name, 22)

		# Drie mogelijke opties per cliënt: onderhandelen met elke
		# geïnteresseerde club plus contract verlengen. Normaal mag je er
		# maar 2 van de 3 doen — bij een hoog gewaardeerde speler blijft de
		# derde staan (tegen een lager tekengeld, zie extend_mult()).
		var high := Game.is_high_rated(p)
		var max_actions := 3 if high else 2
		var used := (int(interest_total.get(cid, 0)) - ints.size()) + (1 if extended.has(cid) else 0)
		var budget := max_actions - used
		var can_extend := str(p.club) != "" and int(p.contract) <= 1 and not extended.has(cid)

		if budget <= 0:
			lbl(T("Geen acties meer over voor %s dit transferwindow.") % p.name, 20)
		elif extended.has(cid):
			# Verlengen sluit clubonderhandelingen voor dit window uit — hij
			# heeft net getekend, dus een nieuwe club is niet meer aan de orde.
			lbl(T("Contract dit window al verlengd. Geen nieuwe clubonderhandeling meer mogelijk."), 20)
		else:
			for club_id in ints:
				var c: Dictionary = Game.state.clubs[club_id]
				var td_txt := str(c.td)
				if Game.td_known(club_id):
					td_txt += " — " + I18n.T(str(Negotiation.PERS_INFO[Game.td_personality(club_id)])).split(" — ")[0]
				btn(T("Onderhandel met %s (TD: %s)") % [c.name, td_txt], func(): _start_nego(cid, club_id))
			if can_extend:
				if high and not ints.is_empty():
					lbl(T("Hoge rating: verlengen blijft een optie náást beide clubgesprekken, maar het tekengeld is lager — met clubs in de rij bindt hij zich niet goedkoop."), 19)
				var tg_preview := int(Game.value(p) * Game.EXTEND_FEE_PCT * Game.tekengeld_mult() * Game.extend_mult(p))
				btn(T("Contract verlengen (tekengeld ~%s)") % eur(tg_preview), func(): _extend(cid))
			elif str(p.club) != "":
				lbl(T("Verlengen kan pas in het laatste contractjaar."), 19)
	sep()
	btn(T("Seizoen afronden →"), _goto_wrapup)


func _extend(cid: String) -> void:
	var tg := Game.extend_contract(cid)
	extended.append(cid)
	flash = T("Contract verlengd. Tekengeld: %s.") % eur(tg)
	show_window()


# ---------------------------------------------------------------- onderhandeling

func _start_nego(cid: String, club_id: String) -> void:
	nego = Negotiation.new()
	nego.cut = Game.fee_cut()
	# Perk-effecten op het gesprek zelf.
	nego.rounds_left = 5 + Meta.perk_level("reserves")
	nego.flow_mult = 1.5 + float(Meta.perk_bonus("flow_meester")) / 100.0
	nego.walk_mod = 1.0 - float(Meta.perk_bonus("stalen_zenuwen")) / 100.0
	nego.clausule_cost = 0.02 - float(Meta.perk_bonus("clausulemeester")) / 1000.0
	nego.aftast_cost = 2 - Meta.perk_level("dossierkennis")
	nego.bluf_bonus = float(Meta.perk_bonus("koelbloedig")) / 100.0
	var v := Game.value(Game.state.players[cid])
	nego.setup(v, Game.start_resistance(club_id), Game.td_personality(club_id), Game.td_known(club_id))
	if Meta.perk_level("helderziend") > 0:
		nego.mood = 2   # elk gesprek start Ontvankelijk
	nego_client = cid
	nego_club = club_id
	show_nego()


func show_nego() -> void:
	refresh_header()
	clear()
	var p: Dictionary = Game.state.players[nego_client]
	var c: Dictionary = Game.state.clubs[nego_club]
	lbl(T("ONDERHANDELING"), 32)
	lbl(T("%s → %s") % [p.name, c.name], 26)
	lbl(T("Transfersom: %s   |   Jouw fee: %d%%") % [eur(nego.deal_value), int(round(nego.cut * 100))], 24)
	# Zodra er een actie is gespeeld (log niet meer leeg) blijft de weerstand
	# zelf ook verborgen tot je de TD kent — anders zou je uit het verschil
	# vóór/na alsnog kunnen afleiden wat een actie deed (en dus welk type hij
	# is), ook al staat er geen expliciet effect meer bij de knoppen.
	var res_txt := "?" if (not nego.pers_known and not nego.log.is_empty()) else str(int(maxf(nego.resistance, 0)))
	lbl(T("Weerstand van TD %s: %s") % [c.td, res_txt], 26)
	_set_turn_bar("Rondes:", nego.rounds_left, 5 + Meta.perk_level("reserves"))
	lbl(T("Stemming: %s") % nego.mood_name(), 24)
	if nego.pers_known:
		lbl(T("Type: %s") % I18n.T(str(Negotiation.PERS_INFO[nego.pers])), 22)
	else:
		lbl(T("Type: onbekend — 'Aftasten' onthult het (blijft deze run bekend)."), 20)
	if nego.has_flow():
		lbl(T("FLOW (%d op rij): je volgende zet krijgt +50%% effect!") % nego.streak, 23)
	elif nego.streak == 1:
		lbl(T("Reeks: 1 succes — nog één voor flow."), 20)
	if not nego.log.is_empty():
		sep()
		# Alleen de meest recente regel — bij een combo kan één zet meerdere
		# regels toevoegen (het effect + "COMBO — ..." + evt. een onthulling),
		# maar we tonen bewust alleen de laatste, geen volledige geschiedenis.
		lbl(T("· ") + str(nego.log[nego.log.size() - 1]), 22)
	sep()
	if nego.finished:
		if nego.success:
			lbl(T("DEAL! Jouw fee: %s") % eur(int(nego.deal_value * nego.cut)), 30)
			btn(T("Incasseren →"), func(): _close_nego(true))
		else:
			lbl(T("Geen deal.") + (T("  De relatie heeft een deuk.") if nego.walked else ""), 28)
			btn(T("Terug naar het window →"), func(): _close_nego(false))
	else:
		# Tactieken links, combo's rechts — twee kolommen naast elkaar. De
		# btn()/lbl()-helpers schrijven altijd naar `content`, dus we wisselen
		# die tijdelijk om zonder de styling-logica te dupliceren.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		content.add_child(row)
		var left_col := VBoxContainer.new()
		left_col.add_theme_constant_override("separation", 14)
		left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var right_col := VBoxContainer.new()
		right_col.add_theme_constant_override("separation", 8)
		right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left_col)
		row.add_child(right_col)

		var real_content := content
		content = left_col
		# Onderhandelaar-perk: elke +5 effectieve rep = +1% tactiekkans.
		# Onderhandelcoach (shop): vlak +3% erbovenop, dus +15 effectieve rep.
		var coach_bonus := 15 if Game.has_shop("onderhandelcoach") else 0
		for t in nego.tactics(int(Game.state.rep) + Meta.perk_bonus("onderhandelen") * 5 + coach_bonus):
			if str(t.id) == "aftasten":
				btn(T("%s  [kost %d %s]") % [T(str(t.label)), nego.aftast_cost, _rounds_word(nego.aftast_cost)], func(): _play_tactic(t), true, NEGO_BTN_FONT)
			else:
				# Zowel de slagingskans als het weerstandseffect blijven verborgen
				# tot je de TD kent (aftasten of een type-combo) — anders zou je
				# via het effect alsnog kunnen afleiden welk type hij is.
				var chance_txt := ("%d%%" % int(round(float(t.chance) * 100))) if nego.pers_known else T("kans ?")
				var drop_txt := (T("weerstand -%d") % int(t.drop)) if nego.pers_known else T("weerstand ?")
				var blocked := nego.is_blocked(str(t.id))
				var suffix := T("  (net mislukt — probeer iets anders)") if blocked else ""
				btn(T("%s  [%s, %s]%s") % [T(str(t.label)), chance_txt, drop_txt, suffix], func(): _play_tactic(t), not blocked, NEGO_BTN_FONT)
		btn(T("Percentage verhogen (+%d%%, raakt weerstand/flow niet)") % int(round(Negotiation.RAISE_FEE_STEP * 100)), _raise_fee, nego.cut < Negotiation.MAX_CUT, NEGO_BTN_FONT)

		var favor_btn := Button.new()
		favor_btn.text = T("🪙 Gunst inzetten: deal direct rond")
		favor_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		favor_btn.custom_minimum_size = Vector2(0, 56)
		favor_btn.disabled = int(Game.state.favors) <= 0
		var favor_style := StyleBoxFlat.new()
		favor_style.bg_color = Color(0.82, 0.64, 0.1)
		favor_style.set_corner_radius_all(10)
		favor_style.content_margin_left = 10
		favor_style.content_margin_right = 10
		favor_btn.add_theme_stylebox_override("normal", favor_style)
		favor_btn.add_theme_stylebox_override("hover", favor_style)
		favor_btn.add_theme_stylebox_override("pressed", favor_style)
		favor_btn.add_theme_color_override("font_color", Color(0.15, 0.09, 0.0))
		favor_btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.36, 0.28))
		favor_btn.pressed.connect(_play_favor_halve)
		left_col.add_child(favor_btn)

		content = right_col
		lbl(T("COMBO'S (opeenvolgende successen; ×1 per gesprek):"), 20)
		# Combo's waar je verder in zit (meer stappen op koers, of al
		# voltooid) staan bovenaan — hoe hoger je zit, hoe relevanter nu.
		var combo_list: Array = Negotiation.COMBOS.duplicate()
		combo_list.sort_custom(func(a, b): return nego.combo_progress(a) > nego.combo_progress(b))
		for combo in combo_list:
			var done: bool = str(combo.id) in nego.combos_done
			var progress := nego.combo_progress(combo)
			var reached: int = combo.pattern.size() if done else progress
			var req := ""
			if combo.has("req_pers"):
				req = T("  [alleen tegen een %s TD]") % T(str(combo.req_pers))
			var mark := "✔" if done else ("▸" if progress > 0 else "·")
			var header_color := Color(0.35, 0.9, 0.4) if done else (Color(1.0, 0.78, 0.15) if progress > 0 else Color(0.75, 0.75, 0.75))
			var header := lbl(T("%s %s (+%d)%s") % [mark, T(str(combo.name)), int(combo.bonus), req], 19)
			header.add_theme_color_override("font_color", header_color)
			_show_combo_pattern_row(combo.pattern, reached)

		content = real_content


# Kleurenschema voor combo-stappen: stap 1 is altijd geel ("net begonnen"),
# de LAATSTE stap is altijd groen ("klaar"), en de stappen ertussen worden
# van AchterAF (vanaf het einde) ingevuld met dit palet — zo werkt de
# kleuring vanzelf voor een combo van willekeurige lengte:
#   lengte 2 → [geel, groen]
#   lengte 3 → [geel, rood, groen]
#   lengte 4 → [geel, blauw, rood, groen]
const COMBO_STEP_FIRST := Color(0.95, 0.85, 0.15)    # geel: stap 1
const COMBO_STEP_FROM_END := [
	Color(0.35, 0.9, 0.4),     # laatste stap: groen
	Color(0.95, 0.3, 0.3),     # voorlaatste stap: rood
	Color(0.35, 0.55, 0.95),   # derde van achteren: blauw
	Color(0.75, 0.4, 0.95),    # vierde van achteren: paars (toekomstige langere combo's)
	Color(0.95, 0.6, 0.2),     # vijfde van achteren: oranje
]
const COMBO_STEP_UNREACHED := Color(0.5, 0.5, 0.5)   # nog niet bereikt: grijs


func _combo_step_color(step_idx: int, total_steps: int) -> Color:
	if step_idx == 0 and total_steps > 1:
		return COMBO_STEP_FIRST
	var distance_from_end := total_steps - 1 - step_idx
	if distance_from_end < COMBO_STEP_FROM_END.size():
		return COMBO_STEP_FROM_END[distance_from_end]
	return Color(0.85, 0.85, 0.85)


func _show_combo_pattern_row(pattern: Array, reached: int) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 2)
	content.add_child(row)
	for i in range(pattern.size()):
		var step_lbl := Label.new()
		step_lbl.text = T(str(Negotiation.MOVE_LABELS.get(pattern[i], pattern[i])))
		step_lbl.add_theme_font_size_override("font_size", 18)
		var col := _combo_step_color(i, pattern.size()) if i < reached else COMBO_STEP_UNREACHED
		step_lbl.add_theme_color_override("font_color", col)
		row.add_child(step_lbl)
		if i < pattern.size() - 1:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.add_theme_font_size_override("font_size", 18)
			arrow.add_theme_color_override("font_color", COMBO_STEP_UNREACHED)
			row.add_child(arrow)


func _play_tactic(t: Dictionary) -> void:
	nego.play(t, Game.rng)
	if nego.pers_known:
		Game.reveal_td(nego_club)
	show_nego()
	if nego.last_combo != "":
		_confetti_burst(nego.last_combo)


func _raise_fee() -> void:
	nego.raise_fee()
	show_nego()


func _play_favor_halve() -> void:
	if int(Game.state.favors) <= 0:
		return
	Game.apply_effects({"favors": -1}, "")
	nego.use_favor_deal()
	show_nego()


# ---------------------------------------------------------------- confetti

const CONFETTI_EMOJI := ["🎉", "✨", "🎊", "⭐", "💰"]

func _confetti_burst(combo_name: String) -> void:
	_confetti(T("★ COMBO — %s! ★") % T(combo_name), Color(1.0, 0.85, 0.2))


func _confetti(banner_text: String, banner_color: Color) -> void:
	# Uit te zetten via Instellingen — één centrale plek, dus zowel de
	# combo-uitbarsting als de tekening-confetti volgen die knop.
	if not bool(Meta.setting("confetti")):
		return
	var vp := get_viewport_rect().size
	var center := vp / 2.0

	var banner := Label.new()
	banner.text = banner_text
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 36)
	banner.add_theme_color_override("font_color", banner_color)
	banner.position = Vector2(0, vp.y * 0.30)
	banner.size = Vector2(vp.x, 60)
	banner.z_index = 100
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.7, 0.7)
	banner.pivot_offset = banner.size / 2.0
	add_child(banner)
	var btw := create_tween()
	btw.tween_property(banner, "modulate:a", 1.0, 0.12)
	btw.parallel().tween_property(banner, "scale", Vector2(1.1, 1.1), 0.12)
	btw.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.1)
	btw.tween_interval(1.0)
	btw.tween_property(banner, "modulate:a", 0.0, 0.5)
	btw.tween_callback(banner.queue_free)

	var burst_rng := RandomNumberGenerator.new()
	burst_rng.randomize()
	for i in range(26):
		var p := Label.new()
		p.text = CONFETTI_EMOJI[burst_rng.randi_range(0, CONFETTI_EMOJI.size() - 1)]
		p.add_theme_font_size_override("font_size", burst_rng.randi_range(20, 34))
		p.z_index = 99
		p.position = center
		p.pivot_offset = Vector2(12, 12)
		add_child(p)
		var angle := burst_rng.randf_range(0, TAU)
		var dist := burst_rng.randf_range(140, 340)
		var target := center + Vector2(cos(angle), sin(angle)) * dist
		var dur := burst_rng.randf_range(0.55, 0.95)
		var tw := create_tween()
		tw.tween_property(p, "position", target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "rotation", burst_rng.randf_range(-4.0, 4.0), dur)
		tw.parallel().tween_property(p, "modulate:a", 0.0, dur * 0.7).set_delay(dur * 0.3)
		tw.tween_callback(p.queue_free)


func _small_negative_puff(text: String) -> void:
	# Klein negatief feedbackje (bijv. bij een afwijzing): een rood tekstje dat
	# kort opkomt, iets omhoog zakt en wegvaagt. Bewust bescheiden — geen
	# schermvullende teleurstelling. Volgt dezelfde instelling als de confetti.
	if not bool(Meta.setting("confetti")):
		return
	var vp := get_viewport_rect().size
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	l.position = Vector2(0, vp.y * 0.36)
	l.size = Vector2(vp.x, 40)
	l.z_index = 100
	l.modulate.a = 0.0
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(l, "position:y", vp.y * 0.32, 0.1)
	tw.tween_interval(0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func _close_nego(deal: bool) -> void:
	if deal and nego != null:
		var income := Game.complete_transfer(nego_client, nego_club, nego.deal_value, nego.cut)
		interest[nego_client] = []
		flash = T("Transfer rond! Jij incasseert %s.") % eur(income)
	else:
		# Eén kans per club per window: afketsen of weglopen verbruikt
		# de interesse, anders kun je eindeloos opnieuw onderhandelen.
		var ints: Array = interest.get(nego_client, [])
		ints.erase(nego_club)
		interest[nego_client] = ints
	nego = null
	show_window()


# ---------------------------------------------------------------- fase 5: afsluiting

# Kleurt een seizoensrapport-regel op basis van het bedrag erin: "-€" is
# altijd een uitgave (rood), "+€" of een kaal "€" (bank/tekengeld-stijl,
# altijd inkomend in deze regels) is groen. Regels zonder bedrag (vertrek,
# vertrouwen) blijven ongekleurd. Ontwikkeling is geen regel meer maar een kaart.
func _wrapup_color(line: String) -> Variant:
	if line.find("-€") != -1:
		return Color(1.0, 0.4, 0.4)
	if line.find("€") != -1:
		return Color(0.4, 0.9, 0.45)
	return null


func _goto_wrapup() -> void:
	var report: Array = Game.end_of_season()
	Game.save_game()
	# Vertrokken cliënten komen als EERSTE, direct na de transferperiode: dat is
	# groot nieuws en moet je in het gezicht slaan vóór de boekhouding van het
	# seizoensrapport. Alleen zichtbaar als er daadwerkelijk iemand weg is.
	var departures: Array = Game.state.get("last_departures", []).duplicate()
	Game.state["last_departures"] = []
	if not departures.is_empty():
		show_departures_news(departures, report)
		return
	_after_departures_news(report)


func _after_departures_news(report: Array) -> void:
	var prepped: Array = Game.state.get("last_prepared_results", []).duplicate()
	Game.state["last_prepared_results"] = []
	if not prepped.is_empty():
		show_prepared_transfer_result(prepped, report)
	else:
		_show_wrapup_report(report)


func show_prepared_transfer_result(results: Array, report: Array) -> void:
	refresh_header()
	clear()
	lbl(T("VOORBEREIDE TRANSFER"), 34)
	lbl(T("Dit is het gevolg van de medische info die je eerder off-the-record kreeg en waarop je een transfer voorbereidde."), 22)
	for r in results:
		sep()
		if bool(r.success):
			lbl(T("%s is verkocht aan een mysterieuze buitenlandse club.") % str(r.name), 26)
			lbl(T("Transfersom: %s") % eur(int(r.transfer_sum)), 24)
			var l := lbl(T("Jouw fee: %s") % eur(int(r.income)), 26)
			l.add_theme_color_override("font_color", Color(0.4, 0.9, 0.45))
		else:
			var l := lbl(T("De transfer van %s ging niet door — de prognose bleek onjuist.") % str(r.name), 24)
			l.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	sep()
	btn(T("Verder →"), func(): _show_wrapup_report(report))


func _show_wrapup_report(report: Array) -> void:
	refresh_header()
	clear()
	lbl(T("SEIZOENSAFSLUITING"), 34)
	for line in report:
		var l := lbl(T("· ") + str(line), 23)
		var c: Variant = _wrapup_color(str(line))
		if c != null:
			l.add_theme_color_override("font_color", c as Color)
	# Ontwikkeling als spelerkaart i.p.v. een tekstregel: met een grijze
	# "WAS"-badge voor de oude rating en een groene pijl naar de nieuwe, zodat je
	# de groei ziet in plaats van hem uit een zin te moeten lezen.
	var developed: Array = Game.state.get("last_developed", [])
	if not developed.is_empty():
		sep()
		lbl(T("📈 ONTWIKKELING"), 28)
		# Volle breedte (géén 2-kolomsraster zoals stal/scouting): deze kaart
		# heeft een derde badge, en in een halve kolom blijft er dan te weinig
		# breedte over voor naam en subregel.
		for d in developed:
			var pid := str(d.get("pid", ""))
			if pid == "" or not Game.state.players.has(pid):
				continue
			var p: Dictionary = Game.state.players[pid]
			# Geen "+X rating"-zin in de subregel: dat cijfer staat nu boven de
			# pijl tussen de WAS- en RAT-badge (zie _player_card()).
			# known_pot: hij was dit seizoen jouw cliënt (anders was er geen
			# ontwikkeling), dus het exacte potentieel hoort er te staan — ook
			# als hij ná zijn groei alsnog vertrok of weggekaapt werd en dus
			# niet meer in state.clients zit.
			content.add_child(_player_card(
				pid, "%s, %d jr" % [str(p.pos), int(p.age)],
				false, false, int(d.get("old", 0)), true))
	sep()
	# Vertrekken zijn hier al langs geweest (show_departures_news() komt vóór dit
	# rapport, zie _goto_wrapup()), dus dit rapport eindigt gewoon.
	_wrapup_continue_button()


func _wrapup_continue_button() -> void:
	if str(Game.state.game_over) != "":
		btn(T("Bekijk het einde →"), show_gameover)
	elif int(Game.state.season) > Game.MAX_SEASONS:
		btn(T("Bekijk het einde →"), show_win)
	else:
		btn(T("🪙 Naar de shop →"), _enter_shop)


func show_departures_news(departures: Array, report: Array) -> void:
	# Groot-nieuws-scherm direct na de transferperiode: je bent een of meer
	# cliënten kwijt. Dekt BEIDE oorzaken (`reason`): "left" = uit zichzelf weg
	# door te laag vertrouwen (veruit het meest voorkomend), "poached" = een
	# rivaal-makelaar nam hem over. Alleen zichtbaar als er echt iemand weg is.
	# Elke speler staat er als volledige spelerkaart bij, zodat je precies ziet
	# wát je kwijt bent (hij bestaat nog in state.players, alleen niet meer in
	# state.clients). Daarna gaat de normale afsluiting verder.
	refresh_header()
	clear()
	var n := departures.size()
	var title := lbl(T("💥 JE RAAKT %s KWIJT") % (T("EEN CLIËNT") if n == 1 else T("%d CLIËNTEN") % n), 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	for entry in departures:
		sep()
		var nm := str(entry.get("name", T("Een cliënt")))
		var reason := str(entry.get("reason", "left"))
		var trust := int(entry.get("trust", 0))
		var line := ""
		if reason == "poached":
			line = T("%s wordt weggekaapt door %s. 'Zij beloven me meer.'") % [nm, str(entry.get("rival", T("een rivaal")))]
		else:
			line = T("%s stapt zelf op. Het vertrouwen was op (%d).") % [nm, trust]
		var l := lbl(line, 26)
		l.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
		var pid := str(entry.get("pid", ""))
		if pid != "" and Game.state.players.has(pid):
			var p: Dictionary = Game.state.players[pid]
			# known_pot: hij wás je cliënt, dus je kende zijn exacte potentieel —
			# dat verdwijnt niet op het moment dat hij vertrekt.
			content.add_child(_player_card(pid, T("%s, %d jr · vertrouwen was %d · waarde %s") % [
				str(p.pos), int(p.age), trust, eur(Game.value(p)),
			], false, false, -1, true))
	sep()
	lbl(T("Vertrouwen is je enige verdediging: onder de 60 loopt het vertrekrisico elk punt verder op. Een cliënt die zich gezien voelt, blijft — en luistert niet naar een rivaal."), 19)
	sep()
	btn(T("Verder →"), func(): _after_departures_news(report))


# ---------------------------------------------------------------- de shop

func _enter_shop() -> void:
	shop_offers = Game.shop_offer(Game.rng, 3)
	show_shop()


func show_shop() -> void:
	refresh_header()
	clear()
	lbl(T("🪙 DE SHOP"), 34)
	lbl(T("Elke seizoenswissel liggen hier 3 willekeurige upgrades voor de rest van deze run. Koop wat je wilt, reroll voor een andere set, of loop gewoon door — niets verplicht."), 22)
	show_flash()
	sep()
	if shop_offers.is_empty():
		lbl(T("Niets (meer) te koop deze keer."), 24)
	for id in shop_offers:
		var title := lbl(Game.shop_name(id), 26)
		title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
		lbl(Game.shop_desc(id), 21)
		if Game.has_shop(id):
			lbl(T("✔ Gekocht"), 20)
		else:
			btn(T("Kopen (%s)") % eur(Game.shop_price(id)), func(): _buy_shop(id), Game.can_buy_shop(id))
		sep()
	btn(T("🎲 Reroll — andere upgrades (%s)") % eur(Game.shop_reroll_cost()), _reroll_shop, Game.can_reroll_shop())
	sep()
	btn(T("Doorgaan naar volgend seizoen →"), show_prep)


func _buy_shop(id: String) -> void:
	if Game.buy_shop_upgrade(id):
		flash = T("%s gekocht!") % Game.shop_name(id)
	show_shop()


func _reroll_shop() -> void:
	if Game.pay_shop_reroll():
		# Sluit de huidige set uit, zodat een reroll echt iets anders geeft
		# (tenzij er te weinig andere upgrades over zijn).
		shop_offers = Game.shop_offer(Game.rng, 3, shop_offers)
		flash = T("Nieuwe upgrades ingeladen.")
	else:
		flash = T("Te weinig geld om te rerollen.")
	show_shop()


# ---------------------------------------------------------------- einde

func show_gameover() -> void:
	refresh_header()
	var earned := _finish_run_meta(false)
	clear()
	var reason := str(Game.state.game_over)
	lbl(T("GAME OVER"), 40)
	match reason:
		"failliet":
			lbl(T("Failliet. De deurwaarder neemt zelfs je gesigneerde shirtjes mee."), 26)
		"licentie":
			lbl(T("Je licentie is ingetrokken. De bond stuurt een koele brief; de pers een fotograaf."), 26)
		"leeg":
			lbl(T("Je laatste cliënt is vertrokken. Een makelaar zonder spelers is gewoon een man met een telefoon."), 26)
		_:
			lbl(T("De run is voorbij."), 26)
	sep()
	lbl(T("Seizoenen overleefd: %d") % (int(Game.state.season)), 24)
	lbl(T("Totaal aan fees verdiend: %s") % eur(Game.state.total_fees), 24)
	sep()
	if earned > 0:
		lbl(T("+%s legacy points verdiend  →  totaal %s") % [_pts(earned), _pts(Meta.state.legacy_points)], 24)
	else:
		lbl(T("Legacy points: %s") % _pts(Meta.state.legacy_points), 24)
	btn(T("Perks bekijken →"), show_perks)
	btn(T("Nieuwe run"), _on_restart)


func show_win() -> void:
	refresh_header()
	var earned := _finish_run_meta(true)
	clear()
	lbl(T("JE HEBT HET GEHAALD"), 38)
	lbl(T("Je overleefde alle %d seizoenen. Van snackbar-kantoor naar gevestigde naam.") % Game.MAX_SEASONS, 26)
	sep()
	lbl(T("EINDSCORE (totaal aan fees): %s") % eur(Game.state.total_fees), 30)
	var fees := int(Game.state.total_fees)
	if fees >= 750000:
		lbl(T("Rang: SUPERAGENT. Jouw naam gonst door elke bestuurskamer."), 24)
	elif fees >= 400000:
		lbl(T("Rang: Gevestigde makelaar. Netjes — maar de top lonkt."), 24)
	else:
		lbl(T("Rang: Overlever. Je bestaat nog. Dat is niet hetzelfde als winnen."), 24)
	sep()
	if earned > 0:
		lbl(T("+%s legacy points verdiend  →  totaal %s") % [_pts(earned), _pts(Meta.state.legacy_points)], 24)
		if Meta.last_champion_bonus > 0:
			var bonus_lbl := lbl(T("Waarvan %s KAMPIOENSBONUS — 12%% van je hele carrière-saldo, in één klap.") % _pts(Meta.last_champion_bonus), 22)
			bonus_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		lbl(T("Legacy points: %s") % _pts(Meta.state.legacy_points), 24)
	btn(T("Perks bekijken →"), show_perks)
	btn(T("Nieuwe run"), _on_restart)


func _on_restart() -> void:
	Game.delete_save()
	Game.new_run()
	show_prep()
