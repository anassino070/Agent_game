# main.gd — de volledige UI, programmatisch opgebouwd.
# Elke fase van een seizoen is een "scherm": prep → scouting → events →
# transferwindow → afsluiting. Game (autoload) bevat alle logica en staat.
extends Control

var header: Label
var content: VBoxContainer

var event_queue: Array = []
var interest: Dictionary = {}      # client_id -> Array van (nog niet gebruikte) club_ids
var interest_total: Dictionary = {} # client_id -> oorspronkelijk aantal geïnteresseerde clubs
var candidates: Array = []         # scouting/tekendoelen dit seizoen
var approached: Array = []         # al benaderd dit seizoen (één poging p.p.)
var extended: Array = []           # contract al verlengd dit window
var flash := ""                    # korte statusmelding bovenin een scherm

var nego: Negotiation = null
var nego_client := ""
var nego_club := ""

# Event-minigames: precies één van deze is actief tijdens een minigame-event.
var mg_ev: Dictionary = {}          # het originerende event (voor client_id, terugkeer)
var bidding: BiddingWar = null
var press: PressConference = null
var sponsor: SponsorPitch = null
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
var confirm_reset := false         # tweestaps-bevestiging voor de perk-reset

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

var bank_deposit_input: LineEdit = null


# ---------------------------------------------------------------- opbouw

func _process(delta: float) -> void:
	if not anagram_active or anagram == null or anagram.finished:
		return
	anagram_time_left -= delta
	if anagram_time_left <= 0.0:
		anagram_time_left = 0.0
		_anagram_timeout()
	elif anagram_timer_label != null and is_instance_valid(anagram_timer_label):
		anagram_timer_label.text = "Tijd: %ds" % int(ceil(anagram_time_left))


func _ready() -> void:
	var th := Theme.new()
	th.default_font_size = 30
	theme = th

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	header = Label.new()
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("font_size", 24)
	vbox.add_child(header)

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
	home_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	home_btn.offset_left = -104
	home_btn.offset_top = -104
	home_btn.offset_right = -24
	home_btn.offset_bottom = -24
	home_btn.pressed.connect(_go_home)
	add_child(home_btn)

	# ∞-upgrade: klein vierkantje rechtsboven, alleen zichtbaar op het
	# perkscherm. Vaste prijs, oneindig te kopen, +0,01% punten per niveau.
	inf_btn = Button.new()
	inf_btn.add_theme_font_size_override("font_size", 18)
	inf_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inf_btn.offset_left = -160
	inf_btn.offset_top = 24
	inf_btn.offset_right = -24
	inf_btn.offset_bottom = 160
	inf_btn.pressed.connect(_buy_inf)
	inf_btn.visible = false
	add_child(inf_btn)

	show_start()


func _go_home() -> void:
	# Terug naar het startscherm. Een run wordt alleen aan het eind van een
	# seizoen opgeslagen; "Doorgaan" pakt dus het begin van dit seizoen op.
	show_start()


# ---------------------------------------------------------------- helpers

func clear() -> void:
	for c in content.get_children():
		c.queue_free()
	if home_btn:
		home_btn.visible = true
	if inf_btn:
		inf_btn.visible = false


func lbl(text: String, size := 28) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(l)
	return l


func btn(text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 72)
	b.pressed.connect(cb)
	content.add_child(b)
	return b


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


func refresh_header() -> void:
	var s: Dictionary = Game.state
	header.text = "Seizoen %d/%d  |  %s  |  Rep %d  |  Schandaal %d  |  Gunsten %d" % [
		int(s.season), Game.MAX_SEASONS, eur(s.money),
		int(s.rep), int(s.scandal), int(s.favors),
	]


func show_flash() -> void:
	if flash != "":
		lbl(">> " + flash, 24)
		flash = ""


# ---------------------------------------------------------------- startscherm

func show_start() -> void:
	clear()
	home_btn.visible = false
	header.text = "VOETBALMAKELAAR"
	lbl("Van kelderkantoor naar superagent.", 34)
	lbl("Overleef %d seizoenen. Ga niet failliet, houd je schandaalmeter onder de 100 en zorg dat je cliënten je niet verlaten." % Game.MAX_SEASONS, 26)
	sep()
	lbl("LEGACY — %d runs gespeeld  |  beste run: %s (seizoen %d)  |  totale carrièrefees: %s" % [
		int(Meta.state.runs_completed), eur(Meta.state.best_fees), int(Meta.state.best_season),
		eur(Meta.state.total_career_fees),
	], 21)
	btn("Perkboom (%s legacy points te besteden) →" % _pts(Meta.state.legacy_points), show_perks)
	sep()
	btn("NIEUWE RUN", _on_new_run)
	if Game.has_save():
		btn("Doorgaan met vorige run", _on_continue)
	sep()
	var dev_tap := btn("v1.0", _on_dev_tap)
	dev_tap.add_theme_font_size_override("font_size", 14)
	dev_tap.modulate = Color(1, 1, 1, 0.25)
	dev_tap.custom_minimum_size = Vector2(0, 36)


# ---------------------------------------------------------------- developer-only

func _on_dev_tap() -> void:
	dev_taps += 1
	if dev_taps >= DEV_TAPS_NEEDED:
		dev_taps = 0
		_show_dev_login()


func _show_dev_login(error := "") -> void:
	clear()
	header.text = "DEVELOPER"
	if error != "":
		var e := lbl(error, 20)
		e.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	lbl("Voer het developer-wachtwoord in.", 22)
	var input := LineEdit.new()
	input.placeholder_text = "wachtwoord"
	input.secret = true
	input.custom_minimum_size = Vector2(0, 56)
	content.add_child(input)
	btn("Bevestigen", func(): _check_dev_password(input.text))
	btn("← Terug", show_start)


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
	header.text = "DEVELOPER — puntenbeheer"
	lbl("Huidig puntensaldo: %s legacy points." % _pts(Meta.state.legacy_points), 26)
	lbl("Dit wist alleen het saldo, niet de gekochte perk-niveaus (gebruik daarvoor 'Reset alle perks' op het perkscherm).", 20)
	sep()
	if dev_confirm:
		lbl("Weet je het zeker? Het puntensaldo gaat naar 0 en dit kan niet ongedaan worden.", 22)
		btn("JA — wis puntensaldo", _do_dev_wipe)
		btn("Annuleer", func(): dev_confirm = false; show_dev_panel())
	else:
		btn("Wis alle punten (naar 0)", func(): dev_confirm = true; show_dev_panel())
	sep()
	lbl("Testmodus: doorloopt ALLE %d events op volgorde, met onbeperkt geld en zonder fail-checks. Start een verse testrun in het geheugen — je opgeslagen run blijft veilig op schijf." % EventsDB.get_events().size(), 20)
	btn("Test: doorloop alle events →", _start_event_test)
	sep()
	btn("← Terug naar start", func(): dev_unlocked = false; dev_confirm = false; show_start())


