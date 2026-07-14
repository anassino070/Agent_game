# poker_bluff.gd — minigame "Poker om een talent" (event: rivaal_poker).
# Een ECHT (heads-up) pokerspel om de rechten op een gedeeld toptalent: eigen
# hand, flop/turn/river en één tegenstander. Elke straat speel je precies één
# actie (meegaan/verhogen/passen); bij een verhoging reageert de tegenstander
# direct. Na de river volgt een showdown met een volwaardige handevaluatie
# (hoge kaart t/m straat-kleur) op de beste 5 van 7 kaarten.
class_name PokerBluff
extends RefCounted

const SUITS := ["♠", "♥", "♦", "♣"]
const RANK_NAMES := {11: "J", 12: "Q", 13: "K", 14: "A"}
const HAND_NAMES := ["Hoge kaart", "Paar", "Twee paar", "Drieling", "Straat", "Kleur", "Full house", "Vierling", "Straat-kleur"]

var deck: Array = []
var my_hole: Array = []
var opp_hole: Array = []
var community: Array = []
var street := "preflop"       # preflop, flop, turn, river, showdown
var pot := 0
var my_stack := 0
var opp_stack := 0
var starting_stack := 0
var ante := 0
var to_call := 0
var finished := false
var folded_by_me := false
var folded_by_opp := false
var log: Array = []


# ---------------------------------------------------------------- opbouw

func setup(rng: RandomNumberGenerator, money_scale: float = 1.0) -> void:
	ante = int(round(300.0 * money_scale))
	starting_stack = int(round(5000.0 * money_scale))
	my_stack = starting_stack
	opp_stack = starting_stack
	_build_deck(rng)
	my_hole = [deck.pop_back(), deck.pop_back()]
	opp_hole = [deck.pop_back(), deck.pop_back()]
	my_stack -= ante
	opp_stack -= ante
	pot = ante * 2
	to_call = 0
	log.append("Inleg betaald door beide spelers. Pot: %s." % _eur(pot))


func _build_deck(rng: RandomNumberGenerator) -> void:
	deck = []
	for suit in range(4):
		for rank in range(2, 15):
			deck.append({"rank": rank, "suit": suit})
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp


# ---------------------------------------------------------------- acties

func play(action: String, rng: RandomNumberGenerator) -> void:
	match action:
		"passen":
			folded_by_me = true
			finished = true
			log.append("Je legt je kaarten neer bij de %s." % street)
			return
		"meegaan":
			var cost := mini(to_call, my_stack)
			my_stack -= cost
			pot += cost
			to_call = 0
			log.append("Je gaat mee. Pot: %s." % _eur(pot))
		"verhogen":
			var raise_amt := maxi(mini(int(round(float(ante) * 2.0)), my_stack - to_call), 0)
			var cost := to_call + raise_amt
			my_stack -= cost
			pot += cost
			log.append("Je verhoogt met %s." % _eur(raise_amt))
			_opp_respond_to_raise(rng, raise_amt)
			if finished:
				return
	_advance_street(rng)


func _opp_respond_to_raise(rng: RandomNumberGenerator, raise_amt: int) -> void:
	var strength := _opp_hand_strength()
	if strength < 0.3 and rng.randf() < 0.55:
		folded_by_opp = true
		finished = true
		log.append("De tegenstander legt zich neer voor jouw verhoging!")
		return
	var cost := mini(raise_amt, opp_stack)
	opp_stack -= cost
	pot += cost
	to_call = 0
	log.append("De tegenstander betaalt mee.")


func _advance_street(rng: RandomNumberGenerator) -> void:
	if finished:
		return
	match street:
		"preflop":
			community.append(deck.pop_back())
			community.append(deck.pop_back())
			community.append(deck.pop_back())
			street = "flop"
			log.append("FLOP: %s" % cards_text(community))
		"flop":
			community.append(deck.pop_back())
			street = "turn"
			log.append("TURN: %s" % cards_text(community))
		"turn":
			community.append(deck.pop_back())
			street = "river"
			log.append("RIVER: %s" % cards_text(community))
		"river":
			finished = true
			street = "showdown"
			return
	var strength := _opp_hand_strength()
	if rng.randf() < strength * 0.6:
		var bet := mini(int(round(float(ante) * 1.5)), opp_stack)
		opp_stack -= bet
		pot += bet
		to_call = bet
		log.append("De tegenstander opent met een inzet van %s." % _eur(bet))
	else:
		to_call = 0


# ---------------------------------------------------------------- AI-sterkte

func _opp_hand_strength() -> float:
	if community.is_empty():
		var r1 := int(opp_hole[0].rank)
		var r2 := int(opp_hole[1].rank)
		var score := float(maxi(r1, r2)) + float(mini(r1, r2)) * 0.3
		if r1 == r2:
			score += 10.0
		if int(opp_hole[0].suit) == int(opp_hole[1].suit):
			score += 2.0
		return clampf(score / 40.0, 0.0, 1.0)
	var seven: Array = opp_hole + community
	var score: Array = best_hand(seven)
	var kicker := float(score[1]) if score.size() > 1 else 0.0
	return clampf(float(score[0]) / 8.0 + kicker / 200.0, 0.0, 1.0)


# ---------------------------------------------------------------- uitkomst

