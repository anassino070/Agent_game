# events_db.gd — alle events als data.
#
# Schema per event:
#   id            unieke string
#   title         korte titel
#   text          eventtekst; "{client}" wordt vervangen door de cliëntnaam
#   needs_client  true = er wordt een willekeurige cliënt aan gekoppeld
#   min_season    (optioneel) vanaf welk seizoen dit event kan voorkomen
#   options       array van keuzes
#
# Schema per optie:
#   label         knoptekst
#   Deterministisch:  effects + txt
#   Kansgebaseerd:    chance + success/fail (effects) + success_txt/fail_txt
#   req_money     (optioneel) knop uitgeschakeld als je dit niet hebt
#   req_favors    (optioneel) idem voor gunsten
#
# Effect-keys: money, rep, scandal, favors, trust (gekoppelde cliënt),
#              all_trust (alle cliënten), scout_points
class_name EventsDB


static func get_events() -> Array:
	return [
		{
			"id": "casino", "title": "Casinofoto's", "needs_client": true,
			"text": "{client} is gefotografeerd in het casino, drie dagen voor een belangrijke wedstrijd. Een roddelsite belt jou eerst.",
			"options": [
				{"label": "Verhaal afkopen", "req_money": 8000,
					"effects": {"money": -8000},
					"txt": "De foto's verdwijnen. Duur, maar stil."},
				{"label": "Publiekelijk afvallen",
					"effects": {"rep": 5, "trust": -15},
					"txt": "De pers prijst je principes. Je cliënt voelt zich verraden."},
				{"label": "Negeren", "chance": 0.6,
					"success": {}, "success_txt": "Het waait over. Geluk gehad.",
					"fail": {"rep": -8, "trust": -5, "scandal": 6},
					"fail_txt": "Het verhaal explodeert en jouw naam staat erbij."},
			],
		},
		{
			"id": "rivaal_belt", "title": "De rivaal belt", "needs_client": true,
			"text": "Makelaar Jorge P. heeft {client} gebeld met gouden beloftes over een transfer naar het buitenland.",
			"options": [
				{"label": "Gunst inzetten: droomclub laten bellen", "req_favors": 1,
					"effects": {"favors": -1, "trust": 12},
					"txt": "Een bevriende TD belt je cliënt persoonlijk. Jorge is vergeten."},
				{"label": "Grote beloftes doen", "chance": 0.7,
					"success": {"trust": 8}, "success_txt": "Je cliënt gelooft je. Voorlopig.",
					"fail": {"trust": -15}, "fail_txt": "Je belofte wordt doorgeprikt. Het vertrouwen krijgt een deuk."},
				{"label": "Laten gaan, vertrouwen op de band",
					"effects": {"trust": -8},
					"txt": "Je doet niets. Je cliënt twijfelt of je wel vecht voor hem."},
			],
		},
		{
			"id": "interview", "title": "Primetime-interview",
			"text": "Een grote talkshow wil jou als gast: 'De wereld achter de transfers'. Gratis publiciteit — of een mijnenveld.",
			"options": [
				{"label": "Doen", "chance": 0.75,
					"success": {"rep": 8}, "success_txt": "Je komt scherp en sympathiek over. Je telefoon ontploft.",
					"fail": {"scandal": 10, "rep": -3}, "fail_txt": "Eén ongelukkige quote wordt eindeloos herhaald."},
				{"label": "Afslaan", "effects": {},
					"txt": "Je blijft liever op de achtergrond."},
			],
		},
		{
			"id": "investeerder", "title": "De weldoener",
			"text": "Een 'investeerder' met vage connecties biedt je €20.000 werkkapitaal. Geen contract, alleen 'wederzijds begrip'.",
			"options": [
				{"label": "Accepteren",
					"effects": {"money": 20000, "scandal": 15},
					"txt": "Het geld staat binnen een uur op je rekening. Je slaapt iets minder goed."},
				{"label": "Weigeren", "effects": {"rep": 4},
					"txt": "Het verhaal dat je 'niet te koop' bent doet de ronde. Goed voor je naam."},
			],
		},
		{
			"id": "jeugdtoernooi", "title": "Tip: jeugdtoernooi",
			"text": "Een oud-scout tipt je over een jeugdtoernooi vol onontdekt talent. Toegang tot de VIP-tribune kost wat.",
			"options": [
				{"label": "Erheen", "req_money": 3000,
					"effects": {"money": -3000, "scout_points": 2},
					"txt": "Je notitieboekje staat vol. Extra scoutingpunten volgend seizoen... nee, nu meteen."},
				{"label": "Overslaan", "effects": {},
					"txt": "Je blijft thuis. Talent genoeg, tijd te weinig."},
			],
		},
		{
			"id": "speeltijd", "title": "Bankzitter", "needs_client": true,
			"text": "{client} zit al weken op de bank en eist dat jij er iets aan doet.",
			"options": [
				{"label": "Druk zetten op de trainer", "chance": 0.6,
					"success": {"trust": 12}, "success_txt": "Het werkt: basisplaats volgende wedstrijd.",
					"fail": {"trust": -8, "rep": -3}, "fail_txt": "De trainer is not amused en zet hem uit wraak in de tribune."},
				{"label": "Geduld prediken", "effects": {"trust": -4},
					"txt": "'Je kans komt.' Hij vindt je slap."},
				{"label": "Een transfer beloven", "effects": {"trust": 10, "rep": -2},
					"txt": "Hij glundert. Nu moet je alleen nog leveren..."},
			],
		},
		{
			"id": "primeur", "title": "De journalist",
			"text": "Een transferjournalist vraagt om een primeur over een van je deals. In ruil staat hij bij je in het krijt.",
			"options": [
				{"label": "Lekken", "effects": {"favors": 1, "scandal": 8},
					"txt": "'HIER IS HET!' De journalist is je wat verschuldigd. De club vermoedt een lek."},
				{"label": "Weigeren", "effects": {"rep": 2},
					"txt": "Discretie is ook een reputatie."},
			],
		},
		{
			"id": "belasting", "title": "Belastingcontrole",
			"text": "De fiscus kondigt een boekenonderzoek aan bij je kantoor.",
			"options": [
				{"label": "Dure boekhouder inhuren", "req_money": 6000,
					"effects": {"money": -6000},
					"txt": "Alles blijkt (net) in orde. De boekhouder stuurt een vette factuur."},
				{"label": "Zelf regelen", "chance": 0.7,
					"success": {}, "success_txt": "Je Excel-skills redden je. Nipt.",
					"fail": {"money": -15000, "scandal": 5},
					"fail_txt": "Naheffing plus boete. Au."},
			],
		},
		{
			"id": "lening", "title": "Oude bekende",
			"text": "Een oud-teamgenoot uit je jeugd zit financieel aan de grond en vraagt om €10.000.",
			"options": [
				{"label": "Lenen", "req_money": 10000,
					"effects": {"money": -10000, "favors": 2},
					"txt": "Hij is je eeuwig dankbaar — en hij kent iedereen in het wereldje."},
				{"label": "Weigeren", "effects": {"rep": -2},
					"txt": "Hij vertelt rond dat je veranderd bent."},
			],
		},
		{
			"id": "blessure", "title": "Blessure", "needs_client": true,
			"text": "{client} grijpt naar zijn hamstring. De clubarts twijfelt over de aanpak.",
			"options": [
				{"label": "Topdokter invliegen", "req_money": 8000,
					"effects": {"money": -8000, "trust": 10},
					"txt": "Binnen drie weken fit. Je cliënt vergeet dit nooit."},
				{"label": "Clubarts vertrouwen", "chance": 0.5,
					"success": {"trust": 5}, "success_txt": "Herstel volgens schema.",
					"fail": {"trust": -10}, "fail_txt": "Te vroeg teruggekeerd, opnieuw geblesseerd. Hij verwijt het jou."},
			],
		},
		{
			"id": "schoenendeal", "title": "Schoenendeal", "needs_client": true,
			"text": "Een sportmerk wil {client} vastleggen. Het openingsbod is mager.",
			"options": [
				{"label": "Agressief onderhandelen", "chance": 0.65,
					"success": {"money": 12000, "trust": 5},
					"success_txt": "Ze gaan overstag. Dikke deal, dikke fee.",
					"fail": {"trust": -8},
					"fail_txt": "Het merk haakt af. Je cliënt baalt van je poker."},
				{"label": "Veilig tekenen", "effects": {"money": 5000, "trust": 3},
					"txt": "Geen vuurwerk, wel getekend."},
			],
		},
		{
			"id": "socialmedia", "title": "Ontplofte tweet", "needs_client": true,
			"text": "{client} heeft midden in de nacht iets doms gepost. Het is al duizend keer gescreenshot.",
			"options": [
				{"label": "Mediatraining regelen", "req_money": 4000,
					"effects": {"money": -4000, "trust": 5},
					"txt": "Een strak excuus en een cursus 'telefoon wegleggen na 23:00'."},
				{"label": "Publiek excuus namens hem", "effects": {"rep": 3, "trust": -5},
					"txt": "Jij vangt de klappen op. Hij vindt dat je hem als kind behandelt."},
				{"label": "Negeren", "effects": {"scandal": 8},
					"txt": "Het internet vergeet niets. Jouw kantoor wordt genoemd."},
			],
		},
		{
			"id": "samenwerking", "title": "Voorstel van de concurrent",
			"text": "Een groter makelaarskantoor stelt een 'samenwerking' voor: jij levert je netwerk, zij betalen — en plukken je leeg.",
			"options": [
				{"label": "Accepteren", "effects": {"money": 8000, "rep": -5},
					"txt": "Het geld is welkom. In het wereldje heet je nu 'hun loopjongen'."},
				{"label": "Weigeren", "effects": {"rep": 3},
					"txt": "Je blijft eigen baas. Dat wordt gezien."},
			],
		},
		{
			"id": "matchfixing", "title": "Anonieme tip",
			"text": "Je krijgt bewijs in handen van matchfixing bij een middenmoter. Melden geeft rumoer, zwijgen maakt je medeplichtig-ish.",
			"options": [
				{"label": "Melden bij de bond", "effects": {"rep": 8, "scandal": -10},
					"txt": "Je wordt geroemd om je integriteit. De onderwereld noteert je naam."},
				{"label": "Zwijgen en bewaren", "effects": {"favors": 1, "scandal": 5},
					"txt": "Kennis is macht. Vieze macht."},
			],
		},
		{
			"id": "heimwee", "title": "Heimwee", "needs_client": true,
			"text": "{client} presteert dramatisch en belt je huilend op: hij mist thuis.",
			"options": [
				{"label": "Familie laten overkomen", "req_money": 5000,
					"effects": {"money": -5000, "trust": 12},
					"txt": "Mama's kookkunst doet wonderen. Hij speelt de sterren van de hemel."},
				{"label": "Hard aanpakken", "chance": 0.55,
					"success": {"trust": 8}, "success_txt": "'Bikkelen.' Het wordt zijn doorbraakmoment.",
					"fail": {"trust": -15}, "fail_txt": "Hij klapt dicht en zoekt steun bij een andere makelaar."},
			],
		},
		{
			"id": "diner", "title": "Diner met een TD",
			"text": "Een technisch directeur nodigt je uit voor een exclusief diner. De rekening is voor jou, 'traditie'.",
			"options": [
				{"label": "Gaan", "req_money": 2000,
					"effects": {"money": -2000, "favors": 1},
					"txt": "Drie gangen, twee flessen, één belofte: 'Ik denk aan je bij de volgende deal.'"},
				{"label": "Afslaan", "effects": {},
					"txt": "Je agenda zit vol. Zegt hij ook tegen jou, voortaan."},
			],
		},
		{
			"id": "wonderkind", "title": "Het Braziliaanse wonderkind",
			"text": "Een agent uit São Paulo biedt een deal: samen zijn wonderkind naar Europa halen, 50/50 op de fee. De medische keuring is... 'flexibel geïnterpreteerd'.",
			"options": [
				{"label": "Meedoen", "chance": 0.6,
					"success": {"money": 25000, "scandal": 8},
					"success_txt": "De jongen slaat aan. Niemand kijkt naar de paperassen. Kassa.",
					"fail": {"money": -5000, "scandal": 15},
					"fail_txt": "Afgekeurd bij de tweede keuring. Jouw handtekening staat overal op."},
				{"label": "Weigeren", "effects": {"rep": 2},
					"txt": "Te veel losse eindjes. Je laat het lopen."},
			],
		},
		{
			"id": "docu", "title": "De documentaire",
			"text": "Een streamingdienst wil een docuserie maken: 'De Makelaar'. Alles komt in beeld — ook wat je liever niet toont.",
			"options": [
				{"label": "Meedoen", "effects": {"rep": 10, "scandal": 5},
					"txt": "Je wordt een bekende kop. Bekende koppen worden beter bekeken — door iedereen."},
				{"label": "Weigeren", "effects": {},
					"txt": "Camera's brengen zelden geluk in dit vak."},
			],
		},
		{
			"id": "gala", "title": "Sponsorgala",
			"text": "Het jaarlijkse voetbalgala. Tafel kost geld, maar iedereen die ertoe doet is er.",
			"options": [
				{"label": "Tafel boeken", "req_money": 3000,
					"effects": {"money": -3000, "rep": 5},
					"txt": "Je deelt kaartjes, drankjes en anekdotes uit. Mensen onthouden je naam."},
				{"label": "Overslaan", "effects": {},
					"txt": "Netwerken kan ook per telefoon. Toch?"},
			],
		},
		{
			"id": "laptop", "title": "Gestolen laptop",
			"text": "Je laptop met alle contracten en scoutingrapporten is gestolen. Een anoniem nummer biedt hem 'terug' aan.",
			"options": [
				{"label": "Losgeld betalen", "req_money": 4000,
					"effects": {"money": -4000},
					"txt": "Een envelop, een parkeergarage, je laptop terug. Je vraagt niets."},
				{"label": "Politie inschakelen", "chance": 0.7,
					"success": {}, "success_txt": "De dief blijkt een amateur. Laptop terug, niets gelekt.",
					"fail": {"scandal": 8}, "fail_txt": "Contractdetails duiken op bij een roddelsite."},
			],
		},
		{
			"id": "rugnummer", "title": "Nummer 10", "needs_client": true,
			"text": "{client} eist het rugnummer 10, maar dat is al vergeven aan de clubtopscorer.",
			"options": [
				{"label": "Gunst inzetten bij de club", "req_favors": 1,
					"effects": {"favors": -1, "trust": 8},
					"txt": "De topscorer krijgt 'vrijwillig' nummer 7. Je cliënt is dolgelukkig."},
				{"label": "Nee zeggen", "effects": {"trust": -3},
					"txt": "'Nummers winnen geen wedstrijden.' Hij pruilt een week."},
			],
		},
		{
			"id": "roddelblad", "title": "Jouw kop in de krant",
			"text": "Een roddelblad kopt: 'DE SCHADUWKANT VAN MAKELAAR X' — met jouw foto. Half kloppend, half verzonnen.",
			"options": [
				{"label": "Advocaat erop zetten", "req_money": 7000,
					"effects": {"money": -7000, "rep": 3},
					"txt": "Rectificatie op pagina 12. Het principe telt."},
				{"label": "Negeren", "effects": {"rep": -6},
					"txt": "'Waar rook is...' hoor je steeds vaker op de tribunes."},
			],
		},
		{
			"id": "poachen", "title": "Het talent van een ander", "needs_slot": true,
			"text": "Het grootste talent van een collega-makelaar is ontevreden en zoekt toenadering tot jou. Poachen is not done — en heel gebruikelijk.",
			"options": [
				{"label": "Binnenhalen", "chance": 0.55,
					"success": {"money": 15000, "rep": -5, "new_client": true},
					"success_txt": "Hij tekent bij jou en jij regelt direct een deal. De collega spuwt vuur.",
					"fail": {"rep": -10, "scandal": 8},
					"fail_txt": "Het lekt uit vóór hij tekent. Nu ben je de aasgier zonder de prooi."},
				{"label": "Netjes weigeren", "effects": {"rep": 3},
					"txt": "Je belt je collega zelfs even. Klasse wordt onthouden."},
			],
		},
		{
			"id": "vergunning", "title": "Licentievernieuwing",
			"text": "Je makelaarslicentie moet vernieuwd worden: verplichte cursus, of 'een regeling' via een kennis bij de bond.",
			"options": [
				{"label": "Cursus volgen", "req_money": 2000,
					"effects": {"money": -2000},
					"txt": "Twee saaie dagen, één geldig papiertje."},
				{"label": "De regeling", "chance": 0.75,
					"success": {}, "success_txt": "Stempel erop, niemand die het merkt.",
					"fail": {"scandal": 20}, "fail_txt": "De kennis wordt zelf onderzocht — en jouw naam staat in zijn mail."},
			],
		},

		# ---------------------------------------------------------------- batch 2 (40 nieuwe events)
		{
			"id": "modeldeal", "title": "Modellencontract", "needs_client": true,
			"text": "Een kledingmerk wil {client} boeken voor een fotoshoot. Leuk bijverdienste, maar de club vindt het maar niks vlak voor de camp.",
			"options": [
				{"label": "Deal sluiten", "chance": 0.7,
					"success": {"money": 9000, "trust": 6},
					"success_txt": "De shoot verloopt soepel. Mooie foto's, mooi geld.",
					"fail": {"trust": -6, "rep": -2},
					"fail_txt": "Hij komt vermoeid terug en presteert slecht. De club belt jou."},
				{"label": "Afhouden tot na het seizoen", "effects": {"trust": -3},
					"txt": "'Focus eerst op voetbal.' Hij vindt je zuinig."},
			],
		},
		{
			"id": "burnout", "title": "Op de rand", "needs_client": true,
			"text": "{client} slaapt slecht, eet slecht en durft het je bijna niet te vertellen: hij is op.",
			"options": [
				{"label": "Sportpsycholoog inschakelen", "req_money": 6000,
					"effects": {"money": -6000, "trust": 15},
					"txt": "Wekelijkse sessies. Hij voelt zich voor het eerst in maanden gehoord."},
				{"label": "'Bijt erdoorheen'", "chance": 0.4,
					"success": {"trust": 5}, "success_txt": "Hij herpakt zich, tegen de verwachting in.",
					"fail": {"trust": -18, "scandal": 4}, "fail_txt": "Hij stort in tijdens een training. De pers is erbij."},
			],
		},
		{
			"id": "aziatoer", "title": "Marketingtour Azië", "needs_client": true,
			"text": "De club wil {client} meenemen op een marketingtour door Azië. Goed voor de clubkas, zwaar voor zijn lijf — en jij regelt de voorwaarden.",
			"options": [
				{"label": "Extra vergoeding eisen", "chance": 0.6,
					"success": {"money": 10000, "trust": 4},
					"success_txt": "De club betaalt bij. Iedereen tevreden.",
					"fail": {"trust": -6}, "fail_txt": "De club weigert en noteert je eis als 'lastig'."},
				{"label": "Meewerken zonder gedoe", "effects": {"trust": 5, "rep": 2},
					"txt": "Soepele samenwerking. De club onthoudt dat."},
			],
		},
		{
			"id": "cryptosponsor", "title": "Cryptosponsor", "needs_client": true,
			"text": "Een cryptoplatform biedt {client} een vet bedrag om hun logo op zijn schoenen te zetten. Het platform bestaat sinds vorige maand.",
			"options": [
				{"label": "Tekenen", "chance": 0.5,
					"success": {"money": 18000}, "success_txt": "Het geld komt binnen. Voor nu.",
					"fail": {"money": -4000, "scandal": 10},
					"fail_txt": "Het platform stort in. Zijn naam staat op elk artikel over de fraude."},
				{"label": "Eerst laten controleren", "req_money": 1500,
					"effects": {"money": -1500, "rep": 2},
					"txt": "Je huurt een accountant in. Die raadt het ten sterkste af. Bespaard."},
			],
		},
		{
			"id": "conflictbelang", "title": "Gênant aanbod", "needs_client": true,
			"text": "Een club biedt jou onder de tafel geld om {client} tactisch af te raden van een transfer naar hun rivaal.",
			"options": [
				{"label": "Aannemen en zwijgen", "effects": {"money": 12000, "scandal": 14},
					"txt": "Het geld is binnen. Als dit uitkomt, ben je klaar in dit vak."},
				{"label": "Weigeren en het cliënt vertellen", "effects": {"rep": 6, "trust": 8},
					"txt": "Hij is je dankbaar. Zijn belang eerst — zo hoort het."},
			],
		},
		{
			"id": "handtekeningenactie", "title": "Meet & greet", "needs_client": true,
			"text": "Fans organiseren een meet & greet voor {client}. Leuk voor de band met het publiek, maar jij moet de beveiliging regelen.",
			"options": [
				{"label": "Professioneel organiseren", "req_money": 2500,
					"effects": {"money": -2500, "trust": 8, "rep": 3},
					"txt": "Alles verloopt gesmeerd. Foto's overal, positief."},
				{"label": "Laten schieten", "effects": {"trust": -4},
					"txt": "De fans zijn teleurgesteld. Hij ook, een beetje."},
			],
		},
		{
			"id": "afscheidstournee", "title": "Afscheidstournee", "needs_client": true, "min_season": 8,
			"text": "{client} speelt met het idee om na dit seizoen te stoppen en wil een passend afscheid — met een prijskaartje.",
			"options": [
				{"label": "Afscheidswedstrijd regelen", "req_money": 9000,
					"effects": {"money": -9000, "trust": 14, "rep": 4},
					"txt": "Een stadion vol, een staande ovatie. Precies wat hij wilde."},
				{"label": "Gewoon laten uitzingen", "effects": {"trust": -5},
					"txt": "Geen ceremonie, geen poespas. Hij voelt zich onderwaardeerd."},
			],
		},
		{
			"id": "verkeerde_storting", "title": "Verkeerde storting",
			"text": "Een club maakt per ongeluk €14.000 te veel over voor een oude deal. Niemand belt erover — nog niet.",
			"options": [
				{"label": "Melden en terugstorten", "effects": {"rep": 5},
					"txt": "De club is opgelucht en onthoudt je eerlijkheid."},
				{"label": "Stilhouden", "chance": 0.5,
					"success": {"money": 14000}, "success_txt": "Niemand merkt iets. Mooi extraatje.",
					"fail": {"money": -14000, "scandal": 12},
					"fail_txt": "De club vindt de fout alsnog en eist het terug — met een dreigbrief erbij."},
			],
		},
		{
			"id": "loyaliteitsbonus", "title": "De loyaliteitsbonus", "needs_client": true,
			"text": "De club van {client} biedt jou persoonlijk een bonus als je hem overhaalt om níet te vertrekken deze zomer.",
			"options": [
				{"label": "Aannemen en hem ompraten", "chance": 0.6,
					"success": {"money": 10000, "trust": -6},
					"success_txt": "Hij blijft. Hij vraagt zich later af waarom je zo overtuigend was.",
					"fail": {"trust": -14, "scandal": 6},
					"fail_txt": "Hij ontdekt de bonus. 'Werk je voor mij of voor hén?'"},
				{"label": "Afslaan, zijn belang eerst", "effects": {"rep": 4, "trust": 5},
					"txt": "Je vertelt hem eerlijk over het aanbod. Hij vertrouwt je meer dan ooit."},
			],
		},
		{
			"id": "medische_info", "title": "Discrete vraag", "needs_client": true,
			"text": "Een buitenlandse club vraagt je, tegen betaling, om vertrouwelijke medische info over {client} te delen vóór de onderhandeling.",
			"options": [
				{"label": "Delen", "effects": {"money": 8000, "scandal": 10},
					"txt": "Het geld is binnen. Als dit uitlekt, is zijn vertrouwen voorgoed weg."},
				{"label": "Weigeren", "effects": {"rep": 4},
					"txt": "Onethisch, punt uit. Je zegt nee en voelt je er goed bij."},
			],
		},
		{
			"id": "kerstborrel", "title": "Kerstborrel van de bond",
			"text": "De voetbalbond nodigt makelaars uit voor de jaarlijkse kerstborrel. Verplicht nummer, nuttig nummer.",
			"options": [
				{"label": "Gaan", "req_money": 1500,
					"effects": {"money": -1500, "favors": 1},
					"txt": "Drankjes, small talk, één belangrijke naam die je nummer vraagt."},
				{"label": "Thuis blijven", "effects": {},
					"txt": "Een avond voor jezelf. Het netwerk groeit niet vanzelf."},
			],
		},
		{
			"id": "trainersverzoek", "title": "Ook de trainer?",
			"text": "De assistent-trainer van een club vraagt of je hem ook wilt vertegenwoordigen. Ander werkveld, ander netwerk.",
			"options": [
				{"label": "Erbij nemen", "effects": {"money": 3000, "rep": 3},
					"txt": "Klein maar leuk contract. Je netwerk in de technische staf groeit."},
				{"label": "Bedanken, je focust op spelers", "effects": {},
					"txt": "Je blijft bij je kernbusiness."},
			],
		},
		{
			"id": "familieruzie", "title": "Ruzie in de familie", "needs_client": true,
			"text": "De familie van {client} maakt onderling ruzie over wie zijn geld beheert — en jij wordt erbij gesleept.",
			"options": [
				{"label": "Bemiddelen", "chance": 0.55,
					"success": {"trust": 12}, "success_txt": "Je brengt de rust terug. Hij is je dankbaar.",
					"fail": {"trust": -10}, "fail_txt": "Je kiest per ongeluk de verkeerde kant. Awkward etentjes voor jaren."},
				{"label": "Buiten blijven", "effects": {"trust": -4},
					"txt": "'Dit is jullie zaak.' Hij had gehoopt dat je hem zou steunen."},
			],
		},
		{
			"id": "hall_of_fame", "title": "Hall of Fame", "min_season": 6,
			"text": "De makelaarsvereniging overweegt jou op te nemen in hun 'rising stars'-lijstje. Een gala-avond met speech hoort erbij.",
			"options": [
				{"label": "Toespraak voorbereiden", "req_money": 4000,
					"effects": {"money": -4000, "rep": 9},
					"txt": "Een gepolijste speech, warm applaus. Je naam verspreidt zich."},
				{"label": "Kort bedanken en gaan zitten", "effects": {"rep": 3},
					"txt": "Bescheiden, maar effectief genoeg."},
			],
		},
		{
			"id": "ongewenste_verhuur", "title": "Verhuur tegen zijn wil", "needs_client": true,
			"text": "De club van {client} wil hem verhuren aan een subtopper. Hij wil dat helemaal niet.",
			"options": [
				{"label": "Verzet aantekenen", "chance": 0.5,
					"success": {"trust": 12}, "success_txt": "De club trekt de verhuur terug. Hij blijft.",
					"fail": {"trust": -8}, "fail_txt": "De club zet door. Hij verhuist, met tegenzin."},
				{"label": "Het positief framen bij hem", "effects": {"trust": 4},
					"txt": "'Speeltijd is speeltijd.' Hij accepteert het, met tegenzin."},
			],
		},
		{
			"id": "fanpetitie", "title": "De petitie", "needs_client": true,
			"text": "Duizenden fans tekenen een petitie om {client} langer te houden. De club voelt de druk — en jij kunt hem gebruiken.",
			"options": [
				{"label": "Publiekelijk inzetten bij de onderhandeling", "chance": 0.6,
					"success": {"rep": 6, "trust": 6},
					"success_txt": "De club buigt zichtbaar mee. Sterk statement — en de fans zien het.",
					"fail": {"scandal": 6, "trust": -4},
					"fail_txt": "De club voelt zich openlijk onder druk gezet en graaft zich juist in. 'Zo werkt dat niet,' klinkt het nors."},
				{"label": "Negeren, zelf onderhandelen", "effects": {"trust": 2},
					"txt": "Je houdt het zakelijk, zonder poespas. Hij waardeert de rust."},
			],
		},
		{
			"id": "getuige_fixing", "title": "Onder druk gezet", "needs_client": true,
			"text": "Een gokkartel benadert {client} rechtstreeks om 'iets minder scherp' te spelen. Hij belt jou in paniek.",
			"options": [
				{"label": "Direct melden bij de bond", "effects": {"rep": 10, "scandal": -8, "trust": 6},
					"txt": "De bond grijpt in. Hij voelt zich beschermd — maar het wordt een dossier, geen geheim."},
				{"label": "Zelf regelen, geen ruchtbaarheid", "chance": 0.5,
					"success": {"trust": 12, "favors": 1},
					"success_txt": "Het kartel trekt zich terug — via een contact dat voortaan bij je in het krijt staat. Stille overwinning, en een gunst rijker.",
					"fail": {"scandal": 14, "trust": -10},
					"fail_txt": "Het kartel dreigt door. Het verhaal lekt alsnog uit — en nu zonder de bond in je rug."},
			],
		},
		{
			"id": "taxconstructie", "title": "De constructie",
			"text": "Je boekhouder stelt een 'agressieve maar legale' belastingconstructie voor. Op het randje, zegt hij zelf.",
			"options": [
				{"label": "Doorzetten", "chance": 0.6,
					"success": {"money": 16000}, "success_txt": "Flink bespaard. Niemand die ernaar kijkt.",
					"fail": {"money": -6000, "scandal": 15},
					"fail_txt": "De fiscus prikt erdoorheen. Naheffing én reputatieschade."},
				{"label": "Gewoon netjes betalen", "effects": {"rep": 2},
					"txt": "Minder spannend, meer nachtrust."},
			],
		},
		{
			"id": "paspoortprobleem", "title": "Paspoortgedoe", "needs_client": true,
			"text": "De transfer van {client} naar het buitenland loopt vast op een paspoortkwestie. De deadline tikt.",
			"options": [
				{"label": "Spoedprocedure betalen", "req_money": 5000,
					"effects": {"money": -5000, "trust": 6},
					"txt": "Binnen 48 uur alles op orde. Op het nippertje."},
				{"label": "Gewone procedure afwachten", "chance": 0.4,
					"success": {}, "success_txt": "Net op tijd binnen. Scheelde weinig.",
					"fail": {"trust": -10}, "fail_txt": "De deadline verstrijkt. De deal valt terug."},
			],
		},
		{
			"id": "jeugdcoach_connectie", "title": "Tip van een jeugdcoach", "needs_slot": true,
			"text": "Een jeugdcoach die je al jaren kent belt opgewonden op: hij heeft een jongen die 'echt iets kan' en wil hem meteen aan je voorstellen.",
			"options": [
				{"label": "Kennismaken", "chance": 0.65,
					"success": {"new_client": true}, "success_txt": "Klik meteen. Hij tekent ter plekke.",
					"fail": {"rep": -2}, "fail_txt": "Hij twijfelt nog. Misschien een andere keer."},
				{"label": "Nu geen tijd", "effects": {},
					"txt": "Druk, druk. Je stelt het uit."},
			],
		},
		{
			"id": "overboden", "title": "Verkeerd begrepen bod", "needs_client": true,
			"minigame": "biedingsoorlog",
			"text": "Door een miscommunicatie denken meteen drie clubs dat er een concurrerend bod ligt op {client}. Niemand wil de eerste zijn die afhaakt — en jij kunt die chaos naar je hand zetten.",
		},
		{
			"id": "podcastuitnodiging", "title": "De podcast",
			"text": "Een populaire voetbalpodcast wil je uitnodigen voor een lang, ongefilterd gesprek. Kansen en risico's in gelijke mate.",
			"options": [
				{"label": "Doen", "chance": 0.65,
					"success": {"rep": 7}, "success_txt": "Ontspannen, geestig, mensen delen fragmenten.",
					"fail": {"scandal": 8}, "fail_txt": "Één losse opmerking wordt breed uitgemeten."},
				{"label": "Afslaan", "effects": {},
					"txt": "Je houdt het bij korte interviews."},
			],
		},
		{
			"id": "spionage_kantoor", "title": "Spionage op kantoor",
			"text": "Een concurrent probeert je assistent om te kopen voor informatie over je cliëntenportefeuille.",
			"options": [
				{"label": "Assistent beter belonen", "req_money": 3000,
					"effects": {"money": -3000, "rep": 2},
					"txt": "Loyaliteit gekocht — en verdiend. Ze weigert het aanbod."},
				{"label": "Niets doen", "chance": 0.5,
					"success": {}, "success_txt": "Ze weigert het aanbod uit zichzelf. Geluk.",
					"fail": {"scandal": 6}, "fail_txt": "Interne info lekt naar de concurrent."},
			],
		},
		{
			"id": "eigen_academie", "title": "Investeren in een academie",
			"text": "Een lokale voetbalacademie zoekt een investeerder in ruil voor eerste toegang tot hun talent.",
			"options": [
				{"label": "Investeren", "req_money": 7000,
					"effects": {"money": -7000, "scout_points": 2, "rep": 3},
					"txt": "Je krijgt voortaan als eerste een belletje bij een nieuw talent."},
				{"label": "Afzien", "effects": {},
					"txt": "Te veel risico voor te weinig zekerheid."},
			],
		},
		{
			"id": "villareportage", "title": "Lifestylereportage", "needs_client": true,
			"text": "Een tijdschrift wil een reportage over het huis en leven van {client}. Goed voor de status, gevoelig voor privacy.",
			"options": [
				{"label": "Meewerken", "effects": {"rep": 6, "trust": -3},
					"txt": "Prachtige foto's. Hij voelt zich er wat ongemakkelijk bij."},
				{"label": "Weigeren namens hem", "effects": {"trust": 5},
					"txt": "Hij waardeert dat je zijn privacy bewaakt."},
			],
		},
		{
			"id": "wraak_exmakelaar", "title": "Wraak van een ex-collega",
			"text": "Een makelaar die je ooit een cliënt afpakte, verspreidt nu roddels over jouw manier van werken.",
			"options": [
				{"label": "Publiekelijk weerleggen", "chance": 0.6,
					"success": {"rep": 6}, "success_txt": "Je weerlegging landt goed. Hij trekt zich terug.",
					"fail": {"scandal": 8, "rep": -4},
					"fail_txt": "Het wordt een welles-nietes in de media. Niemand wint."},
				{"label": "Negeren", "effects": {"scandal": 4},
					"txt": "De roddels blijven een tijdje hangen."},
			],
		},
		{
			"id": "bruiloft_td", "title": "Bruiloft van een TD",
			"text": "Een technisch directeur nodigt je uit voor de bruiloft van zijn dochter. Een cadeau en een reis, maar ook goud aan connecties.",
			"options": [
				{"label": "Gaan, met een mooi cadeau", "req_money": 3500,
					"effects": {"money": -3500, "favors": 2},
					"txt": "Een onvergetelijk feest — en twee gunsten in je binnenzak."},
				{"label": "Vriendelijk bedanken", "effects": {},
					"txt": "Niet iedere uitnodiging moet je aannemen."},
			],
		},
		{
			"id": "wondertrainer", "title": "De wondertrainer", "needs_client": true,
			"text": "Een onconventionele personal trainer claimt {client} naar een hoger niveau te kunnen tillen. De methodes zijn... apart.",
			"options": [
				{"label": "Uitproberen", "req_money": 4500, "chance": 0.55,
					"success": {"trust": 10}, "success_txt": "Het werkt verrassend goed. Hij is een believer.",
					"fail": {"money": -4500, "trust": -6},
					"fail_txt": "Vooral veel poespas, weinig resultaat. Geld weg."},
				{"label": "Bij de clubstaf blijven", "effects": {},
					"txt": "Saai maar veilig."},
			],
		},
		{
			"id": "dopinggerucht", "title": "Gerucht over een test", "needs_client": true,
			"text": "Een anonieme tip claimt dat een dopingtest van {client} 'twijfelachtig' was. Niets bevestigd, alles mogelijk.",
			"options": [
				{"label": "Advocaat inschakelen", "req_money": 8000,
					"effects": {"money": -8000, "trust": 8},
					"txt": "Voordat het verhaal groeit, ligt er al een dreigbrief richting de bron."},
				{"label": "Afwachten", "chance": 0.6,
					"success": {}, "success_txt": "Het gerucht sterft een stille dood.",
					"fail": {"scandal": 16, "trust": -8},
					"fail_txt": "Het verhaal ontploft, bevestigd of niet."},
			],
		},
		{
			"id": "persconferentie_druk", "title": "Persconferentie onder druk", "needs_client": true,
			"minigame": "persconferentie",
			"text": "Na een dramatische nederlaag moet {client} de pers te woord staan. Jij zit naast hem en fluistert antwoorden — de vragen worden ronde na ronde scherper.",
		},
		{
			"id": "sponsorpitch", "title": "De sponsorpitch", "needs_client": true,
			"minigame": "sponsorpitch",
			"text": "Een groot merk wil {client} als gezicht van een campagne, maar de eerste pitch-vergadering wordt een pokerspel over voorwaarden.",
		},
		{
			"id": "fiscale_schikking", "title": "Schikkingsvoorstel",
			"minigame": "fiscale_schikking",
			"text": "De fiscus controleert drie posten in je boeken. Per post kies je: open aangeven, deels verhullen, of volledig verhullen — hoe meer je verhult, hoe groter de besparing én het risico.",
		},
		{
			"id": "dubbele_pet", "title": "Twee petten, één positie", "needs_client": true,
			"text": "{client} en een andere cliënt van jou strijden bij dezelfde club om exact dezelfde basisplaats. Ongemakkelijk.",
			"options": [
				{"label": "Allebei gelijk en eerlijk behandelen", "effects": {"all_trust": 4},
					"txt": "Lastig te managen, maar beiden voelen zich serieus genomen."},
				{"label": "Stiekem één van de twee voortrekken", "effects": {"trust": 10, "rep": -3},
					"txt": "{client} is dolblij. Als de ander het ooit ontdekt, is het einde verhaal."},
			],
		},
		{
			"id": "scoutingcongres", "title": "Scoutingcongres",
			"text": "Een internationaal scoutingcongres belooft toegang tot databases en contacten die je normaal niet ziet.",
			"options": [
				{"label": "Ticket kopen", "req_money": 4000,
					"effects": {"money": -4000, "scout_points": 3},
					"txt": "Drie dagen vol nuttige contacten en scoutingrapporten."},
				{"label": "Overslaan", "effects": {},
					"txt": "Je bespaart geld, mist wellicht een kans."},
			],
		},
		{
			"id": "verjaardagscadeau", "title": "Een duur cadeau", "needs_client": true,
			"text": "De familie van {client} hint stevig naar een extravagant verjaardagscadeau — 'dat je toch wel kunt missen'.",
			"options": [
				{"label": "Geven", "req_money": 5000,
					"effects": {"money": -5000, "trust": 8},
					"txt": "Groot cadeau, grote glimlach. Voor even."},
				{"label": "Iets kleins en persoonlijks", "effects": {"trust": 2},
					"txt": "Bescheiden, maar gemeend. Niet iedereen is onder de indruk."},
			],
		},
		{
			"id": "clubarts_geheim", "title": "Het geheim van de clubarts", "needs_client": true,
			"text": "De clubarts vertrouwt je off-the-record een onzekere prognose over {client} toe, nog voor de club het zelf weet.",
			"options": [
				{"label": "Alvast een transfer voorbereiden", "effects": {"money": -2000, "rep": -2, "prepare_transfer": true},
					"txt": "Je speelt slim vooruit. Als dit uitkomt, is het einde van deze bron. Aan het eind van het seizoen blijkt of de mysterieuze koper toehapt — of dat de prognose toch onjuist was."},
				{"label": "Rustig afwachten", "effects": {"trust": 3},
					"txt": "Je wacht het officiële nieuws af. Integer, misschien te laat."},
			],
		},
		{
			"id": "media_boycot", "title": "Mediaboycot",
			"text": "Na een ongelukkige quote van jou boycotten een paar journalisten je kantoor. Ze schrijven liever over je concurrenten.",
			"options": [
				{"label": "Excuses aanbieden en bruggen bouwen", "req_money": 1000,
					"effects": {"money": -1000, "rep": 4},
					"txt": "Een lunch, een excuus, de kou is uit de lucht."},
				{"label": "Trots negeren", "effects": {"scandal": 5},
					"txt": "Ze schrijven gewoon door — nu net iets kritischer."},
			],
		},
		{
			"id": "goede_doelen_gala", "title": "Goede doelen-gala",
			"text": "Een goededoelenstichting vraagt je als tafelsponsor voor hun jaarlijkse gala. Prestige tegen een prijs.",
			"options": [
				{"label": "Sponsoren", "req_money": 6000,
					"effects": {"money": -6000, "rep": 7},
					"txt": "Je naam staat op het programma, naast de echt grote namen."},
				{"label": "Alleen komen kijken", "effects": {"rep": 1},
					"txt": "Netjes aanwezig, verder onopvallend."},
			],
		},
		{
			"id": "interlandroof", "title": "Weggehaald bij het elftal", "needs_client": true,
			"text": "{client} wordt op het laatste moment uit de interlandselectie gehaald. Hij vermoedt politiek en wil dat jij ingrijpt.",
			"options": [
				{"label": "Gunst inzetten bij de bond", "req_favors": 1,
					"effects": {"favors": -1, "trust": 10},
					"txt": "Een telefoontje later staat hij weer op de lijst. Hij is je eeuwig dankbaar."},
				{"label": "Hem kalmeren", "effects": {"trust": -3},
					"txt": "'Volgende keer.' Hij gelooft je niet helemaal."},
			],
		},
		{
			"id": "pensioengesprek", "title": "Het pensioengesprek", "needs_client": true, "min_season": 10,
			"text": "{client} vraagt je in vertrouwen: is het tijd om te stoppen, of gaat hij door voor nog één contract?",
			"options": [
				{"label": "Nog één seizoen erbij plakken", "chance": 0.6,
					"success": {"money": 8000, "trust": 10},
					"success_txt": "Hij tekent bij, gemotiveerder dan in jaren.",
					"fail": {"trust": -8}, "fail_txt": "Hij twijfelt en voelt zich onder druk gezet."},
				{"label": "Hem helpen met een waardig afscheid", "effects": {"rep": 5, "trust": 8},
					"txt": "Geen fee meer op dit contract, wel een cliënt die je nooit vergeet."},
			],
		},

		# ---------------------------------------------------------------- batch 3 (6 nieuwe minigame-events)
		{
			"id": "rivaal_poker", "title": "Pokeravond om een talent", "needs_slot": true,
			"minigame": "pokerbluf",
			"text": "Een rivaliserende makelaar zit aan tafel met hetzelfde toptalent op het oog. Jullie leggen de knikkers op tafel — win de hand en dat talent wordt jouw NIEUWE CLIËNT, plus de pot.",
		},
		{
			"id": "bookmaker_dobbelen", "title": "De achterkamer van de bookmaker",
			"minigame": "dobbelen",
			"text": "Een bevriende bookmaker biedt je een gokje op zijn dobbelstenen. Vijf worpen, twee herkansingen, en een uitbetaling die met de uitkomst meeschaalt.",
		},
		{
			"id": "boekhoud_puzzel", "title": "De boekhoudpuzzel",
			"minigame": "boekhoudpuzzel",
			"text": "Je boekhouder legt een rooster voor je neer: vul het correct in en je bespaart legaal een aardig bedrag. Geen risico, wel denkwerk.",
		},
		{
			"id": "anagram_jacht", "title": "Het gelekte document",
			"minigame": "anagramjacht",
			"text": "Een gelekt clubdocument ligt gehusseld in je inbox — letterlijk. Ontcijfer de sleutelwoorden voordat een rivaal-makelaar hetzelfde document doorheeft.",
		},
		{
			"id": "scoutingbeurs_speeddate", "title": "Speed-daten op de scoutingbeurs",
			"minigame": "scoutspeeddate",
			"text": "Op de jaarlijkse scoutingbeurs zoek je binnen een paar minuten uit welke scout bij welk talent past. Klik goed, en je netwerk groeit.",
		},
		{
			"id": "mediatraining_simon", "title": "Mediatraining: Simon Says", "needs_client": true,
			"minigame": "simonmedia",
			"text": "{client} moet leren zijn mond te houden onder druk. Jullie oefenen een groeiende reeks veilige reacties — één foutje en de sessie is voorbij.",
		},
		{
			"id": "topspeler_kaap", "title": "De sterspeler wil weg", "needs_slot": true, "min_season": 3,
			"text": "Een sterspeler bij een concurrerend kantoor voelt zich verwaarloosd en fluistert je toe dat hij wel wil overstappen — voor een bedrag dat belachelijk laag is voor zijn niveau.",
			"options": [
				{"label": "Het risico nemen (omkopen + overtuigen)", "req_money": 12000, "chance": 0.5,
					"success": {"money": -12000, "new_top_client": true, "rep": -6},
					"success_txt": "Hij tekent bij je. Zijn oude makelaar raast, maar het papierwerk is al rond.",
					"fail": {"money": -12000, "scandal": 10, "rep": -8},
					"fail_txt": "Het lekt uit vóór hij tekent. Je bent de geldsmijter die probeerde te stropen — zonder resultaat."},
				{"label": "Laten zitten, te riskant", "effects": {"rep": 2},
					"txt": "Verstandig, misschien. Een andere makelaar is minder kieskeurig."},
			],
		},
	]
