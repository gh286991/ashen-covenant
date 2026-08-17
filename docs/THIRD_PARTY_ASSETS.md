# Third-party game assets

## Vermilion Annex Tileset

- Source: [Tiny Top Down Pack by Screaming Brain Studios](https://opengameart.org/content/tiny-top-down-pack)
- Imported file: `assets/tiles/third_party/sbs_tiny_top_down/Tiny Top Down 32x32.png`
- Licence: CC0 / Public Domain (the original `License.txt` is included beside the asset)
- Use: `assets/tiles/vermilion_annex_32x32.tres` and `levels/vermilion_annex_tilemap.tscn`

The original pack includes 100 seamless 32×32 tiles and a Tiled example map. Attribution is not required, but the source is recorded here for project provenance.

## Castle Wall Slates PBR (previous variant)

- Source: [Poly Haven — Castle Wall Slates](https://polyhaven.com/a/castle_wall_slates)
- Imported maps: `assets/3d_dungeon/kit/textures/castle_wall_slates/`
- Material: `assets/3d_dungeon/kit/textures/castle_wall_slates/castle_wall_slates_material.tres`
- Licence: CC0
- Use: retained as an alternate material for comparison; the user wall scenes remain available for rollback/reference

## Stylized Mossy Dungeon Wall PBR (active variant)

- Source: [Stylized Mossy Dungeon Wall by kaczor237](https://kaczor237.itch.io/stylized-mossy-dungeon-wall-seamless-pbr-texture)
- Imported maps: `assets/3d_dungeon/kit/textures/castle_wall_stylized/`
- Material: `assets/3d_dungeon/kit/textures/castle_wall_stylized/castle_wall_stylized_material.tres`
- Licence: CC0 / Public Domain
- Use: active PBR material for the Castle wrappers; its normal/AO strength is kept moderate so the hand-painted stone stays closer to the game's cartoon palette

## EPIC RPG World Pack — Old Prison V1.7.1

- Source: user-provided purchased asset pack at `assets/old_prison/source/`
- Imported files: Old Prison terrain tiles, prop sheets, individual runtime props, and the 60×40 example map source
- Runtime TileSet: `assets/old_prison/tiles/old_prison_tileset.tres`
- Runtime map: `levels/old_prison_tilemap.tscn`, assembled as eight editable `TileMapLayer` layers from the original Tiled map
- Occlusion: two foreground wall `TileMapLayer` copies render above actors; a shader samples the player's actual transparent visual silhouette and fades only wall pixels that cover that silhouette, leaving nearby walls at full opacity
- Conversion data: `data/old_prison_tiled_layers.json`, generated from the retained Tiled source by `tools/convert_old_prison_tmx.py`
