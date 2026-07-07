class_name Economy
extends RefCounted
# Economy (design/經濟與債務.md): tax, capital gains, interest ladder, debt consequence,
# national-treasure emergency sale. Pure logic — mutates GameState in place, returns
# itemized report Dictionaries for the view/telemetry layer.
#
# Settle order (fixed): production -> tax -> capital gains -> interest -> debt consequence.
# Money is integer; tax/capital-gains floor, interest rounds toward MORE debt (ceil of magnitude).

const SECURITIES_TIER: int = 6            # bank line tier 6 = 證券市場 (capital gains unlock)
const CAPITAL_GAINS_PERCENT: int = 2      # +treasury×2% per generation when positive
const BASE_INTEREST_PERCENT: int = 10     # on negative treasury, per generation
const DEBT_HAPPINESS_PENALTY: int = -5    # pre-國債司 debt consequence (幸福 −5／回合)
const TREASURE_FLAG: StringName = &"treasures"   # state.flags inventory (count of unsold 國寶)
const TREASURE_BASE_VALUE: int = 30       # sale price = 30 × Era.coeff (design gives no number)


static func settle(state: GameState) -> Dictionary:
	# Full end-of-generation settlement. Applies, IN THIS ORDER:
	# 1. production  2. tax  3. capital gains  4. interest  5. debt consequence.
	var report: Dictionary = {}
	var treasury_before: int = state.treasury

	# 1. production (Operations owns the numbers; we apply them to the axes).
	var prod: Dictionary = Operations.production(state)
	var pop_before: int = state.population
	var pop_gain: int = int(prod["population"])
	var pop_cap: int = int(prod["pop_cap"])
	if pop_gain > 0:
		# Growth respects pop_cap but never culls a population already above it.
		state.population = maxi(pop_before, mini(pop_before + pop_gain, pop_cap))
	else:
		state.population = pop_before + pop_gain
	var happiness_before: int = state.happiness
	Happiness.adjust(state, int(prod["happiness"]))
	state.culture += int(prod["culture"])
	state.tech += int(prod["tech"])
	state.treasury += int(prod["income"])
	report["production"] = {
		"raw": prod,
		"population_applied": state.population - pop_before,
		"happiness_applied": state.happiness - happiness_before,
		"culture": int(prod["culture"]),
		"tech": int(prod["tech"]),
		"income": int(prod["income"]),
		"pop_cap": pop_cap,
	}

	# 2. tax (人口×稅率, floored to integer money).
	var tax: int = tax_income(state)
	state.treasury += tax
	report["tax"] = tax
	report["tax_rate"] = tax_rate(state)

	# 3. capital gains (證券市場: bank tier 6, positive treasury only, capped at 50% of this tax).
	var gains: int = capital_gains(state, tax)
	state.treasury += gains
	report["capital_gains"] = gains

	# 4. interest on negative treasury (ceil of magnitude — rounds toward more debt).
	var interest: int = interest_due(state)
	state.treasury -= interest
	report["interest"] = interest
	report["interest_rate"] = interest_rate(state)

	# 5. debt consequence. 國債司 building permanently switches the consequence channel
	# from "-5 happiness" to unrest weight (Unrest module consumes debt_unrest_mode).
	if state.buildings.has(&"debt_office"):
		state.debt_unrest_mode = true
	var in_debt: bool = state.treasury < 0
	var debt_happiness_delta: int = 0
	if in_debt and not state.debt_unrest_mode:
		var h_before: int = state.happiness
		Happiness.adjust(state, DEBT_HAPPINESS_PENALTY)
		debt_happiness_delta = state.happiness - h_before
	report["debt"] = {
		"in_debt": in_debt,
		"unrest_mode": state.debt_unrest_mode,
		"happiness_delta": debt_happiness_delta,
	}

	report["treasury_before"] = treasury_before
	report["treasury_after"] = state.treasury
	return report


static func tax_rate(state: GameState) -> float:
	# Base 1.0; 國策「官僚體系」+10%.
	if state.policies.has(&"bureaucracy"):
		return 1.1
	return 1.0


static func tax_income(state: GameState) -> int:
	# population × tax rate, floored (integer money).
	var base: int = maxi(state.population, 0)
	if state.policies.has(&"bureaucracy"):
		@warning_ignore("integer_division")
		return base * 11 / 10
	return base


static func capital_gains(state: GameState, tax_this_gen: int) -> int:
	# Only while treasury is positive AND the bank line reached tier 6 (證券市場).
	# +treasury×2% (floor), capped at 50% of this generation's tax (floor).
	if state.treasury <= 0:
		return 0
	if int(state.buildings.get(&"bank", 0)) < SECURITIES_TIER:
		return 0
	@warning_ignore("integer_division")
	var gain: int = state.treasury * CAPITAL_GAINS_PERCENT / 100
	@warning_ignore("integer_division")
	var cap: int = maxi(tax_this_gen, 0) / 2
	return mini(gain, cap)


static func interest_rate(state: GameState) -> float:
	# Base 10%; bank line tiers 1..5 lower it to 9/8/7/6/5% (tier 6 keeps 5%);
	# 國債司 building halves the final rate again.
	return float(_interest_permille(state)) / 1000.0


static func interest_due(state: GameState) -> int:
	# Interest charged this settlement on a negative treasury; 0 when non-negative.
	# Rounded toward more debt: ceil(|treasury| × rate), exact integer math (per-mille).
	if state.treasury >= 0:
		return 0
	var magnitude: int = -state.treasury
	var permille: int = _interest_permille(state)
	@warning_ignore("integer_division")
	return (magnitude * permille + 999) / 1000


static func sell_treasure(state: GameState) -> Dictionary:
	# 國寶 emergency cash: irreversibly sell one treasure from the flags inventory.
	# (+culture was granted at acquisition time by MapNodes, not here.)
	var count: int = int(state.flags.get(TREASURE_FLAG, 0))
	if count <= 0:
		return {"sold": false, "amount": 0, "treasures_left": count}
	var amount: int = TREASURE_BASE_VALUE * Era.coeff(state.generation)
	state.flags[TREASURE_FLAG] = count - 1
	state.treasury += amount
	return {"sold": true, "amount": amount, "treasures_left": count - 1}


static func _interest_permille(state: GameState) -> int:
	# Rate ladder in per-mille so the halved rates (e.g. 4.5%) stay exact integers.
	var percent: int = BASE_INTEREST_PERCENT
	var bank_tier: int = int(state.buildings.get(&"bank", 0))
	if bank_tier >= 1:
		percent = BASE_INTEREST_PERCENT - mini(bank_tier, 5)
	var permille: int = percent * 10
	if state.buildings.has(&"debt_office"):
		@warning_ignore("integer_division")
		permille = permille / 2
	return permille
