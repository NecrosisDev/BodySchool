# Runtime requests from Stone Skin

Stone Skin (`com.necrosis.stoneskin`) needs two additions to the script runtime
(E:\ExanimaLua). Both are additive (a new `api.revision`); the addon already
lists them under `optional` and only warns while they are missing.

Since 0.2.0 the addon only ever targets `"player"` (the effect is the player's,
from an elixir), so record-id targets are optional for it.

## 1. `characters.damage_scale`: damage multipliers per damage type

```lua
characters.set_damage_scale(target, {cut = 0.35, pierce = 0.6, crush = 1.6})  -- boolean
characters.set_damage_scale(target, nil)                                       -- clears
```

- `target`: a `record_id` from `characters.snapshot()` (every live character in
  this level with that id), or the string `"player"` for the player's character.
- Fields are optional multipliers, each 0.05..4 (missing = 1): `cut`, `pierce`,
  `crush`, and `impact` (falls, thrown objects and body collisions, the
  `source = "impact"` hits).
- The runtime applies them inside the game's own damage computation, to each
  damage component **before** the components are combined and before armour,
  so a stone body takes `cut * 0.35` where flesh would take `cut`. If the game
  only separates the types inside the armour step, apply them to what passes
  the armour instead; say which in API.md.
- Health and balance damage both scale. `character.hit` reports the scaled
  numbers.
- Held by the runtime, not staged: any number of calls per callback, from timer
  and event callbacks during a session; forgotten at a level change (the addon
  sets them again) and when the addon unloads.
- Not saved.

Open static question for the KB thread: where the per-type amounts (cut,
crush, point/pierce from the weapon grip; impact) exist separately on the way
to the damage applier (KB lists damage at 159700/159A60, applier slot
0x4F0900). The runtime's API.md says it avoids taking over the applier slot; a
detour of the per-type step, under the runtime's one-owner rule, is the ask.

## 2. `characters.marks`: a per-character mark other mods can read

```lua
characters.set_mark(target, "stoneskin.look", 1)   -- boolean; 0 clears
```

- `target` as above. `name`: 1..31 bytes of letters, digits, `_ . -`; prefix it
  with the addon's own name. `value`: integer 0..255.
- Held by the runtime, not staged; forgotten at a level change and when the
  addon unloads.

Native exports in `ScriptRuntime.dll`, for ExCamera (which draws marked
characters with stone plates):

| Export | Does |
|---|---|
| `uint32_t character_marks_version()` | 1 |
| `int character_mark_nodes(const char* name, uintptr_t* nodes, uint32_t* values, int capacity)` | fills up to `capacity` entries: each marked live character's **scene node** (the pointer at character `+0x18`, the root of its mesh tree) and its value; returns how many (0 when none) |

`character_mark_nodes` is called from the render thread once per colour pass
(several times a frame), so it must not take a lock the game thread holds for
long, must not read game memory, and must not allocate: keep a small published
copy (for example 64 entries behind a sequence counter) that the runtime
refreshes at its session pulse from the characters it resolved for each
`record_id`. A node from a character that has since left the level may be
reported until the next refresh; ExCamera only compares node pointers and never
dereferences one it was given.

## Why not something already there

- `character.hit` only observes damage (API.md "Not exposed, on purpose"), and
  carries no damage type.
- `player.damage` reaches only the player, so it cannot make NPCs weaker to
  crush, and nothing can lower damage.
- Roles (`charroles.rdb` overrides) would replace the whole role file and are
  read once per session, so they cannot pick NPCs per level.