func outcome() -> Dictionary:
	if folded_by_me:
		var net := my_stack - starting_stack
		return {"effects": {"money": net},
			"txt": "Je legt je kaarten neer bij de %s. Verlies: %s." % [street, _eur(-net)]}
	if folded_by_opp:
		var net := (my_stack + pot) - starting_stack
		return {"effects": {"money": net, "new_client": true},
			"txt": "De tegenstander legt zich neer! Jij incasseert de pot (%s) én wint de rechten op het talent." % _eur(pot)}
	var my_best: Array = best_hand(my_hole + community)
	var opp_best: Array = best_hand(opp_hole + community)
	var cmp := compare_scores(my_best, opp_best)
	if cmp > 0:
		var net := (my_stack + pot) - starting_stack
		return {"effects": {"money": net, "new_client": true},
			"txt": "Showdown! Jij wint met %s tegen %s — de pot (%s) én het talent zijn voor jou." % [HAND_NAMES[my_best[0]], HAND_NAMES[opp_best[0]], _eur(pot)]}
	elif cmp < 0:
		var net := my_stack - starting_stack
		return {"effects": {"money": net},
			"txt": "Showdown! De tegenstander wint met %s tegen jouw %s. Verlies: %s." % [HAND_NAMES[opp_best[0]], HAND_NAMES[my_best[0]], _eur(-net)]}
	else:
		var net := (my_stack + int(pot / 2)) - starting_stack
		return {"effects": {"money": net},
			"txt": "Showdown! Gelijkspel (beiden %s). De pot wordt gedeeld." % HAND_NAMES[my_best[0]]}


# ---------------------------------------------------------------- weergave

func card_text(c: Dictionary) -> String:
	var r := int(c.rank)
	var rt := str(r) if r < 11 else str(RANK_NAMES[r])
	return "%s%s" % [rt, SUITS[int(c.suit)]]


func cards_text(cards: Array) -> String:
	var parts: Array = []
	for c in cards:
		parts.append(card_text(c))
	return " ".join(parts)


func _eur(n: int) -> String:
	var v := n
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-€" if v < 0 else "€") + out


# ---------------------------------------------------------------- handevaluatie
# Standaard pokerhandwaardering op de beste 5 van maximaal 7 kaarten. Score
# is een Array [categorie, tiebreak...]; hoger vergelijkt lexicografisch beter.

static func _rank_counts(cards: Array) -> Dictionary:
	var counts := {}
	for c in cards:
		var r := int(c.rank)
		counts[r] = int(counts.get(r, 0)) + 1
	return counts


static func _is_flush(cards: Array) -> bool:
	var suit := int(cards[0].suit)
	for c in cards:
		if int(c.suit) != suit:
			return false
	return true


static func _straight_high(cards: Array) -> int:
	var ranks: Array = []
	for c in cards:
		ranks.append(int(c.rank))
	ranks.sort()
	ranks.reverse()
	if ranks == [14, 5, 4, 3, 2]:
		return 5
	for i in range(ranks.size() - 1):
		if int(ranks[i]) - 1 != int(ranks[i + 1]):
			return 0
	return int(ranks[0])


static func evaluate5(cards: Array) -> Array:
	var counts := _rank_counts(cards)
	var groups: Array = []
	for r in counts:
		groups.append([int(counts[r]), int(r)])
	groups.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] > b[1])
	var flush := _is_flush(cards)
	var straight_high := _straight_high(cards)
	if straight_high > 0 and flush:
		return [8, straight_high]
	if int(groups[0][0]) == 4:
		return [7, groups[0][1], groups[1][1]]
	if int(groups[0][0]) == 3 and int(groups[1][0]) == 2:
		return [6, groups[0][1], groups[1][1]]
	if flush:
		var ranks: Array = []
		for c in cards:
			ranks.append(int(c.rank))
		ranks.sort()
		ranks.reverse()
		return [5] + ranks
	if straight_high > 0:
		return [4, straight_high]
	if int(groups[0][0]) == 3:
		var kickers: Array = []
		for g in groups:
			if int(g[0]) == 1:
				kickers.append(g[1])
		kickers.sort()
		kickers.reverse()
		return [3, groups[0][1]] + kickers
	if int(groups[0][0]) == 2 and int(groups[1][0]) == 2:
		return [2, groups[0][1], groups[1][1], groups[2][1]]
	if int(groups[0][0]) == 2:
		var kickers2: Array = []
		for g in groups:
			if int(g[0]) == 1:
				kickers2.append(g[1])
		kickers2.sort()
		kickers2.reverse()
		return [1, groups[0][1]] + kickers2
	var ranks2: Array = []
	for c in cards:
		ranks2.append(int(c.rank))
	ranks2.sort()
	ranks2.reverse()
	return [0] + ranks2


static func compare_scores(a: Array, b: Array) -> int:
	var n := maxi(a.size(), b.size())
	for i in range(n):
		var av := int(a[i]) if i < a.size() else 0
		var bv := int(b[i]) if i < b.size() else 0
		if av != bv:
			return 1 if av > bv else -1
	return 0


static func best_hand(cards7: Array) -> Array:
	var best: Array = []
	var n := cards7.size()
	for a in range(n):
		for b in range(a + 1, n):
			for c in range(b + 1, n):
				for d in range(c + 1, n):
					for e in range(d + 1, n):
						var hand := [cards7[a], cards7[b], cards7[c], cards7[d], cards7[e]]
						var score := evaluate5(hand)
						if best.is_empty() or compare_scores(score, best) > 0:
							best = score
	return best