func _do_dev_wipe() -> void:
	Meta.dev_wipe_points()
	dev_confirm = false
	show_dev_panel()


# ---- Developer-only eventtest ----

func _dev_test_banner() -> void:
	if not dev_test_mode:
		return
	var l := lbl("[DEV TEST] Event %d/%d — id: %s" % [dev_test_index, dev_test_total, str(mg_ev.get("id", "?"))], 18)
	l.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	dev_jump_input = LineEdit.new()
	dev_jump_input.placeholder_text = "nr"
	dev_jump_input.custom_minimum_size = Vector2(70, 40)
	row.add_child(dev_jump_input)
	var jump_btn := Button.new()
	jump_btn.text = "Ga naar event"
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
	bidding = null
	press = null
	sponsor = null
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
	flash = "Testrun klaar: alle %d events doorlopen." % dev_test_total
	show_dev_panel()


# ---------------------------------------------------------------- meta: perks

func show_perks() -> void:
	clear()
	_refresh_inf_btn()
	inf_btn.visible = true
	header.text = "PERKBOOM — %s legacy points" % _pts(Meta.state.legacy_points)
	lbl("Boom voltooid: %s%%  (%s van %s punten)" % [
		("%.1f" % (Meta.tree_progress() * 100.0)).replace(".", ","),
		_pts(Meta.tree_spent()), _pts(Meta.tree_total_cost()),
	], 26)
	lbl("Permanente upgrades voor elke volgende run. Je verdient legacy points door te spelen — hoe verder je komt, hoe exponentieel meer (een gewonnen run = 1%% van de boom). Elke rij biedt 3 opties; koop %d niveaus in een rij om de rij eronder te ontgrendelen." % Meta.TIER_REQ, 22)
	for branch in Meta.TREE:
		sep()
		lbl("◆ TAK: %s" % str(branch.name), 30)
		for tier_idx in range(branch.tiers.size()):
			var unlocked: bool = Meta.tier_unlocked(branch, tier_idx)
			if unlocked:
				lbl("— Rij %d —" % (tier_idx + 1), 22)
				for id in branch.tiers[tier_idx]:
					_perk_node(str(id))
			else:
				var names: Array = []
				for id in branch.tiers[tier_idx]:
					names.append(str(Meta.PERKS[id].name))
				lbl("🔒 Rij %d (%s) — vereist %d niveaus in rij %d (nu %d)." % [
					tier_idx + 1, ", ".join(names), Meta.TIER_REQ, tier_idx,
					Meta.tier_levels(branch, tier_idx - 1),
				], 20)
	sep()
	lbl("★ OVERPOWERED — extra's buiten de boom (tellen niet mee voor de 100%)", 26)
	for id in Meta.OP_PERKS:
		_perk_node(str(id))
	sep()
	var spent := Meta.spent_points()
	if spent > 0:
		if confirm_reset:
			lbl("Weet je het zeker? Alle perks (ook de ★-extra's) gaan naar 0; je krijgt %s punten terug." % _pts(spent), 22)
			btn("JA — reset alles", _do_reset)
			btn("Annuleer", func(): _set_confirm(false))
		else:
			btn("Reset alle perks (geeft %s punten terug)" % _pts(spent), func(): _set_confirm(true))
	btn("← Terug", show_start)


func _pts(n) -> String:
	# Zelfde duizendtal-notatie als eur(), zonder valutateken.
	return eur(n).replace("€", "")


func _set_confirm(v: bool) -> void:
	confirm_reset = v
	show_perks()


func _do_reset() -> void:
	Meta.reset_perks()
	confirm_reset = false
	show_perks()


func _perk_node(id: String) -> void:
	var perk: Dictionary = Meta.PERKS[id]
	var lvl := Meta.perk_level(id)
	var maxlvl := int(perk.max_level)
	var bar := "●".repeat(lvl) + "○".repeat(maxlvl - lvl)
	lbl("  %s  %s" % [str(perk.name), bar], 25)
	if lvl > 0:
		lbl("       nu: " + Meta.perk_desc(id, lvl), 21)
	if lvl < maxlvl:
		lbl("       volgend niveau: " + Meta.perk_desc(id, 1), 21)
		btn("Koop %s niveau %d  (%s punten)" % [str(perk.name), lvl + 1, _pts(Meta.perk_cost(id))], func(): _buy_perk(id), Meta.can_buy(id))
	else:
		lbl("       MAX bereikt.", 20)


func _buy_perk(id: String) -> void:
	Meta.buy_perk(id)
	show_perks()


func _refresh_inf_btn() -> void:
	inf_btn.text = "∞ ×%s\n+0,01%%\nkoop: %d pt" % [
		("%.4f" % Meta.inf_multiplier()).replace(".", ","), Meta.INF_COST,
	]
	inf_btn.disabled = int(Meta.state.legacy_points) < Meta.INF_COST


func _buy_inf() -> void:
	if Meta.buy_inf():
		# Alleen de knop en de header verversen; de boom hoeft niet opnieuw.
		header.text = "PERKBOOM — %s legacy points" % _pts(Meta.state.legacy_points)
	_refresh_inf_btn()


