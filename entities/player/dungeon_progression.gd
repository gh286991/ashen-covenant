class_name DungeonProgression
extends Node

signal progression_changed(snapshot: Dictionary)
signal leveled_up(new_level: int, attribute_points_awarded: int, skill_points_awarded: int)
signal attribute_changed(attribute: StringName, new_value: int)
signal skill_unlocked(skill_id: StringName)
signal skill_equipped(slot_index: int, skill_id: StringName)

const MAX_LEVEL := 99
const ATTRIBUTE_POINTS_PER_LEVEL := 5
const SKILL_POINTS_PER_LEVEL := 1
const VALID_ATTRIBUTES: Array[StringName] = [&"strength", &"vitality", &"agility", &"luck"]
const SKILL_COSTS := {
	&"ash_slash": 0,
	&"soul_orb": 1,
	&"shadow_step": 1,
}
const SKILL_PREREQUISITES := {
	&"soul_orb": &"ash_slash",
	&"shadow_step": &"ash_slash",
}

@export_category("Starting Progression")
@export_range(1, MAX_LEVEL, 1) var level := 1
@export_range(0, 999999, 1) var experience := 0
@export_range(0, 99, 1) var attribute_points := 5
@export_range(0, 99, 1) var skill_points := 1

@export_category("Starting Attributes")
@export_range(1, 99, 1) var strength := 10
@export_range(1, 99, 1) var vitality := 10
@export_range(1, 99, 1) var agility := 10
@export_range(1, 99, 1) var luck := 10

var _unlocked_skills: Array[StringName] = [&"ash_slash"]
var _skill_loadout: Array[StringName] = [&"ash_slash", &"", &"", &""]


func experience_required() -> int:
	return mini(2500, 100 + maxi(0, level - 1) * 50)


func experience_ratio() -> float:
	return clampf(float(experience) / float(maxi(1, experience_required())), 0.0, 1.0)


func add_experience(amount: int) -> int:
	if amount <= 0 or level >= MAX_LEVEL:
		return 0
	experience += amount
	var levels_gained := 0
	while level < MAX_LEVEL and experience >= experience_required():
		experience -= experience_required()
		level += 1
		levels_gained += 1
		attribute_points += ATTRIBUTE_POINTS_PER_LEVEL
		skill_points += SKILL_POINTS_PER_LEVEL
	if levels_gained > 0:
		# Emit one aggregated presentation event. A large EXP reward can cross
		# several thresholds in one frame; the UI must show the real total award
		# instead of repeatedly replacing the same animation with single-level data.
		leveled_up.emit(
			level,
			ATTRIBUTE_POINTS_PER_LEVEL * levels_gained,
			SKILL_POINTS_PER_LEVEL * levels_gained
		)
	if level >= MAX_LEVEL:
		experience = 0
	_emit_progression_changed()
	return levels_gained


func spend_attribute_point(attribute: StringName) -> bool:
	if attribute_points <= 0 or attribute not in VALID_ATTRIBUTES:
		return false
	var current_value := get_attribute(attribute)
	if current_value >= 99:
		return false
	attribute_points -= 1
	_set_attribute(attribute, current_value + 1)
	attribute_changed.emit(attribute, current_value + 1)
	_emit_progression_changed()
	return true


func get_attribute(attribute: StringName) -> int:
	match attribute:
		&"strength":
			return strength
		&"vitality":
			return vitality
		&"agility":
			return agility
		&"luck":
			return luck
		_:
			return 0


func can_unlock_skill(skill_id: StringName) -> bool:
	if skill_id in _unlocked_skills or not SKILL_COSTS.has(skill_id):
		return false
	var prerequisite: StringName = SKILL_PREREQUISITES.get(skill_id, &"")
	if prerequisite != &"" and prerequisite not in _unlocked_skills:
		return false
	return skill_points >= int(SKILL_COSTS[skill_id])


func unlock_skill(skill_id: StringName) -> bool:
	if not can_unlock_skill(skill_id):
		return false
	skill_points -= int(SKILL_COSTS[skill_id])
	_unlocked_skills.append(skill_id)
	skill_unlocked.emit(skill_id)
	_emit_progression_changed()
	return true


func equip_skill(slot_index: int, skill_id: StringName) -> bool:
	if slot_index < 0 or slot_index >= _skill_loadout.size():
		return false
	if skill_id not in _unlocked_skills:
		return false
	_skill_loadout[slot_index] = skill_id
	skill_equipped.emit(slot_index, skill_id)
	_emit_progression_changed()
	return true


func get_snapshot() -> Dictionary:
	var unlocked: Array[String] = []
	for skill_id in _unlocked_skills:
		unlocked.append(String(skill_id))
	var loadout: Array[String] = []
	for skill_id in _skill_loadout:
		loadout.append(String(skill_id))
	var skill_rules := {}
	for skill_id: StringName in SKILL_COSTS:
		var prerequisite: StringName = SKILL_PREREQUISITES.get(skill_id, &"")
		skill_rules[String(skill_id)] = {
			"point_cost": int(SKILL_COSTS[skill_id]),
			"prerequisite": String(prerequisite),
			"unlocked": skill_id in _unlocked_skills,
			"can_unlock": can_unlock_skill(skill_id),
		}
	return {
		"level": level,
		"experience": experience,
		"experience_required": experience_required(),
		"experience_ratio": experience_ratio(),
		"attribute_points": attribute_points,
		"skill_points": skill_points,
		"strength": strength,
		"vitality": vitality,
		"agility": agility,
		"luck": luck,
		"attack_damage_bonus": float(maxi(0, strength - 10)) * 2.0,
		"max_health_bonus": float(maxi(0, vitality - 10)) * 8.0,
		"move_speed_bonus": float(maxi(0, agility - 10)) * 0.08,
		"attack_cooldown_multiplier": clampf(1.0 - float(maxi(0, agility - 10)) * 0.015, 0.65, 1.0),
		"critical_chance": clampf(float(luck) * 0.005, 0.0, 0.5),
		"unlocked_skills": unlocked,
		"skill_loadout": loadout,
		"skill_rules": skill_rules,
	}


func emit_current_state() -> void:
	_emit_progression_changed()


func _set_attribute(attribute: StringName, value: int) -> void:
	match attribute:
		&"strength":
			strength = value
		&"vitality":
			vitality = value
		&"agility":
			agility = value
		&"luck":
			luck = value


func _emit_progression_changed() -> void:
	progression_changed.emit(get_snapshot())
