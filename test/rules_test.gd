extends GdUnitTestSuite
## M1 Part-A gate: the pure `play_card` rule. Logic only — runs headless.
## Contract: playing a card spends its energy cost, grants its gold reward,
## and returns a NEW state without mutating the caller's (purity).

func test_play_card_spends_energy_and_grants_gold() -> void:
	var before := GameState.new(3, 0)
	var card := Card.new(1, 5)
	var after := Rules.play_card(before, card)
	assert_int(after.energy).is_equal(2)
	assert_int(after.gold).is_equal(5)

func test_play_card_does_not_mutate_input_state() -> void:
	var before := GameState.new(3, 0)
	var card := Card.new(1, 5)
	Rules.play_card(before, card)
	assert_int(before.energy).is_equal(3)
	assert_int(before.gold).is_equal(0)
