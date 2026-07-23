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
		# …maar de rek is eruit: de potentieel-marge loopt richting 27 jaar naar 0.
		var headroom := maxi(27 - age, 0) * 2
		var pot := rating
		if headroom > 0:
			pot = mini(rating + rng.randi_range(2, headroom + 2), 94)
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


static func make_candidate(rng: RandomNumberGenerator, pid: String, rating: int) -> Dictionary:
	# Eén verse scoutingkandidaat met een OPGELEGDE rating (uit de band van je
	# kantoorniveau). Leeftijd bepaalt de potentieel-marge en onzekerheid net
	# als in generate(): jonge spelers hebben meer rek én meer ruis, oudere
	# zijn "af". Zo blijft het scout-/potentieelspel intact op de nieuwe pool.
	var age := rng.randi_range(16, 30)
	var headroom := maxi(27 - age, 0) * 2
	var pot := rating
	if headroom > 0:
		pot = mini(rating + rng.randi_range(2, headroom + 2), 94)
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