# Kent legacy points toe voor de afgelopen run, maar hoogstens één keer per
# run (anders zou opnieuw naar hetzelfde game-over-scherm gaan dubbel uitbetalen).
func _finish_run_meta(won: bool) -> int:
	if bool(Game.state.get("meta_awarded", false)):
		return 0
	var seasons := mini(int(Game.state.season), Game.MAX_SEASONS)
	var earned := Meta.award_run(int(Game.state.total_fees)/10, seasons, won)
	Game.state.meta_awarded = true
	Game.save_game()
	return earned


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
	lbl("VOORBEREIDING", 34)
	if str(Game.state.news) != "":
		lbl("Nieuws: " + str(Game.state.news), 24)
	show_flash()
	sep()
	lbl("Jouw stal (%d/%d):" % [Game.state.clients.size(), Game.client_cap()], 28)
	for cid in Game.state.clients:
		var p: Dictionary = Game.state.players[cid]
		lbl("• %s (%s, %d jr) — rating %d, vertrouwen %d, %s, contract %d jr, waarde %s" % [
			p.name, p.pos, int(p.age), int(p.rating), int(p.trust),
			Game.club_name(str(p.club)), int(p.contract), eur(Game.value(p)),
		], 23)
	sep()
	lbl("DE BANK — stort geld weg, krijg het na %d seizoenen verdubbeld terug." % Game.BANK_MATURITY_SEASONS, 20)
	if Game.bank_deposit_count() > 0:
		lbl("Nog uitstaand: %s in %d storting(en)." % [eur(Game.bank_total_pending()), Game.bank_deposit_count()], 19)
	var bank_row := HBoxContainer.new()
	bank_row.add_theme_constant_override("separation", 10)
	content.add_child(bank_row)
	bank_deposit_input = LineEdit.new()
	bank_deposit_input.placeholder_text = "bedrag"
	bank_deposit_input.custom_minimum_size = Vector2(140, 48)
	bank_row.add_child(bank_deposit_input)
	var deposit_btn := Button.new()
	deposit_btn.text = "Storten"
	deposit_btn.custom_minimum_size = Vector2(0, 48)
	deposit_btn.pressed.connect(_do_bank_deposit)
	bank_row.add_child(deposit_btn)
	sep()
	btn("Naar scouting →" if Meta.perk_level("vaste_kern") > 0 else "Naar stalbeheer →", _goto_release)


func _do_bank_deposit() -> void:
	if bank_deposit_input == null:
		return
	var amount := int(bank_deposit_input.text)
	if Game.bank_deposit(amount):
		var payout := int(round(float(amount) * Game.BANK_MULTIPLIER))
		flash = "Gestort: %s. Komt over %d seizoenen terug als %s." % [eur(amount), Game.BANK_MATURITY_SEASONS, eur(payout)]
	else:
		flash = "Storting mislukt — vul een geldig bedrag in dat je ook echt hebt."
	show_prep()


# ---------------------------------------------------------------- fase 1b: stalbeheer

func _goto_release() -> void:
	# ★ Vaste kern-perk: jij bent de uitzondering op de ontslagregel.
	if Meta.perk_level("vaste_kern") > 0:
		_goto_scouting()
		return
	# Met 0 of 1 cliënten is ontslaan direct game over ("leeg") — dan slaan
	# we de verplichting over.
	if Game.state.clients.size() <= 1:
		_goto_scouting()
		return
	show_release()


func show_release() -> void:
	refresh_header()
	clear()
	lbl("STALBEHEER — VERPLICHT ONTSLAG", 34)
	lbl("Een makelaar zonder ruimte mist het volgende toptalent. Stuur één cliënt weg om plek te maken. De rest van je stal verliest er 2 vertrouwen door.", 24)
	sep()
	for cid in Game.state.clients:
		var p: Dictionary = Game.state.players[cid]
		lbl("%s (%s, %d jr) — rating %d, vertrouwen %d, waarde %s" % [
			p.name, p.pos, int(p.age), int(p.rating), int(p.trust), eur(Game.value(p)),
		], 23)
		btn("Stuur %s weg" % p.name, func(): _release(cid))
		sep()


func _release(cid: String) -> void:
	var p: Dictionary = Game.state.players[cid]
	Game.release_client(cid)
	flash = "%s pakt zijn spullen. 'Ik dacht dat we een team waren.'" % p.name
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
	lbl("SCOUTING  (%d punten over)" % int(Game.state.scout_points), 34)
	show_flash()
	lbl("De potentieel-band is een schátting — die kan er flink naast zitten. Scouten trekt haar naar de waarheid én maakt tekenen makkelijker (+5% per scout, max +10%).", 22)
	lbl("Jouw reputatie (%d) opent deuren tot rating ~%d (jong) / ~%d (gevestigd)." % [
		int(Game.state.rep), Game.rating_cap_young(), Game.rating_cap_older(),
	], 20)
	for pid in candidates:
		sep()
		var p: Dictionary = Game.state.players[pid]
		var est := Game.estimate(pid)
		var lo := maxi(est - int(p.unc), int(p.rating))
		var hi := mini(est + int(p.unc), 95)
		var is_client: bool = pid in Game.state.clients
		lbl("%s (%s, %d jr) — rating %d, potentieel %d–%d, %s%s" % [
			p.name, p.pos, int(p.age), int(p.rating), lo, hi,
			Game.club_name(str(p.club)), "  [CLIËNT]" if is_client else "",
		], 24)
		if int(Game.state.scout_points) > 0 and int(p.unc) > 2:
			btn("Scout (1 punt)", func(): _scout(pid))
		if not is_client:
			if approached.has(pid):
				lbl("Al benaderd dit seizoen — hij wil er even over nadenken.", 20)
			elif Game.state.clients.size() < Game.client_cap():
				btn("Benader als cliënt (kans %d%%)" % int(round(Game.sign_chance(pid) * 100)), func(): _try_sign(pid))
	sep()
	btn("Naar events →", _goto_events)


func _scout(pid: String) -> void:
	Game.scout(pid)
	show_scouting()


func _try_sign(pid: String) -> void:
	var p: Dictionary = Game.state.players[pid]
	approached.append(pid)
	if Game.attempt_sign(pid):
		flash = "%s tekent bij jou!" % p.name
	else:
		flash = "%s wijst je af. 'Ik hoor goede verhalen over een ander kantoor.'" % p.name
	show_scouting()


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
	lbl("EVENT: %s" % str(ev.title), 32)
	lbl(str(ev.text).replace("{client}", cname), 26)
	sep()
	if ev.has("minigame"):
		btn("Beginnen →", func(): _start_minigame(ev))
		return
	var em_ctx := _event_emphasis_context(ev)
	for opt in ev.options:
		var enabled := true
		var suffix := ""
		if opt.has("req_money") and int(Game.state.money) < int(round(float(opt.req_money) * Game.event_money_scale())):
			enabled = false
			suffix = "  (te weinig geld)"
		if opt.has("req_favors") and int(Game.state.favors) < int(opt.req_favors):
			enabled = false
			suffix = "  (geen gunst beschikbaar)"
		var label := str(opt.label)
		if opt.has("chance"):
			# Geluksvogel-perk telt mee in de getoonde én de echte kans.
			var shown := clampf(float(opt.chance) + Game.luck_bonus(), 0.0, 0.98)
			label += "  [%d%% kans]" % int(round(shown * 100))
			btn(label + suffix, func(): _resolve(ev, opt), enabled)
			var succ_eff := Game.scale_money_effects(opt.get("success", {}))
			var fail_eff := Game.scale_money_effects(opt.get("fail", {}))
			var succ_rows := _effect_rows(succ_eff, "", false, _emphasis_for(succ_eff, em_ctx.max_abs, em_ctx.distinct_counts))
			var fail_rows := _effect_rows(fail_eff, "", false, _emphasis_for(fail_eff, em_ctx.max_abs, em_ctx.distinct_counts))
			if not succ_rows.is_empty():
				lbl("Bij succes:", 18)
				for row in succ_rows:
					var l := lbl(str(row.text), 19)
					l.add_theme_color_override("font_color", Color(0.35, 0.9, 0.4) if bool(row.good) else Color(1.0, 0.35, 0.35))
			if not fail_rows.is_empty():
				lbl("Bij mislukking:", 18)
				for row in fail_rows:
					var l := lbl(str(row.text), 19)
					l.add_theme_color_override("font_color", Color(0.35, 0.9, 0.4) if bool(row.good) else Color(1.0, 0.35, 0.35))
		else:
			btn(label + suffix, func(): _resolve(ev, opt), enabled)
			var eff := Game.scale_money_effects(opt.get("effects", {}))
			_show_effect_rows(eff, "", false, _emphasis_for(eff, em_ctx.max_abs, em_ctx.distinct_counts))


