# Handleiding — Voetbalmakelaar Roguelike (Godot MVP)

Dit is de speelbare MVP van het game design document: één archetype, 15 seizoenen per run, 70 events (waarvan 10 een eigen minigame starten), 10 clubs, 80 procedureel gegenereerde spelers, een onderhandelings-minigame met stemming, verborgen TD-persoonlijkheden en flow, drie fail states, autosave én meta-progressie (legacy points en permanente perks die runs overleven). Alles is opgezet volgens het GDD-principe: **staat en logica strikt gescheiden van presentatie**, zodat je later moeiteloos archetypes en daily seeds kunt toevoegen.

---

## 1. Installatie en starten

1. Download **Godot 4.4 (of nieuwer), Standard versie** van https://godotengine.org/download — géén .NET-versie nodig, alles is GDScript. Godot is één uitvoerbaar bestand van ~50MB, geen installer.
2. Pak de projectmap `voetbalmakelaar/` ergens uit.
3. Start Godot → **Import** → navigeer naar de map → selecteer `project.godot` → **Import & Edit**.
4. Druk op **F5** (of de play-knop rechtsboven). Het spel start in een portrait-venster van 720×1280.

Dat is alles. Geen dependencies, geen assets, geen plugins.

> **Eerste keer openen:** Godot herbouwt de projectcache en genereert UID's voor de bestanden; dat is normaal. Krijg je een melding over een ontbrekend hoofdscherm, controleer dan in Project → Project Settings → Application → Run of `res://scenes/Main.tscn` als main scene staat ingesteld.

---

## 2. Zo speel je (de loop)

Elke run bestaat uit 15 seizoenen. De balans is bewust hard: zonder perks is een run uitspelen bijna onmogelijk — de bedoeling is dat je de eerste ~20 runs vooral legacy points verzamelt en langzaam sterker wordt (zie §4.3). **Je begint met een lege stal** (`new_run()` in `game.gd` wijst géén startcliënt meer toe) — een bewust moeilijker begin: je moet je eerste cliënt zelf werven in de eerste scoutingronde van seizoen 1. Dat kan geen onmiddellijke game over veroorzaken, want de "lege stal"-fail-check (§2, Fail states) loopt pas aan het EINDE van seizoen 1, dus je hebt de hele eerste ronde de tijd. De Erfenis-perk Kroonjuweel-netwerk (§4.4) is de uitzondering: die laat je wél met één cliënt starten. Elk seizoen doorloopt zes fasen:

1. **Voorbereiding** — overzicht van je stal, geld, reputatie en het nieuws (nieuws heeft echte effecten: clubbudgetten veranderen). Je stal staat hier als dezelfde kaartjes met **rating/potentieel-badges** die ook in scouting en stalbeheer verschijnen (`_stat_card()`, hergebruikt in `show_prep()`), i.p.v. platte tekstregels.

**Clubs staan voorlopig cosmetisch buiten beeld** ("geen waarde momenteel"): de clubnaam/"clubloos"-vermelding is weggehaald uit de stal (voorbereiding, stalbeheer), scoutingkaartjes en de permanente speler-tooltip (`_player_tooltip()`). Contractstatus ("contract nog X jr") blijft wél zichtbaar in de stal, want dat blijft relevant voor de tekengeld-timing bij verlenging. Dit raakt alleen de UI — het onderliggende transfersysteem (transferwindow, clubbudgetten, contractverlenging) is ongewijzigd en blijft volledig functioneren; `show_window()` (het transferwindow zelf) toont de clubnaam dus nog gewoon, want daar is die functioneel nodig voor de onderhandel-knoppen.
2. **Stalbeheer** — heb je 2 of meer cliënten, dan móét je er minstens één wegsturen. **Seizoen 1 slaat dit altijd over** (`_goto_release()` in `main.gd`, ongeacht cliëntenaantal) — sowieso al irrelevant met een lege start-stal, maar ook nodig voor de Erfenis-perk Kroonjuweel-netwerk (§4.4), die je wél met een cliënt laat starten. Dit is een **multi-select**: je tikt op zoveel cliënten als je wilt om ze te markeren (kaartje kleurt rood, knop wisselt naar "✔ Blijft toch"), zolang er minstens 1 overblijft — de "Bevestig"-knop onderaan toont hoeveel je wegstuurt en hoeveel er overblijven, en is uitgeschakeld zolang niemand is geselecteerd (`show_release()`/`_toggle_release()`/`_confirm_release()` in `main.gd`). Handig om in één keer ruimte te maken voor bijvoorbeeld een kantoorupgrade. De rest van je stal verliest 2 vertrouwen per weggestuurde cliënt (stapelt dus bij meerdere ontslagen). Elke cliënt is hier een spelerkaart (`_stat_card()` → `_player_card()`).

**De spelerkaart is één centraal component** (`_player_card()` in `main.gd`) dat overal wordt hergebruikt waar een speler genoemd wordt: de scoutinglijst, je stal op het voorbereidingsscherm, stalbeheer, het permanente infopaneel onderaan bij **events en minigames** (`_show_player_info()`), en het weggekaapt-nieuwsscherm. Opmaak: naam (+ `[CLIËNT]`-tag waar dat informatie toevoegt) en een subregel links, **POT-badge rechtsboven** (groen) en **RAT-badge rechtsonder** (blauw). De info-kolom hangt als meta `"info_col"` aan de kaart, zodat een aanroeper er nog eigen regels of knoppen aan kan hangen (`_candidate_card()` voegt zo de tekenkans en de Scout/Benader-knoppen toe) zonder dat `_player_card()` elke variant hoeft te kennen. Omdat er nu een volledige kaart in het onderste infopaneel staat i.p.v. één regel tekst, is dat paneel hoger (156px, was 88px).

Dat paneel **zweeft** onderaan over de content heen (het hangt aan de root, niet in de scroll-layout), waardoor de onderste knop van een lang event erachter verdween en onbereikbaar werd. `_reserve_panel_space()` lost dat op door de ondermarge van de root-`MarginContainer` te vergroten (`MARGIN_BOTTOM_BASE` 28 → `MARGIN_BOTTOM_WITH_PANEL` 164) zolang het paneel zichtbaar is, zodat de scrollbare content bóven het paneel eindigt. `clear()` roept `_show_player_info("")` aan bij elke schermwissel, dus de marge valt automatisch terug naar 28 op schermen zonder speler — de ruimte wordt alleen gereserveerd wanneer die daadwerkelijk nodig is.

**Twee kolommen.** In scouting, je stal (voorbereiding) en stalbeheer staan de kaarten in een **2-kolomsraster** (`_card_grid()`: `GridContainer` met `columns = 2`), dus elke kaart is een halve schermbreedte. Dat vroeg drie aanpassingen aan de kaart zelf: de naam- en subregel **wrappen** nu (`AUTOWRAP_WORD_SMART`) omdat ze niet meer op één regel passen, de **badges zijn compacter** (POT 74×46 en RAT 54×54, was 96×52/64×64) zodat er naast de badges genoeg breedte overblijft voor de tekst, en `_mini_btn()` heeft **geen vaste breedte meer** (was 130px) maar `SIZE_EXPAND_FILL` — anders zouden Scout + Benader samen (260px) buiten een kaart van ~200px tekstbreedte lopen. De subregels in de stal zijn ook ingekort (`vert.` i.p.v. `vertrouwen`, waarde op een eigen regel). Het onderste infopaneel gebruikt dezelfde kaart maar staat NIET in een raster, dus daar krijgt hij de volle breedte.

**Tags (★ favoriet / 🔒 slot).** Elke spelerkaart heeft twee aan/uit-tags (`_tag_btn()`), overal waar de kaart verschijnt. Ze zijn **puur visueel** — geen enkel mechanisch effect, alleen om je eigen plannen te onthouden ("deze wil ik houden", "deze niet verkopen"). Aan = goudkleurig, uit = sterk doorzichtig. De staat leeft als `fav`/`lock` op de speler-dictionary, dus hij gaat mee in de save. De knop werkt zichzelf bij (`_toggle_player_tag()` past alleen zijn eigen `modulate` aan) i.p.v. het scherm te hertekenen — daardoor hoeft de knop niet te weten op welk scherm hij staat en blijft je scrollpositie staan. De tags staan op een eigen compacte rij onder de subregel, niet naast de naam, zodat de naam in een halve kolom zijn volle breedte houdt.
3. **Scouting** — 3 scoutingpunten per seizoen. Elk seizoen krijg je een **verse trekking van 8 spelers** (`gen_candidates()` in `game.gd`, aantal via `candidate_count()` = `CANDIDATES_PER_SEASON` 8 + Extra kandidaat-perk) — van amateur tot het beste dat je kantoor kan aantrekken. Een korte, overzichtelijke lijst i.p.v. eindeloos scrollen. **Je kantoorniveau (§2b) bepaalt de rating-band** waaruit ze getrokken worden; **reputatie bepaalt niet meer wíe je ziet, maar alléén nog of ze bij je tekenen** (`sign_chance()`, als tekenkans-% op elke regel). Zo kun je op niveau 5 een rating-90 fenomeen zien staan, maar hem zonder naam alsnog niet strikken. Je kunt de lijst sorteren op **rating** of **leeftijd** (tik nogmaals voor omgekeerde richting; `_sorted_candidates()`). Elke speler is een kaartje (`_candidate_card()`) met twee gekleurde badges rechts: **potentieel** in een groene rechthoek rechtsboven, **rating** in een blauw vierkant rechtsonder (`_stat_badge()`). Onder de info zitten compacte knopjes **Scout** / **Benader** — heb je iemand dit seizoen al benaderd (en afgewezen gekregen), dan verdwijnen béíde knoppen (er valt niets meer te doen tot volgend seizoen), en zie je "al benaderd dit seizoen". Potentieel is voor scoutingdoelen een geschatte band (bijv. 68–82); zit iemand eenmaal in je stal, dan ken je zijn **exacte** potentieel (één getal, ook in de speler-tooltip/`_player_tooltip()`). Kaarten over spelers die dit seizoen nog van jou wáren maar inmiddels uit `state.clients` zijn gehaald — ontwikkeling van iemand die ná zijn groei vertrok of werd weggekaapt, en het wegkaap-nieuwsscherm — geven `force_known` mee aan `_pot_badge_text()`, zodat daar het exacte getal blijft staan in plaats van terug te vallen op een vage band. **Potentieel is OMGEKEERD gekoppeld aan de rating** (`WorldGen._potential_for()`), zodat de hoogste rating niet automatisch de beste keuze is — je kiest tussen "nu al bruikbaar" en "kan veel verder komen". Een kandidaat krijgt een fractie van de resterende rek tot het plafond (94): onderaan de band **0,85** van die rek (`POT_FRAC_AT_BAND_LOW`, ruwe diamant), bovenaan **0,25** (`POT_FRAC_AT_BAND_HIGH`, al grotendeels "af"), plus een kleine leeftijdsbonus en ±0,12 ruis zodat de regel niet exact af te lezen is. Er wordt met de RESTERENDE ruimte gerekend (niet met een vast aantal punten), zodat potentieel nooit absurd door het plafond schiet bij een al hoge rating. Gesimuleerd per kantoorniveau:

| Niveau | Band | Zwakste kandidaat | Sterkste kandidaat | Bandgemiddelde |
|---|---|---|---|---|
| 1 | 18–40 | rating 18 → pot ~85 | rating 40 → pot ~55 | ~68 |
| 2 | 28–54 | rating 28 → pot ~86 | rating 54 → pot ~66 | ~74 |
| 3 | 43–68 | rating 43 → pot ~88 | rating 68 → pot ~76 | ~79 |
| 4 | 58–82 | rating 58 → pot ~90 | rating 82 → pot ~85 | ~85 |
| 5 | 74–93 | rating 74 → pot ~92 | rating 93 → pot ~93 | ~91 |

