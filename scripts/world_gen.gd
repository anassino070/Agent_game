# world_gen.gd — genereert elke run een verse voetbalwereld.
# Alles is data (Dictionaries), zodat opslaan als JSON triviaal is.
class_name WorldGen

const FIRST := [
	"Sem", "Daan", "Luuk", "Milan", "Jayden", "Kofi", "Youssef", "Ibrahim",
	"Thiago", "Mateo", "Kenan", "Emir", "Nikola", "Andrej", "Tomasz", "Jari",
	"Rens", "Bram", "Olivier", "Noah", "Rafael", "Diego", "Kwame", "Amir",
	"Viktor", "Luka", "Petar", "Casper", "Finn", "Ezra", "Ravi", "Ilyas",
	"Dario", "Marco", "Julius", "Sven", "Timo", "Nino", "Bo", "Joris"
]
const LAST := [
	"van Dijk", "de Groot", "Jansen", "Bakker", "Smit", "Mulder", "Visser",
	"Kovacevic", "Petrovic", "Yilmaz", "Demir", "Kaya", "Osei", "Mensah",
	"Da Silva", "Fernandes", "Moreira", "Costa", "Nowak", "Kowalski",
	"Haddad", "El Amrani", "Benali", "Novak", "Horvat", "Jovic", "Vermeer",
	"van den Berg", "Koster", "Prins", "de Wit", "Hendriks", "Willems",
	"Martens", "Peters", "Sanders", "Vos", "Kuipers", "Blom", "Dekker"
]
const CLUB_NAMES := [
	"FC Meerhaven", "Sportclub Duindorp", "Rood-Wit '61", "FC Oostpoort",
	"VV Zilverstad", "AFC Kanaalzicht", "FC Noorderlicht",
	"SV Grenswachters", "FC Bronsstad", "United Westkust"
]
const POS := ["K", "V", "M", "A"]
const PERS := ["loyaal", "avonturier", "geldwolf", "prof"]


static func generate(rng: RandomNumberGenerator) -> Dictionary:
	var clubs := {}
	for i in range(10):
		var amb := rng.randi_range(1, 5)
		var cid := "c%d" % i
		clubs[cid] = {
			"id": cid,
			"name": CLUB_NAMES[i],
			"ambition": amb,
			"budget": amb * rng.randi_range(300, 1200) * 1000,
			"td": _rand_name(rng),
			"relation": 50,
		}

	var players := {}
	for i in range(80):
		var age := rng.randi_range(16, 33)
		# Oudere spelers zijn verder ontwikkeld: rating stijgt mee met leeftijd…
		# Basis en plafond bewust verlaagd (was 42-62 / clamp 45-88): spelers
		# zijn nu overal wat minder goed, wat samen met de veel steilere
		# waardeformule (zie value()) betekent dat eenzelfde transferfee nu
		# bij een lagere rating hoort — de markt is duurder geworden.
		var rating := clampi(rng.randi_range(35, 52) + int(float(age - 16) * 1.1) + rng.randi_range(-3, 3), 38, 82)
		# Potentieel is omgekeerd gekoppeld aan de rating (zie _potential_for()):
		# binnen de generatieband 38-82 krijgt een zwakke speler veel rek en een
		# sterke weinig, zodat "hoogste rating" niet automatisch "beste speler"
		# betekent. Zelfde regel als bij de scoutingkandidaten.
		var pot := _potential_for(rng, rating, age, 38, 82)
		var club_id := ""
		if rng.randf() > 0.15:
			club_id = "c%d" % rng.randi_range(0, 9)
		var unc := 12 if age <= 23 else 6
		# De publieke inschatting van het potentieel is zélf ruis: ze kan er
		# flink naast zitten. Scouten trekt haar richting de waarheid.
		var spread := int(float(unc) * 0.75)
		var est := clampi(pot + rng.randi_range(-spread, spread), rating, 94)
		var pid := "p%d" % i
		players[pid] = {
			"id": pid,
			"name": _rand_name(rng),
			"age": age,
			"pos": POS[rng.randi_range(0, 3)],
			"rating": rating,
			# Rating zoals hij GEGENEREERD is. De ontwikkelstap wordt hierop
			# geschaald (zie DEV_* in game.gd), niet op de bandondergrens en niet
			# op zijn actuele rating — zo staat het tempo van dag één vast.
			"base_rating": rating,
			"pot": pot,          # verborgen echt potentieel
			"est": est,          # publieke schatting; middelpunt van de band
			"unc": unc,          # onzekerheid; scouting verlaagt dit
			"scouted": 0,        # aantal keer gescout (geeft tekenkans-bonus)
			"club": club_id,     # "" = clubloos
			"contract": 0 if club_id == "" else rng.randi_range(1, 4),  # clubloos = geen contract
			"trust": 50,         # alleen relevant zodra iemand cliënt is
			"pers": PERS[rng.randi_range(0, 3)],
		}

	return {"players": players, "clubs": clubs}