func _resolve(ev: Dictionary, opt: Dictionary) -> void:
	var txt := ""
	var notes: Array = []
	var used: Dictionary = {}
	if opt.has("chance"):
		if Game.rng.randf() < clampf(float(opt.chance) + Game.luck_bonus(), 0.0, 0.98):
			used = Game.scale_money_effects(opt.get("success", {}))
			notes = Game.apply_effects(used, str(ev.client_id))
			txt = str(opt.get("success_txt", "Het pakt goed uit."))
		else:
			used = Game.scale_money_effects(opt.get("fail", {}))
			notes = Game.apply_effects(used, str(ev.client_id))
			txt = str(opt.get("fail_txt", "Het mislukt."))
	else:
		used = Game.scale_money_effects(opt.get("effects", {}))
		notes = Game.apply_effects(used, str(ev.client_id))
		txt = str(opt.get("txt", "Gedaan."))
	refresh_header()
	clear()
	lbl("UITKOMST", 32)
	lbl(txt, 26)
	var cname := ""
	if str(ev.client_id) != "" and Game.state.players.has(ev.client_id):
		cname = str(Game.state.players[ev.client_id].name)
	_show_effect_lines(used, cname)
	for n in notes:
		lbl(">> " + str(n), 24)
	sep()
	btn("Verder →", _next_event)


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
}
const EFFECT_GOOD_HIGH := {
	"money": true, "rep": true, "scandal": false, "favors": true, "scout_points": true,
}


func _emphasis_symbol(key: String, emphasize: Dictionary, v: int) -> String:
	var sym := "+" if v > 0 else "-"
	var reps := 3 if bool(emphasize.get(key, false)) else 2
	return sym.repeat(reps)


func _effect_rows(effects: Dictionary, client_name: String = "", show_numbers: bool = true, emphasize: Dictionary = {}) -> Array:
	# Eén rij per gewijzigde variabele, altijd gekleurd (groen = goed voor
	# jou, rood = slecht). show_numbers=false geeft de kwalitatieve preview
	# (++/-- , of +++/---- als `emphasize` deze variabele als grootste
	# impact aanmerkt — vergeleken met de andere opties van hetzelfde
	# event) voor vóór een keuze; show_numbers=true geeft de exacte
	# bedragen voor het uitkomstscherm ná een keuze.
	var rows: Array = []
	for key in ["money", "rep", "scandal", "favors", "scout_points"]:
		if effects.has(key) and int(effects[key]) != 0:
			var v := int(effects[key])
			var good: bool = (v > 0) == bool(EFFECT_GOOD_HIGH[key])
			var label := str(EFFECT_LABELS[key])
			var text: String
			if show_numbers:
				var amount := eur(v) if key == "money" else _fmt_delta(v)
				text = "%s: %s" % [label, amount]
			else:
				text = "%s %s" % [_emphasis_symbol(key, emphasize, v), label]
			rows.append({"text": text, "good": good})
	if effects.has("trust") and int(effects.trust) != 0:
		var v := int(effects.trust)
		var who := client_name if client_name != "" else "cliënt"
		var text := ("Vertrouwen (%s): %s" % [who, _fmt_delta(v)]) if show_numbers else ("%s Vertrouwen (%s)" % [_emphasis_symbol("trust", emphasize, v), who])
		rows.append({"text": text, "good": v > 0})
	if effects.has("all_trust") and int(effects.all_trust) != 0:
		var v := int(effects.all_trust)
		var text := ("Vertrouwen (hele stal): %s" % _fmt_delta(v)) if show_numbers else ("%s Vertrouwen (hele stal)" % _emphasis_symbol("all_trust", emphasize, v))
		rows.append({"text": text, "good": v > 0})
	return rows


func _show_effect_rows(effects: Dictionary, client_name: String = "", show_numbers: bool = true, emphasize: Dictionary = {}) -> void:
	var rows := _effect_rows(effects, client_name, show_numbers, emphasize)
	for row in rows:
		var l := lbl(str(row.text), 24 if show_numbers else 20)
		l.add_theme_color_override("font_color", Color(0.35, 0.9, 0.4) if bool(row.good) else Color(1.0, 0.35, 0.35))


# ---------------------------------------------------------------- preview-nadruk
# Vergelijkt alle mogelijke uitkomsten van een event (alle opties, succes én
# mislukking) en merkt per variabele de GROOTSTE impact aan — die krijgt in
# de preview 3 tekens (+++/---) i.p.v. 2, zodat het zwaarder weegt in de
# afweging. Alleen relevant als er ook daadwerkelijk variatie is (anders
# is "grootst" zinloos).

const EFFECT_KEYS_FOR_EMPHASIS := ["money", "rep", "scandal", "favors", "scout_points", "trust", "all_trust"]


func _collect_branches(ev: Dictionary) -> Array:
	var branches: Array = []
	for opt in ev.options:
		if opt.has("chance"):
			branches.append(Game.scale_money_effects(opt.get("success", {})))
			branches.append(Game.scale_money_effects(opt.get("fail", {})))
		else:
			branches.append(Game.scale_money_effects(opt.get("effects", {})))
	return branches


