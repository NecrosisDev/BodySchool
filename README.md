# Body School (Stone Skin)

Adds the Body page to Exanima's spell book. Its first power, Stone Skin, hardens
your skin into craggy stone plates that turn edges but crack under blunt blows.
Seven more powers strengthen and speed your body, heal it, or turn the same
magic against your foes. You learn and cast them like the game's own powers,
from the spell book and the power wheel.

## Features

Held powers are cast once to start and again to release. They cost focus when
cast, then drain focus each second while they last; Sustain halves the drain. A
held power ends by itself when your focus runs dry. Instant powers catch every
foe fighting you within about 4 m (up to eight of them) and cost focus only if
they catch someone.

| Power | Type | What it does |
|---|---|---|
| Stone Skin | Held | Your skin hardens into stone plates. While it lasts you take less cut and pierce damage and more crush damage, and blows on you sound like striking stone. |
| Might | Held | Drives your muscles past their limits: heavy weapons come round faster and your pushes land harder. It strengthens the body, not the blow. |
| Quicken | Held | Every swing, recovery and step comes quicker. |
| Petrify | Instant | Turns the foes around you to stone for a few seconds. They stand all but frozen, blades glance off them and blunt blows shatter; then the stone falls away. |
| Weaken | Instant | Drains the strength of the foes around you for a while: their weapons drag and their blows land softer. |
| Slow | Instant | Weighs down the foes around you for a while: every swing, recovery and step of theirs lags. |
| Regenerate | Held | Your wounds close and broken limbs mend, a little each moment, worst first. |
| Mend | Held | Heals the nearest follower or friend within arm's reach the same way. |

Default damage taken while Stone Skin lasts: cut 35%, pierce 60%, crush 160%.

**Learning.** Stone Skin is the root of the page. Might, Quicken and Petrify
branch from Stone Skin; Weaken from Might; Slow from Quicken; Regenerate from
Might; Mend from Regenerate. As in the game's own trees, some nodes also need an
Insight technique: Petrify, Weaken and Slow (Inversion), Regenerate (Coherence)
and Mend (Expansion).

**Feedback.** Casts play the game's own thaumaturgy sounds and cast motions, and
a brief arc of light leaves your casting hand.

The page's tree and its icons are new files made for this mod; no game file is
replaced.

## Requirements

- Exanima (Steam).
- EMTK with the script-runtime startup patch, shipped with the Exanima Lua
  Runtime release.
- Exanima Lua Runtime 0.28.0 or later.

Optional:

- **ExCamera**, built with the stone-look patches in this repository's
  `excamera` folder, draws your skin (and petrified foes) as rock plates. The
  game's own lights and shadows shade them. Without it, Stone Skin and Petrify
  still work but look unchanged.
- **Injuries** (`com.necrosis.injuries`) does the healing for Regenerate and
  Mend. Without it these two powers still drain focus but heal nothing.

## Install

1. Download `StoneSkin-<version>.zip` from the Releases page.
2. Close Exanima.
3. Copy the `mods` folder from the ZIP into your Exanima game folder, so you end
   up with `Exanima\mods\com.necrosis.stoneskin`.
4. Enable Body School in your EMTK profile.
5. Launch the game through EMTK.

## Using it

When you load a game, the mod teaches your character Stone Skin, the root of the
Body page, so the page can be opened in the spell book. Learn further powers
there, put them on the power wheel and cast them like any other power. If you
lack the focus to cast, you get a short message and the game's refusal sound.

## Settings

Open Settings > Mod Settings > Stone Skin:

| Setting | What it does |
|---|---|
| Cost | Focus paid when your skin hardens. |
| Drain | Focus drained each second while it lasts. Sustain halves it. |
| Cut | Cut damage you take while stone. |
| Pierce | Pierce damage you take while stone. |
| Crush | Crush (blunt) damage you take while stone. |
| Rock look | Draws your skin as rock plates while it lasts. Needs ExCamera. |
| Messages | On-screen messages when it starts and ends. |

The tuning for the other powers is in `scripts/config.lua` inside the mod
folder.

## Saves and uninstalling

- The mod writes nothing into your save. Every effect ends when you return to
  the menu or quit. Curses on foes end when you change level, and foes get their
  own strength, speed and skill back when a curse ends.
- Powers your character learns on the Body page are kept by the game with the
  character. Back up your saves before removing the mod.
- To uninstall, disable Body School in your EMTK profile, or delete
  `Exanima\mods\com.necrosis.stoneskin`.

## For other mods

Game scripts can switch Stone Skin on the player with `LuaEvent(StoneSkin, n)`:
`n` seconds, `-1` to hold it until ended, `0` to end it.

Another mod can make an NPC cast a Body power:

- `addons.send("com.necrosis.stoneskin", "body.cast", {caster = <characters.read row or record id>, power = "stone" | "might" | "quicken" | "petrify" | "weaken" | "slow", seconds = <optional>})`
- or a game script line `LuaEvent(BodyCast<Power>, <caster record id>)`, where
  `<Power>` is Stone, Might, Quicken, Petrify, Weaken or Slow.

## Building from source

The build writes the Body page's power tree with the ExaniMate power-tree writer
and paints the icon sheet with `icon.py`. It reads one file from the installed
game, the Energy page's icon sheet, only to copy its texture format; none of its
pixels are used. You need Python 3 with Pillow, and the ExaniMate service folder
(which holds the `exanimate` format library).

```
python -X utf8 -B release.py --game <Exanima folder> --exanimate <ExaniMate service folder>
```

Pass both options: their built-in defaults are only for the author's machine.
`--exanimate` can instead come from the `EXANIMATE_SERVICE` environment
variable.

This writes the mod folder to `dist/mods/com.necrosis.stoneskin/` and the
release to `dist/StoneSkin-<version>.zip`, with a `.sha256` file beside it. An
earlier build in `dist/mods/` is moved to `dist/previous/` first. Other options:

- `--zip-only` packages the mod folder already in `dist/` without rebuilding.
- `--tag v<version>` stops unless the tag matches the version in
  `manifest.toml`.

The `excamera` folder holds the ExCamera patches for the stone look; they are
applied to ExCamera's source, not shipped in this mod's ZIP.

Author: NecrosisDev
