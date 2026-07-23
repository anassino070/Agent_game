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

Elke run bestaat uit 15 seizoenen. De balans is bewust hard: zonder perks is een run uitspelen bijna onmogelijk — de bedoeling is dat je de eerste ~20 runs vooral legacy points verzamelt en langzaam sterker wordt (zie §4.3). Elk seizoen doorloopt zes fasen:

1. **Voorbereiding** — overzicht van je stal, geld, reputatie en het nieuws (nieuws heeft echte effecten: clubbudgetten veranderen).
2. **Stalbeheer** — heb je 2 of meer cliënten, dan móét je er minstens één wegsturen. Dit is een **multi-select**: je tikt op zoveel cliënten als je wilt om ze te markeren (kaartje kleurt rood, knop wisselt naar "✔ Blijft toch"), zolang er minstens 1 overblijft — de "Bevestig"-knop onderaan toont hoeveel je wegstuurt en hoeveel er overblijven, en is uitgeschakeld zolang niemand is geselecteerd (`show_release()`/`_toggle_release()`/`_confirm_release()` in `main.gd`). Handig om in één keer ruimte te maken voor bijvoorbeeld een kantoorupgrade. De rest van je stal verliest 2 vertrouwen per weggestuurde cliënt (stapelt dus bij meerdere ontslagen). Elke cliënt is hier een kaartje (`_stat_card()`, gedeeld met de scoutingkaartjes) met dezelfde **rating/potentieel-badges** rechts (potentieel exact bekend zodra iemand in je stal zit) en vertrouwen/waarde in de subregel. Diezelfde badges staan ook in het permanente infobalkje onderaan bij events/minigames (`_show_player_info()`), dus je herkent overal dezelfde stat-blokjes.
3. **Scouting** — 3 scoutingpunten per seizoen. Elk seizoen krijg je een **verse trekking van 8 spelers** (`gen_candidates()` in `game.gd`, aantal via `candidate_count()` = `CANDIDATES_PER_SEASON` 8 + Extra kandidaat-perk) — van amateur tot het beste dat je kantoor kan aantrekken. Een korte, overzichtelijke lijst i.p.v. eindeloos scrollen. **Je kantoorniveau (§2b) bepaalt de rating-band** waaruit ze getrokken worden; **reputatie bepaalt niet meer wíe je ziet, maar alléén nog of ze bij je tekenen** (`sign_chance()`, als tekenkans-% op elke regel). Zo kun je op niveau 5 een rating-86 fenomeen zien staan, maar hem zonder naam alsnog niet strikken. Je kunt de lijst sorteren op **rating** of **leeftijd** (tik nogmaals voor omgekeerde richting; `_sorted_candidates()`). Elke speler is een kaartje (`_candidate_card()`) met twee gekleurde badges rechts: **potentieel** in een groene rechthoek rechtsboven, **rating** in een blauw vierkant rechtsonder (`_stat_badge()`). Onder de info zitten compacte knopjes **Scout** / **Benader** — heb je iemand dit seizoen al benaderd (en afgewezen gekregen), dan verdwijnen béíde knoppen (er valt niets meer te doen tot volgend seizoen), en zie je "al benaderd dit seizoen". Potentieel is voor scoutingdoelen een geschatte band (bijv. 68–82); zit iemand eenmaal in je stal, dan ken je zijn **exacte** potentieel (één getal, ook in de speler-tooltip/`_player_tooltip()`). De 8 zijn geen persistente wereld: ongetekende kandidaten verdwijnen aan het einde van het seizoen (`_clear_old_candidates()` ruimt ze op), een getekende wordt cliënt en blijft. De getoonde potentieel-band is gecentreerd op een publieke schátting die er zelf flink naast kan zitten — een "70–90"-belofte kan na scouten een 72-dud blijken. Scouten versmalt de band én trekt de schatting richting de waarheid, en een gescoute speler tekent bovendien makkelijker bij je (+5% tekenkans per scout, max +10% — hij voelt zich serieus genomen). Een geslaagde tekening kleurt de melding groen met een confetti-uitbarsting (`_confetti()`); een afwijzing geeft een klein rood puffje (`_small_negative_puff()`). Eén benaderpoging per speler per seizoen: wijst hij je af, dan is die kandidaat weg (verse trekking volgend seizoen).
4. **Events** — 4 à 6 encounters met keuzes (`gen_events()` in `game.gd`). Kansen staan op de knoppen; risicovolle opties hebben grotere uitkomsten. Sommige opties vereisen geld of een gunst. Tien events starten in plaats daarvan een eigen minigame (zie 4.2). Met 70 events in de pool en gemiddeld 5 per seizoen kan de pool tegen het einde van een lange run uitgeput raken (`used_events`) — vandaar dat meer events de belangrijkste groeirichting blijft (zie 4.1).
5. **Transferwindow** — per cliënt melden zich 0–2 geïnteresseerde clubs. Onderhandelen = de weerstand van de TD naar 0 spelen binnen 5 rondes, en de vólgorde van je zetten is de kern:
   - **Stemming** (Geïrriteerd → Zakelijk → Ontvankelijk): charmeren en clausules bouwen de stemming op; bluffen heeft haar nodig (25/50/75% kans per stemming) en "Feiten & cijfers" is juist het sterkst bij Zakelijk. Deadline-druk verslechtert de stemming áltijd — en bij een geïrriteerde TD riskeer je dat hij wegloopt. Druk is dus een finisher, geen opener.
   - **Persoonlijkheid** (verborgen; werkt vooral op kansen, mild op weerstand): IJdel (charme slaagt altijd en iets sterker), Koppig (+5 weerstand, stemming zakt nooit onder Zakelijk), Nerveus (druk +20% slaagkans, maar hij loopt sneller weg), Rekenmeester (+8 weerstand, feiten +8% kans en 1,15× effect, charme doet niets, ongevoelig voor bluf en druk (-15%/-10% kans) — alleen cijfers overtuigen hem). **Zolang je het type niet kent, blijft de exacte slaagkans op de knoppen verborgen** ("kans ?"); je ziet wél de weerstandswinst. Je leert het type op twee manieren: via **"Aftasten"** (kost twee rondes) óf door een **type-combo** af te ronden — een geslaagde druk→druk tegen een (nog onbekende) nerveuze TD onthult hem meteen, net als aftasten. Die kennis blijft de hele run per club bewaard.
   - **Flow**: twee successen op rij geven +50% effect op je volgende zet; een mislukking reset de reeks.
   - **Combo's** (opeenvolgende successen; elk maximaal één keer per gesprek): De Goede Cop (charme → charme → feiten, +6), De Slotklap (charme → feiten → charme → druk, +14), De Boekhouder (feiten → feiten tegen een Rekenmeester, +8), Het Ultimatum (clausule → clausule → druk, +10 — maar je fee is dan al 4% gezakt), De Nerveuze Val (druk → druk tegen een Nerveus, +16 — het hoogste, maar risico-op-risico), Slow Play (clausule → charme → feiten → bluf, +12 — de veilige lange route). **Type-gebonden combo's (Boekhouder, Nerveuze Val) werken en lichten op zodra de TD daadwerkelijk dat type ís — je hoeft het niet vooraf te weten, en ze afronden ONthult het type** (`_check_combos()`/`combo_progress()` gaten nu op `pers`, niet op `pers_known`). Een zet die door de persoonlijkheid volledig wordt geneutraliseerd — **charme tegen een Rekenmeester** — telt níét mee voor een combo (hij doet immers niets), via de `no_combo`-vlag in `tactics()`. Elke combo toont zijn patroon als losse, individueel gekleurde stappen (`_show_combo_pattern_row()` in `main.gd`) i.p.v. één vlakke statuskleur: stap 1 is altijd **geel**, de laatste stap altijd **groen**, en de stappen ertussen worden van achteren naar voren ingevuld met een vast palet (`COMBO_STEP_FROM_END`) — bij lengte 3 dus geel→rood→groen, bij lengte 4 geel→blauw→rood→groen. Stappen die je nog niet hebt bereikt blijven grijs; het algoritme (`_combo_step_color()`) is lengte-onafhankelijk en werkt dus automatisch ook voor eventuele toekomstige, langere combo's. Bij het voltooien van een combo verschijnt een korte confetti-uitbarsting met de combonaam.

   Weglopen kan zonder schade, maar elke club biedt maar één kans per window: ketst het af, dan is die deal dit seizoen weg. Contract verlengen kan alleen als een cliënt in zijn laatste contractjaar zit (en maximaal één keer per window). Elk 5e seizoen is het Deadline Day: TD's beginnen met lagere weerstand.