func _emphasis_for(effects: Dictionary, max_abs: Dictionary, distinct_counts: Dictionary) -> Dictionary:
	var em := {}
	for key in EFFECT_KEYS_FOR_EMPHASIS:
		if not effects.has(key) or int(effects[key]) == 0:
			continue
		var av := absi(int(effects[key]))
		var seen: Dictionary = distinct_counts.get(key, {})
		if av == int(max_abs.get(key, 0)) and seen.size() > 1:
			em[key] = true
	return em


func _event_emphasis_context(ev: Dictionary) -> Dictionary:
	var max_abs: Dictionary = {}
	var distinct_counts: Dictionary = {}
	for eff in _collect_branches(ev):
		for key in EFFECT_KEYS_FOR_EMPHASIS:
			if eff.has(key) and int(eff[key]) != 0:
				var av := absi(int(eff[key]))
				max_abs[key] = maxi(int(max_abs.get(key, 0)), av)
				var seen: Dictionary = distinct_counts.get(key, {})
				seen[av] = true
				distinct_counts[key] = seen
	return {"max_abs": max_abs, "distinct_counts": distinct_counts}


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
		"biedingsoorlog":
			var cid := str(ev.client_id)
			var value := Game.value(Game.state.players[cid])
			var pool: Array = []
			for club_id in Game.state.clubs:
				var c: Dictionary = Game.state.clubs[club_id]
				if club_id != str(Game.state.players[cid].club) and int(c.budget) >= int(float(value) * 0.5):
					pool.append(club_id)
			var picked: Array = []
			while picked.size() < 3 and not pool.is_empty():
				var i := Game.rng.randi_range(0, pool.size() - 1)
				picked.append(pool[i])
				pool.remove_at(i)
			bidding = BiddingWar.new()
			bidding.setup(cid, picked, value, Game.state.clubs, Game.rng)
			show_bidding()
		"persconferentie":
			press = PressConference.new()
			press.setup(Game.rng)
			show_press()
		"sponsorpitch":
			sponsor = SponsorPitch.new()
			show_sponsor()
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


# -- Biedingsoorlog --

func show_bidding() -> void:
	refresh_header()
	clear()
	_dev_test_banner()
	lbl("BIEDINGSOORLOG", 32)
	lbl("Cliënt: %s   |   Rondes over: %d" % [str(Game.state.players[bidding.client_id].name), bidding.rounds_left], 24)
	sep()
	for c in bidding.clubs:
		var status := "actief" if c.active else "afgehaakt"
		lbl("%s — bod %s (%s)" % [str(c.name), eur(int(c.bid)), status], 24)
	if not bidding.log.is_empty():
		sep()
		for line in bidding.log:
			lbl("· " + str(line), 20)
	sep()
	if bidding.finished:
		if bidding.deal:
			lbl("Winnaar: %s met %s." % [str(bidding.find_club(bidding.winner_id).name), eur(bidding.final_bid)], 26)
			var income := int(float(bidding.final_bid) * Game.fee_cut())
			if Meta.perk_level("superprovisie") > 0:
				income *= 2
			_show_effect_lines({"money": income})
		else:
			lbl("Geen deal. De bui trekt over zonder handtekening.", 26)
			_show_effect_lines({"rep": BIDDING_FAIL_REP})
		btn("Verder →", _finish_bidding)
	else:
		for c in bidding.active_clubs():
			btn("Bluffen richting %s" % str(c.name), func(): _play_bidding("bluf", str(c.id)))
		if not bidding.top_club().is_empty():
			btn("Deadline-druk op de leider (%s)" % str(bidding.top_club().name), func(): _play_bidding("druk", ""))
		if bidding.active_clubs().size() >= 2:
			btn("Vergelijken (alle clubs)", func(): _play_bidding("vergelijk", ""))
		if not bidding.top_club().is_empty():
			btn("Bod aannemen nu", func(): _play_bidding("aannemen", ""))


func _play_bidding(action: String, target_id: String) -> void:
	match action:
		"bluf": bidding.play_bluf(target_id, Game.rng)
		"druk": bidding.play_pressure(Game.rng)
		"vergelijk": bidding.play_compare(Game.rng)
		"aannemen": bidding.accept_now()
	show_bidding()


const BIDDING_FAIL_REP := -3

func _finish_bidding() -> void:
	if bidding.deal:
		var income := Game.complete_transfer(bidding.client_id, bidding.winner_id, bidding.final_bid, Game.fee_cut())
		flash = "Transfer uit de biedingsoorlog! Jij incasseert %s." % eur(income)
	else:
		Game.apply_effects({"rep": BIDDING_FAIL_REP}, "")
	bidding = null
	_next_event()


# -- Persconferentie --

func show_press() -> void:
	refresh_header()
	clear()
	_dev_test_banner()
	var cid := str(mg_ev.client_id)
	lbl("PERSCONFERENTIE", 32)
	lbl("%s   |   Spanning: %d/100   |   Vragen over: %d" % [
		str(Game.state.players[cid].name), int(press.tension), press.questions_left,
	], 24)
	if not press.log.is_empty():
		sep()
		for line in press.log:
			lbl("· " + str(line), 20)
	sep()
	if press.finished:
		var o := press.outcome()
		lbl(str(o.txt), 26)
		_show_effect_lines(o.effects, str(Game.state.players[cid].name))
		btn("Verder →", func(): _finish_press(o))
	else:
		var q := lbl(press.current_question(), 26)
		q.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		sep()
		btn("Ontwijken — 'Daar ga ik nu niet op in.'", func(): _play_press("ontwijken"))
		btn("Toegeven — vertel het eerlijke verhaal", func(): _play_press("toegeven"))
		btn("Aanvallen — de vraag zelf onterecht noemen", func(): _play_press("aanvallen"))


func _play_press(action: String) -> void:
	press.play(action, Game.rng)
	show_press()


func _finish_press(o: Dictionary) -> void:
	Game.apply_effects(o.effects, str(mg_ev.client_id))
	press = null
	_next_event()


# -- Sponsorpitch --

