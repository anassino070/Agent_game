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
	]
