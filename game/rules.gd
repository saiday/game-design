class_name Rules
## Pure, static game rules — no GUI, no nodes — so they're unit-testable headless.

## Plays `card` against `state` and returns the resulting NEW state:
## spends the card's energy cost and grants its gold reward.
static func play_card(state: GameState, card: Card) -> GameState:
	var next := state.duplicate()
	next.energy -= card.cost
	next.gold += card.reward
	return next
