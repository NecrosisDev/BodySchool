-- Defaults. The Mod Settings rows (main.lua) use these as their defaults and
-- override them per profile.
return {
    -- The Body school's first power (domain byte 3, sustained mode bit 16, icon cell 1).
    -- Must match POWER in tools/make_dist.py.
    power = 0x10301,
    body_school = 3,
    -- Focus: paid once when the skin hardens, then drained each second while held.
    -- The Sustain technique halves the drain, as it does for the game's sustained powers.
    cost = 0.08,
    drain = 0.012,
    -- Damage multipliers while the player is stone, per damage type the game computes.
    cut = 0.35,     -- edges skate over the plates
    pierce = 0.6,   -- points find the cracks now and then
    crush = 1.6,    -- blunt blows shatter stone
    -- ExCamera draws the player with the stone skin while it lasts.
    look = true,
    notices = true,
    -- Seconds between ticks (drain, level changes).
    tick_seconds = 1.0,
    -- The mark ExCamera reads (RUNTIME-REQUESTS.md); value 1 = stone look.
    mark = "stoneskin.look",
    -- Game scripts can also start and end it: LuaEvent(StoneSkin, n): n > 0 seconds, 0 ends it, -1 holds it.
    event = "StoneSkin",
}
