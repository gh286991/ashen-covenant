class_name DamageFormula
extends RefCounted

static func mitigate(raw_damage: float, armor: float) -> float:
	var safe_armor := maxf(0.0, armor)
	return maxf(1.0, raw_damage * (100.0 / (100.0 + safe_armor)))

static func roll_player_damage(
	base_damage: float,
	level: int,
	gear_damage: float,
	crit_chance: float,
	multiplier: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	var progression := pow(1.12, clampi(level - 1, 0, 30))
	var amount := (base_damage * progression + gear_damage) * multiplier
	var critical := rng.randf() < clampf(crit_chance, 0.0, 0.75)
	if critical:
		amount *= 1.75
	return {"amount": maxf(1.0, amount), "critical": critical}

