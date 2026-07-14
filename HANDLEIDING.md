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
2. **Stalbeheer** — heb je 2 of meer cliënten, dan móét je er één wegsturen (de rest van je stal verliest er 2 vertrouwen door). Zo blijft er altijd ruimte — en reden — om te scouten.
3. **Scouting** — 3 scoutingpunten per seizoen. De kandidatenlijst mengt jonge beloftes (≤22, veel rek, veel onzekerheid) met gevestigde namen (23–30, hogere rating maar weinig potentieel-marge — vanaf 27 is de rek eruit). Je reputatie bepaalt het plafond van wie er überhaupt met je wil praten (het scherm toont de actuele grenzen): met rep 50 kom je niet verder dan rating ~62 (jong) / ~71 (gevestigd), toppers vereisen een grote naam. De getoonde potentieel-band is gecentreerd op een publieke schátting die er zelf flink naast kan zitten — een "70–90"-belofte kan na scouten een 72-dud blijken. Scouten versmalt de band én trekt de schatting richting de waarheid, en een gescoute speler tekent bovendien makkelijker bij je (+5% tekenkans per scout, max +10% — hij voelt zich serieus genomen). Hier benader je ook nieuwe cliënten; de kans dat ze tekenen hangt af van je reputatie en hun niveau. Eén benaderpoging per speler per seizoen: wijst hij je af, dan is het volgend seizoen pas weer een optie.
4. **Events** — 4 à 6 encounters met keuzes (`gen_events()` in `game.gd`). Kansen staan op de knoppen; risicovolle opties hebben grotere uitkomsten. Sommige opties vereisen geld of een gunst. Tien events starten in plaats daarvan een eigen minigame (zie 4.2). Met 70 events in de pool en gemiddeld 5 per seizoen kan de pool tegen het einde van een lange run uitgeput raken (`used_events`) — vandaar dat meer events de belangrijkste groeirichting blijft (zie 4.1).
5. **Transferwindow** — per cliënt melden zich 0–2 geïnteresseerde clubs. Onderhandelen = de weerstand van de TD naar 0 spelen binnen 5 rondes, en de vólgorde van je zetten is de kern:
   - **Stemming** (Geïrriteerd → Zakelijk → Ontvankelijk): charmeren en clausules bouwen de stemming op; bluffen heeft haar nodig (25/50/75% kans per stemming) en "Feiten & cijfers" is juist het sterkst bij Zakelijk. Deadline-druk verslechtert de stemming áltijd — en bij een geïrriteerde TD riskeer je dat hij wegloopt. Druk is dus een finisher, geen opener.
   - **Persoonlijkheid** (verborgen; werkt vooral op kansen, mild op weerstand): IJdel (charme slaagt altijd en iets sterker), Koppig (+5 weerstand, stemming zakt nooit onder Zakelijk), Nerveus (druk +20% slaagkans, maar hij loopt sneller weg), Rekenmeester (+8 weerstand, feiten +8% kans en 1,15× effect, charme doet niets, ongevoelig voor bluf en druk (-15%/-10% kans) — alleen cijfers overtuigen hem). "Aftasten" kost twee rondes en onthult het type — die kennis blijft de hele run per club bewaard, ook zichtbaar in het window.
   - **Flow**: twee successen op rij geven +50% effect op je volgende zet; een mislukking reset de reeks.
   - **Combo's** (opeenvolgende successen; elk maximaal één keer per gesprek): De Goede Cop (charme → charme → feiten, +6), De Slotklap (charme → feiten → charme → druk, +14), De Boekhouder (feiten → feiten tegen een bekende Rekenmeester, +8), Het Ultimatum (clausule → clausule → druk, +10 — maar je fee is dan al 4% gezakt), De Nerveuze Val (druk → druk tegen een bekende Nerveus, +16 — het hoogste, maar risico-op-risico), Slow Play (clausule → charme → feiten → bluf, +12 — de veilige lange route). Het scherm toont de lijst en kleurt een combo **goud** ("OP KOERS") zodra je huidige reeks er een prefix van is, en **groen** met ✔ als hij al is afgerond. Bij het voltooien van een combo verschijnt een korte confetti-uitbarsting met de combonaam.

   Weglopen kan zonder schade, maar elke club biedt maar één kans per window: ketst het af, dan is die deal dit seizoen weg. Contract verlengen kan alleen als een cliënt in zijn laatste contractjaar zit (en maximaal één keer per window). Elk 5e seizoen is het Deadline Day: TD's beginnen met lagere weerstand.
6. **Afsluiting** — kantoorkosten (×1,8 per seizoen: €10k in seizoen 1, €33k in seizoen 3, €105k in seizoen 5, €612k in seizoen 8 — de kosten zijn de échte klok van de run), spelerontwikkeling, vertrouwensdrift, contractafloop, en de fail-checks.