Het bandgemiddelde op niveau 1 blijft ~68, dus de eerdere kalibratie is bewaard. **Let op de degradatie op niveau 5:** daar bindt het 94-plafond zo hard dat de omkering verdwijnt (92 vs 93) — met nog maar 1–20 punten rek over is er simpelweg geen ruimte om een zwakkere speler méér potentieel te geven. De afweging werkt dus vooral op niveau 1–4, waar je nog aan het bouwen bent; op het topniveau is een hoge rating gewoon beter, wat ook logisch is. De 8 zijn geen persistente wereld: ongetekende kandidaten verdwijnen aan het einde van het seizoen (`_clear_old_candidates()` ruimt ze op), een getekende wordt cliënt en blijft. De getoonde potentieel-band is gecentreerd op een publieke schátting die er zelf flink naast kan zitten — een "70–90"-belofte kan na scouten een 72-dud blijken. Scouten versmalt de band én trekt de schatting richting de waarheid, en een gescoute speler tekent bovendien makkelijker bij je (+5% tekenkans per scout, max +10% — hij voelt zich serieus genomen). Een geslaagde tekening geeft een confetti-uitbarsting (`_confetti()`); een afwijzing geeft een klein rood puffje (`_small_negative_puff()`) — de losse `>> `-meldingsregel (`show_flash()`) wordt op dit scherm bewust NIET getoond, want die visuele feedback (plus de bijgewerkte kaart/tekenkans zelf) communiceert het resultaat al; `_discard_flash()` leegt de melding stil op de achtergrond zodat hij niet later op een ander scherm alsnog opduikt. Eén benaderpoging per speler per seizoen: wijst hij je af, dan is die kandidaat weg (verse trekking volgend seizoen).
4. **Events** — 4 à 6 encounters met keuzes (`gen_events()` in `game.gd`). Kansen staan op de knoppen; risicovolle opties hebben grotere uitkomsten. Sommige opties vereisen geld of een gunst. Tien events starten in plaats daarvan een eigen minigame (zie 4.2). Met 70 events in de pool en gemiddeld 5 per seizoen kan de pool tegen het einde van een lange run uitgeput raken (`used_events`) — vandaar dat meer events de belangrijkste groeirichting blijft (zie 4.1).
5. **Transferwindow** — per cliënt melden zich 0–2 geïnteresseerde clubs. Onderhandelen = de weerstand van de TD naar 0 spelen binnen 5 rondes, en de vólgorde van je zetten is de kern:
   - **Stemming** (Geïrriteerd → Zakelijk → Ontvankelijk): charmeren en clausules bouwen de stemming op; bluffen heeft haar nodig (25/50/75% kans per stemming) en "Feiten & cijfers" is juist het sterkst bij Zakelijk. Deadline-druk verslechtert de stemming áltijd — en bij een geïrriteerde TD riskeer je dat hij wegloopt. Druk is dus een finisher, geen opener.
   - **Een mislukte tactiek mag je niet direct herhalen** (`last_failed_id`/`is_blocked()` in `negotiation.gd`) — zo kun je niet gewoon op dezelfde knop blijven klikken tot hij toevallig lukt. De geblokkeerde knop blijft zichtbaar maar uitgeschakeld, met "(net mislukt — probeer iets anders)". De blokkade geldt voor precies de eerstvolgende beurt: een succesvolle actie, een andere mislukking, óf aftasten heft 'm weer op (aftasten telt als een aparte beurt). Clausule (altijd 100% kans) kan nooit geblokkeerd worden, dus je hebt altijd een uitweg.
   - **Persoonlijkheid** (verborgen; werkt vooral op kansen, mild op weerstand): IJdel (charme slaagt altijd en iets sterker), Koppig (+5 weerstand, stemming zakt nooit onder Zakelijk), Nerveus (druk +20% slaagkans, maar hij loopt sneller weg), Rekenmeester (+8 weerstand, feiten +8% kans en 1,15× effect, charme doet niets, ongevoelig voor bluf en druk (-15%/-10% kans) — alleen cijfers overtuigen hem). **Zolang je het type niet kent, blijven zowel de slaagkans ALS het weerstandseffect op de knoppen verborgen** ("kans ?" / "weerstand ?") — anders zou je uit het effect alsnog kunnen afleiden welk type hij is. Om diezelfde reden verdwijnt ook het zichtbare weerstandsgetal van de TD zelf zodra je één actie hebt gespeeld (naar een "?"), én worden de weerstandscijfers in de LOG-regels (bij een geslaagde actie, een combo-bonus, en de gunst-halvering) vervangen door "?" — anders zou je alsnog uit het loggetal, of uit het verschil vóór/na, terug kunnen rekenen wat een actie deed. Je leert het type op twee manieren: via **"Aftasten"** (kost twee rondes) óf door een **type-combo** af te ronden — een geslaagde druk→druk tegen een (nog onbekende) nerveuze TD onthult hem meteen, net als aftasten; zodra het type bekend is, verschijnen kans, weerstandseffect én het weerstandsgetal weer gewoon. Die kennis blijft de hele run per club bewaard.
   - **Flow**: twee successen op rij geven +50% effect op je volgende zet; een mislukking reset de reeks.
   - **Gunst inzetten = instant win** (`use_favor_deal()` in `negotiation.gd`, was "weerstand halveren"): een contact belt de TD persoonlijk en die zwicht meteen — de weerstand valt naar 0, dus het gesprek sluit direct af als geslaagd. Kost 1 gunst. De deal gaat rond op de **huidige** voorwaarden (`deal_value` en `cut`), dus vroeg inzetten betekent dat je geen fee-opbouw (Percentage verhogen) of clausulewinst meer pakt — de gunst is de premium-uitweg uit een gesprek dat je dreigt te verliezen, niet automatisch de beste opening.
   - **Combo's** (opeenvolgende successen; elk maximaal één keer per gesprek): De Goede Cop (charme → charme → feiten, +6), De Slotklap (charme → feiten → charme → druk, +14), De Boekhouder (feiten → feiten tegen een Rekenmeester, +8), Het Ultimatum (clausule → clausule → druk, +10 — maar je fee is dan al 4% gezakt), De Nerveuze Val (druk → druk tegen een Nerveus, +16 — het hoogste, maar risico-op-risico), Slow Play (clausule → charme → feiten → bluf, +12 — de veilige lange route). **Type-gebonden combo's (Boekhouder, Nerveuze Val) werken en lichten op zodra de TD daadwerkelijk dat type ís — je hoeft het niet vooraf te weten, en ze afronden ONthult het type** (`_check_combos()`/`combo_progress()` gaten nu op `pers`, niet op `pers_known`). Een zet die door de persoonlijkheid volledig wordt geneutraliseerd — **charme tegen een Rekenmeester** — telt níét mee voor een combo (hij doet immers niets), via de `no_combo`-vlag in `tactics()`. Elke combo toont zijn patroon als losse, individueel gekleurde stappen (`_show_combo_pattern_row()` in `main.gd`) i.p.v. één vlakke statuskleur: stap 1 is altijd **geel**, de laatste stap altijd **groen**, en de stappen ertussen worden van achteren naar voren ingevuld met een vast palet (`COMBO_STEP_FROM_END`) — bij lengte 3 dus geel→rood→groen, bij lengte 4 geel→blauw→rood→groen. Stappen die je nog niet hebt bereikt blijven grijs; het algoritme (`_combo_step_color()`) is lengte-onafhankelijk en werkt dus automatisch ook voor eventuele toekomstige, langere combo's. Bij het voltooien van een combo verschijnt een korte confetti-uitbarsting met de combonaam. Onder de stemming/streak toont het scherm alleen de ALLERLAATSTE logregel (`nego.log[nego.log.size()-1]`, niet de hele geschiedenis) — bij een combo-afronding met type-onthulling voegt één zet soms 2-3 regels toe (het effect, "COMBO — …", eventueel de onthulling); alleen de laatste daarvan blijft zichtbaar, de combo zelf wordt sowieso al apart gevierd via de confetti-banner.

   Weglopen kan zonder schade, maar elke club biedt maar één kans per window: ketst het af, dan is die deal dit seizoen weg. Contract verlengen kan alleen als een cliënt in zijn laatste contractjaar zit (en maximaal één keer per window). Elk 5e seizoen is het Deadline Day: TD's beginnen met lagere weerstand.
6. **Afsluiting** — kantoorkosten (×1,95 per seizoen, `COSTS_MULT` in `game.gd`: €10k in seizoen 1, €38k in seizoen 3, €145k in seizoen 5, €1,07mln in seizoen 8, ~€115mln in seizoen 15 — de kosten zijn de échte klok van de run), clubbudgetten groeien +20%/seizoen (`CLUB_BUDGET_GROWTH` in `game.gd` — zonder dit lopen ze bevroren op hun seizoen-1-waarde vast terwijl spelerswaarde via ontwikkeling wél doorgroeit, met een harde muur van "geen enkele club kan het betalen" tot gevolg), De Bank keert rijpe stortingen uit (zie hieronder), spelerontwikkeling (zie hieronder), vertrouwensdrift, contractafloop, en de fail-checks. Een **clubloze** speler heeft geen aflopend contract: het contract tikt alleen af (en levert tekengeld op bij verlenging) zolang hij bij een club zit. Daarna volgt **🪙 De Shop** voor je verder gaat naar het volgende seizoen.

   Elke speler is altijd verkoopbaar — clubbudget speelt GEEN rol meer in clubinteresse. `Game.gen_interest()` garandeert elke speler ELK seizoen 1 of 2 geïnteresseerde clubs (betaalbaarheid is volledig verwijderd, ook de vroegere kans-penalty); ambitie bepaalt (met wat ruis toegevoegd, zodat het niet volledig voorspelbaar is) welke clubs het eerst aan de beurt zijn, niet óf er interesse is. Of het er 1 of 2 worden hangt af van rating (hogere rating trekt vaker een 2e club) en van schandaal (vanaf 70 remt `scandal_interest_mult()` de kans op een 2e club af — schandaal beïnvloedt dus nog steeds hoevéél interesse je krijgt, niet meer óf je die krijgt). Zie je toch "alle interesse is afgehandeld" in het transferwindow, dan heb je je gegarandeerde interesse(s) al opgebruikt via onderhandelen/afwijzen — er was nooit 0.

### 2b. Het kantoor (niveaus 1–5, geheim niveau 6 voor wie ooit wint)

Je **kantoorniveau** is de centrale progressie-as van een run: het bepaalt de rating-band waaruit je 8 scoutingkandidaten worden getrokken (zie fase 3). Je begint op niveau 1 (of niveau 2 met de Erfenis-perk Kantoorvoorsprong, zie §4.4) en kunt op het **voorbereidingsscherm** upgraden voor **40% van de gemiddelde spelerswaarde op het doelniveau** (`office_upgrade_cost()`, zie §4.1 voor de exacte curve) — dus ca. €132k → €352k → €1,52mln → €6,4mln (→ €21,6mln voor het geheime niveau 6). Bewust géén economie-herbalans en bewust duur: dit is de centrale progressie-as, in tegenstelling tot de optionele shop-upgrades (zie hieronder) mag dit gewoon een forse investering blijven — de hoogste niveaus zijn eindgame-luxe die je alleen in een topseizoen haalt. De hele achtergrond-art wisselt per niveau (`_update_office_background()` in `main.gd` laadt `res://art/office_<niveau>.png` als die bestaat, anders een effen sfeerkleur; een halfdoorzichtige scrim houdt de tekst altijd leesbaar). De niveaus (`Game.OFFICE_LEVELS`), met hun gemiddelde spelersniveau en sfeer:

| Niv. | Naam | Gem. rating | Band (rating) | Sfeer/beeld |
|---|---|---|---|---|
| 1 | Boven de Snackbar | 28 | 18–40 | Zolderkamertje boven een snackbar, patatneon |
| 2 | De Portacabin | 40 | 28–54 | Bouwkeet op een bedrijventerrein, tl-licht |
| 3 | Het Grachtenpand | 55 | 43–68 | Klassiek Amsterdams grachtenpand, hout |
| 4 | De Glazen Toren | 70 | 58–82 | Zuidas-wolkenkrabber, glas en skyline |
| 5 | Monaco | 84 | 74–93 | Penthouse/jacht in de haven van Monaco, goud |
| 6 🔒 | De Kampioenssuite | 90 | 84–94 | Geheim — pas zichtbaar/koopbaar nadat je ooit één run hebt gewonnen |