const RATING_CAP := 94
# Potentieel is OMGEKEERD gekoppeld aan de rating binnen de band: de zwakste
# kandidaat gebruikt een groot deel van de resterende rek naar het plafond, de
# sterkste maar een klein deel. Zo is de hoogste rating niet automatisch de
# beste keuze — je kiest tussen "nu al bruikbaar" en "kan veel verder komen".
const POT_FRAC_AT_BAND_LOW := 0.85   # onderkant van de band: ruwe diamant
const POT_FRAC_AT_BAND_HIGH := 0.25  # bovenkant: al grotendeels "af"


static func _potential_for(rng: RandomNumberGenerator, rating: int, age: int, band_lo: int, band_hi: int) -> int:
	# Positie in de band (0 = zwakste kandidaat, 1 = sterkste).
	var t := 0.5
	if band_hi > band_lo:
		t = clampf(float(rating - band_lo) / float(band_hi - band_lo), 0.0, 1.0)
	# Fractie van de resterende rek tot het plafond. Werkt met de RESTERENDE
	# ruimte (niet met een vast aantal punten), zodat potentieel nooit absurd
	# door het RATING_CAP heen schiet bij een al hoge rating.
	var frac := lerpf(POT_FRAC_AT_BAND_LOW, POT_FRAC_AT_BAND_HIGH, t)
	frac += float(27 - age) * 0.01        # jonge spelers houden iets meer rek
	frac += rng.randf_range(-0.12, 0.12)  # ruis: de regel mag niet exact af te lezen zijn
	frac = clampf(frac, 0.05, 0.95)
	var room := maxi(RATING_CAP - rating, 0)
	return mini(rating + int(round(float(room) * frac)), RATING_CAP)


static func make_candidate(rng: RandomNumberGenerator, pid: String, rating: int, band_lo := -1, band_hi := -1) -> Dictionary:
	# Eén verse scoutingkandidaat met een OPGELEGDE rating (uit de band van je
	# kantoorniveau). `band_lo`/`band_hi` zijn die band: ze bepalen of deze
	# speler onderaan of bovenaan zit, en dus hoeveel potentieel hij krijgt
	# (zie _potential_for()). Zonder band vallen we terug op de rating zelf,
	# wat neerkomt op "midden in de band".
	var age := rng.randi_range(16, 30)
	var lo := band_lo if band_lo >= 0 else rating
	var hi := band_hi if band_hi >= 0 else rating
	var pot := _potential_for(rng, rating, age, lo, hi)
	var club_id := ""
	if rng.randf() > 0.5:
		club_id = "c%d" % rng.randi_range(0, 9)
	var unc := 12 if age <= 23 else 6
	var spread := int(float(unc) * 0.75)
	var est := clampi(pot + rng.randi_range(-spread, spread), rating, 94)
	return {
		"id": pid,
		"name": _rand_name(rng),
		"age": age,
		"pos": POS[rng.randi_range(0, 3)],
		"rating": rating,
		"base_rating": rating,   # zie generate(): schaalt de ontwikkelstap
		"pot": pot,
		"est": est,
		"unc": unc,
		"scouted": 0,
		"club": club_id,
		"contract": 0 if club_id == "" else rng.randi_range(1, 4),  # clubloos = geen contract
		"trust": 50,
		"pers": PERS[rng.randi_range(0, 3)],
	}


static func _rand_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [
		FIRST[rng.randi_range(0, FIRST.size() - 1)],
		LAST[rng.randi_range(0, LAST.size() - 1)],
	]