6. **Afsluiting** — kantoorkosten (×1,8 per seizoen: €10k in seizoen 1, €33k in seizoen 3, €105k in seizoen 5, €612k in seizoen 8 — de kosten zijn de échte klok van de run), clubbudgetten groeien +12%/seizoen (`CLUB_BUDGET_GROWTH` in `game.gd` — zonder dit lopen ze bevroren op hun seizoen-1-waarde vast terwijl spelerswaarde via ontwikkeling wél doorgroeit, met een harde muur van "geen enkele club kan het betalen" tot gevolg tegen seizoen 10-12), De Bank keert rijpe stortingen uit (zie hieronder), spelerontwikkeling (spelers ≤26 groeien richting hun potentieel — ~30% sneller dan voorheen, `int(round(randi(0..3) * 1,3))`), vertrouwensdrift, contractafloop, en de fail-checks. Een **clubloze** speler heeft geen aflopend contract: het contract tikt alleen af (en levert tekengeld op bij verlenging) zolang hij bij een club zit. Daarna volgt **🪙 De Shop** voor je verder gaat naar het volgende seizoen.

   Heeft een cliënt geen interesse van clubs, dan legt het transferwindow uit waaróm: als geen enkele club hem kan betalen, staat dat er expliciet bij staan (met de waarde van de speler en het budget van de rijkste club), in plaats van gewoon "geen interesse" te melden alsof het toeval was (`Game.any_club_can_afford()`).

