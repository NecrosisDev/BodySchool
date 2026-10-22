-- Stone Skin: a Body-school power. Cast it and your skin hardens into craggy
-- stone plates until you cast it again or your focus runs dry. Edges skate off
-- them (less cut and pierce damage), blunt blows shatter them (more crush
-- damage). The runtime applies the multipliers inside the game's own damage
-- computation and carries the look mark to ExCamera, which draws the plates.
local defaults = require("config")
local effect = require("effect")

local cfg = {}
for k, v in pairs(defaults) do cfg[k] = v end
effect.init(cfg)

local ROWS = {
    {key = "cost", label = "Focus to cast", type = "number", default = defaults.cost, min = 0, max = 0.5, step = 0.01,
     help = "Focus paid when your skin hardens"},
    {key = "drain", label = "Focus per second", type = "number", default = defaults.drain, min = 0, max = 0.1, step = 0.002,
     help = "Focus drained each second while you hold it (Sustain halves it)"},
    {key = "cut", label = "Cut damage", type = "number", default = defaults.cut, min = 0.05, max = 1, step = 0.05,
     help = "Multiplier on cut damage while you are stone"},
    {key = "pierce", label = "Pierce damage", type = "number", default = defaults.pierce, min = 0.05, max = 1.5, step = 0.05,
     help = "Multiplier on pierce damage while you are stone"},
    {key = "crush", label = "Crush damage", type = "number", default = defaults.crush, min = 1, max = 3, step = 0.1,
     help = "Multiplier on crush (blunt) damage while you are stone"},
    {key = "look", label = "Stone look", type = "toggle", default = defaults.look,
     help = "Draw your skin as rock plates while it lasts (needs ExCamera)"},
    {key = "notices", label = "Show notices", type = "toggle", default = defaults.notices},
}

if api.has_capability("ui.settings") and settings and settings.define then
    settings.define("Stone Skin", ROWS)
    for _, row in ipairs(ROWS) do
        local v = settings.get(row.key)
        if v ~= nil then cfg[row.key] = v end
    end
    events.on("settings.changed", function(e)
        if cfg[e.key] ~= nil then cfg[e.key] = e.value effect.refresh() end
    end)
end

local function say(text)
    if cfg.notices and api.has_capability("ui.notify") and ui and ui.notify then ui.notify(text) end
end
local function caster()
    return api.has_capability("powers.cast") and powers and powers.caster and powers.caster() or nil
end
local function spend(amount)
    if amount > 0 and api.has_capability("powers.focus") and powers.spend_focus then powers.spend_focus(amount) end
end
local function wheel(outcome)
    if powers and powers.wheel then pcall(powers.wheel, cfg.power, outcome) end
end

-- Held by the power (not by a game script): the drain applies and the next cast releases it.
local by_power = false
local POWER = cfg.power & 0x3FFFF

if api.has_capability("powers.cast") then
    -- The spell book's wheel lists only schools the character knows a power in; the Body page opens anyway.
    if powers.open_school then pcall(powers.open_school, cfg.body_school) end
    events.on("power.cast", function(event)
        if (event.power & 0x3FFFF) ~= POWER then return end
        if by_power and effect.held() then
            by_power = false
            effect.stop()
            wheel("cast")
            return
        end
        local c = caster()
        if c and c.focus and c.focus < cfg.cost then
            say("Not enough focus to harden your skin.")
            wheel("fail")
            return
        end
        spend(cfg.cost)
        by_power = true
        effect.hold()
        wheel("cast")
    end)
end

-- Game scripts (dialogue, zones, items) can drive it too: LuaEvent(StoneSkin, n).
if api.has_capability("events.script") then
    events.on("script.event", function(e)
        if e.name ~= cfg.event then return end
        local n = e.number or 0
        by_power = false
        if n > 0 then effect.start(n)
        elseif n < 0 then effect.hold()
        else effect.stop() end
    end)
end

local function tick()
    if by_power then
        if not effect.held() then
            by_power = false
        else
            local c = caster()
            local drain = cfg.drain * ((c and c.techniques and c.techniques.sustain) and 0.5 or 1)
            if c and c.focus and c.focus < drain then
                by_power = false
                effect.stop()
            else
                spend(drain)
            end
        end
    end
    effect.tick()
end

local timer = nil
events.on("runtime.phase", function(e)
    if e.phase == "session" then
        if not timer then timer = timers.every(cfg.tick_seconds, tick) end
        -- Knowing the page's root is what lets the player study it; teaching keeps any progress.
        if api.has_capability("powers.cast") and powers.teach then
            timers.after(0, function() pcall(powers.teach, cfg.power) end)
        end
    else
        if timer then timers.cancel(timer) timer = nil end
        by_power = false
        effect.reset()
    end
end)
