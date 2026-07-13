# main.gd — de volledige UI, programmatisch opgebouwd.
# Elke fase van een seizoen is een "scherm": prep → scouting → events →
# transferwindow → afsluiting. Game (autoload) bevat alle logica en staat.
extends Control

var header: Label
var content: VBoxContainer

var event_queue: Array = []
var interest: Dictionary = {}      # client_id -> Array van club_ids
var candidates: Array = []         # scouting/tekendoelen dit seizoen
var approached: Array = []         # al benaderd dit seizoen (één poging p.p.)
var extended: Array = []           # contract al verlengd dit window
var flash := ""                    # korte statusmelding bovenin een scherm

var nego: Negotiation = null
var nego_client := ""
var nego_club := ""

var home_btn: Button
var confirm_reset := false         # tweestaps-bevestiging voor de perk-reset


# ---------------------------------------------------------------- opbouw

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


# ---------------------------------------------------------------- meta: perks

func show_perks() -> void:
	clear()
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
	sep()
	lbl("Jouw stal (%d/%d):" % [Game.state.clients.size(), Game.client_cap()], 28)
	for cid in Game.state.clients:
		var p: Dictionary = Game.state.players[cid]
		lbl("• %s (%s, %d jr) — rating %d, vertrouwen %d, %s, contract %d jr, waarde %s" % [
			p.name, p.pos, int(p.age), int(p.rating), int(p.trust),
			Game.club_name(str(p.club)), int(p.contract), eur(Game.value(p)),
		], 23)
	sep()
	btn("Naar stalbeheer →", _goto_release)


# ---------------------------------------------------------------- fase 1b: stalbeheer

func _goto_release() -> void:
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
		_goto_window()
		return
	var ev: Dictionary = event_queue.pop_front()
	show_event(ev)


func show_event(ev: Dictionary) -> void:
	refresh_header()
	clear()
	var cname := ""
	if str(ev.client_id) != "":
		cname = str(Game.state.players[ev.client_id].name)
	lbl("EVENT: %s" % str(ev.title), 32)
	lbl(str(ev.text).replace("{client}", cname), 26)
	sep()
	for opt in ev.options:
		var enabled := true
		var suffix := ""
		if opt.has("req_money") and int(Game.state.money) < int(opt.req_money):
			enabled = false
			suffix = "  (te weinig geld)"
		if opt.has("req_favors") and int(Game.state.favors) < int(opt.req_favors):
			enabled = false
			suffix = "  (geen gunst beschikbaar)"
		var label := str(opt.label)
		if opt.has("chance"):
			label += "  [%d%% kans]" % int(round(float(opt.chance) * 100))
		btn(label + suffix, func(): _resolve(ev, opt), enabled)


func _resolve(ev: Dictionary, opt: Dictionary) -> void:
	var txt := ""
	var notes: Array = []
	if opt.has("chance"):
		if Game.rng.randf() < float(opt.chance):
			notes = Game.apply_effects(opt.get("success", {}), str(ev.client_id))
			txt = str(opt.get("success_txt", "Het pakt goed uit."))
		else:
			notes = Game.apply_effects(opt.get("fail", {}), str(ev.client_id))
			txt = str(opt.get("fail_txt", "Het mislukt."))
	else:
		notes = Game.apply_effects(opt.get("effects", {}), str(ev.client_id))
		txt = str(opt.get("txt", "Gedaan."))
	refresh_header()
	clear()
	lbl("UITKOMST", 32)
	lbl(txt, 26)
	for n in notes:
		lbl(">> " + str(n), 24)
	sep()
	btn("Verder →", _next_event)


# ---------------------------------------------------------------- fase 4: window

func _goto_window() -> void:
	interest = {}
	extended = []
	for cid in Game.state.clients:
		interest[cid] = Game.gen_interest(cid)
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
		lbl("%s — rating %d, %s, waarde %s" % [
			p.name, int(p.rating), Game.club_name(str(p.club)), eur(Game.value(p)),
		], 26)
		var ints: Array = interest.get(cid, [])
		if ints.is_empty():
			lbl("Geen interesse van clubs dit seizoen.", 22)
			if extended.has(cid):
				lbl("Contract dit window al verlengd.", 20)
			elif str(p.club) != "" and int(p.contract) <= 1:
				btn("Contract verlengen (tekengeld ~%s)" % eur(int(Game.value(p) * 0.02)), func(): _extend(cid))
			elif str(p.club) != "":
				lbl("Contract loopt nog %d jaar — verlengen is pas in het laatste jaar aan de orde." % int(p.contract), 20)
		else:
			for club_id in ints:
				var c: Dictionary = Game.state.clubs[club_id]
				var td_txt := str(c.td)
				if Game.td_known(club_id):
					td_txt += " — " + str(Negotiation.PERS_INFO[Game.td_personality(club_id)]).split(" — ")[0]
				btn("Onderhandel met %s (TD: %s)" % [c.name, td_txt], func(): _start_nego(cid, club_id))
	sep()
	btn("Seizoen afronden →", _goto_wrapup)


func _extend(cid: String) -> void:
	var tg := Game.extend_contract(cid)
	interest[cid] = []
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
		# Onderhandelaar-perk: elke +5 effectieve rep = +1% tactiekkans.
		for t in nego.tactics(int(Game.state.rep) + Meta.perk_bonus("onderhandelen") * 5):
			if str(t.id) == "aftasten":
				btn("%s  [kost %d ronde%s]" % [str(t.label), nego.aftast_cost, "" if nego.aftast_cost == 1 else "s"], func(): _play_tactic(t))
			else:
				btn("%s  [%d%%, weerstand -%d]" % [str(t.label), int(round(float(t.chance) * 100)), int(t.drop)], func(): _play_tactic(t))
		btn("Weglopen (geen schade, maar de kans vervalt)", func(): _close_nego(false))
		sep()
		lbl("COMBO'S (opeenvolgende successen; ×1 per gesprek):", 20)
		for combo in Negotiation.COMBOS:
			var done: bool = str(combo.id) in nego.combos_done
			var req := ""
			if combo.has("req_pers"):
				req = "  [vereist bekende %s]" % str(combo.req_pers)
			lbl("%s %s: %s  (+%d)%s" % [
				"✔" if done else "·", str(combo.name),
				" → ".join(combo.pattern), int(combo.bonus), req,
			], 19)


func _play_tactic(t: Dictionary) -> void:
	nego.play(t, Game.rng)
	if nego.pers_known:
		Game.reveal_td(nego_club)
	show_nego()


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