**Fail states:** saldo onder €0 (failliet), schandaalmeter op 100 (licentie kwijt), of een lege stal (alle cliënten weg). Vertrouwen onder 30 geeft elk seizoen 40% vertrekkans per cliënt, en rivaal-makelaars kunnen daarnaast cliënten wegkapen — hoe hoger de rating en hoe lager het vertrouwen, hoe groter dat risico.

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

Beschikbare effect-keys: `money`, `rep`, `scandal`, `favors`, `trust` (de gekoppelde cliënt), `all_trust`, `scout_points`, `new_client` (voegt een vrij talent toe aan je stal en meldt wie). Poortwachters: `req_money` en `req_favors` schakelen de knop uit als de speler het niet heeft.

Alle `money`-bedragen in events (in `effects`, `success`, `fail` én `req_money`) worden automatisch geschaald met `Game.event_money_scale()`: elk seizoen +20% (`EVENT_MONEY_GROWTH` in `game.gd`), zodat een event met "-8000" niet vanaf seizoen 6 al waardeloos aanvoelt naast de exponentieel stijgende kantoorkosten. Je hoeft in `events_db.gd` dus gewoon seizoen-1-bedragen te blijven schrijven — de schaling gebeurt centraal via `Game.scale_money_effects()`, aangeroepen in `_resolve()` vóór zowel toepassing als weergave. De minigames met vaste bedragen schalen op dezelfde manier via een `money_scale`-parameter op hun `outcome()`/`resolve()`; `BiddingWar` blijft ongemoeid omdat die al op de rating-gebaseerde `Game.value()` draait. Het uitkomstscherm na een event toont altijd een expliciete regel per gewijzigde waarde (bijv. "Geld: +€5.000", "Reputatie: -3", "Vertrouwen (Sem Kovacevic): +8") naast het verhaaltje — zie `_effect_lines()` in `main.gd`. Dezelfde samenvatting verschijnt ook na elke minigame. Event-voorwaarden: `min_season` (verschijnt pas vanaf dat seizoen), `needs_client` (koppelt een cliënt) en `needs_slot` (verschijnt alleen als je stal niet vol is — verplicht bij events met `new_client`). Elk event komt maximaal één keer per run voor (`used_events`).

**Events met een minigame.** Een event kan in plaats van `options` een `"minigame": "<key>"` hebben. `show_event()` in `main.gd` toont dan alleen intro-tekst plus een "Beginnen →"-knop; `_start_minigame()` bouwt het bijbehorende object op en toont het eigen scherm. Elke minigame is een losse `RefCounted`-klasse naar het patroon van `negotiation.gd` (state + `play()`-methodes + een `outcome()`/resultaat), met een eigen script en `show_*()`/`_play_*()`/`_finish_*()`-functies in `main.gd`. Bij afsluiten roept de `_finish_*()`-functie `Game.apply_effects()` (of, bij de biedingsoorlog, `Game.complete_transfer()`) aan en gaat daarna verder via `_next_event()` — exact het patroon van een normaal event. Tien huidige minigames:

- **Biedingsoorlog** (`bidding_war.gd`, event `overboden`) — drie clubs denken door een miscommunicatie dat er een concurrerend bod ligt. Tactieken: bluffen richting een specifieke club, deadline-druk op de huidige leider, vergelijken (alle clubs zien elkaars bod) en direct aannemen. 4 rondes; bij een deal volgt een échte transfer via `Game.complete_transfer()`.
- **Persconferentie** (`press_conference.gd`, event `persconferentie_druk`) — 5 vragen, een spanningsmeter (0–100) die bij zwakke antwoorden oploopt. Ontwijken (veilig maar bouwt spanning op), Toegeven (kalmeert meestal) of Aanvallen (hoog risico/beloning). Loopt de spanning naar 100, dan ontspoort het gesprek volledig.
- **Sponsorpitch** (`sponsor_pitch.gd`, event `sponsorpitch`) — verkorte negotiation-variant gericht op een merk: "terughoudendheid" in plaats van TD-weerstand, 3 rondes, tactieken Cijfers tonen / Exclusiviteit beloven (groot effect, kost vertrouwen) / Prestatiebonus voorstellen.
- **Fiscale schikking** (`tax_settlement.gd`, event `fiscale_schikking`) — risicoverdeling in plaats van één worp: drie boekhoudposten, elk met een keuze tussen open aangeven, deels verhullen of volledig verhullen. Meer verhullen = grotere besparing bij succes maar hoger ontdekkingsrisico én een zwaardere boete als het misgaat.
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

### 4.3 Meta-progressie (legacy points en perks)

`scripts/meta.gd` (autoload `Meta`) houdt een tweede savebestand bij (`user://meta.json`) dat runs overleeft, los van `Game.state`. Elke afgeronde run — ook een game over — levert legacy points op (`Meta.award_run()`, aangeroepen vanuit `main.gd` in `show_gameover()`/`show_win()`), op basis van verdiende fees en aantal overleefde seizoenen. Die punten besteed je op het "Perks"-scherm (bereikbaar vanaf het startscherm) aan permanente upgrades in `Meta.PERKS`.