func show_sponsor() -> void:
	refresh_header()
	clear()
	_dev_test_banner()
	var cid := str(mg_ev.client_id)
	lbl("SPONSORPITCH", 32)
	lbl("Cliënt: %s" % str(Game.state.players[cid].name), 24)
	lbl("Terughoudendheid merk: %d   |   Rondes over: %d" % [int(sponsor.reluctance), sponsor.rounds_left], 26)
	if not sponsor.log.is_empty():
		sep()
		for line in sponsor.log:
			lbl("· " + str(line), 20)
	sep()
	if sponsor.finished:
		var o := sponsor.outcome(Game.event_money_scale())
		lbl(str(o.txt), 26)
		_show_effect_lines(o.effects, str(Game.state.players[cid].name))
		btn("Verder →", func(): _finish_sponsor(o))
	else:
		btn("Cijfers tonen  [70%%, -15]", func(): _play_sponsor("cijfers"))
		btn("Exclusiviteit beloven  [55%%, -22, kost vertrouwen]", func(): _play_sponsor("exclusiviteit"))
		btn("Prestatiebonus voorstellen  [85%%, -10]", func(): _play_sponsor("prestatiebonus"))


func _play_sponsor(action: String) -> void:
	sponsor.play(action, Game.rng)
	show_sponsor()


func _finish_sponsor(o: Dictionary) -> void:
	Game.apply_effects(o.effects, str(mg_ev.client_id))
	sponsor = null
	_next_event()


# -- Fiscale schikking --

func show_tax() -> void:
	refresh_header()
	clear()
	_dev_test_banner()
	lbl("FISCALE SCHIKKING", 32)
	if not tax.resolved:
		lbl("Kies per post hoe je ermee omgaat. Pas als alle drie gekozen zijn, kun je regelen.", 22)
		for i in range(TaxSettlement.POSTS.size()):
			sep()
			var post: Dictionary = TaxSettlement.POSTS[i]
			var chosen := int(tax.choices[i])
			var labels := ["Open aangeven", "Deels verhullen", "Volledig verhullen"]
			var scaled_amount := int(round(float(post.amount) * Game.event_money_scale()))
			lbl("%s (%s)  —  %s" % [str(post.name), eur(scaled_amount),
				labels[chosen] if chosen >= 0 else "nog niet gekozen"], 24)
			for opt_i in range(3):
				if opt_i != chosen:
					btn(labels[opt_i], func(): _choose_tax(i, opt_i))
		sep()
		btn("Regelen →", _resolve_tax, tax.all_chosen())
	else:
		for r in tax.results:
			lbl("· " + str(r.txt), 22)
		_show_effect_lines({"money": tax.total_money, "scandal": tax.total_scandal})
		sep()
		btn("Verder →", _finish_tax)


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
	lbl("POKER OM EEN TALENT", 32)
	lbl("Straat: %s   |   Pot: %s" % [str(poker.street).capitalize(), eur(poker.pot)], 26)
	lbl("Jouw kaarten: %s   |   Bord: %s" % [
		poker.cards_text(poker.my_hole),
		poker.cards_text(poker.community) if not poker.community.is_empty() else "—",
	], 24)
	lbl("Jouw stack: %s   |   Tegenstander: %s%s" % [
		eur(poker.my_stack), eur(poker.opp_stack),
		"   |   Bij te leggen: %s" % eur(poker.to_call) if poker.to_call > 0 else "",
	], 22)
	if not poker.log.is_empty():
		sep()
		for line in poker.log:
			lbl("· " + str(line), 20)
	sep()
	if poker.finished:
		lbl("Tegenstander had: %s" % poker.cards_text(poker.opp_hole), 22)
		var o := poker.outcome()
		lbl(str(o.txt), 26)
		_show_effect_lines(o.effects)
		for n in poker_notes:
			lbl(">> " + str(n), 24)
		btn("Verder →", _finish_poker)
	else:
		btn("Meegaan" if poker.to_call > 0 else "Checken", func(): _play_poker("meegaan"))
		btn("Verhogen", func(): _play_poker("verhogen"))
		btn("Passen (veilig wegwezen)", func(): _play_poker("passen"))


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
	lbl("DOBBELEN BIJ DE BOOKMAKER", 32)
	lbl("Inzet: %s   |   Herkansingen over: %d" % [eur(dice.stake), dice.rolls_left], 24)
	lbl("Uitbetaling op je inzet: 5 gelijke ogen ×10, 4 gelijk ×4, full house ×3, 3 gelijk ×1,5, twee paar ×0,5. Niets van dit alles? Dan ben je je inzet kwijt.", 19)
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
			lbl("· " + str(line), 20)
	sep()
	if dice.finished:
		var o := dice.outcome()
		lbl(str(o.txt), 26)
		_show_effect_lines(o.effects)
		btn("Verder →", func(): _finish_dice(o))
	else:
		lbl("Tik dobbelstenen aan om ze vast te houden, gooi dan de rest opnieuw.", 20)
		btn("Opnieuw gooien (%d over)" % dice.rolls_left, _reroll_dice, dice.rolls_left > 0)
		btn("Nu stoppen, uitbetalen", _stop_dice)


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
	lbl("DE BOEKHOUDPUZZEL", 32)
	lbl("Vul elke rij en kolom met de cijfers 1-5, elk precies één keer. Pogingen over: %d" % accounting.attempts_left, 22)
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
			lbl("· " + str(line), 20)
	sep()
	if accounting.finished:
		var o := accounting.outcome(Game.event_money_scale())
		lbl(str(o.txt), 26)
		_show_effect_lines(o.effects)
		btn("Verder →", func(): _finish_accounting(o))
	else:
		btn("Controleren", _check_accounting)


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
	lbl("HET GELEKTE DOCUMENT", 32)
	if not anagram.finished:
		var r: Dictionary = anagram.current()
		if anagram_round_started_idx != anagram.round_idx:
			anagram_round_started_idx = anagram.round_idx
			anagram_time_left = AnagramHunt.ROUND_SECONDS
			anagram_active = true
		lbl("Woord %d/3: %s" % [anagram.round_idx + 1, str(r.scrambled)], 28)
		anagram_timer_label = lbl("Tijd: %ds" % int(ceil(anagram_time_left)), 22)
		lbl("Getypt: %s" % (str(anagram.typed) if str(anagram.typed) != "" else "_"), 26)
		sep()
		var kb := GridContainer.new()
		kb.columns = 13
		kb.add_theme_constant_override("h_separation", 4)
		kb.add_theme_constant_override("v_separation", 4)
		content.add_child(kb)
		for code in range(65, 91):
			var ch := char(code)
			var kbtn := Button.new()
			kbtn.text = ch
			kbtn.custom_minimum_size = Vector2(40, 40)
			kbtn.pressed.connect(func(): _type_anagram_letter(ch))
			kb.add_child(kbtn)
		sep()
		btn("⌫ Wis", _backspace_anagram)
		btn("Indienen", _submit_anagram, anagram.can_submit())
	if not anagram.log.is_empty():
		sep()
		for line in anagram.log:
			lbl("· " + str(line), 20)
	if anagram.finished:
		anagram_active = false
		sep()
		var o := anagram.outcome(Game.event_money_scale())
		lbl(str(o.txt), 26)
		_show_effect_lines(o.effects)
		btn("Verder →", func(): _finish_anagram(o))


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
	lbl("SPEED-DATEN OP DE SCOUTINGBEURS", 32)
	lbl("Vastgezet: %d/4   |   Pogingen over: %d" % [scoutdate.locked_count(), scoutdate.attempts_left], 24)
	if not scoutdate.log.is_empty():
		sep()
		for line in scoutdate.log:
			lbl("· " + str(line), 20)
	sep()
	if scoutdate.finished:
		var o := scoutdate.outcome()
		lbl(str(o.txt), 26)
		_show_effect_lines(o.effects)
		btn("Verder →", func(): _finish_scoutdate(o))
	else:
		lbl("Let op: een fout aanbod verbrandt de scout — hij is dan niet meer beschikbaar.", 19)
		for si in range(ScoutSpeedDate.SCOUTS.size()):
			if bool(scoutdate.locked[si]):
				lbl("✔ %s — vastgezet" % str(ScoutSpeedDate.SCOUTS[si]), 22)
				continue
			if bool(scoutdate.burned[si]):
				lbl("✘ %s — afgehaakt" % str(ScoutSpeedDate.SCOUTS[si]), 22)
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
	lbl("MEDIATRAINING: SIMON SAYS", 32)
	lbl("%s   |   Reeks %d/%d" % [str(Game.state.players[cid].name), simon.round_num, SimonMedia.TARGET_ROUNDS], 24)
	sep()
	if simon.finished:
		var o := simon.outcome()
		lbl(str(o.txt), 26)
		_show_effect_lines(o.effects, str(Game.state.players[cid].name))
		btn("Verder →", func(): _finish_simon(o))
	elif simon.phase == "show":
		lbl("Onthoud deze reeks:", 22)
		lbl(simon.sequence_text(), 28)
		btn("Ik heb het onthouden →", _start_simon_input)
	else:
		lbl("Herhaal de reeks (stap %d/%d):" % [simon.player_progress + 1, simon.sequence.size()], 22)
		for i in range(simon.moves.size()):
			var mv := i
			btn(str(simon.moves[i]), func(): _play_simon(mv))


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
	lbl("TRANSFERWINDOW" + ("  — DEADLINE DAY!" if deadline_day else ""), 34)
	if deadline_day:
		lbl("TD's zijn nerveus vandaag: onderhandelen is makkelijker.", 22)
	show_flash()
	if Game.state.clients.is_empty():
		lbl("Je hebt geen cliënten om deals voor te sluiten...", 26)
	for cid in Game.state.clients:
		sep()
		var p: Dictionary = Game.state.players[cid]
		var contract_txt := "contract loopt af" if int(p.contract) <= 1 else "contract nog %d jaar" % int(p.contract)
		lbl("%s — rating %d, %s, waarde %s, %s" % [
			p.name, int(p.rating), Game.club_name(str(p.club)), eur(Game.value(p)), contract_txt,
		], 26)
		var ints: Array = interest.get(cid, [])
		if ints.is_empty():
			lbl("Geen interesse van clubs dit seizoen.", 22)

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
			lbl("Geen acties meer over voor %s dit transferwindow." % p.name, 20)
		elif extended.has(cid):
			# Verlengen sluit clubonderhandelingen voor dit window uit — hij
			# heeft net getekend, dus een nieuwe club is niet meer aan de orde.
			lbl("Contract dit window al verlengd. Geen nieuwe clubonderhandeling meer mogelijk.", 20)
		else:
			for club_id in ints:
				var c: Dictionary = Game.state.clubs[club_id]
				var td_txt := str(c.td)
				if Game.td_known(club_id):
					td_txt += " — " + str(Negotiation.PERS_INFO[Game.td_personality(club_id)]).split(" — ")[0]
				btn("Onderhandel met %s (TD: %s)" % [c.name, td_txt], func(): _start_nego(cid, club_id))
			if can_extend:
				if high and not ints.is_empty():
					lbl("Hoge rating: verlengen blijft een optie náást beide clubgesprekken, maar het tekengeld is lager — met clubs in de rij bindt hij zich niet goedkoop.", 19)
				var tg_preview := int(Game.value(p) * 0.02 * Game.tekengeld_mult() * Game.extend_mult(p))
				btn("Contract verlengen (tekengeld ~%s)" % eur(tg_preview), func(): _extend(cid))
			elif str(p.club) != "":
				lbl("Verlengen kan pas in het laatste contractjaar.", 19)
	sep()
	btn("Seizoen afronden →", _goto_wrapup)


