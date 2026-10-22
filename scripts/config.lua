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
    duration = 60,

    -- Might and Quicken (scripts/body.lua): sustained, cost paid once, then drained each second
    -- (Sustain halves the drain). `multiplier` scales the body's own value; `arc` is the brief
    -- arc of the game's own drawn from the casting hand.
    might = {
        power = 0x10302,
        cost = 0.08,
        drain = 0.014,
        multiplier = 1.35,           -- motor strength (arm torque)
        arc = {from = "hand", strands = 6, segments = 5, life = 12, length = 0.5},
    },
    -- The inversions (scripts/petrify.lua): instant curses on every foe fighting you within `reach`
    -- (cm from your body centre), at most `most` of them, for `seconds`. Focus is paid only when
    -- someone is caught.
    -- Petrify: the stone look, stone's damage multipliers, the animation rate dropped to `anim_rate`
    -- and their AI skill to nothing.
    petrify = {
        power = 0x00304,
        cost = 0.25,
        reach = 400,
        most = 8,
        seconds = 5,
        cut = 0.35,
        pierce = 0.6,
        crush = 1.6,
        anim_rate = 0.02,            -- of their own: frozen (runtime r38 allows it for NPCs)
        anim_rate_floor = 0.5,       -- what older runtimes allow at least
        strength = 0.25,             -- motor strength: the runtime's floor
        sound = "golem_act01",       -- the game's own golem sound as the stone takes them
        arc = {from = "hand", strands = 14, segments = 6, life = 16, length = 1.0},
    },
    -- Weaken: their motor strength times `multiplier`.
    weaken = {
        power = 0x00305,
        cost = 0.15,
        reach = 400,
        most = 8,
        seconds = 8,
        multiplier = 0.6,
        sound = "thaumshow02",
        arc = {from = "hand", strands = 8, segments = 5, life = 12, length = 0.8},
    },
    -- Slow: their animation rate times `multiplier`.
    slow = {
        power = 0x00306,
        cost = 0.15,
        reach = 400,
        most = 8,
        seconds = 8,
        multiplier = 0.65,
        sound = "thaumshow02",
        arc = {from = "hand", strands = 8, segments = 5, life = 12, length = 0.8},
    },
    -- Body powers cast by an NPC on another mod's request (scripts/companions.lua): how long each self
    -- power lasts when the request gives no time, the longest any request may ask for, and the cast
    -- sound's volume (ui.sound plays at the player).
    companions = {
        seconds = {stone = 20, might = 15, quicken = 12},
        longest = 60,
        volume = 0.3,
    },
    -- Regenerate (scripts/regenerate.lua): sustained; each second asks the Injuries mod to mend
    -- `amount` of your wounds (in that mod's units, PROVISIONAL until its heal call is published).
    regenerate = {
        power = 0x10307,
        cost = 0.10,
        drain = 0.03,
        amount = 0.02,
        injuries = "com.necrosis.injuries",
        arc = {from = "hand", strands = 5, segments = 8, life = 30, length = 0.5},
    },
    -- Mend (scripts/regenerate.lua): sustained; each second asks Injuries to mend `amount` of the
    -- wounds of the nearest follower (or NPC who trusts you this much) within `reach` cm.
    mend = {
        power = 0x10308,
        cost = 0.10,
        drain = 0.035,
        amount = 0.02,
        reach = 200,
        ally_trust = 50,
        arc = {from = "hand", strands = 5, segments = 10, life = 30, length = 2.0},   -- reaching toward the ally
    },
    -- The arc Stone Skin draws from the casting hand as the skin hardens.
    stone_arc = {from = "hand", strands = 12, segments = 3, life = 20, length = 0.5},
    quicken = {
        power = 0x10303,
        cost = 0.10,
        drain = 0.018,
        multiplier = 1.2,            -- base animation rate: swings, recoveries, steps
        arc = {from = "hand", strands = 10, segments = 4, life = 8, length = 0.6},
    },
    -- Struck while stone: the player's hit sounds come from the game's golem-stone material
    -- (characters.set_hit_sound); NPCs turned to stone, which that call cannot reach, get one of the
    -- game's own golem hit sounds through ui.sound instead (Sound.rpk).
    hit_material = 6,
    hit_sounds = {"hitglm01", "hitglm02", "hitglm03", "hitglm04", "hitglm05", "hitglm06"},
    hit_volume = 0.5,
    -- The game's thaumaturgy sounds for the cast, release and a refused cast (Sound.rpk).
    sounds = {start = "thaumchnl01", release = "thaumchnl02", fail = "thaumfail01", volume = 0.5},
}
