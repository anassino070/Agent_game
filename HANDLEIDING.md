# Handleiding — Voetbalmakelaar Roguelike (Godot MVP)

Dit is de speelbare MVP van het game design document: één archetype, 15 seizoenen per run, 64 events, 10 clubs, 80 procedureel gegenereerde spelers, een onderhandelings-minigame met stemming, verborgen TD-persoonlijkheden en flow, drie fail states, autosave én meta-progressie (legacy points en permanente perks die runs overleven). Alles is opgezet volgens het GDD-principe: **staat en logica strikt gescheiden van presentatie**, zodat je later moeiteloos archetypes en daily seeds kunt toevoegen.

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
4. **Events** — 2 à 3 encounters met keuzes. Kansen staan op de knoppen; risicovolle opties hebben grotere uitkomsten. Sommige opties vereisen geld of een gunst.
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
    ├── events_db.gd       # alle 64 events als pure data
    ├── negotiation.gd     # het onderhandelings-minigame
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

Beschikbare effect-keys: `money`, `rep`, `scandal`, `favors`, `trust` (de gekoppelde cliënt), `all_trust`, `scout_points`, `new_client` (voegt een vrij talent toe aan je stal en meldt wie). Poortwachters: `req_money` en `req_favors` schakelen de knop uit als de speler het niet heeft. Event-voorwaarden: `min_season` (verschijnt pas vanaf dat seizoen), `needs_client` (koppelt een cliënt) en `needs_slot` (verschijnt alleen als je stal niet vol is — verplicht bij events met `new_client`). Elk event komt maximaal één keer per run voor (`used_events`).

Het GDD mikt op 120+ events voor launch. Dit bestand is dus waar het meeste van je toekomstige werk zit — en je hoeft er geen regel engine-code voor aan te raken.

### 4.2 Balans tweaken

Alle knoppen staan bovenin `scripts/game.gd` als constants: startgeld, aantal seizoenen (`MAX_SEASONS`, standaard 15), cliënten-cap, kantoorkosten, fee-percentage, vertrek-drempel en -kans. De waardeformule (`value()`) en de interesse-kansen (`gen_interest()`) staan er direct onder.

### 4.3 Meta-progressie (legacy points en perks)

`scripts/meta.gd` (autoload `Meta`) houdt een tweede savebestand bij (`user://meta.json`) dat runs overleeft, los van `Game.state`. Elke afgeronde run — ook een game over — levert legacy points op (`Meta.award_run()`, aangeroepen vanuit `main.gd` in `show_gameover()`/`show_win()`), op basis van verdiende fees en aantal overleefde seizoenen. Die punten besteed je op het "Perks"-scherm (bereikbaar vanaf het startscherm) aan permanente upgrades in `Meta.PERKS`.

De perks vormen een boom van **3 takken × 3 rijen × 3 opties = 27 perks** (Kapitaal, Relaties, Vakwerk; structuur in `Meta.TREE`). Elke rij biedt drie keuzes; een rij ontgrendelt zodra je `Meta.TIER_REQ` (5) niveaus in de rij erboven hebt gekocht — binnen dezelfde tak.

De economie is ontworpen voor **~240 uur goed spel tot 100%**. De volledige boom kost ~834.000 punten en de beloning per run is exponentieel in hoe ver je komt: een **gewonnen run levert exact 1% van de boom** op (`tree_total_cost()/100` ≈ 8.340 punten), en elk seizoen mínder deelt dat door 1,45 (`Meta.REWARD_BASE`). Seizoen 10 halen ≈ 1.300 punten, seizoen 5 ≈ 200, seizoen 3 ≈ 90 (minimum 10). 100% vereist dus ~100 gewonnen runs van elk ~2,5 uur — vroeg doodgaan levert bijna niets op, ver komen loont exponentieel. Het perkscherm toont je voortgang ("Boom voltooid: X%"). Er is ook een **reset-knop** (tweestaps-bevestiging) die alle perks naar 0 zet en álle bestede punten teruggeeft, zodat je vrij kunt herspeccen.

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
