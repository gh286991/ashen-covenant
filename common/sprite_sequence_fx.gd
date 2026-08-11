class_name SpriteSequenceFX
extends Node2D

## Fire-and-forget playback for the imported OpenGameArt spell-frame sequences.
## SpriteFrames are built and cached once during the title screen, then shared by
## every instance so combat does not perform disk I/O in its hot path.

enum EffectID {
	BLUE_TOP,
	SWORD_FIRE,
	FIREBALL,
	FIRE_RUNE,
	FIRE_SCISSORS,
	EATER_FIRE,
	ENERGY_BALL,
	LIGHTNING_BALL,
	BLACK_EXPLOSION,
	BLADE_IMPACT,
	BLADE_CRIT,
}

const ANIMATION_NAME := &"play"
const EFFECT_SPECS := {
	EffectID.BLUE_TOP: {"path": "res://assets/effects/third_party/opengameart_2d_spell_effects/fx1_blue_topEffect/spell_bluetop_1_%d.png", "frames": 22, "fps": 36.0},
	EffectID.SWORD_FIRE: {"path": "res://assets/effects/third_party/opengameart_2d_spell_effects/fx2_swordFire/spell_decap_1_zoomblur_%d.png", "frames": 35, "fps": 54.0},
	EffectID.FIREBALL: {"path": "res://assets/effects/third_party/opengameart_2d_spell_effects/fx3_fireBall/spell_decap_2_ball_%d.png", "frames": 20, "fps": 30.0},
	EffectID.FIRE_RUNE: {"path": "res://assets/effects/third_party/opengameart_2d_spell_effects/fx4_sign_of_fire/spell_signoffire_%d.png", "frames": 20, "fps": 30.0},
	EffectID.FIRE_SCISSORS: {"path": "res://assets/effects/third_party/opengameart_2d_spell_effects/fx5_fire_scissors/spell_twoflames_%d.png", "frames": 13, "fps": 32.0},
	EffectID.EATER_FIRE: {"path": "res://assets/effects/third_party/opengameart_2d_spell_effects/fx6_eaterFire/spell_spiderfire_%d.png", "frames": 20, "fps": 30.0},
	EffectID.ENERGY_BALL: {"path": "res://assets/effects/third_party/opengameart_2d_spell_effects/fx7_energyBall/aura_test_1_32_%d.png", "frames": 32, "fps": 42.0},
	EffectID.LIGHTNING_BALL: {"path": "res://assets/effects/third_party/opengameart_2d_spell_effects/fx8_lighteningBall/lighteningball_1_20_%d.png", "frames": 20, "fps": 36.0},
	EffectID.BLACK_EXPLOSION: {"path": "res://assets/effects/third_party/opengameart_2d_spell_effects/fx10_blackExplosion/smoke_black_1_19_%d.png", "frames": 19, "fps": 28.0},
	# CC0 blade flashes by Reactorcore. Each option is held for a few frames,
	# then freed, so the impact has variation without a persistent particle node.
	EffectID.BLADE_IMPACT: {"paths": [
		"res://assets/effects/third_party/opengameart_melee_flashes/RC Art - Muzzle Effects/Sprites/Blade Red/BladeRed_13.png",
		"res://assets/effects/third_party/opengameart_melee_flashes/RC Art - Muzzle Effects/Sprites/Blade Red/BladeRed_25.png",
		"res://assets/effects/third_party/opengameart_melee_flashes/RC Art - Muzzle Effects/Sprites/Blade Red/BladeRed_37.png",
		"res://assets/effects/third_party/opengameart_melee_flashes/RC Art - Muzzle Effects/Sprites/Blade Red/BladeRed_48.png",
	], "hold": 4, "fps": 32.0},
	EffectID.BLADE_CRIT: {"paths": [
		"res://assets/effects/third_party/opengameart_melee_flashes/RC Art - Muzzle Effects/Sprites/Blade Red/BladeRed_25.png",
		"res://assets/effects/third_party/opengameart_melee_flashes/RC Art - Muzzle Effects/Sprites/Blade Red/BladeRed_37.png",
		"res://assets/effects/third_party/opengameart_melee_flashes/RC Art - Muzzle Effects/Sprites/Blade Red/BladeRed_48.png",
	], "hold": 6, "fps": 38.0},
}