### 2b. Het kantoor (niveaus 1–5)

Je **kantoorniveau** is de centrale progressie-as van een run: het bepaalt de rating-band waaruit je 8 scoutingkandidaten worden getrokken (zie fase 3). Je begint op niveau 1 en kunt op het **voorbereidingsscherm** upgraden voor een vast bedrag van **€100.000 × (doelniveau)²** — dus €400k → €900k → €1,6mln → €2,5mln. Bewust géén economie-herbalans: niveau 5 is eindgame-luxe die je alleen in een topseizoen haalt. De hele achtergrond-art wisselt per niveau (`_update_office_background()` in `main.gd` laadt `res://art/office_<niveau>.png` als die bestaat, anders een effen sfeerkleur; een halfdoorzichtige scrim houdt de tekst altijd leesbaar). De vijf niveaus (`Game.OFFICE_LEVELS`), met hun gemiddelde spelersniveau en sfeer:

| Niv. | Naam | Gem. rating | Band (rating) | Sfeer/beeld |
|---|---|---|---|---|
| 1 | Boven de Snackbar | 45 | 33–57 | Zolderkamertje boven een snackbar, patatneon |
| 2 | De Portacabin | 57 | 45–69 | Bouwkeet op een bedrijventerrein, tl-licht |
| 3 | Het Grachtenpand | 69 | 57–81 | Klassiek Amsterdams grachtenpand, hout |
| 4 | De Glazen Toren | 78 | 68–88 | Zuidas-wolkenkrabber, glas en skyline |
| 5 | Monaco | 86 | 78–94 | Penthouse/jacht in de haven van Monaco, goud |

Het effectieve plafond (`candidate_ceiling()`) is de band-bovengrens plus de meta-perks die vroeger de rating-cap verhoogden (Talentmagneet, Grote naam) en de shop-upgrades Kantoorrenovatie (+3) en Breed scoutingnetwerk (+4) — zo blijven die relevant nu reputatie het plafond niet meer bepaalt. Het aantal kandidaten is 20 + Extra kandidaat-perk (`candidate_count()`).

**Fail states:** saldo onder €0 (failliet), schandaalmeter op 100 (licentie kwijt), of een lege stal (alle cliënten weg). Vertrekkans is een DOORLOPENDE curve (`leave_chance()` in `game.gd`, geen harde knip meer bij één drempel): onder 60 vertrouwen loopt het risico lineair op tot max 85% bij 0. Rivaal-makelaars kunnen daarnaast cliënten wegkapen (`poach_chance()`) — hoe hoger de rating en hoe lager het vertrouwen, hoe groter dat risico (de vertrouwens-invloed is onlangs verzwaard).

