-- Defaults. The Mod Settings rows (main.lua) use these as their defaults and
-- override them per profile.
return {
    -- Seconds a timed stone skin lasts (an elixir, a script); a held one lasts until released.
    duration = 60,
    -- Damage multipliers while the player is stone, per damage type the game computes.
    cut = 0.35,     -- edges skate over the plates
    pierce = 0.6,   -- points find the cracks now and then
    crush = 1.6,    -- blunt blows shatter stone
    -- ExCamera draws the player with the stone skin while it lasts.
    look = true,
    notices = true,
    -- Seconds between checks (expiry, level changes).
    tick_seconds = 0.5,
    -- The mark ExCamera reads (RUNTIME-REQUESTS.md); value 1 = stone look.
    mark = "stoneskin.look",
    -- Game scripts start and end it with LuaEvent(StoneSkin, n): n > 0 seconds, 0 ends it, -1 holds it.
    event = "StoneSkin",
    -- The elixir's bottle (Elixir P1's model); must match ELIXIR_MODEL in assets.py.
    elixir_model = "Bottle_Med A1",
    -- One elixir at your feet the first time a save is played with the mod.
    starter = true,
}
