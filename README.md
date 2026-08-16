# Ashen Covenant

A self-contained Godot 4.5 dark fantasy action RPG demo with a complete combat loop, loot, upgrades, checkpoints, a multi-phase boss, and a unified hand-painted HD art set.

## Dungeon

- A purchased Old Prison World Pack layout with four exploration zones: the Iron Arrival, Silent Cells, Gearworks, and Bloodworks
- Three soul-anchor objectives unlock two return shortcuts and the sealed Warden gate
- The Keeper's Sanctum is the final area, where the Ashen Warden becomes the dungeon boss
- Four spike-trap zones, three loot chests, six breakable prison props, room discovery, and a live exploration minimap
- Authored walkable regions and blockers keep the player, enemies, and projectiles inside the visible prison architecture

## Controls

- Left mouse on ground: pathfind and move
- Left mouse on an enemy: pursue and attack automatically
- F: Cleave — a quick three-hit weapon combo
- Right mouse / Q: Ash Nova — an area burst that knocks back and slows enemies
- Space: Shadow Step — an invulnerable dash that rends enemies at departure
- R: Blood Vial — restore life from a limited supply
- Tab: character and loot sheet
- Esc: pause

## Art

- Old Prison tiles, props, prison gates, and the original Tiled source are preserved under `assets/old_prison/`; the runtime map is assembled as editable `TileMapLayer` layers

- Four-direction hand-painted sprites for the player, Ash Ghouls, Void Wraiths, Grave Brutes, and the Ashen Warden
- A matching Soul Anchor prop and four illustrated ability icons
- An original gothic altar HUD with an angel-bound life orb and demon-bound essence orb
- Original hand-painted combat characters, Soul Anchor art, HUD illustrations, and effects remain available alongside the new prison environment
- Procedural combat effects retained for motion, glow, telegraphs, and readability
- Raw generations, processed transparent sheets, individual frames, prompts, and pipeline metadata are all preserved under `assets/`

The generated art is included locally, so the demo has no runtime network or font dependencies. See `assets/ART_DIRECTION.md` for the palette, lighting, and asset-pipeline rules.

## Audio

- CC0-licensed dungeon ambience and boss music crossfade between exploration and boss states.
- CC0-licensed effects reinforce weapon swings and impacts, Ash Nova, Shadow Step, enemy attacks and casts, anchors, loot, potions, level-ups, UI confirmations, chests, and major boss outcomes.
- Music automatically softens while the character sheet, skill tree, or pause screen is open.
- See `assets/audio/ATTRIBUTION.md` for the exact source and license of every audio file.
