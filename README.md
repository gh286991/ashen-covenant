# Ashen Covenant

A self-contained Godot 4.5 dark fantasy action RPG demo with a complete combat loop, loot, upgrades, checkpoints, a multi-phase boss, and a unified hand-painted HD art set.

## Dungeon

- Twelve named spaces across a main nave, ritual court, two combat branches, hidden side caches, shortcut stairs, a sealed gate passage, and the Warden's sanctum
- Three branch objectives that unlock two return shortcuts and the final boss gate
- Four spike-trap zones, three loot chests, six breakable props, room discovery, and a live exploration minimap
- Authored walkable regions and blockers keep the player, enemies, and projectiles inside the visible architecture

## Controls

- Left mouse on ground: pathfind and move
- Left mouse on an enemy: pursue and attack automatically
- F: manual weapon attack fallback
- Right mouse / Q: Ash Nova
- Space: Shadow Step
- R: drink a health potion
- Tab: character and loot sheet
- Esc: pause

## Art

- Four-direction hand-painted sprites for the player, Ash Ghouls, Void Wraiths, Grave Brutes, and the Ashen Warden
- A matching Soul Anchor prop and four illustrated ability icons
- An original gothic altar HUD with an angel-bound life orb and demon-bound essence orb
- A hand-painted 2200×1400 catacomb map plus matching chests, sarcophagi, braziers, urns, bones, columns, fences, and spike traps
- Procedural combat effects retained for motion, glow, telegraphs, and readability
- Raw generations, processed transparent sheets, individual frames, prompts, and pipeline metadata are all preserved under `assets/`

The generated art is included locally, so the demo has no runtime network or font dependencies. See `assets/ART_DIRECTION.md` for the palette, lighting, and asset-pipeline rules.
