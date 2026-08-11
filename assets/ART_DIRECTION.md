# Ashen Covenant — Art Direction

## Visual identity

Clean HD hand-painted dark gothic fantasy viewed from a top-down three-quarter camera. Silhouettes stay broad and readable at gameplay scale, with restrained surface detail and strong value separation.

## Palette and lighting

- Charcoal stone and near-black iron form the world base.
- Oxblood red identifies the player covenant and soul-binding objects.
- Bone, corpse grey, and tarnished brass carry character detail.
- Cool violet identifies void magic and ranged threats.
- Warm upper-left rim light separates subjects from the floor; cool violet fill keeps the shadow side readable.

## Gameplay hierarchy

- Player: oxblood hood, bone mask, pale cleaver edge.
- Ghoul: low corpse-grey silhouette with yellow eye accents.
- Wraith: tall violet shroud and bright magical core.
- Brute: wide rust-armored mass, roughly 1.3× normal-enemy height.
- Ashen Warden: horned ember-black plate, roughly 1.5× player height.
- Soul Anchor: black iron reliquary with a crimson core and a unique vertical silhouette.

## Runtime rules

- Directional order is south, west, east, north.
- Character art is foot-anchored to the physics origin; procedural ellipses provide contact shadows.
- Generated images are filtered linearly with mipmaps for clean HD downscaling.
- Procedural arcs, rings, projectiles, flashes, and telegraphs remain above the painted art so attacks stay legible.
- UI icons use the same bone, oxblood, violet, and brass palette as the world.

## Asset provenance and processing

All painted assets in this demo were generated specifically for Ashen Covenant from the same player style reference. Original generations and exact prompts are in `assets/raw/`. The sprite pipeline removed the key-color background, normalized framing, sliced the sheets, and produced metadata in each output folder. Every shipped frame passed the edge-touch quality gate (`edge_touch_frames: []`).
