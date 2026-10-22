# Stone Skin

Some humanoids have thick, rounded, cracked rock plates for skin. Edges skate
off them (cut x0.35, pierce x0.6) and blunt blows shatter them (crush x1.6).

Two parts:

- **The Lua addon** (`com.necrosis.stoneskin`, this repo). Each level, a stable
  share of the other humanoids (15% by default; the same ones every visit,
  picked from the level name and record id) is stone. It asks the script
  runtime for per-type damage multipliers and marks them for the look.
  Settings > Mod Settings > Stone Skin: on/off, share, the three multipliers,
  the look, and "Stone player" (off by default).
- **ExCamera's stone look** (`excamera/stone-skin-01.patch`, applied by the
  ExCamera owner in E:\ExCamera). Marked characters' body faces are drawn with
  procedural stone maps (Voronoi plates, rounded slab bevel in the normal map,
  crevice occlusion in the colour) in place of their skin textures, through the
  game's own material program, so the game's lights and shadows shade them.
  Worn pieces stay as they are. `excamera/stone-lit-tiled.png` is an offline
  render of the maps.

## Needs

- Script runtime with `characters.damage_scale` and `characters.marks`
  (requested in RUNTIME-REQUESTS.md). Without them the addon only warns once
  each, and nothing changes in play.
- ExCamera with the patch, for the look. The ExCamera side needs OpenGL 4.5
  (direct-state textures, multi-bind); below that, characters draw normally.

## Build and check

```
python -X utf8 -B test_stoneskin.py      # offline: the addon against a stubbed API
python -B tools/make_dist.py             # dist/mods/com.necrosis.stoneskin
```

## ExCamera patch: what it reads and changes

Reads only: the mark list from ScriptRuntime.dll's `character_mark_nodes`
(version 1); a draw's `_SKIN` node name and parent; the node's face tags
(`+0x2F8`, tag 0 = the body); the material's texture set (`+0x100`, objects at
`+0x10/+0x18/+0x20`, GL target `+0x40`, name `+0x58`), which the game's mesh
submit (0x200770) binds to units 0, 1, 2 through 0x6FC30. Writes no game memory.
GL: creates three textures once per context with direct-state calls, binds them
with `glBindTextures(0, 3, ...)` (which leaves the active unit alone) for the
body face runs, and binds the material's own three back right after. Uses the
existing submit/draw hooks of the headwearRender group; no new hook or
signature.

Inferred, not seen in game: that units 0/1/2 are diffuse/specular/normal (the
order the texture set holds `_d`, `_s`, `_n`), that the normal map is tangent
space with +Y up, and that NPC skin materials carry that texture set. When the
set is missing the draw stays native and a fallback counter rises.
