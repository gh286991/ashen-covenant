class_name LootItem
extends Resource

enum Rarity { COMMON, MAGIC, RARE, LEGENDARY }

const RARITY_COLORS: Array[Color] = [
	Color("c6c0b1"), Color("5caeff"), Color("d9a7ff"), Color("ffb43b")
]
const RARITY_NAMES: Array[String] = ["Common", "Magic", "Rare", "Legendary"]
const WEAPON_BASES: Array[String] = ["Ash Blade", "Grave Cleaver", "Oathbreaker", "Cinder Fang"]
const ARMOR_BASES: Array[String] = ["Penitent Mail", "Crypt Mantle", "Iron Reliquary", "Warden Plate"]
const CHARM_BASES: Array[String] = ["Blood Sigil", "Bone Rosary", "Void Eye", "Ember Seal"]
const PREFIXES: Array[String] = ["Forsaken", "Sanguine", "Hollow", "Vengeful", "Blackened"]

@export var item_id: String = ""
@export var display_name: String = "Worn Relic"
@export var slot: StringName = &"weapon"
@export var rarity: Rarity = Rarity.COMMON
@export var item_level: int = 1
@export var power: int = 1
@export var bonus_damage: int = 0
@export var bonus_health: int = 0
@export var bonus_mana: int = 0
@export var bonus_crit: float = 0.0

static func roll(level: int, rng: RandomNumberGenerator, forced_slot: StringName = &"") -> LootItem:
	var item := LootItem.new()
	item.item_level = maxi(1, level)
	var rarity_roll := rng.randf()
	if rarity_roll < 0.04:
		item.rarity = Rarity.LEGENDARY
	elif rarity_roll < 0.17:
		item.rarity = Rarity.RARE
	elif rarity_roll < 0.46:
		item.rarity = Rarity.MAGIC
	else:
		item.rarity = Rarity.COMMON
	var slots: Array[StringName] = [&"weapon", &"armor", &"charm"]
	item.slot = forced_slot if forced_slot != &"" else slots[rng.randi_range(0, slots.size() - 1)]
	var bases: Array[String]
	match item.slot:
		&"armor": bases = ARMOR_BASES
		&"charm": bases = CHARM_BASES
		_: bases = WEAPON_BASES
	var rarity_scale := 1.0 + float(item.rarity) * 0.55
	item.power = maxi(1, int((3.0 + level * 2.2) * rarity_scale + rng.randf_range(0.0, 4.0)))
	item.display_name = bases[rng.randi_range(0, bases.size() - 1)]
	if item.rarity >= Rarity.MAGIC:
		item.display_name = "%s %s" % [PREFIXES[rng.randi_range(0, PREFIXES.size() - 1)], item.display_name]
	match item.slot:
		&"weapon":
			item.bonus_damage = item.power
			item.bonus_crit = float(item.rarity) * 0.015
		&"armor":
			item.bonus_health = item.power * 6
		&"charm":
			item.bonus_mana = item.power * 3
			item.bonus_crit = 0.01 + float(item.rarity) * 0.02
	item.item_id = "%s_%d_%d" % [item.slot, Time.get_ticks_usec(), rng.randi()]
	return item

func rarity_color() -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]

func rarity_name() -> String:
	return RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)]

func score() -> float:
	return float(bonus_damage * 8 + bonus_health + bonus_mana * 2) + bonus_crit * 500.0

func to_dict() -> Dictionary:
	return {
		"id": item_id, "name": display_name, "slot": String(slot), "rarity": int(rarity),
		"level": item_level, "power": power, "damage": bonus_damage,
		"health": bonus_health, "mana": bonus_mana, "crit": bonus_crit
	}

static func from_dict(data: Dictionary) -> LootItem:
	var item := LootItem.new()
	item.item_id = str(data.get("id", "restored_item"))
	item.display_name = str(data.get("name", "Restored Relic"))
	item.slot = StringName(data.get("slot", "weapon"))
	item.rarity = clampi(int(data.get("rarity", 0)), 0, Rarity.size() - 1) as Rarity
	item.item_level = maxi(1, int(data.get("level", 1)))
	item.power = maxi(1, int(data.get("power", 1)))
	item.bonus_damage = maxi(0, int(data.get("damage", 0)))
	item.bonus_health = maxi(0, int(data.get("health", 0)))
	item.bonus_mana = maxi(0, int(data.get("mana", 0)))
	item.bonus_crit = clampf(float(data.get("crit", 0.0)), 0.0, 0.5)
	return item