func _extend(cid: String) -> void:
	var tg := Game.extend_contract(cid)
	extended.append(cid)
	flash = "Contract verlengd. Tekengeld: %s." % eur(tg)
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
	lbl("ONDERHANDELING", 32)
	lbl("%s → %s" % [p.name, c.name], 26)
	lbl("Transfersom: %s   |   Jouw fee: %d%%" % [eur(nego.deal_value), int(round(nego.cut * 100))], 24)
	lbl("Weerstand van TD %s: %d   |   Rondes over: %d" % [c.td, int(maxf(nego.resistance, 0)), nego.rounds_left], 26)
	lbl("Stemming: %s" % nego.mood_name(), 24)
	if nego.pers_known:
		lbl("Type: %s" % str(Negotiation.PERS_INFO[nego.pers]), 22)
	else:
		lbl("Type: onbekend — 'Aftasten' onthult het (blijft deze run bekend).", 20)
	if nego.has_flow():
		lbl("FLOW (%d op rij): je volgende zet krijgt +50%% effect!" % nego.streak, 23)
	elif nego.streak == 1:
		lbl("Reeks: 1 succes — nog één voor flow.", 20)
	if not nego.log.is_empty():
		sep()
		for line in nego.log:
			lbl("· " + str(line), 22)
	sep()
	if nego.finished:
		if nego.success:
			lbl("DEAL! Jouw fee: %s" % eur(int(nego.deal_value * nego.cut)), 30)
			btn("Incasseren →", func(): _close_nego(true))
		else:
			lbl("Geen deal." + ("  De relatie heeft een deuk." if nego.walked else ""), 28)
			btn("Terug naar het window →", func(): _close_nego(false))
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
		for t in nego.tactics(int(Game.state.rep) + Meta.perk_bonus("onderhandelen") * 5):
			if str(t.id) == "aftasten":
				btn("%s  [kost %d ronde%s]" % [str(t.label), nego.aftast_cost, "" if nego.aftast_cost == 1 else "s"], func(): _play_tactic(t))
			else:
				btn("%s  [%d%%, weerstand -%d]" % [str(t.label), int(round(float(t.chance) * 100)), int(t.drop)], func(): _play_tactic(t))
		btn("Percentage verhogen (+%d%%, raakt weerstand/flow niet)" % int(round(Negotiation.RAISE_FEE_STEP * 100)), _raise_fee, nego.cut < Negotiation.MAX_CUT)

		var favor_btn := Button.new()
		favor_btn.text = "🪙 Gunst inzetten: weerstand halveren"
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
		lbl("COMBO'S (opeenvolgende successen; ×1 per gesprek):", 20)
		# Combo's waar je verder in zit (meer stappen op koers, of al
		# voltooid) staan bovenaan — hoe hoger je zit, hoe relevanter nu.
		var combo_list: Array = Negotiation.COMBOS.duplicate()
		combo_list.sort_custom(func(a, b): return nego.combo_progress(a) > nego.combo_progress(b))
		for combo in combo_list:
			var done: bool = str(combo.id) in nego.combos_done
			var progress := nego.combo_progress(combo)
			var req := ""
			if combo.has("req_pers"):
				req = "  [vereist bekende %s]" % str(combo.req_pers)
			var mark := "·"
			var suffix := ""
			var color := Color(0.75, 0.75, 0.75)  # neutraal grijs
			if done:
				mark = "✔"
				color = Color(0.35, 0.9, 0.4)       # groen: voltooid
			elif progress > 0:
				mark = "▸"
				suffix = "  — OP KOERS (%d/%d)!" % [progress, combo.pattern.size()]
				color = Color(1.0, 0.78, 0.15)      # goud: op koers
			var l := lbl("%s %s: %s  (+%d)%s%s" % [
				mark, str(combo.name), nego.combo_pattern_text(combo),
				int(combo.bonus), req, suffix,
			], 19)
			l.add_theme_color_override("font_color", color)
			if progress > 0 and not done:
				l.add_theme_font_size_override("font_size", 21)

		content = real_content


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
	nego.halve_resistance()
	show_nego()