**Reputatie en vertrouwen zijn bewust lastiger te winnen dan te verliezen.** In `game.gd`: `REP_GAIN_MULT`/`TRUST_GAIN_MULT` (beide 0,6) dempen alleen POSITIEVE rep/vertrouwen-effecten; negatieve tellen voluit. Reputatie zakt bovendien elk seizoen terug richting een neutrale basis van 50 als je erboven zit (`REP_DECAY_ABOVE_BASELINE`) — anders groei je één keer naar 100 en blijft het daar voor de rest van de run hangen zonder dat je nog iets hoeft te doen. **Het gewicht van vertrouwen groeit over de seizoenen heen** (`trust_gain_mult()`): in seizoen 1 valt er nog weinig op te bouwen (demping 0,6), maar elke +0,09/seizoen (`TRUST_GAIN_PER_SEASON`, tot een plafond `TRUST_GAIN_MAX` = 1,6 rond seizoen 12) telt een positieve vertrouwensmutatie zwaarder mee — vertrouwen wordt zo een investering die zich over de run opbouwt. Álle vijf positieve vertrouwenstoekenningen lopen hierlangs (event-`trust`/`all_trust`, transfer +8, verlenging +5, voorbereide transfer +6); negatieve drift blijft voluit tellen.

**De Bank** (`Game.bank_deposit()`, voorbereidingsscherm) — stort een zelfgekozen bedrag; na 2 seizoenen (`BANK_MATURITY_SEASONS`) krijg je het verdubbeld terug (`BANK_MULTIPLIER`). Geen risico, wel je geld 2 seizoenen lang vastgezet — een gegarandeerd maar traag tegenwicht tegen de exponentiële kosten.

**🪙 De Shop** (`Game.SHOP_UPGRADES`, `show_shop()` in `main.gd`) — na elke seizoensafsluiting krijg je 3 willekeurige, nog niet gekochte upgrades te koop aangeboden (`Game.shop_offer()`). Bevalt de set niet, dan kun je tegen betaling **rerollen** naar een andere set (`Game.shop_reroll_cost()` = €8k × seizoenschaling; de huidige set wordt uitgesloten zodat je echt iets anders krijgt). Je kunt ook gewoon doorlopen. Alle upgrades zijn eenmalig en gelden alleen **voor deze run** (los van de permanente legacy-perks uit §4.3), met prijzen die meeschalen via `event_money_scale()`. De bedragen hieronder zijn de **basisprijzen** in `SHOP_UPGRADES`; op alles geldt een generieke korting van 45% (`SHOP_PRICE_MULT` = 0,55), dus de werkelijke seizoen-1-prijs is 0,55× het genoemde bedrag (bijv. Groter kantoor €36k → €19,8k). 24 upgrades, zodat je niet allang tegen seizoen 6 alles hebt gekocht:
- **Groter kantoor** (€36k) — +1 stalplek, rest van de run.
- **Nog groter kantoor** (€44k) — nog eens +1 stalplek (stapelt met Groter kantoor).
- **PR-bureau** (€28k) — +2 extra schandaalverval per seizoen.
- **Eigen jeugdscout** (€42k) — +1 scoutpunt per seizoen.
- **Extra scoutingbudget** (€22k) — eenmalig +3 scoutpunten.
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
- **Data-analytics abonnement** (€38k) — scouten verlaagt onzekerheid 2 extra.
- **Breed scoutingnetwerk** (€34k) — +4 op je scouting-plafond: betere spelers binnen bereik (`candidate_ceiling()`).
- **Fiscalist** (€36k) — +2% fee-percentage op elke transfer.
- **Contractenspecialist** (€32k) — +30% tekengeld bij elke contractverlenging.
- **Clubcontactenboek** (€40k) — clubbudgetten groeien +17%/seizoen i.p.v. +12% (`CLUB_BUDGET_GROWTH` +0,05).
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
    ├── world_gen.gd       # procedurele generatie (spelers, clubs, namen)
    ├── events_db.gd       # alle 70 events als pure data
    ├── negotiation.gd     # het onderhandelings-minigame (transferwindow)
    ├── bidding_war.gd     # minigame "Biedingsoorlog" (event: overboden)
    ├── press_conference.gd  # minigame "Persconferentie" (event: persconferentie_druk)
    ├── sponsor_pitch.gd   # minigame "Sponsorpitch" (event: sponsorpitch)
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

Beschikbare effect-keys: `money`, `rep`, `scandal`, `favors`, `trust` (de gekoppelde cliënt), `all_trust`, `scout_points`, `new_client`/`new_top_client` (voegt een vrij talent toe aan je stal en meldt wie). Poortwachters: `req_money` en `req_favors` schakelen de knop uit als de speler het niet heeft.