static var _sprite_frames_cache: Dictionary = {}
static var _variation_seed := 0

var effect_id: EffectID = EffectID.SWORD_FIRE
var tint := Color.WHITE
var display_scale := 1.0
var playback_speed := 1.0
var should_loop := false
var variation_index := 0
var animated_sprite: AnimatedSprite2D

func setup(effect: EffectID, color: Color = Color.WHITE, scale_factor: float = 1.0, speed: float = 1.0, loop: bool = false, variation: int = -1) -> SpriteSequenceFX:
	effect_id = effect
	tint = color
	display_scale = maxf(0.01, scale_factor)
	playback_speed = maxf(0.01, speed)
	should_loop = loop
	var spec: Dictionary = EFFECT_SPECS.get(effect_id, {})
	var path_options: Array = spec.get("paths", [])
	if not path_options.is_empty():
		if variation < 0:
			_variation_seed += 1
			variation_index = _variation_seed % path_options.size()
		else:
			variation_index = variation % path_options.size()
	return self

static func warm_gameplay_effects() -> void:
	for effect in EFFECT_SPECS:
		var spec: Dictionary = EFFECT_SPECS[effect]
		var path_options: Array = spec.get("paths", [])
		if path_options.is_empty():
			_sprite_frames_for(effect as EffectID, false)
		else:
			for variation in path_options.size():
				_sprite_frames_for(effect as EffectID, false, variation)
	_sprite_frames_for(EffectID.FIREBALL, true)

func _ready() -> void:
	z_index = 31
	z_as_relative = false
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "SpellFrames"
	animated_sprite.sprite_frames = _sprite_frames_for(effect_id, should_loop, variation_index)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	animated_sprite.modulate = tint
	animated_sprite.speed_scale = playback_speed
	add_child(animated_sprite)
	if animated_sprite.sprite_frames == null or animated_sprite.sprite_frames.get_frame_count(ANIMATION_NAME) == 0:
		queue_free()
		return
	scale = Vector2.ONE * display_scale
	if not should_loop:
		animated_sprite.animation_finished.connect(queue_free)
	animated_sprite.play(ANIMATION_NAME)
	animated_sprite.set_frame_and_progress(0, 0.0)

static func _sprite_frames_for(effect: EffectID, loop: bool, variation: int = 0) -> SpriteFrames:
	var spec: Dictionary = EFFECT_SPECS.get(effect, {})
	var path_options: Array = spec.get("paths", [])
	var selected_variation := variation % path_options.size() if not path_options.is_empty() else 0
	var cache_key := "%d_%s_%d" % [effect, "loop" if loop else "once", selected_variation]
	if _sprite_frames_cache.has(cache_key):
		return _sprite_frames_cache[cache_key] as SpriteFrames
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation(ANIMATION_NAME)
	sprite_frames.set_animation_loop(ANIMATION_NAME, loop)
	sprite_frames.set_animation_speed(ANIMATION_NAME, float(spec.get("fps", 30.0)))
	if not path_options.is_empty():
		var texture := load(String(path_options[selected_variation])) as Texture2D
		if texture:
			for frame_number in range(maxi(1, int(spec.get("hold", 1)))):
				sprite_frames.add_frame(ANIMATION_NAME, texture)
	else:
		var path_format := String(spec.get("path", ""))
		var first_frame := int(spec.get("first", 1))
		for frame_offset in range(int(spec.get("frames", 0))):
			var texture := load(path_format % (first_frame + frame_offset)) as Texture2D
			if texture:
				sprite_frames.add_frame(ANIMATION_NAME, texture)
	_sprite_frames_cache[cache_key] = sprite_frames
	return sprite_frames