# ---------------------------------------------------------------- confetti

const CONFETTI_EMOJI := ["🎉", "✨", "🎊", "⭐", "💰"]

func _confetti_burst(combo_name: String) -> void:
	var vp := get_viewport_rect().size
	var center := vp / 2.0

	var banner := Label.new()
	banner.text = "★ COMBO — %s! ★" % combo_name
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 36)
	banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
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


func _close_nego(deal: bool) -> void:
	if deal and nego != null:
		var income := Game.complete_transfer(nego_client, nego_club, nego.deal_value, nego.cut)
		interest[nego_client] = []
		flash = "Transfer rond! Jij incasseert %s." % eur(income)
	else:
		# Eén kans per club per window: afketsen of weglopen verbruikt
		# de interesse, anders kun je eindeloos opnieuw onderhandelen.
		var ints: Array = interest.get(nego_client, [])
		ints.erase(nego_club)
		interest[nego_client] = ints
	nego = null
	show_window()


# ---------------------------------------------------------------- fase 5: afsluiting

func _goto_wrapup() -> void:
	var report: Array = Game.end_of_season()
	Game.save_game()
	refresh_header()
	clear()
	lbl("SEIZOENSAFSLUITING", 34)
	for line in report:
		lbl("· " + str(line), 23)
	sep()
	if str(Game.state.game_over) != "":
		btn("Bekijk het einde →", show_gameover)
	elif int(Game.state.season) > Game.MAX_SEASONS:
		btn("Bekijk het einde →", show_win)
	else:
		btn("Volgende seizoen →", show_prep)


# ---------------------------------------------------------------- einde

func show_gameover() -> void:
	refresh_header()
	var earned := _finish_run_meta(false)
	clear()
	var reason := str(Game.state.game_over)
	lbl("GAME OVER", 40)
	match reason:
		"failliet":
			lbl("Failliet. De deurwaarder neemt zelfs je gesigneerde shirtjes mee.", 26)
		"licentie":
			lbl("Je licentie is ingetrokken. De bond stuurt een koele brief; de pers een fotograaf.", 26)
		"leeg":
			lbl("Je laatste cliënt is vertrokken. Een makelaar zonder spelers is gewoon een man met een telefoon.", 26)
		_:
			lbl("De run is voorbij.", 26)
	sep()
	lbl("Seizoenen overleefd: %d" % (int(Game.state.season)), 24)
	lbl("Totaal aan fees verdiend: %s" % eur(Game.state.total_fees), 24)
	sep()
	if earned > 0:
		lbl("+%s legacy points verdiend  →  totaal %s" % [_pts(earned), _pts(Meta.state.legacy_points)], 24)
	else:
		lbl("Legacy points: %s" % _pts(Meta.state.legacy_points), 24)
	btn("Perks bekijken →", show_perks)
	btn("Nieuwe run", _on_restart)


func show_win() -> void:
	refresh_header()
	var earned := _finish_run_meta(true)
	clear()
	lbl("JE HEBT HET GEHAALD", 38)
	lbl("Je overleefde alle %d seizoenen. Van snackbar-kantoor naar gevestigde naam." % Game.MAX_SEASONS, 26)
	sep()
	lbl("EINDSCORE (totaal aan fees): %s" % eur(Game.state.total_fees), 30)
	var fees := int(Game.state.total_fees)
	if fees >= 750000:
		lbl("Rang: SUPERAGENT. Jouw naam gonst door elke bestuurskamer.", 24)
	elif fees >= 400000:
		lbl("Rang: Gevestigde makelaar. Netjes — maar de top lonkt.", 24)
	else:
		lbl("Rang: Overlever. Je bestaat nog. Dat is niet hetzelfde als winnen.", 24)
	sep()
	if earned > 0:
		lbl("+%s legacy points verdiend  →  totaal %s" % [_pts(earned), _pts(Meta.state.legacy_points)], 24)
	else:
		lbl("Legacy points: %s" % _pts(Meta.state.legacy_points), 24)
	btn("Perks bekijken →", show_perks)
	btn("Nieuwe run", _on_restart)


func _on_restart() -> void:
	Game.delete_save()
	Game.new_run()
	show_prep()