`new_client`/`new_top_client` (`_sign_event_talent()`/`_sign_top_talent()` in `game.gd`) leveren bewust een BOVENGEMIDDELDE speler op i.p.v. een doorsnee scoutvondst: de ondergrens schaalt mee met je reputatie (geclampt op de daadwerkelijk hoogst beschikbare rating in de pool, zodat een hoge reputatie nooit tot niemand of altijd hetzelfde ~58-rating resultaat leidt) en de uiteindelijke pick is de beste uit een best-of-3-steekproef (`_best_of_sample()`), niet zomaar een willekeurige. Na afloop toont het uitkomstscherm de échte stats van de nieuwe cliënt onderaan in het infopaneel (`Game.last_new_client_id` → `_show_player_info()` in `_resolve()` en `show_poker()`), i.p.v. alleen zijn naam in de meldingsregel.

Alle `money`-bedragen in events (in `effects`, `success`, `fail` én `req_money`) worden automatisch geschaald met `Game.event_money_scale()`, die nu EXACT dezelfde curve gebruikt als de kantoorkosten (`COSTS_MULT`, ×1,8/seizoen) — zo blijven event-bedragen in de pas met de rest van de economie in plaats van er een eigen (zachtere) groeivoet op na te houden. Je hoeft in `events_db.gd` dus gewoon seizoen-1-bedragen te blijven schrijven — de schaling gebeurt centraal via `Game.scale_money_effects()`, aangeroepen in `_resolve()` vóór zowel toepassing als weergave. De minigames met vaste bedragen schalen op dezelfde manier via een `money_scale`-parameter op hun `outcome()`/`resolve()`; `BiddingWar` blijft ongemoeid omdat die al op de rating-gebaseerde `Game.value()` draait. Het uitkomstscherm na een event toont altijd een expliciete regel per gewijzigde waarde (bijv. "Geld: +€5.000", "Reputatie: -3", "Vertrouwen (Sem Kovacevic): +8") naast het verhaaltje — zie `_effect_lines()` in `main.gd`. Dezelfde samenvatting verschijnt ook na elke minigame. Event-voorwaarden: `min_season` (verschijnt pas vanaf dat seizoen), `needs_client` (koppelt een cliënt) en `needs_slot` (verschijnt alleen als je stal niet vol is — verplicht bij events met `new_client`). Elk event komt maximaal één keer per run voor (`used_events`).

**Events met een minigame.** Een event kan in plaats van `options` een `"minigame": "<key>"` hebben. `show_event()` in `main.gd` toont dan alleen intro-tekst plus een "Beginnen →"-knop; `_start_minigame()` bouwt het bijbehorende object op en toont het eigen scherm. Elke minigame is een losse `RefCounted`-klasse naar het patroon van `negotiation.gd` (state + `play()`-methodes + een `outcome()`/resultaat), met een eigen script en `show_*()`/`_play_*()`/`_finish_*()`-functies in `main.gd`. Bij afsluiten roept de `_finish_*()`-functie `Game.apply_effects()` (of, bij de biedingsoorlog, `Game.complete_transfer()`) aan en gaat daarna verder via `_next_event()` — exact het patroon van een normaal event. Tien huidige minigames:

