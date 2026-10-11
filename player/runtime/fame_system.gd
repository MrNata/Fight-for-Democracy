extends RefCounted
## Resource arithmetic shared by every fighter; no negative cost or overflow.
static func gain(value: float, amount: float) -> float:
	return clampf(value + maxf(0.0,amount),0.0,100.0)

static func can_spend(value: float, cost: float) -> bool:
	return cost >= 0.0 and cost <= 100.0 and value >= cost

static func spend(value: float, cost: float) -> float:
	return clampf(value-cost,0.0,100.0) if can_spend(value,cost) else value
