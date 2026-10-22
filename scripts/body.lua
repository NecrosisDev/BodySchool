-- Might and Quicken: sustained Body powers that change the player's own body for as long as they
-- are held (cast to start, cast again to release; focus drained each second).
--   Might: your muscles do more: the game's motor strength (char +998, 1.25 x body size, the
--     arm torque every swing, grapple and push uses) is scaled up, so heavy weapons come round
--     faster and you shove harder. It changes the body, not the blow: Force's Strikes adds force
--     to the strike itself.
--   Quicken: everything your body does runs faster: the base animation rate (char +DCC, which the
--     game's per-tick rate is built from) is scaled up, so swings, recoveries and steps all speed
--     up. The world tick stays fixed.
-- Both go through the runtime's characters.set_strength / set_anim_rate(target, factor or nil)
-- (capability characters.body; strength 0.25..3, rate 0.5..2), behind a pcall, re-sent each tick
-- while held (the game rewrites the rate after a knockdown) and cleared with nil on release. The
-- cast arc is effects.spawn_arc (capability effects.arc).
local body = {}

local cfg
local held = {might = false, quicken = false}
local SETTER = {might = "set_strength", quicken = "set_anim_rate"}

function body.init(config) cfg = config end
function body.held(name) return held[name] end

local function set(name, multiplier)
    local fn = characters and characters[SETTER[name]]
    if not fn or not api.has_capability("characters.body") then
        return false
    end
    local ok, result = pcall(fn, "player", multiplier)
    return ok and result ~= false
end

-- A brief arc of the game's own (the generic arc builder Energy's Shock uses) from the casting hand.
local function arc(spec)
    if effects and effects.spawn_arc and api.has_capability("effects.arc") then
        pcall(effects.spawn_arc, spec)
    end
end

function body.start(name)
    held[name] = true
    set(name, cfg[name].multiplier)
    arc(cfg[name].arc)
end

function body.stop(name)
    if not held[name] then return end
    held[name] = false
    set(name, nil)
end

-- Re-sends each held power's multiplier (main.lua drains the focus).
function body.tick()
    for name, on in pairs(held) do
        if on then
            set(name, cfg[name].multiplier)
        end
    end
end

-- Leaving the session: the runtime forgets what it held; so do we.
function body.reset()
    held.might, held.quicken = false, false
end

return body