- **Biedingsoorlog** (`bidding_war.gd`, event `overboden`) — drie clubs denken door een miscommunicatie dat er een concurrerend bod ligt. Echte tactiek zit 'm in drie dingen: elke club toont zijn AMBITIE (zichtbaar in de UI — ambitieuze clubs springen groter bij een geslaagde bluf maar stappen ook sneller geïrriteerd uit); bluffen tegen dezelfde club raakt "verbrand" (dalende slagingskans + hoger uitstaprisico bij herhaling, dus wissel van doelwit); "vergelijken" is niet meer gratis — de koploper kan zich ondermijnd voelen (`annoyed`) en wordt daardoor prikkelbaarder bij een latere druk-actie. 4 rondes; bij een deal volgt een échte transfer via `Game.complete_transfer()`.
- **Persconferentie** (`press_conference.gd`, event `persconferentie_druk`) — 5 vragen, een spanningsmeter (0–100) die bij zwakke antwoorden oploopt. Ontwijken (veilig maar bouwt spanning op), Toegeven (kalmeert meestal) of Aanvallen (hoog risico/beloning). Loopt de spanning naar 100, dan ontspoort het gesprek volledig.
- **Sponsorpitch** (`sponsor_pitch.gd`, event `sponsorpitch`) — verkorte negotiation-variant gericht op een merk: "terughoudendheid" in plaats van TD-weerstand, 3 rondes, tactieken Cijfers tonen / Exclusiviteit beloven (groot effect, kost vertrouwen) / Prestatiebonus voorstellen.
- **Fiscale schikking** (`tax_settlement.gd`, event `fiscale_schikking`) — risicoverdeling in plaats van één worp: drie boekhoudposten, elk met een keuze tussen open aangeven, deels verhullen of volledig verhullen. Gebalanceerd op verwachte kosten (% van het postbedrag) zodat elke optie een reden heeft: **Open** is de dure zekerheid (−40%, nooit schandaal); **Deels** heeft de laagste verwachte kosten (65% kans op slechts −8%, 35% kans op −55% + wat schandaal) — de slimme keuze, met een klein risico; **Volledig** is een pure variantiegok (50% gratis, 50% een boete ZWAARDER dan de belasting zelf (−110%) plus fors schandaal) — alleen zinnig als je echt op geluk speelt.
- **Poker om een talent** (`poker_bluff.gd`, event `rivaal_poker`, `needs_slot`) — een ECHT heads-up pokerspel om de rechten op een gedeeld toptalent: eigen hand, flop/turn/river, één tegenstander. Meegaan/Verhogen/Passen per straat; volwaardige 5-van-7-handevaluatie (hoge kaart t/m straat-kleur) bij showdown. Winnen levert een nieuwe cliënt (`new_client`) plus je netto chipwinst op.
- **Dobbelen bij de bookmaker** (`dice_bookmaker.gd`, event `bookmaker_dobbelen`) — Yahtzee-lite: 5 dobbelstenen, 2 herkansingen (vasthouden/opnieuw gooien). Het scherm toont de uitbetalingstabel (5 gelijk ×10 t/m niets = verlies) zodat de uitkomst nooit een raadsel is.
- **De boekhoudpuzzel** (`accounting_puzzle.gd`, event `boekhoud_puzzel`) — een 5×5 Latijns vierkant (elke rij/kolom bevat 1-5 precies één keer, geen vakconstructie — 5 is een priemgetal), 3 controlepogingen. Seizoen 1-7 meer starthints, seizoen 8-15 minder (moeilijker). Legitiem en risicoloos alternatief voor de fiscale schikking.
- **Anagramjacht** (`anagram_hunt.gd`, event `anagram_jacht`) — drie gehusselde woorden uit een gelekt document; typ het antwoord via een virtueel toetsenbord binnen 25 seconden per woord (echte klok via `_process()` in `main.gd`). Score bepaalt de beloning (geld/reputatie).
- **Speed-daten op de scoutingbeurs** (`scout_speed_date.gd`, event `scoutingbeurs_speeddate`) — vier scouts, vier talenten. Sommige scouts passen bij twee talenten; een FOUT aanbod verbrandt de scout meteen (niet meer beschikbaar), dus wild gokken kost je opties. Raad koppels binnen 6 pogingen.
- **Mediatraining: Simon Says** (`simon_media.gd`, event `mediatraining_simon`) — klassiek geheugenspel: bekijk een groeiende reeks "veilige reacties", herhaal haar daarna blind. Het aantal beschikbare reacties groeit mee met het seizoen (`round(4 + 0,4×seizoen)`, uit een pool van 10). 5 foutloze rondes = volledig getraind; één fout beëindigt de sessie zonder schade.

Het GDD mikt op 120+ events voor launch. Dit bestand is dus waar het meeste van je toekomstige werk zit — en je hoeft er geen regel engine-code voor aan te raken.

**Developer-eventtest.** Op het verborgen developer-scherm (7× tikken op de kleine "v1.0"-tekst op het startscherm, dan het wachtwoord) staat naast de puntenreset ook "Test: doorloop alle events →" (`_start_event_test()` in `main.gd`). Dit start een verse testrun in het geheugen (`Game.new_run()`), zet het geld op 999.999.999 en doorloopt daarna ALLE events uit `EventsDB.get_events()` op volgorde — inclusief alle tien minigames — zonder de normale `min_season`/`needs_slot`/`used_events`-filters en zonder fail-checks (scandal/faillissement onderbreken de test niet). Elk scherm toont een oranje regel "[DEV TEST] Event X/70 — id: ..." mét een invoerveld + knop "Ga naar event" om direct naar een specifiek eventnummer te springen (`_dev_jump_to_event()`; sluit eventuele actieve minigame af zonder de effecten toe te passen). Je opgeslagen run op schijf blijft ongemoeid; alleen niet-opgeslagen voortgang in de huidige sessie wordt vervangen door de testrun.