De perks vormen een boom van **3 takken × 4 rijen × 3 opties = 36 perks** (Kapitaal, Relaties, Vakwerk; structuur in `Meta.TREE`). Elke rij biedt drie keuzes; een rij ontgrendelt zodra je `Meta.TIER_REQ` (5) niveaus in de rij erboven hebt gekocht — binnen dezelfde tak. Rij 4 bevat de eindgame-perks: o.a. Waardestijging (hogere marktwaardes), Schuldpapier (vaste kostenkorting), Iconenstatus, Spelersfluisteraar (+vertrouwen per seizoen), Empathie (lagere vertrek-drempel), Koelbloedig (+blufkans), Voorwerk (minder startweerstand) en Geluksvogel (+kans op alle event-gokjes).

De economie is ontworpen voor **~240 uur goed spel tot 100%**. De volledige boom kost ~1,4 miljoen punten en de beloning per run is exponentieel in hoe ver je komt: een **gewonnen run levert exact 1% van de boom** op (`tree_total_cost() * (Meta.WIN_REWARD_PCT/100)` ≈ 14.100 punten), en elk seizoen mínder deelt dat door 1,45 (`Meta.REWARD_BASE`). Seizoen 10 halen ≈ 2.200 punten, seizoen 5 ≈ 340, seizoen 3 ≈ 160 (minimum 10). 100% vereist dus ~100 gewonnen runs van elk ~2,5 uur — vroeg doodgaan levert bijna niets op, ver komen loont exponentieel.

Rechtsboven op het perkscherm zit de **∞-upgrade**: een klein vierkantje met een vaste prijs (`Meta.INF_COST`, 200 punten — stijgt nooit) dat oneindig vaak gekocht kan worden en per koop +0,01% oplevert op álle verdiende legacy points (`Meta.inf_multiplier()`, toegepast in `award_run()`). Een goedkope, eindeloze uitlaatklep voor restpunten die op de heel lange termijn optelt; de perk-reset raakt hem niet aan. Het perkscherm toont je voortgang ("Boom voltooid: X%"). Er is ook een **reset-knop** (tweestaps-bevestiging) die alle perks naar 0 zet en álle bestede punten teruggeeft, zodat je vrij kunt herspeccen.

Daarnaast bestaat een **developer-only puntenreset** die het puntensaldo hard naar 0 zet (zonder terugbetaling, en zonder de perks te resetten) — bedoeld om de economie tijdens ontwikkeling te testen. Toegang: tik 7 keer op de kleine "v1.0"-tekst onderaan het startscherm (`_on_dev_tap()` in `main.gd`), voer het wachtwoord in (`DEV_PASSWORD`, bovenin `main.gd`) en bevestig op het developer-scherm. Dit is geen echte beveiliging — de broncode is leesbaar — maar voorkomt dat spelers er per ongeluk tegenaan lopen. Wijzig `DEV_PASSWORD` naar je eigen wachtwoord voordat je het spel deelt.

Daarnaast zijn er **vier ★ OVERPOWERED extra's** buiten de boom (tellen niet mee voor de 100%): **Superprovisie** (alle transfer-inkomsten ×2, ~417k), **IJzeren contracten** (cliënten vertrekken nooit meer en zijn niet te kapen, ~417k), **Helderziend** (alle TD-persoonlijkheden direct bekend én elk gesprek start Ontvankelijk, ~417k) en **Vaste kern** (je bent de uitzondering op het verplichte seizoensontslag — stalbeheer wordt overgeslagen, ~250k / ±30% van de boom). Pure luxe voor wie ver voorbij de boom grindt.

De perks grijpen op vrijwel elk systeem in: startgeld/rep/gunsten/startvertrouwen (`new_run()`, `_make_client()`), kantoorkosten, rente, gunstenfabriek en schandaalverval (`end_of_season()`), tekenkans (`sign_chance()`), kaapkans (`poach_chance()`), scoutdiepte en kandidatenlijst (`scout()`, `gen_candidates()`), rating-plafonds (`rating_cap_young/older()`), fee en tekengeld (`fee_cut()`, `tekengeld_mult()`), stal-cap (`client_cap()`), een eenmalige bailout (`try_bailout()`) en het hele onderhandelspel (extra ronde, flow-multiplier, wegloopdemping, clausulekosten, aftastkosten — gezet in `_start_nego()` in `main.gd`). Nieuwe perks toevoegen = een entry aan `Meta.PERKS` toevoegen, in een rij van `Meta.TREE` hangen en de bonus ergens toepassen (gebruik `fmt` voor de weergave: `int`, `money` of `pct10`).

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