Niveaus bewust verder uit elkaar getrokken en het gemiddelde omlaag (was gem. 71 over alle niveaus, nu gem. ~61) — vooral niveau 1 is nu veel zwakker (28 i.p.v. 45, bijna zuiver amateurniveau). Zonder dit kon je vroeg al redelijk veel geld verdienen en dat compound sparen (De Bank/rente), waardoor de late game bijna vanzelf makkelijk werd. De top (Monaco/Kampioenssuite) blijft bewust binnen de 94-cap uit `world_gen.gd` (`make_candidate()` capt `pot`/`est` altijd op 94) — die grens doorbreken zou rating > potentieel kunnen opleveren. Niveau 6 gaat dus niet hoger dan Monaco kon, maar heeft wel een hogere floor (74→84), dus minder variantie op het topniveau.

**Niveau 6 is een permanente, carrièrebrede trofee**: zodra je één keer een run hebt gewonnen, zet `Meta.record_win()` `Meta.state.has_won_ever = true`, en `Game.office_max_level()` staat vanaf dan in élke toekomstige run (ook na een verloren run) een 6e upgrade toe. Vóór je eerste winst bestaat niveau 6 gewoon niet — de upgrade-knop en het "hoogste niveau bereikt"-bericht stoppen bij niveau 5.

Het effectieve plafond (`candidate_ceiling()`) is de band-bovengrens plus de meta-perks die vroeger de rating-cap verhoogden (Talentmagneet, Grote naam) en de shop-upgrades Kantoorrenovatie (+3) en Breed scoutingnetwerk (+4) — zo blijven die relevant nu reputatie het plafond niet meer bepaalt. Het aantal kandidaten is `CANDIDATES_PER_SEASON` (8) + Extra kandidaat-perk (`candidate_count()`).

**Fail states:** saldo onder €0 (failliet), schandaalmeter op 100 (licentie kwijt), of een lege stal (alle cliënten weg). Vertrekkans is een DOORLOPENDE curve (`leave_chance()` in `game.gd`, geen harde knip meer bij één drempel): onder 60 vertrouwen loopt het risico lineair op tot max 85% bij 0. Rivaal-makelaars kunnen daarnaast cliënten wegkapen (`poach_chance()`) — hoe hoger de rating en hoe lager het vertrouwen, hoe groter dat risico (de vertrouwens-invloed is onlangs verzwaard). **Een cliënt is onaantastbaar tijdens zijn eerste 2 seizoenen bij je** — pas vanaf zijn 3e seizoen loopt hij kaaprisico (`client_since` op de speler, gezet in `_make_client()`; `poach_chance()` geeft 0,0 terug zolang `state.season - client_since < 2`). Een net getekend talent is dus even veilig. **Elk vertrek van een cliënt verschijnt NIET in het seizoensrapport** maar op een eigen groot-nieuws-scherm dat als EERSTE komt na de transferperiode — nog vóór het seizoensrapport en vóór een eventuele voorbereide transfer (`Game.state["last_departures"]` → `_goto_wrapup()` → `show_departures_news()` in `main.gd`, zelfde patroon als `last_prepared_results`; daarna loopt de afsluiting via `_after_departures_news()` gewoon door). Dat dekt **beide** manieren om iemand te verliezen, onderscheiden via een `reason`-veld: `"left"` (uit zichzelf weg door te laag vertrouwen) en `"poached"` (een rivaal nam hem over). Dat onderscheid is belangrijk, want `leave_chance` is veruit de meest voorkomende oorzaak — bij vertrouwen 30 is dat ~48% per seizoen, tegenover ~3% voor wegkapen (dat bovendien alleen wordt geprobeerd als de vertrekcheck al faalde). Vroeger kreeg alleen wegkapen een scherm en verdween "uit zichzelf vertrokken" als losse tekstregel tussen de boekhoudregels, waardoor je cliënten kon verliezen zonder het door te hebben. Het scherm verschijnt alleen als er daadwerkelijk iemand weg is: met de volledige spelerkaart van wie je kwijt bent en welke rivaal hem overnam, zodat het niet wegvalt tussen de kantoorkosten- en tekengeldregels. Een cliënt die uit zichzelf vertrekt (te laag vertrouwen, `leave_chance()`) blijft wél gewoon een regel in het rapport — dat is jouw eigen nalatigheid, geen extern nieuws.

**Schandaal had tot voor kort geen enkel effect tussen 0 en 99** — alleen bij exact 100 verloor je je licentie, een binaire val i.p.v. een voelbare stat. Twee drempels (`SCANDAL_TIER1`=40, `SCANDAL_TIER2`=70 in `game.gd`) geven schandaal nu continue, lineair oplopende gevolgen vóórdat het de 100-grens bereikt (`_scandal_tier_factor()`: 0.0 onder de drempel, oplopend naar 1.0 bij schandaal 100):
- **Vanaf 40** ("onder een vergrootglas"): lagere tekenkans bij nieuwe cliënten, tot −20% bij schandaal 100 (`scandal_signing_penalty()`, toegepast in `sign_chance()`).
- **Vanaf 70** ("reputatie in vrije val"): hogere kaapkans, tot +20% bij schandaal 100 (`scandal_poach_bonus()`, in `poach_chance()`) én minder clubinteresse bij transfers, tot −50% bij schandaal 100 (`scandal_interest_mult()`, in `gen_interest()`).

Beide drempels tonen ook een zichtbare waarschuwing op het voorbereidingsscherm zodra ze overschreden worden (`show_prep()` in `main.gd`), zodat je begrijpt waarom je kansen ineens anders zijn. Bewust géén wijziging aan het automatische seizoensverval (`scandal_decay`, nog steeds minstens −3/seizoen) — de drempel-effecten maken schandaal relevant zonder de bestaande balans van hoe snel het op- en afbouwt aan te raken.