**Optie-previews en context.** Elke event-optieknop toont nu direct een compacte samenvatting van het effect (bijv. "Geld: -€8.000, Reputatie: +5", of bij kansopties apart voor succes/mislukking) via `_effect_preview()` in `main.gd` — je hoeft niet meer te klikken om te weten wat een keuze kost of oplevert. Bij een vertrek of kaping van een cliënt (`end_of_season()` in `game.gd`) staat het actuele vertrouwenscijfer in de melding, zodat duidelijk is waaróm hij wegging. De persconferentie-minigame toont nu ook de daadwerkelijke journalistenvraag per ronde (`PressConference.current_question()`), zodat Ontwijken/Toegeven/Aanvallen een reactie is op iets concreets.

### 4.2 Balans tweaken

Alle knoppen staan bovenin `scripts/game.gd` als constants: startgeld, aantal seizoenen (`MAX_SEASONS`, standaard 15), cliënten-cap, kantoorkosten, fee-percentage, vertrek-drempel en -kans. De waardeformule (`value()`) en de interesse-kansen (`gen_interest()`) staan er direct onder.

**Markt- en ratingbalans.** `value()` gebruikt `pow(max(rating-40, 5), 2) * 3000` (was `* 650`): een veel steilere curve, zodat een fee al rond seizoen 4 meetelt tegen de exponentieel stijgende kantoorkosten in plaats van na een paar seizoenen zakgeld te worden. `WorldGen.generate()` genereert spelers nu met een lagere basisrating en een lager plafond (35-52 basis, clamp 38-82, was 42-62/45-88) — de markt is dus duurder per rating-punt, maar spelers zijn zelf ook wat minder goed; per saldo hoort bij eenzelfde transferfee nu een lagere rating dan voorheen (een speler die vroeger ~rating 70 was voor €500k, is nu ~rating 54 voor hetzelfde bedrag). Het rating-plafond van je scouting komt sinds de kantoor-update NIET meer van reputatie of seizoen, maar van je **kantoorniveau** (§2b): `gen_candidates()` trekt elk seizoen 8 verse spelers binnen de band van dat niveau (`candidate_floor()`–`candidate_ceiling()`) via `WorldGen.make_candidate()`. Het oude `rating_cap_young/older()` + meeschuivend-venster-systeem (`CANDIDATE_WINDOW`) is daarmee vervallen. De perks die vroeger die caps ophoogden (Talentmagneet, Grote naam) en de shop-upgrades Kantoorrenovatie/Breed scoutingnetwerk tillen nu `candidate_ceiling()` een paar punten op, zodat ze relevant blijven.

### 4.3 Meta-progressie (legacy points en perks)

`scripts/meta.gd` (autoload `Meta`) houdt een tweede savebestand bij (`user://meta.json`) dat runs overleeft, los van `Game.state`. Elke afgeronde run — ook een game over — levert legacy points op (`Meta.award_run()`, aangeroepen vanuit `main.gd` in `show_gameover()`/`show_win()`), op basis van verdiende fees en aantal overleefde seizoenen. Die punten besteed je op het "Perks"-scherm (bereikbaar vanaf het startscherm) aan permanente upgrades in `Meta.PERKS`.

De perks vormen een boom van **3 takken × 4 rijen × 3 opties = 36 perks** (Kapitaal, Relaties, Vakwerk; structuur in `Meta.TREE`). Elke rij biedt drie keuzes; een rij ontgrendelt zodra je `Meta.TIER_REQ` (5) niveaus in de rij erboven hebt gekocht — binnen dezelfde tak. Rij 4 bevat de eindgame-perks: o.a. Waardestijging (hogere marktwaardes), Schuldpapier (vaste kostenkorting), Iconenstatus, Spelersfluisteraar (+vertrouwen per seizoen), Empathie (lagere vertrek-drempel), Koelbloedig (+blufkans), Voorwerk (minder startweerstand) en Geluksvogel (+kans op alle event-gokjes).

De economie is ontworpen voor **~240 uur goed spel tot 100%**. De volledige boom kost ~1,4 miljoen punten en de beloning per run is exponentieel in hoe ver je komt: een **gewonnen run levert exact 1% van de boom** op (`tree_total_cost() * (Meta.WIN_REWARD_PCT/100)` ≈ 14.100 punten), en elk seizoen mínder deelt dat door 1,45 (`Meta.REWARD_BASE`). Seizoen 10 halen ≈ 2.200 punten, seizoen 5 ≈ 340, seizoen 3 ≈ 160 (minimum 10). 100% vereist dus ~100 gewonnen runs van elk ~2,5 uur — vroeg doodgaan levert bijna niets op, ver komen loont exponentieel.

