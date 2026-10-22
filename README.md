# Stone Skin

Drink a Stoneskin Elixir and for a minute your skin sets into thick, cracked
rock plates, like The Thing. Edges skate off them (cut x0.35, pierce x0.6) and
blunt blows shatter them (crush x1.6).

Two parts:

- **The Lua addon** (`com.necrosis.stoneskin`, this repo). The effect is the
  player's only, timed or held (`scripts/effect.lua`: start, hold, stop), so
  other triggers can switch it on later. Triggers now: the Stoneskin Elixir
  (record 0x5A0: double-click it, click anything, it is drunk; found in
  civilian loot, and one appears at your feet the first time a save is played
  with the mod), and game scripts via `LuaEvent(StoneSkin, n)` (n seconds, -1
  held, 0 ends it). Settings > Mod Settings > Stone Skin: duration, the three
  multipliers, the look, notices, the starter elixir.
- **ExCamera's stone look** (`excamera/stone-skin-0*.patch`, applied in order by
  the ExCamera owner in E:\ExCamera). While the player is marked, the body faces
  are drawn with procedural stone maps (Voronoi plates, rounded slab bevel,
  grit, pits, fractures, crevice occlusion) in place of the skin textures,
  through the game's own material program, so the game's lights and shadows
  shade them. Worn pieces stay as they are. In first person the headwear path
  keeps hiding the head and swaps the maps on the visible body itself (03).
  `excamera/stone-lit-tiled.png` is an offline render of the maps.

## Needs

- Script runtime with `characters.set_damage_scale("player", ...)` and
  `characters.set_mark("player", ...)` (RUNTIME-REQUESTS.md). Without them the
  elixir is still drunk and notices show, but nothing else changes.
- ExCamera with the patches, for the look; OpenGL 4.5.

## Build and check

```
python -X utf8 -B test_stoneskin.py      # offline: the addon against a stubbed API
python -B tools/make_dist.py             # dist/mods/com.necrosis.stoneskin (reads the installed objdb)
```

## ExCamera patches: what they read and change

Reads only: the mark list from ScriptRuntime.dll's `character_mark_nodes`
(version 1); a draw's `_SKIN` node name and parent; the node's face tags
(`+0x2F8`, tag 0 = the body); the material's texture set (`+0x100`, objects at
`+0x10/+0x18/+0x20`, GL target `+0x40`, name `+0x58`), which the game's mesh
submit (0x200770) binds to units 0, 1, 2 through 0x6FC30. Writes no game memory.
GL: three textures made once per context with direct-state calls, bound with
`glBindTextures(0, 3, ...)` (the active unit is untouched) for body face runs,
and the material's own three bound back right after. Uses the existing
headwearRender submit/draw hooks; no new hook or signature.

Inferred, not seen in game: units 0/1/2 are diffuse/specular/normal (the order
the set holds `_d`, `_s`, `_n`), the normal map is tangent space with +Y up, and
skin materials carry that texture set. Without the set the draw stays native.