**Reputatie en vertrouwen zijn bewust lastiger te winnen dan te verliezen.** In `game.gd`: `REP_GAIN_MULT`/`TRUST_GAIN_MULT` (beide 0,6) dempen alleen POSITIEVE rep/vertrouwen-effecten; negatieve tellen voluit. **Reputatie heeft GEEN bovengrens** (alle `state.rep`-stijgingen zijn `maxi(..., 0)`, niet langer `clampi(..., 0, 100)`) — vertrouwen blijft wel geclampt op 0-100. Reputatie zakt bovendien elk seizoen terug richting een neutrale basis van 50 als je erboven zit (`REP_DECAY_ABOVE_BASELINE`) — zonder die decay zou reputatie, met geen plafond, ongelimiteerd door kunnen blijven groeien zonder dat je er nog iets voor hoeft te doen; de decay dwingt je dus tot actief onderhoud, ook (juist) bij een hoge reputatie. Kansen die op reputatie zijn gebaseerd (`sign_chance()`, `_sign_event_talent()`'s ondergrens) hebben zelf nog wel hun eigen plafond (bijv. `clampf(c, 0.1, 0.85)`), dus een extreem hoge reputatie geeft een oplopend maar uiteindelijk verzadigend voordeel — het is de RUWE stat zelf die onbegrensd is, niet elk effect dat erop gebaseerd is. **Het gewicht van vertrouwen groeit over de seizoenen heen** (`trust_gain_mult()`): in seizoen 1 valt er nog weinig op te bouwen (demping 0,6), maar elke +0,09/seizoen (`TRUST_GAIN_PER_SEASON`, tot een plafond `TRUST_GAIN_MAX` = 1,6 rond seizoen 12) telt een positieve vertrouwensmutatie zwaarder mee — vertrouwen wordt zo een investering die zich over de run opbouwt. Álle vijf positieve vertrouwenstoekenningen lopen hierlangs (event-`trust`/`all_trust`, transfer +8, verlenging +5, voorbereide transfer +6); negatieve drift blijft voluit tellen.

**Spelerontwikkeling** (`end_of_season()` in `game.gd`) — de groei per seizoen is een **functie van het gat tussen rating en potentieel**, maar wordt **één keer vastgelegd** en daarna nooit herberekend: `dev_step = (potentieel − base_rating) / aantal ontwikkelseizoenen`, opgeslagen op de speler zelf. **`base_rating` is de rating zoals de speler GEGENEREERD is** (gezet in `world_gen.gd`, in zowel `generate()` als `make_candidate()`) — bewust niet zijn actuele rating en niet de bandondergrens, zodat het tempo van dag één vaststaat. Het aantal seizoenen wordt per speler getrokken uit een normale verdeling (`DEV_SEASONS_MEAN` 10, `DEV_SEASONS_SD` 4, geclampt op 5–22 via `_draw_dev_seasons()`), dus **een speler is gemiddeld 10 seizoenen onderweg naar zijn potentieel** — de een is er in 6, de ander heeft er 15 voor nodig.

**`DEV_MAX_STEP` (7) is een harde bovengrens op de groei per seizoen.** Zonder die cap kon een speler met een enorm gat (rating 18 → potentieel 85 = gat 67) én een lage trekking uit `_draw_dev_seasons()` **meer dan 20 rating in één seizoen** winnen, waarmee een run in één klap gewonnen was — dat gebeurde bij zo'n 5% van de spelers, want `DEV_SEASONS_MIN` stond op 3. Twee fixes samen: MIN naar 5 én de cap op 7. Gesimuleerd over 20.000 spelers (niveau-1-band): gemiddeld 10,70 seizoenen tot potentieel (SD 3,49), grootste sprong in één seizoen **max 7**, gemiddeld 4,20. De cap knijpt dus alleen de extreme uitschieters af; de gemiddelde speler zit er ver onder.

Dat "één keer vastleggen" is bewust: eerder werd het gat élk seizoen opnieuw uit de HUIDIGE rating berekend (`gat / dev_left`, met een meelopende noemer). Dat was zelfcorrigerend, maar de stap hing daardoor af van de actuele rating — een speler wiens rating om welke reden dan ook verschoof, kreeg meteen een ander groeitempo. Nu berust de groei puur op de **basisrating van zijn eerste seizoen** en blijft de stap constant, wat ook voorspelbaarder speelt ("deze jongen groeit ~3 per jaar").

In het seizoensrapport is ontwikkeling **geen tekstregel meer maar een spelerkaart** (`Game.state["last_developed"]` → `_show_wrapup_report()`), op volle breedte onder een "📈 ONTWIKKELING"-kopje. Die kaart heeft een derde badge: een grijze **WAS**-badge met de oude rating, dan het **groeicijfer met daaronder een pijl** (`+3` boven `→`, beide groen) en dan de gewone blauwe RAT-badge met de nieuwe rating — je ziet de groei dus in één blik in plaats van hem uit een zin te moeten lezen (`prev_rating`-parameter op `_player_card()`; het cijfer wordt daar berekend als `rating - prev_rating`, dus er is geen extra parameter voor nodig). Bewust géén 2-kolomsraster hier, want met die extra badge blijft er in een halve kolom te weinig breedte over voor naam en subregel.

Een groter gat bij de start betekent dus een grotere stap per seizoen (een rating-30-speler met potentieel 85 maakt grote sprongen; iemand die al bijna "af" is kruipt). De stochastische afronding is onvertekend (`floor(per)` plus kans `per − floor(per)` op +1), zodat de verwachte groei exact `dev_step` is en er geen systematische drift insluipt. De vroegere **leeftijdsgrens van 26 is verwijderd** — die maakte de 15-seizoenen-kalibratie onhaalbaar voor iedereen die op zijn 20e instroomde (dat gaf maar 7 seizoenen rek). `dev_step` wordt lazy geïnitialiseerd, dus saves van vóór dit veld werken gewoon door.

**De Bank** (`Game.bank_deposit()`, voorbereidingsscherm) — stort een zelfgekozen bedrag; na 3 seizoenen (`BANK_MATURITY_SEASONS`, was 2) krijg je het verdubbeld terug (`BANK_MULTIPLIER`). Geen risico, wel je geld 3 seizoenen lang vastgezet — een gegarandeerd maar traag tegenwicht tegen de exponentiële kosten; de langere looptijd remt compound-sparen iets af. Het bedrag kies je via een **horizontale slider** (`HSlider`, stap €1.000) die van €0 tot je volledige huidige saldo loopt (`bank_deposit_slider` in `main.gd`) — een label erboven toont live het geselecteerde bedrag, de "Storten"-knop staat eronder en is uitgeschakeld zolang je saldo €0 is. Net als bij scouting toont het voorbereidingsscherm bewust GEEN losse `>> `-meldingsregel (`show_flash()`) na storten of een kantoor-upgrade — het resultaat is al zichtbaar via de bijgewerkte staat zelf (de lopende-bankstortingen-lijst, het kantoorniveau); `_discard_flash()` leegt de melding stil zodat hij niet later op een ander scherm (stalbeheer, transferwindow, shop) alsnog opduikt.

**🪙 De Shop** (`Game.SHOP_UPGRADES`, `show_shop()` in `main.gd`) — na elke seizoensafsluiting krijg je 3 willekeurige, nog niet gekochte upgrades te koop aangeboden (`Game.shop_offer()`). Bevalt de set niet, dan kun je tegen betaling **rerollen** naar een andere set (`Game.shop_reroll_cost()`; de huidige set wordt uitgesloten zodat je echt iets anders krijgt). Je kunt ook gewoon doorlopen. Alle upgrades zijn eenmalig en gelden alleen **voor deze run** (los van de permanente legacy-perks uit §4.3), met prijzen die meeschalen via **`Game.shop_money_scale()`** — een EIGEN, milde groeivoet (`SHOP_MONEY_GROWTH` = 1,15/seizoen, seizoen 15 ≈ ×6), losstaand van de harde `event_money_scale()` (gekoppeld aan dezelfde `COSTS_MULT` als de kantoorkosten, ×1,95/seizoen sinds de VALUE_ANCHORS-herbalancering, seizoen 15 ≈ ×11.495) die de kantoorkosten en event-bedragen gebruiken. Zonder die eigen, mildere curve zouden shop-upgrades in de tweede seizoenshelft onbetaalbaar worden — je inkomen (clubbudgetten groeien maar 20-25%/seizoen) houdt de ×1,95-curve namelijk nooit bij, en je zou de latere upgrades dan gewoon nooit meer kopen. De bedragen hieronder zijn de **basisprijzen** in `SHOP_UPGRADES`; op alles geldt een generieke multiplier `SHOP_PRICE_MULT` = 0,9 (bijna geen korting meer op de basisprijs — de mildere groeivoet is de eigenlijke fix, niet een lagere startprijs). 24 upgrades, zodat je niet allang tegen seizoen 6 alles hebt gekocht:
- **Groter kantoor** (€36k) — +1 stalplek, rest van de run.
- **Nog groter kantoor** (€44k) — nog eens +1 stalplek (stapelt met Groter kantoor).
- **PR-bureau** (€28k) — +2 extra schandaalverval per seizoen.
- **Eigen jeugdscout** (€42k) — +1 scoutpunt per seizoen.
- **Extra scoutingbudget** (€22k) — +2 scoutpunten per seizoen, de rest van de run (via `scout_points_per_season()`, net als Eigen jeugdscout — niet meer eenmalig).
- **Juridisch adviseur** (€32k) — schandaal-stijgingen 1 lager (min. 1).
- **Risicomanager** (€30k) — schandaal kan niet meer boven de 80 uitkomen.
- **Clubarts-netwerk** (€26k) — eenmalig -15 schandaal.
- **Media-trainer voor je stal** (€24k) — eenmalig +15 vertrouwen bij al je huidige cliënten.
- **Sportpsycholoog** (€30k) — vertrekkans van cliënten daalt (alsof hun vertrouwen 8 hoger is).
- **Veiligheidsnet** (€34k) — rivalen kapen 5 procentpunt minder vaak een cliënt weg (`poach_chance()` -0,05).
- **Netwerkdiner-abonnement** (€46k) — +1 gunst per seizoen.
- **VIP-netwerkclub** (€24k) — eenmalig +2 gunsten.
- **Kantoorrenovatie** (€38k) — eenmalig +8 reputatie, plus +3 op je scouting-plafond.
- **PR-campagne** (€24k) — eenmalig +10 reputatie.
- **Reputatiebeheerder** (€34k) — je reputatie zakt niet meer vanzelf terug richting 50 (normaal -3/seizoen, `REP_DECAY_ABOVE_BASELINE`).
- **Data-analytics abonnement** (€38k) — effect van 1 scoutpunt verdubbelt: de onzekerheidsverlaging per scout (normaal 5 + Talentenoog-perk) telt 2× (`scout_drop *= 2` in `scout()`).
- **Breed scoutingnetwerk** (€34k) — +4 op je scouting-plafond: betere spelers binnen bereik (`candidate_ceiling()`).
- **Fiscalist** (€36k) — +2% fee-percentage op elke transfer.
- **Contractenspecialist** (€32k) — +30% tekengeld bij elke contractverlenging.
- **Clubcontactenboek** (€40k) — clubbudgetten groeien +25%/seizoen i.p.v. +20% (`CLUB_BUDGET_GROWTH` +0,05).
- **Investeringsfonds** (€30k) — De Bank keert 2,3× uit i.p.v. 2× op elke storting (`BANK_MULTIPLIER` +0,3).
- **Onderhandelaar-coach** (€34k) — +3% slagingskans op alle onderhandeltactieken.
- **★ Noodfonds — lifeline** (€52k) — kom je onder €0, dan reset je saldo eenmalig per run naar €0 en ga je door (`Game.try_shop_bailout()`, los van en naast de gelijknamige `laatste_redmiddel`-legacy-perk).

Er wordt automatisch opgeslagen aan het eind van elk seizoen (`user://save.json`); "Doorgaan" op het startscherm pakt de run weer op bij de voorbereiding.

---

## 3. Projectstructuur

```
voetbalmakelaar/
├── project.godot          # projectconfig: portrait, autoload, main scene
├── scenes/
│   └── Main.tscn          # één kale Control-node; alle UI is code
└── scripts/
    ├── game.gd            # AUTOLOAD "Game": alle staat + spellogica van één run
    ├── meta.gd            # AUTOLOAD "Meta": meta-progressie (legacy points, perks), overleeft runs
    ├── i18n.gd            # AUTOLOAD "I18n": vertaallaag NL/EN/FR/ES/DE/AR + RTL (zie §4.7)
    ├── world_gen.gd       # procedurele generatie (spelers, clubs, namen)
    ├── events_db.gd       # alle 69 events als pure data
    ├── negotiation.gd     # het onderhandelings-minigame (transferwindow)
    ├── press_conference.gd  # minigame "Persconferentie" (event: persconferentie_druk)
    ├── tax_settlement.gd  # minigame "Fiscale schikking" (event: fiscale_schikking)
    ├── poker_bluff.gd     # minigame "Pokerbluf tegen een rivaal" (event: rivaal_poker)
    ├── dice_bookmaker.gd  # minigame "Dobbelen bij de bookmaker" (event: bookmaker_dobbelen)
    ├── accounting_puzzle.gd # minigame "De boekhoudpuzzel" (event: boekhoud_puzzel)
    ├── anagram_hunt.gd    # minigame "Anagramjacht" (event: anagram_jacht)
    ├── scout_speed_date.gd  # minigame "Speed-daten op de scoutingbeurs" (event: scoutingbeurs_speeddate)
    ├── simon_media.gd     # minigame "Mediatraining: Simon Says" (event: mediatraining_simon)
    └── main.gd            # de UI: bouwt elk scherm programmatisch
```

De belangrijkste ontwerpbeslissing: **`Game.state` is één plat Dictionary** met daarin de hele wereld (spelers, clubs, cliënten, meters, vlaggen). Daardoor is opslaan letterlijk `JSON.stringify(state)`, is een daily-seed later triviaal, en kun je de logica testen zonder ook maar één UI-node.

De UI is bewust programmatisch (geen geneste .tscn-scènes): voor een tekst-gedreven game itereert dat sneller en heb je geen scene-bestanden die uit sync raken met je data. Wil je later visueel pimpen, dan vervang je alleen `main.gd`-helpers (`lbl`, `btn`) door mooiere componenten — de logica raakt het niet aan.

---

## 4. Uitbreiden

### 4.1 Events toevoegen (belangrijkste groeipad!)

Open `scripts/events_db.gd` en voeg een Dictionary toe aan de array. Deterministische optie:

```gdscript
{
    "id": "mijn_event",              # uniek!
    "title": "De titel",
    "text": "Wat er gebeurt. {client} wordt vervangen door de cliëntnaam.",
    "needs_client": true,            # koppelt een willekeurige cliënt
    "amount": 5000,                  # optioneel: ongeschaalde basiswaarde voor {amount} in "text"
    "options": [
        {"label": "Keuze A", "effects": {"money": -5000, "trust": 10},
         "txt": "Wat er daarna gebeurt."},
    ],
}
```

Kansgebaseerde optie:

```gdscript
{"label": "Gok het erop", "chance": 0.6,
 "success": {"rep": 8},  "success_txt": "Gelukt!",
 "fail":    {"scandal": 12}, "fail_txt": "Oei."}
```

**De kans staat NIET als tekst op de knop.** De knop is zelf de meter: groen vanaf de leidende rand tot de slaagkans, rood daarna (`_chance_style()` / `_style_chance_button()` in `main.gd`). Zo zie je het risico in één blik zonder te rekenen. Drie dingen om te weten als je hieraan sleutelt:

* het is een `StyleBoxTexture` met een `GradientTexture2D` erin, en die kent **geen `corner_radius`** — kansknoppen hebben dus rechte hoeken waar gewone knoppen die van het thema volgen;
* de harde grens komt van twee gradient-stops op `p ± 0,001` in plaats van twee stops op exact dezelfde offset, zodat het niet afhangt van hoe `Gradient` met dubbele offsets omgaat;
* **alle** button-states krijgen een eigen stijl (`normal`/`hover`/`pressed`/`focus`/`disabled`). Vergeet je er één, dan pakt Godot daar weer de themastijl en knippert de balk weg bij aanraken. In RTL vult de balk vanaf rechts (`I18n.is_rtl()`).

Het getoonde percentage is de kans **inclusief** de Geluksvogel-perk (`Game.luck_bonus()`), dus wat je ziet is wat er echt gerold wordt.

Beschikbare effect-keys: `money`, `rep`, `scandal`, `favors`, `trust` (de gekoppelde cliënt), `all_trust`, `scout_points`, `new_client`/`new_top_client` (voegt een vrij talent toe aan je stal en meldt wie). Poortwachters: `req_money` en `req_favors` schakelen de knop uit als de speler het niet heeft.

**Faillissement-vangnet (generiek, geen `req_money` nodig).** `_option_certain_bankrupt()` in `main.gd` schakelt élke optie uit die je saldo gegarandeerd onder €0 zou zetten — ook zonder expliciete `req_money`. Dat was een echt gat: events als `clubarts_geheim` ("Alvast een transfer voorbereiden", `money: -2000`) hadden geen poortwachter, dus je kon jezelf failliet klikken. En dat is direct fataal: `_next_event()` doet een tussentijdse fail-check en zet `game_over = "failliet"` zodra je saldo onder €0 komt, dus het was een instant self-destruct. Bij een **gok** geldt de blokkade alleen als BEIDE uitkomsten je eronder brengen — een gok die je pas bij mislukking kopt blijft beschikbaar, want dat is een geïnformeerd risico (de preview toont dat bedrag). Zijn hierdoor álle opties geblokkeerd, dan verschijnt een **"Laten lopen →"**-knop zodat je niet vastzit op het eventscherm.

**`scout_points` vs. `scout_points_permanent`** — deze twee zijn NIET hetzelfde en de keuze moet kloppen met je flavor-tekst. `scout_points` is eenmalig: het verhoogt alleen je huidige seizoenspool, en verdwijnt bij de volgende reset in `_goto_scouting()` (`Game.state.scout_points = Game.scout_points_per_season()`) — gebruik dit voor teksten die expliciet "nu meteen"/"deze ronde" beloven. `scout_points_permanent` verhoogt DAARNAAST ook `state.bonus_scout_points`, wat in `scout_points_per_season()` wordt meegeteld — dus je krijgt het bedrag zowel deze ronde als in élk volgend seizoen. Gebruik dit voor teksten die "voortaan" of een structurele verandering beloven. Twee events gebruiken het nu: `eigen_academie` ("Je krijgt voortaan als eerste een belletje bij een nieuw talent", +2/seizoen) en `jeugdtoernooi` (de oud-scout houdt je op de hoogte, +1/seizoen). Bij beide beloofde de tekst eerder een blijvende verandering terwijl het effect stiekem maar één seizoen meeging — een mismatch tussen tekst en mechaniek. `scoutingcongres` blijft bewust eenmalig (+3): een congres van drie dagen is een eenmalige gebeurtenis, geen structureel netwerk.

`new_client`/`new_top_client` (`_sign_event_talent()`/`_sign_top_talent()` in `game.gd`) leveren bewust een BOVENGEMIDDELDE speler op i.p.v. een doorsnee scoutvondst: de ondergrens schaalt mee met je reputatie (geclampt op de daadwerkelijk hoogst beschikbare rating in de pool, zodat een hoge reputatie nooit tot niemand of altijd hetzelfde ~58-rating resultaat leidt) en de uiteindelijke pick is de beste uit een best-of-3-steekproef (`_best_of_sample()`), niet zomaar een willekeurige. Na afloop toont het uitkomstscherm de échte stats van de nieuwe cliënt onderaan in het infopaneel (`Game.last_new_client_id` → `_show_player_info()` in `_resolve()` en `show_poker()`), i.p.v. alleen zijn naam in de meldingsregel.

Alle `money`-bedragen in events (in `effects`, `success`, `fail` én `req_money`) worden automatisch geschaald met `Game.event_money_scale()`, die nu EXACT dezelfde curve gebruikt als de kantoorkosten (`COSTS_MULT`, ×1,95/seizoen sinds de VALUE_ANCHORS-herbalancering) — zo blijven event-bedragen in de pas met de rest van de economie in plaats van er een eigen (zachtere) groeivoet op na te houden. Je hoeft in `events_db.gd` dus gewoon seizoen-1-bedragen te blijven schrijven — de schaling gebeurt centraal via `Game.scale_money_effects()`, aangeroepen in `_resolve()` vóór zowel toepassing als weergave. **Noem je een concreet bedrag in de flavor-tekst zelf** (bijv. "vraagt om €10.000"), gebruik dan een `"amount"`-key (ongeschaalde basiswaarde) op het event en `{amount}` in de tekst — anders klopt de intro na seizoen 1 niet meer met het werkelijk geschaalde effect. `show_event()` in `main.gd` vervangt `{amount}` met `eur(round(ev.amount * Game.event_money_scale()))`, net als `{client}` voor de cliëntnaam. De minigames met vaste bedragen schalen op dezelfde manier via een `money_scale`-parameter op hun `outcome()`/`resolve()`. Het uitkomstscherm na een event toont altijd een expliciete regel per gewijzigde waarde (bijv. "Geld: +€5.000", "Reputatie: -3", "Vertrouwen (Sem Kovacevic): +8") naast het verhaaltje — zie `_effect_lines()` in `main.gd`. Standaard is dat groen (goed voor jou) of rood (slecht); **Gunsten vormen de uitzondering en zijn altijd goudkleurig** (`GUNST_GOLD` in `_show_effect_rows()`), ongeacht of de mutatie positief of negatief is — consistent met de goudkleurige "Gunsten"-teller in de header zelf (`refresh_header()` gebruikt daarvoor BBCode; `header` is sindsdien een `RichTextLabel` i.p.v. een kale `Label`). Dezelfde samenvatting verschijnt ook na elke minigame.

**Kwalitatieve preview vóór een keuze** (`_effect_rows()` met `show_numbers=false`): op de keuzeknoppen zelf staan geen exacte getallen maar tekens — **`++`/`--` is normaal, `++++`/`----` is de zwaarste impact**. Die zwaarste markering (`_emphasis_for()`) vereist nu TWEE dingen: de waarde moet de grootste zijn binnen dit event ÉN minstens **2× de kleinste** variant (`EMPHASIS_MIN_RATIO`). Voorheen was het `+++` bij enkel "grootste binnen het event", wat betekenisloos werd bij een verschil van bijv. 5 vs. 6 rep — je zag `+++` naast `++` terwijl het praktisch hetzelfde was. Nu betekent `++++` echt "ongeveer dubbel of meer", en bij kleine onderlinge verschillen krijgen alle opties gewoon `++` (accurater dan een vals onderscheid).

**Absolute uitzondering voor geld** (`EMPHASIS_BIG_MONEY`, €10.000 op seizoen-1-schaal via `_big_money_threshold()`). De relatieve regel hierboven viel bij de **corruptie-events** verkeerd uit: bij "De weldoener" (€20.000 smeergeld) en "Gênant aanbod" (€12.000 zwijggeld) heeft de nette optie helemaal géén geldeffect, dus was er niets om mee te vergelijken (`distinct_counts` had één waarde) en bleef het bij `++geld` — terwijl dat objectief een smak geld is. Bij "Verkeerde storting" (€14.000 winst vs. €14.000 verlies) waren beide bedragen even groot, met hetzelfde gevolg. Een bedrag boven de drempel krijgt nu altijd de zware markering, ongeacht de rest van het event. De drempel schaalt mee met `event_money_scale()`, anders zou vanaf seizoen ~5 élk bedrag "veel" zijn. Werkt op de absolute waarde, dus een fikse straf krijgt net zo goed `----geld`. Concreet omgeslagen: De weldoener, Gênant aanbod, Verkeerde storting, Cryptosponsor, De constructie en Schoenendeal; bedragen onder €10.000 blijven terecht `++`.

Event-voorwaarden: `min_season` (verschijnt pas vanaf dat seizoen), `needs_client` (koppelt een cliënt) en `needs_slot` (verschijnt alleen als je stal niet vol is — verplicht bij events met `new_client`). Elk event komt maximaal één keer per run voor (`used_events`).

**Events met een minigame.** Een event kan in plaats van `options` een `"minigame": "<key>"` hebben. `show_event()` in `main.gd` toont dan alleen intro-tekst plus een "Beginnen →"-knop; `_start_minigame()` bouwt het bijbehorende object op en toont het eigen scherm. Elke "X over"-teller (pogingen, vragen, herkansingen, rondes) wordt getoond als een rij blokjes i.p.v. kale tekst — een HP-bar-achtig `_set_turn_bar(label, current, max_turns)` in `main.gd`: felgeel = nog beschikbaar, dof = al opgebruikt. Hetzelfde patroon geldt voor scoutpunten op het scoutingscherm. Deze balk (`turn_bar`) is een VAST element net onder de header, buiten de `ScrollContainer` — hij blijft dus altijd zichtbaar boven de rest van het scherm, ook als je in een lange log naar beneden scrollt. `clear()` verbergt en leegt hem bij elke schermwissel; een scherm dat een teller nodig heeft, roept `_set_turn_bar()` daarna zelf weer aan. Elke minigame is een losse `RefCounted`-klasse naar het patroon van `negotiation.gd` (state + `play()`-methodes + een `outcome()`/resultaat), met een eigen script en `show_*()`/`_play_*()`/`_finish_*()`-functies in `main.gd`. Bij afsluiten roept de `_finish_*()`-functie `Game.apply_effects()` aan en gaat daarna verder via `_next_event()` — exact het patroon van een normaal event. Negen huidige minigames:

- **Persconferentie** (`press_conference.gd`, event `persconferentie_druk`) — volledig herontworpen. Elke vraag komt nu van een **zichtbare journalist** (`JOURNALISTS`: 📰 De Feitenjager, 🎤 De Provocateur, 🔮 De Speculant), elk met een naam, icoon en een ALTIJD zichtbare hint over welk antwoord bij hem werkt (bijv. "Wil bewijs zien — eerlijkheid ontwapent hem het best"). Dit vervangt de oude verborgen "toon" die je blind uit de vraagformulering moest raden — de tactiek zit nu in het kóppelen van journalist-type aan reactie, niet in giswerk. Doel is ook positief geframed: een **publiekssympathie-meter** (0–100, hóger is beter) i.p.v. een spanningsmeter die je moest zien te vermijden; zakt sympathie naar 0, dan ontploft de zaal. Twee successen op rij geven **MOMENTUM** (+50% effect op de volgende succesvolle actie, net als Flow bij de onderhandeling), en de **laatste vraag is een Slotvraag met dubbele inzet** (`is_final_question()`) — een climax in plaats van gewoon nog een ronde. Net als bij de onderhandeling toont het scherm alleen de meest recente uitkomst (laatste 3 logregels: vraag, antwoord, resultaat), niet de hele geschiedenis.
- **Fiscale schikking** (`tax_settlement.gd`, event `fiscale_schikking`) — risicoverdeling in plaats van één worp: drie boekhoudposten, elk met een keuze tussen open aangeven, deels verhullen of volledig verhullen. Gebalanceerd op verwachte kosten (% van het postbedrag) zodat elke optie een reden heeft: **Open** is de dure zekerheid (−40%, nooit schandaal); **Deels** heeft de laagste verwachte kosten (65% kans op slechts −8%, 35% kans op −55% + wat schandaal) — de slimme keuze, met een klein risico; **Volledig** is een pure variantiegok (50% gratis, 50% een boete ZWAARDER dan de belasting zelf (−110%) plus fors schandaal) — alleen zinnig als je echt op geluk speelt. Op de keuzeknoppen staan **geen percentages meer**, alleen de bedragen: onder elke knop een groene "lukt: €X" en een rode "mislukt: €Y" (`preview_amounts()` in `tax_settlement.gd`, dezelfde groen/rood-conventie als de event-previews). "Open aangeven" heeft maar één uitkomst en toont dus één rode regel met het zekere bedrag. De percentages in `preview_amounts()` moeten wél in de pas blijven met `resolve()` — ze staan bewust naast elkaar in hetzelfde bestand. Elke keuzeknop toont een **compacte preview** van de uitkomst (`preview_text()`) — bijv. "Deels verhullen [65%: -€720 / 35%: -€4.950]" — zodat je niet blind hoeft te kiezen; bij Open (gegarandeerd) staat er gewoon één bedrag.
- **Poker om een talent** (`poker_bluff.gd`, event `rivaal_poker`, `needs_slot`) — een ECHT heads-up pokerspel om de rechten op een gedeeld toptalent: eigen hand, flop/turn/river, één tegenstander. Meegaan/Verhogen/Passen per straat; volwaardige 5-van-7-handevaluatie (hoge kaart t/m straat-kleur) bij showdown. **Verhogen is geen gratis winst**: bij een zwakke hand fold de tegenstander soms (55% kans onder handsterkte 0,3), maar bij een sterke hand (>0,6) kan hij in plaats daarvan **terug-raisen** (50% kans) — dan moet jij zelf kiezen tussen meegaan tegen extra kosten of alsnog passen (`awaiting_my_response`; geen re-re-raise, om het overzichtelijk te houden). Winnen levert een nieuwe cliënt (`new_client`) plus je netto chipwinst op.
- **Dobbelen bij de bookmaker** (`dice_bookmaker.gd`, event `bookmaker_dobbelen`) — Yahtzee-lite: 5 dobbelstenen, 2 herkansingen (vasthouden/opnieuw gooien). Het scherm toont de uitbetalingstabel (5 gelijk ×10 t/m niets = verlies) zodat de uitkomst nooit een raadsel is.
- **De boekhoudpuzzel** (`accounting_puzzle.gd`, event `boekhoud_puzzel`) — een 5×5 Latijns vierkant (elke rij/kolom bevat 1-5 precies één keer, geen vakconstructie — 5 is een priemgetal), 3 controlepogingen. Seizoen 1-7 meer starthints, seizoen 8-15 minder (moeilijker). Elk vakje cyclet 0 (leeg) → 1 → 2 → 3 → 4 → 5 → 0 → …, zodat je een vakje kunt legen voor overzicht; de check valideert generiek (`_is_valid_grid()`) of rijen/kolommen kloppen — een Latijns vierkant heeft meerdere geldige oplossingen, dus elke logisch kloppende invulling telt, niet alleen de ene intern gegenereerde. Legitiem en risicoloos alternatief voor de fiscale schikking, maar wél de zwaarste denkpuzzel in het spel (14-17 lege vakjes, maar 3 controles) — daarom een fors hogere beloning dan je zou verwachten van een risicoloze optie: **€15.000** bij succes (was €4.000).
- **Anagramjacht** (`anagram_hunt.gd`, event `anagram_jacht`) — drie gehusselde woorden uit een gelekt document; typ het antwoord via een virtueel toetsenbord binnen 25 seconden per woord (echte klok via `_process()` in `main.gd`). Dat toetsenbord staat in **5 kolommen × 6 rijen** met grote toetsen (72px hoog, font 32, breedte-vullend) — was 13 kolommen × 2 rijen met 40×40-toetsjes, veel te klein om onder tijdsdruk accuraat te tikken. Score bepaalt de beloning (geld/reputatie). `WORD_BANK` bevat 44 voetbal-/makelaardij-thematische woorden (was 8) — genoeg variatie zodat de trekking van 3 woorden per potje niet snel voorspelbaar wordt bij herhaald spelen.
- **Speed-daten op de scoutingbeurs** (`scout_speed_date.gd`, event `scoutingbeurs_speeddate`) — vier scouts, vier talenten. Sommige scouts passen bij twee talenten; een FOUT aanbod verbrandt de scout meteen (niet meer beschikbaar), dus wild gokken kost je opties. Raad koppels binnen 6 pogingen.
- **Mediatraining: Simon Says** (`simon_media.gd`, event `mediatraining_simon`) — klassiek geheugenspel: bekijk een groeiende reeks "veilige reacties", herhaal haar daarna blind. Het aantal beschikbare reacties groeit mee met het seizoen (`round(4 + 0,4×seizoen)`, uit een pool van 10). 5 foutloze rondes = volledig getraind; één fout beëindigt de sessie zonder schade. De reactie-knoppen staan in een **raster van 2 kolommen** (`GridContainer`, `columns = 2` in `show_simon()`) i.p.v. één verticale lijst — bij 8-10 beschikbare reacties zou je anders door het halve scherm scrollen, en naast elkaar zijn ze veel sneller te scannen tijdens het herhalen. `_extend()` staat NOOIT een directe herhaling van de vorige stap toe — bij een kleine pool voelt pure onafhankelijke rng (die statistisch best vaak toevallig herhaalt, bijv. ~41% kans op minstens één directe herhaling bij 8 opties over 5 stappen) als scheef aan, ook al is de trekking zelf uniform verdeeld. De regel geldt alleen voor AANGRENZENDE stappen; verder blijft elke trekking eerlijk verdeeld over de overige opties.

Het GDD mikt op 120+ events voor launch. Dit bestand is dus waar het meeste van je toekomstige werk zit — en je hoeft er geen regel engine-code voor aan te raken.

**Developer-eventtest.** Op het verborgen developer-scherm (7× tikken op de kleine "v1.0"-tekst op het startscherm, dan het wachtwoord) staat naast de puntenreset ook "Test: doorloop alle events →" (`_start_event_test()` in `main.gd`). Dit start een verse testrun in het geheugen (`Game.new_run()`), zet het geld op 999.999.999 en doorloopt daarna ALLE events uit `EventsDB.get_events()` op volgorde — inclusief alle tien minigames — zonder de normale `min_season`/`needs_slot`/`used_events`-filters en zonder fail-checks (scandal/faillissement onderbreken de test niet). Elk scherm toont een oranje regel "[DEV TEST] Event X/70 — id: ..." mét een invoerveld + knop "Ga naar event" om direct naar een specifiek eventnummer te springen (`_dev_jump_to_event()`; sluit eventuele actieve minigame af zonder de effecten toe te passen). Je opgeslagen run op schijf blijft ongemoeid; alleen niet-opgeslagen voortgang in de huidige sessie wordt vervangen door de testrun.

**Optie-previews en context.** Elke event-optieknop toont nu direct een compacte samenvatting van het effect (bijv. "Geld: -€8.000, Reputatie: +5", of bij kansopties apart voor succes/mislukking) via `_effect_preview()` in `main.gd` — je hoeft niet meer te klikken om te weten wat een keuze kost of oplevert. Bij een vertrek of kaping van een cliënt (`end_of_season()` in `game.gd`) staat het actuele vertrouwenscijfer in de melding, zodat duidelijk is waaróm hij wegging. De persconferentie-minigame toont nu ook de daadwerkelijke journalistenvraag per ronde (`PressConference.current_question()`), zodat Ontwijken/Toegeven/Aanvallen een reactie is op iets concreets.

### 4.2 Balans tweaken

Alle knoppen staan bovenin `scripts/game.gd` als constants: startgeld, aantal seizoenen (`MAX_SEASONS`, standaard 15), cliënten-cap, kantoorkosten, fee-percentage, vertrek-drempel en -kans. De waardeformule (`value()`) en de interesse-kansen (`gen_interest()`) staan er direct onder.

**Markt- en ratingbalans.** `value()` gebruikt sinds kort géén kwadratische formule meer, maar **piecewise log-lineaire interpolatie** tussen vaste ankerpunten (`VALUE_ANCHORS` in `game.gd`) — expliciet gekozen zodat de gemiddelde transferwaarde per kantoorniveau exact op een gewenst bedrag uitkomt, met een vloeiende curve ertussenin:

| Niveau | Gem. rating | Gem. transferwaarde |
|---|---|---|
| 1 | 28 | €45.000 |
| 2 | 40 | €330.000 |
| 3 | 55 | €880.000 |
| 4 | 70 | €3.800.000 |
| 5 | 84 | €16.000.000 |
| 6 | 90 | €54.000.000 |

`_value_for_rating(r)` zoekt het segment tussen twee opeenvolgende ankers waar `r` in valt en interpoleert log-lineair (`v0 * (v1/v0)^t`) — dat geeft exact de tabelwaarden op de niveau-gemiddeldes en een natuurlijke (multiplicatieve) curve ertussen, in plaats van een lineaire knik. Ratings buiten het ankerbereik (18–94, de uiterste waarden die het spel kan opleveren: niveau-1-floor resp. de wereldwijde 94-cap in `world_gen.gd`) worden geclampt, nooit geëxtrapoleerd.

Deze curve maakt niveau 1 iets ARMER dan voorheen (€45k vs. voorheen ~€75k) maar de hogere niveaus fors RIJKER (niveau 5: 2,8× hoger; niveau 6: 7,2× hoger dan de oude kwadratische formule zou geven). Dat had drie cascade-effecten die zijn meegenomen om te voorkomen dat de late game er juist MAKKELIJKER van wordt:

1. **`COSTS_MULT`** (kantoorkosten-groeivoet) van 1,8 naar **1,95** — houdt de vroege seizoenen (kleine bedragen) vrijwel ongemoeid maar maakt seizoen 15 ongeveer 3× duurder (~€115mln i.p.v. ~€37,5mln), wat de extra fee-macht op de hogere niveaus grotendeels neutraliseert.
2. **`office_upgrade_cost()`** herzien: i.p.v. de losstaande vaste formule (€100.000 × doelniveau²) kost een upgrade nu **40% van de gemiddelde spelerswaarde op het doelniveau** (`OFFICE_UPGRADE_PCT_OF_VALUE`, via `_value_for_rating()`) — schaalt dus automatisch mee als de waardecurve ooit weer verandert. Resultaat: niveau 2 (€132k) en 3 (€352k) zijn nu GOEDKOPER dan voorheen (paste bij het armere begin), niveau 5 (€6,4mln) en 6 (€21,6mln) fors DUURDER (paste bij het rijkere einde).
3. **`CLUB_BUDGET_GROWTH`** van 0,12 naar **0,20** — zonder deze verhoging zou zelfs de rijkste, meest ambitieuze club tegen seizoen 15 nooit meer dan ~€16mln kunnen ophoesten, ver onder de nieuwe €54mln-gemiddelde op het topniveau. Bij 0,20 komt de rijkste club op ~€77mln uit, genoeg om ook de duurste toppers te kunnen kopen.

Fee-percentages (fee_cut ~10% bij transfer, `EXTEND_FEE_PCT` 7% bij contractverlenging, `PREPARED_TRANSFER_VALUE_PCT` 80% bij een voorbereide transfer) zijn ongewijzigd gebleven — die zijn percentages VAN `value()`, dus ze schalen vanzelf mee met de nieuwe curve zonder aparte aanpassing.

Het rating-plafond van je scouting komt NIET van reputatie of seizoen, maar van je **kantoorniveau** (§2b): `gen_candidates()` trekt elk seizoen 8 verse spelers binnen de band van dat niveau (`candidate_floor()`–`candidate_ceiling()`) via `WorldGen.make_candidate()`. De perks die vroeger de rating-caps ophoogden (Talentmagneet, Grote naam) en de shop-upgrades Kantoorrenovatie/Breed scoutingnetwerk tillen `candidate_ceiling()` nog een paar punten op, zodat ze relevant blijven.

### 4.3 Meta-progressie (legacy points en perks)

`scripts/meta.gd` (autoload `Meta`) houdt een tweede savebestand bij (`user://meta.json`) dat runs overleeft, los van `Game.state`. Elke afgeronde run — ook een game over — levert legacy points op (`Meta.award_run()`, aangeroepen vanuit `main.gd` in `show_gameover()`/`show_win()`), op basis van verdiende fees en aantal overleefde seizoenen. Die punten besteed je op het "Perks"-scherm (bereikbaar vanaf het startscherm) aan permanente upgrades in `Meta.PERKS`.

De perks vormen een boom van **3 takken × 4 rijen × 3 opties = 36 perks** (Kapitaal, Relaties, Vakwerk; structuur in `Meta.TREE`). Elke rij biedt drie keuzes; een rij ontgrendelt zodra je `Meta.TIER_REQ` (5) niveaus in de rij erboven hebt gekocht — binnen dezelfde tak. **Die eis wordt geclampt op wat een rij maximaal kán opleveren** (`Meta.tier_req_for()` = `min(TIER_REQ, tier_max_levels())`). Dat is geen detail: KAPITAAL rij 3 heeft samen maar **4** koopbare niveaus (kantoor 2 + reserves 1 + laatste_redmiddel 1), waardoor rij 4 van die tak met een vaste eis van 5 **permanent onbereikbaar** was. Nu volstaat het om die rij vol te kopen. Ter vergelijking: RELATIES rij 3 heeft 12 niveaus en VAKWERK rij 3 heeft er 6, dus daar blijft de eis gewoon 5. Door de clamp datagestuurd te maken kan dezelfde blokkade niet stilletjes terugkeren als er later een `max_level` wordt verlaagd. Rij 4 bevat de eindgame-perks: o.a. Waardestijging (hogere marktwaardes), Schuldpapier (vaste kostenkorting), Iconenstatus, Spelersfluisteraar (+vertrouwen per seizoen), Empathie (lagere vertrek-drempel), Koelbloedig (+blufkans), Voorwerk (minder startweerstand) en Geluksvogel (+kans op alle event-gokjes).

De economie is ontworpen voor **~240 uur goed spel tot 100%**. De volledige boom kost ~1,4 miljoen punten en de beloning per run is exponentieel in hoe ver je komt: een **gewonnen run levert exact 1% van de boom** op (`tree_total_cost() * (Meta.WIN_REWARD_PCT/100)` ≈ 14.100 punten), en elk seizoen mínder deelt dat door 1,45 (`Meta.REWARD_BASE`). Seizoen 10 halen ≈ 2.200 punten, seizoen 5 ≈ 340, seizoen 3 ≈ 160 (minimum 10). 100% vereist dus ~100 gewonnen runs van elk ~2,5 uur — vroeg doodgaan levert bijna niets op, ver komen loont exponentieel.

**Kampioensbonus:** een gewonnen run geeft bovenop de normale beloning in één klap **12% van je bestaande carrière-puntensaldo** erbij (`Meta.CHAMPION_BONUS_PCT`, berekend over het saldo vóór deze run se punten worden bijgeschreven — dus een bonus op je hele carrière, niet op jezelf), **met een ondergrens van 25% van de winbeloning zelf** (`Meta.CHAMPION_BONUS_MIN_PCT_OF_WIN`) — anders zou een vroege winst (nog weinig opgespaard) bijna geen bonus opleveren. `award_run()` neemt het maximum van beide berekeningen: bij een klein carrière-saldo wint de 25%-ondergrens, bij een groot saldo neemt de 12%-over-saldo-berekening het vanzelf over. Zichtbaar apart uitgelicht op het winscherm (`Meta.last_champion_bonus`). Dat maakt latere winsten steeds waardevoller naarmate je carrière-saldo groeit, zonder dat een vroege winst zich onbeloond voelt.

**Mega-boost:** een gewonnen run zet ook een eenmalige vlag (`Meta.state.pending_boost`, via `Meta.has_pending_boost()`/`consume_pending_boost()`) die **alléén je allereerstvolgende nieuwe run** een klapper geeft — geen permanente perk, puur momentum: dubbel startkapitaal, +25 startreputatie, +1 startgunst en +2 extra scoutpunten **per seizoen, de hele run** (`Game.new_run()`, constanten `BOOST_*`). Die laatste loopt via `state.bonus_scout_points` — hetzelfde veld dat events met `scout_points_permanent` vullen — en komt daardoor automatisch terug in `scout_points_per_season()` bij elke seizoensreset. Zichtbaar als gele banner op het startscherm zolang de boost klaarstaat; wordt pas verbruikt zodra je daadwerkelijk op "NIEUWE RUN" klikt (niet bij "Doorgaan met vorige run").

> **Let op bij `new_run()`:** `scout_points_per_season()` leest `state` (voor `bonus_scout_points` én `has_shop()`). Binnen de `state = {…}`-dictliteral verwijst `state` nog naar de **vorige** run, dus `scout_points` wordt daar op 0 gezet en pas ná de toewijzing berekend. Zet nieuwe startwaarden die van andere state-velden afhangen dus altijd ná de dict, niet erin.

**Hall of Fame:** puur cosmetisch, geen mechanisch effect. Elke gewonnen run voegt een regel toe (`Meta.record_win()`) met je meest waardevolle cliënt op het moment van winnen (`_best_client_name()` in `main.gd`, hoogste `value()` in je stal), het eindbedrag aan fees en het seizoen. De top 10 (gesorteerd op fees, `Meta.HALL_OF_FAME_MAX`) staat op het startscherm. Het seizoen wordt **niet getoond**: je komt hier alleen in via een gewonnen run, en winnen kan pas als `season > MAX_SEASONS`, waarna `mini(season, MAX_SEASONS)` altijd 15 oplevert. Het veld blijft wel opgeslagen, zodat oude entries geldig blijven als de winconditie ooit verandert.

### 4.4 Prestige & Erfenis-perks

Op het perkscherm zit, naast de reguliere boom, een aparte sectie **✦ Erfenis-perks**. Deze koop je NIET met legacy points maar met **Prestige-sterren** (`Meta.state.prestige_stars`) — een aparte, zeldzame munt die je alleen krijgt door te **prestigen** (`Meta.prestige_run()`): je hele perkboom reset naar 0, **zonder puntenrefund** (in tegenstelling tot de gewone reset-knop, die je bestede punten wél teruggeeft), in ruil voor 1 Prestige-ster. Tweestaps-bevestiging net als bij de gewone reset (`confirm_prestige` in `main.gd`). **Prestigen kan pas vanaf 50% boomvoortgang** (`Meta.can_prestige()`, drempel `Meta.PRESTIGE_MIN_TREE_PROGRESS` op `tree_progress()`) — bij een paar losse niveaus zou de "opoffering" bijna gratis zijn, dus moet er eerst echt iets substantieels op het spel staan. Zit je onder de drempel, dan toont het scherm hoe ver je nog moet.

Het hele punt van Erfenis-perks (`Meta.LEGACY_PERKS`) is dat ze **onbereikbaar zijn zonder ooit te prestigen**, hoeveel legacy points je ook opspaart:

| Perk | Kosten | Effect |
|---|---|---|
| Kroonjuweel-netwerk | 1 ster | Begin elke run met een startcliënt i.p.v. een lege stal |
| Kantoorvoorsprong | 2 sterren | Begin elke run standaard op kantoorniveau 2 i.p.v. 1 |
| Eeuwige gunst | 3 sterren | Begin elke run met +2 extra gunsten |

Eenmaal gekocht blijft een Erfenis-perk voor altijd actief (`Meta.has_legacy_perk()`, toegepast in `Game.new_run()`) — ze verdwijnen niet bij een volgende prestige-reset. Prestigen is dus een investeringskeuze: je huidige boom opofferen voor toegang tot permanente bonussen die de gewone boom nooit kan bieden.

Wil je van gedachten veranderen, dan kan dat via een aparte **"Reset Erfenis-perks"**-knop (`Meta.reset_legacy_perks()`/`spent_stars()`, tweestaps-bevestiging net als de andere twee reset-knoppen): net als bij de gewone perk-reset krijg je de volledige investering (alle vastzittende Prestige-sterren) terug, zodat herspeccen geen straf is. Dit is losgekoppeld van de gewone "Reset alle perks"-knop, die alleen `Meta.PERKS` (de reguliere boom + de vier ★ OVERPOWERED-extra's) raakt — géén van beide bestaande reset-knoppen raakte voorheen de Erfenis-perks, vandaar deze aparte derde knop.

Rechtsboven op het perkscherm zit de **∞-upgrade**: een klein vierkantje met een vaste prijs (`Meta.INF_COST`, 200 punten — stijgt nooit) dat oneindig vaak gekocht kan worden en per koop +0,1% oplevert op álle verdiende legacy points (`Meta.inf_multiplier()`, toegepast in `award_run()`). Een goedkope, eindeloze uitlaatklep voor restpunten die op de heel lange termijn optelt; de perk-reset raakt hem niet aan. Het perkscherm toont je voortgang ("Boom voltooid: X%"). Er is ook een **reset-knop** (tweestaps-bevestiging) die alle perks naar 0 zet en álle bestede punten teruggeeft, zodat je vrij kunt herspeccen.

Daarnaast bestaat een **developer-only puntenreset** die het puntensaldo hard naar 0 zet (zonder terugbetaling, en zonder de perks te resetten) — bedoeld om de economie tijdens ontwikkeling te testen. Toegang: tik 7 keer op de kleine "v1.0"-tekst onderaan het startscherm (`_on_dev_tap()` in `main.gd`), voer het wachtwoord in (`DEV_PASSWORD`, bovenin `main.gd`) en bevestig op het developer-scherm. Dit is geen echte beveiliging — de broncode is leesbaar — maar voorkomt dat spelers er per ongeluk tegenaan lopen. Wijzig `DEV_PASSWORD` naar je eigen wachtwoord voordat je het spel deelt.

Hetzelfde developer-scherm heeft ook een knop om **`Meta.state.has_won_ever`** te forceren aan/uit (`dev_toggle_won_ever()`) — zo test je het geheime 6e kantoorniveau (De Kampioenssuite, §2b) zonder een volledige 15-seizoenen-run te hoeven winnen. Let op: die vlag wordt alléén gezet op het MOMENT dat je wint, niet met terugwerkende kracht — als je vóór het bestaan van deze feature al eens had gewonnen, blijft niveau 6 dus vergrendeld tot je opnieuw wint (of de vlag hier handmatig forceert).

Daarnaast zijn er **vier ★ OVERPOWERED extra's** buiten de boom (tellen niet mee voor de 100%): **Superprovisie** (alle transfer-inkomsten ×2, ~417k), **IJzeren contracten** (cliënten vertrekken nooit meer en zijn niet te kapen, ~417k), **Helderziend** (alle TD-persoonlijkheden direct bekend én elk gesprek start Ontvankelijk, ~417k) en **Vaste kern** (je bent de uitzondering op het verplichte seizoensontslag — stalbeheer wordt overgeslagen, ~250k / ±30% van de boom). Pure luxe voor wie ver voorbij de boom grindt.

De perks grijpen op vrijwel elk systeem in: startgeld/rep/gunsten/startvertrouwen (`new_run()`, `_make_client()`), kantoorkosten, rente, gunstenfabriek en schandaalverval (`end_of_season()`), tekenkans (`sign_chance()`), kaapkans (`poach_chance()`), scoutdiepte en kandidatenlijst (`scout()`, `gen_candidates()`), scouting-plafond (`candidate_ceiling()`), fee en tekengeld (`fee_cut()`, `tekengeld_mult()`), stal-cap (`client_cap()`), een eenmalige bailout (`try_bailout()`) en het hele onderhandelspel (extra ronde, flow-multiplier, wegloopdemping, clausulekosten, aftastkosten — gezet in `_start_nego()` in `main.gd`). Nieuwe perks toevoegen = een entry aan `Meta.PERKS` toevoegen, in een rij van `Meta.TREE` hangen en de bonus ergens toepassen (gebruik `fmt` voor de weergave: `int`, `money` of `pct10`).

### 4.5 Richting het volledige GDD

Logische volgorde, oplopend in werk:

1. **Meer events** (zie 4.1) — grootste kwaliteitswinst per uur werk.
2. **Archetypes** — voeg `state.archetype` toe in `new_run()`, laat het startscherm laten kiezen, en check het archetype in `sign_chance()`, `Negotiation.tactics()` en event-conditions. De datastructuur is er al op voorbereid.
3. **Meta-netwerk uitbreiden** — laat `world_gen` bekende gezichten (oud-cliënten, rivalen) terugbrengen op basis van `Meta.state`, bovenop de bestaande legacy points/perks (zie 4.3).
4. **Rivaal-makelaars** — genereer 3 rivalen in `world_gen` en geef ze een beurt in `end_of_season()` (trekken aan cliënten met laag vertrouwen).
5. **Deadline Day-timer en juice** — pas als de kern bewezen verslavend is.

De enige vraag die deze MVP moet beantwoorden: **wil je na een game-over meteen opnieuw beginnen?** Zo nee, eerst events en balans verbeteren; geen enkel meta-systeem repareert een saaie kernloop.

### 4.6 Instellingen (⚙)

Bereikbaar via het startscherm (`show_settings()` in `main.gd`). Alle instellingen leven in `Meta.state.settings` (dus in `meta.json`, runs-overstijgend) met defaults in `Meta.SETTING_DEFAULTS`; lezen via `Meta.setting(key)`, wisselen via `Meta.toggle_setting(key)`. Bewust géén nep-schakelaars: elke toggle grijpt echt ergens in — de enige uitzondering is de taalkeuze, die als placeholder in de UI staat gemarkeerd.

| Instelling | Key | Wat het doet |
|---|---|---|
| Taal | `lang` | Nederlands, English, Français, Español, Deutsch of العربية, live omschakelbaar (ook de RTL-layout). Zie §4.7. |
| Confetti & animaties | `confetti` | Gate in `_confetti()` én `_small_negative_puff()`, dus zowel de combo-uitbarsting en tekening-confetti als het rode puffje bij een afwijzing. |
| Kantoor-achtergrond | `office_bg` | Gate in `_update_office_background()`: uit = effen donkere achtergrond i.p.v. beeld/sfeerkleur per niveau (rustiger te lezen). Wordt direct toegepast door `_bg_level` te invalideren. |
| Spelerkaart onderaan | `player_panel` | Gate in `_show_player_info()`: uit = het onderste paneel blijft verborgen, wat ~156px schermruimte teruggeeft bij events/minigames. |

Daarnaast staan hier de **destructieve acties**, allemaal met tweestaps-bevestiging via één `settings_confirm`-string (i.p.v. een aparte bool per actie):

- **Reset perkboom** — `Meta.reset_perks()`, volledige puntenrefund. Verhuisd van het perkscherm hierheen; dat scherm is al lang en dit is geen aankoop-actie.
- **Reset Erfenis-perks** — `Meta.reset_legacy_perks()`, volledige sterrenrefund. Idem verhuisd.
- **Verwijder huidige run** — `Game.delete_save()`; legacy points en perks blijven staan.
- **Alles wissen** — `Meta.wipe_everything()` + `Game.delete_save()`. Wist punten, perks, Erfenis-perks, sterren, ∞-upgrade, carrièrestats, Hall of Fame én de niveau-6-ontgrendeling. **Instellingen blijven expres staan** — die zijn geen progressie, en het is irritant als je taal-/animatiekeuzes verdwijnen omdat je opnieuw wilt beginnen.

**Prestige** is bewust NIET verhuisd: dat is een progressie-keuze (boom opofferen voor een ster), geen instelling, en hoort dus op het perkscherm.

### 4.7 Meertaligheid (NL / EN / FR / ES / DE / AR)

`scripts/i18n.gd` (autoload `I18n`) bevat de vertaallaag. **De NEDERLANDSE string is zelf de sleutel**: in de code staat `T("Naar events →")` en de tabel mapt die naar de doeltaal. Waarom zo, en niet met abstracte sleutels als `EVENTS_NEXT`:

* de broncode blijft leesbaar — je ziet meteen wat er op het scherm komt;
* een ontbrekende vertaling valt automatisch terug op het Nederlands, i.p.v. een lege string of een sleutelnaam te tonen;
* er is geen aparte sleutel-administratie die uit de pas kan lopen.

`I18n` staat in `project.godot` **ná** `Meta` geregistreerd, zodat de opgeslagen taalkeuze bij `_ready()` al beschikbaar is. In `main.gd` staat een korte alias `T()`; andere scripts roepen `I18n.T()` aan.

**Regel 1: vertaal ALTIJD vóór het interpoleren.**

```gdscript
lbl(T("Seizoen %d/%d") % [a, b])     # goed
lbl(T("Seizoen %d/%d" % [a, b]))     # FOUT — zoekt een al ingevulde string op en mist dus altijd
```

Dit is de belangrijkste valkuil: de tweede vorm crasht niet, hij blijft gewoon stil Nederlands. De placeholders (`%s`, `%d`) moeten in de vertaling in dezelfde ORDE staan, want GDScript's `%`-operator kent geen genummerde argumenten.

**Regel 2: pluraliseer met HELE woorden, niet met een achtervoegsel.** `"%d ster%s"` met `"" if n == 1 else "ren"` werkt alleen in het Nederlands — in het Engels wordt dat `"starren"`. Gebruik daarom `_stars_word(n)` / `_rounds_word(n)`, die `T("ster")` of `T("sterren")` teruggeven. Dit patroon zat op drie plekken en is nu overal weg; als je een nieuwe teller toevoegt, doe het meteen goed.

**Regel 3: data-dicts lokaliseren op de LEESSITE, niet in de dict.** `SHOP_UPGRADES`, `PERKS`, `OFFICE_LEVELS` en `LEGACY_PERKS` zijn `const` — die kunnen op parse-time geen `T()` aanroepen. Daarom zijn er accessors: `Game.shop_name()/shop_desc()`, `Game.office_name()`, `Meta.perk_name()/perk_desc()/legacy_perk_name()/legacy_perk_desc()`. De UI leest hierlangs. Dat is ook waarom ~150 strings maar 9 code-edits kostten. Let op: `office_name()` dekt alleen het HUIDIGE niveau — leest je ergens `OFFICE_LEVELS[i].name` rechtstreeks (zoals de upgrade-preview doet), dan moet die leessite zelf gewrapt worden.

**Regel 4: één `T()` per regel is niet genoeg.** De grote omzetting is met een regex gedaan die per regel het EERSTE string-literaal wrapt. Drie soorten regels ontsnappen daaraan, en dat waren precies de plekken waar later nog Nederlands opdook:

* **ternaries** — `btn(T("Naar scouting →") if x else "Naar stalbeheer →")`: alleen de eerste tak was gewrapt;
* **opgebouwde strings** — `var sub := "%s, %d jr" % [...]` gevolgd door `sub += " · waarde %s" % ...`: dat zijn geen `lbl()`/`btn()`-aanroepen, dus de regex zag ze niet;
* **strings uit een ander bestand** — de nieuwsregels komen uit `game.gd`'s `_gen_news()`;
* **directe `.text =`-toewijzingen** — een node die buiten `lbl()`/`btn()` om zijn tekst krijgt. Dit is de gemeenste: een label kan bij opbouw correct via `lbl(T(...))` gaan en daarna door een callback met een KALE literal worden overschreven. Zo bleef de bank-slider "Storten: €9.000" tonen terwijl het label eronder wél Engels begon — `_on_bank_slider_changed()` zette hem elke beweging terug naar Nederlands.

Zoek ze met:

```bash
grep -n 'T("[^"]*") if .* else "' scripts/main.gd     # halve ternary
grep -n 'var sub := "\|sub += "' scripts/main.gd      # opgebouwde string
grep -n '\.text = "' scripts/main.gd                  # directe toewijzing
```

Symbolen (`"🏠"`, `"→"`) hoeven niet gewrapt; de rest wel.

**Noot over het nieuws.** `_gen_news()` interpoleert de clubnaam en bewaart het resultaat in `state.news` (dus in de save). Vertalen gebeurt daarom bij GENERATIE, niet bij weergave. Gevolg: schakel je midden in een run van taal, dan blijft die ene nieuwsregel in de oude taal staan tot het volgende seizoen. Bewust geaccepteerd — het alternatief is een sleutel + argumenten in de save opslaan, wat het saveformaat verandert voor één regel tekst.

**`events_db.gd` blijft volledig onaangeroerd.** `get_events()` is een `static func`, en autoload-toegang vanuit een static context is in GDScript riskant. In plaats daarvan vertaalt `main.gd` op de **zes weergavesites**: `ev.title`, `ev.text`, `opt.label` en de drie uitkomst-fallbacks (`txt` / `success_txt` / `fail_txt`). Zes edits dekken zo alle 424 event-strings. Let op dat `{client}` en `{amount}` in elke vertaling bewaard blijven — die worden ná het vertalen vervangen.

**Niet elke taalverschil is een vertaling.** `anagram_hunt.gd`'s `WORD_BANK` bevat woorden die gehusseld worden; een gehusseld Nederlands woord is onontcijferbaar in een Engels spel. Daarom geeft `I18n.word_bank()` per taal een eigen lijst met dezelfde thematiek en vergelijkbare woordlengtes — spelinhoud, niet tekst. Hetzelfde geldt voor `club_names()`. Alle niet-Nederlandse woordenlijsten zijn bewust **accentloos** (`RESERVE`, `ENTRAINEUR`, `PENALITE`, `PRAEMIE`): de anagramjacht husselt losse letters, en een `É`, `Ñ` of `ß` als apart tegeltje is zowel lastig te typen als verwarrend. Bij Duits betekent dat woorden kiezen die zonder umlaut kunnen, of de `AE`/`OE`/`UE`-schrijfwijze.

**Een taal toevoegen.** Schrijf een `_table_xx()` naar het model van `_table_en()`, voeg de taalcode toe aan `I18n.LANGS`, registreer de tabel in `_ready()`, en breid `word_bank()`/`club_names()` uit. Er is geen code-wijziging nodig buiten `i18n.gd`; het taalmenu in `show_settings()` loopt over `I18n.LANGS` en pikt de nieuwe taal automatisch op.

**RTL (Arabisch).** `I18n.RTL_LANGS` markeert talen die van rechts naar links lopen; `I18n.is_rtl()` vraagt het op. Het echte werk gebeurt in één functie: `_apply_layout_direction()` in `main.gd`, aangeroepen vanuit `_ready()` en `_set_lang()`. Die zet `layout_direction` op de **root** `Control`, en omdat elke Control dat standaard erft, spiegelt Godot vanzelf de ordening in `HBoxContainer`/`GridContainer` en de tekstuitlijning van Labels en Buttons. Drie dingen doet Godot NIET:

* **ankers spiegelen** — die zijn absoluut. De twee zwevende knoppen (🏠 en de ∞-knop) worden daarom met de hand omgeklapt van `PRESET_*_RIGHT` naar `PRESET_*_LEFT` met omgekeerde offsets. Hun geometrie staat alléén in `_apply_layout_direction()`, niet ook in `_ready()` — anders drift het uit elkaar.
* **pijltekens spiegelen** — `→` blijft `→` in een RTL-regel. De pijlen zitten in de vertaaltabel, dus de Arabische waarden gebruiken `←` (en `← Terug` wordt `→ رجوع`). Controleerbaar: elke sleutel met een pijl moet in `_table_ar()` de tegenovergestelde pijl hebben.
* **het anagram-toetsenbord vullen** — dat was hardgecodeerd `range(65, 91)`, oftewel A–Z. Nu komt het alfabet uit `I18n.keyboard_letters()`.

De `horizontal_alignment`-instellingen in `main.gd` zijn allemaal `CENTER` en hoeven dus niets: gecentreerd blijft gecentreerd.

**Het anagram-toetsenbord moet elk antwoord kunnen typen.** Dat is de reden dat de Latijnse woordenlijsten accentloos zijn, en bij Arabisch kostte het een extra ronde: de eerste versie van `KEYBOARD_AR` had de 28 basisletters, maar 18 van de 44 woorden eindigen op `ة` (taa marbuta) en één bevat `ء` (hamza). Die twee staan nu op het toetsenbord (30 letters, bij 5 kolommen precies 6 rijen). De alif-varianten `أ إ آ` en de `ى` blijven er buiten, en de woordenlijst vermijdt ze daarom ook. Te controleren met een verzamelingsverschil: elke letter die in `WORD_BANK_xx` voorkomt moet in het bijbehorende `KEYBOARD_*` zitten.

Bij een nieuwe tabel zijn drie mechanische checks de moeite waard, want geen ervan valt op tijdens spelen:

1. **sleutelset identiek** aan `_table_en()` — anders val je stil terug op Nederlands;
2. **placeholders in dezelfde soort én ORDE** (`%s`, `%d`, `{client}`, `{amount}`, `\n`), want GDScript's `%`-operator kent geen genummerde argumenten: een omgewisselde `%s`/`%d` is een harde crash, geen schoonheidsfoutje;
3. **stringsyntaxis**: exact vier niet-ge-escapete `"` per regel. Een losse `"` in een vertaling breekt het hele bestand bij het parsen. Handige vergelijking: het escape-profiel van de nieuwe tabel moet gelijk zijn aan dat van `_table_en()` (nu 12× `\n`, 48× `\"`) — alle vier de huidige tabellen komen daar precies op uit.

**Naamvallen in het Duits.** Een paar waarden worden in een frame geïnterpoleerd dat de naamval bepaalt, dus staan ze niet in de nominatief: `d["een rivaal"] = "einem Rivalen"` (datief, want `von %s abgeworben`) en `d["EEN CLIËNT"] = "EINEN KLIENTEN"` (accusatief, want `DU VERLIERST %s`). Wie zulke sleutels later hergebruikt in een ánder frame krijgt een grammaticale fout die geen enkele check opmerkt — de tabel is per definitie contextloos.

**Controleren of je niets mist**, na het toevoegen van strings:

```bash
grep -oh 'T("[^"]*")' scripts/*.gd | sed 's/^T("//;s/")$//' | sort -u > /tmp/used.txt
grep -o '	d\[".*"\] =' scripts/i18n.gd | sed 's/^\td\["//;s/"\] =$//' | sort -u > /tmp/have.txt
comm -23 /tmp/used.txt /tmp/have.txt | grep '[a-zA-Z]'
```

Wat overblijft zijn puur structurele sleutels (`"%s"`, `"%s%s"`, witruimte) — die vallen correct identiek terug. Let op: een sleutel met een `]` erin (zoals de header met `[color=…]`) geeft een vals-negatief in die tweede grep.

---

## 5. Exporteren naar Android (kort)

1. In Godot: **Editor → Manage Export Templates → Download and Install**.
2. Installeer Android Studio (voor de SDK) en OpenJDK 17; wijs in **Editor → Editor Settings → Export → Android** de SDK-paden aan.
3. **Project → Export → Add → Android**, vul een unieke package name in (bijv. `com.jouwnaam.makelaar`), maak een debug keystore aan (Godot kan dit zelf).
4. **Export Project** → APK op je telefoon zetten, of gebruik "One-click deploy" met USB-debugging aan.

De volledige, actuele stappen staan in de officiële docs: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html — die zijn leidend, want de Android-toolchain verandert regelmatig. Voor iOS heb je een Mac met Xcode nodig; bewaar dat voor later.

---

## 6. Bekende versimpelingen (bewust, voor de MVP)

- Geen archetypes (zie roadmap). Rivaal-makelaars bestaan alleen als namen met een kaapkans (`poach_chance()` in `game.gd`), niet als volwaardige tegenspelers. Meta-progressie (legacy points/perks, §4.3) is er wel, maar zonder terugkerende personages.
- De relatie met clubs (`relation`) wordt bijgehouden maar nog weinig gebruikt — haak er gerust events op in.
- Contractverlenging bij afloop gaat automatisch; in de volledige game is dat een onderhandeling.
- Seizoensprestaties zijn een simpele dobbelworp (1–10); het GDD voorziet een lichte competitiesimulatie.
- Opslaan gebeurt alleen aan het eind van een seizoen; sluit je de app midden in een seizoen, dan herstart dat seizoen.

Veel succes — en onthoud de MVP-vraag: drukt de tester na "GAME OVER" meteen op "Nieuwe run"?