Rechtsboven op het perkscherm zit de **∞-upgrade**: een klein vierkantje met een vaste prijs (`Meta.INF_COST`, 200 punten — stijgt nooit) dat oneindig vaak gekocht kan worden en per koop +0,1% oplevert op álle verdiende legacy points (`Meta.inf_multiplier()`, toegepast in `award_run()`). Een goedkope, eindeloze uitlaatklep voor restpunten die op de heel lange termijn optelt; de perk-reset raakt hem niet aan. Het perkscherm toont je voortgang ("Boom voltooid: X%"). Er is ook een **reset-knop** (tweestaps-bevestiging) die alle perks naar 0 zet en álle bestede punten teruggeeft, zodat je vrij kunt herspeccen.

Daarnaast bestaat een **developer-only puntenreset** die het puntensaldo hard naar 0 zet (zonder terugbetaling, en zonder de perks te resetten) — bedoeld om de economie tijdens ontwikkeling te testen. Toegang: tik 7 keer op de kleine "v1.0"-tekst onderaan het startscherm (`_on_dev_tap()` in `main.gd`), voer het wachtwoord in (`DEV_PASSWORD`, bovenin `main.gd`) en bevestig op het developer-scherm. Dit is geen echte beveiliging — de broncode is leesbaar — maar voorkomt dat spelers er per ongeluk tegenaan lopen. Wijzig `DEV_PASSWORD` naar je eigen wachtwoord voordat je het spel deelt.

Daarnaast zijn er **vier ★ OVERPOWERED extra's** buiten de boom (tellen niet mee voor de 100%): **Superprovisie** (alle transfer-inkomsten ×2, ~417k), **IJzeren contracten** (cliënten vertrekken nooit meer en zijn niet te kapen, ~417k), **Helderziend** (alle TD-persoonlijkheden direct bekend én elk gesprek start Ontvankelijk, ~417k) en **Vaste kern** (je bent de uitzondering op het verplichte seizoensontslag — stalbeheer wordt overgeslagen, ~250k / ±30% van de boom). Pure luxe voor wie ver voorbij de boom grindt.

De perks grijpen op vrijwel elk systeem in: startgeld/rep/gunsten/startvertrouwen (`new_run()`, `_make_client()`), kantoorkosten, rente, gunstenfabriek en schandaalverval (`end_of_season()`), tekenkans (`sign_chance()`), kaapkans (`poach_chance()`), scoutdiepte en kandidatenlijst (`scout()`, `gen_candidates()`), scouting-plafond (`candidate_ceiling()`), fee en tekengeld (`fee_cut()`, `tekengeld_mult()`), stal-cap (`client_cap()`), een eenmalige bailout (`try_bailout()`) en het hele onderhandelspel (extra ronde, flow-multiplier, wegloopdemping, clausulekosten, aftastkosten — gezet in `_start_nego()` in `main.gd`). Nieuwe perks toevoegen = een entry aan `Meta.PERKS` toevoegen, in een rij van `Meta.TREE` hangen en de bonus ergens toepassen (gebruik `fmt` voor de weergave: `int`, `money` of `pct10`).

### 4.4 Richting het volledige GDD

Logische volgorde, oplopend in werk:

1. **Meer events** (zie 4.1) — grootste kwaliteitswinst per uur werk.
2. **Archetypes** — voeg `state.archetype` toe in `new_run()`, laat het startscherm laten kiezen, en check het archetype in `sign_chance()`, `Negotiation.tactics()` en event-conditions. De datastructuur is er al op voorbereid.
3. **Meta-netwerk uitbreiden** — laat `world_gen` bekende gezichten (oud-cliënten, rivalen) terugbrengen op basis van `Meta.state`, bovenop de bestaande legacy points/perks (zie 4.3).
4. **Rivaal-makelaars** — genereer 3 rivalen in `world_gen` en geef ze een beurt in `end_of_season()` (trekken aan cliënten met laag vertrouwen).
5. **Deadline Day-timer en juice** — pas als de kern bewezen verslavend is.

De enige vraag die deze MVP moet beantwoorden: **wil je na een game-over meteen opnieuw beginnen?** Zo nee, eerst events en balans verbeteren; geen enkel meta-systeem repareert een saaie kernloop.

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
