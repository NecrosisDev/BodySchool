-- Defaults. The Mod Settings rows (main.lua) use these as their defaults and
-- override them per profile.
return {
    enabled = true,
    -- Percent of the level's other humanoids that are stone.
    share = 15,
    -- Damage multipliers for a stone character, per damage type the game computes.
    cut = 0.35,     -- edges skate over the plates
    pierce = 0.6,   -- points find the cracks now and then
    crush = 1.6,    -- blunt blows shatter stone
    -- ExCamera draws marked characters with the stone skin.
    look = true,
    -- The player's own character is stone too.
    player = false,
    -- Seconds between checks of the level's characters.
    scan_seconds = 1.0,
    -- The mark ExCamera reads (RUNTIME-REQUESTS.md); value 1 = stone look.
    mark = "stoneskin.look",
}
