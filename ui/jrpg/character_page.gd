class_name JrpgCharacterPage
extends PanelContainer

signal attribute_spend_requested(attribute: StringName)

@onready var level_label: Label = %CharacterLevel
@onready var exp_bar: ProgressBar = %CharacterExpBar
@onready var exp_value: Label = %CharacterExpValue
@onready var points_label: Label = %AttributePoints
@onready var strength_value: Label = %StrengthValue
@onready var vitality_value: Label = %VitalityValue
@onready var agility_value: Label = %AgilityValue
@onready var luck_value: Label = %LuckValue
@onready var strength_add: Button = %StrengthAdd
@onready var vitality_add: Button = %VitalityAdd
@onready var agility_add: Button = %AgilityAdd
@onready var luck_add: Button = %LuckAdd
@onready var attack_value: Label = %DerivedAttack
@onready var health_value: Label = %DerivedHealth
@onready var speed_value: Label = %DerivedSpeed
@onready var critical_value: Label = %DerivedCritical


func _ready() -> void:
	strength_add.pressed.connect(attribute_spend_requested.emit.bind(&"strength"))
	vitality_add.pressed.connect(attribute_spend_requested.emit.bind(&"vitality"))
	agility_add.pressed.connect(attribute_spend_requested.emit.bind(&"agility"))
	luck_add.pressed.connect(attribute_spend_requested.emit.bind(&"luck"))


func apply_progression(snapshot: Dictionary) -> void:
	var points := int(snapshot.get("attribute_points", 0))
	level_label.text = "LV. %02d" % int(snapshot.get("level", 1))
	exp_bar.value = float(snapshot.get("experience_ratio", 0.0)) * 100.0
	exp_value.text = "%d / %d" % [
		int(snapshot.get("experience", 0)),
		int(snapshot.get("experience_required", 100)),
	]
	points_label.text = "可用能力點　%d" % points
	strength_value.text = str(int(snapshot.get("strength", 10)))
	vitality_value.text = str(int(snapshot.get("vitality", 10)))
	agility_value.text = str(int(snapshot.get("agility", 10)))
	luck_value.text = str(int(snapshot.get("luck", 10)))
	strength_add.disabled = points <= 0 or int(snapshot.get("strength", 10)) >= 99
	vitality_add.disabled = points <= 0 or int(snapshot.get("vitality", 10)) >= 99
	agility_add.disabled = points <= 0 or int(snapshot.get("agility", 10)) >= 99
	luck_add.disabled = points <= 0 or int(snapshot.get("luck", 10)) >= 99
	attack_value.text = "攻擊　%d" % roundi(20.0 + float(snapshot.get("attack_damage_bonus", 0.0)))
	health_value.text = "生命　%d" % roundi(100.0 + float(snapshot.get("max_health_bonus", 0.0)))
	speed_value.text = "移速　%.2f" % (5.4 + float(snapshot.get("move_speed_bonus", 0.0)))
	critical_value.text = "暴擊　%d%%" % roundi(float(snapshot.get("critical_chance", 0.05)) * 100.0)
