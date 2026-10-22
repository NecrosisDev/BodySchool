-- Stone Skin: a Body-school power. Cast it and your skin hardens into craggy
-- stone plates until you cast it again or your focus runs dry. Edges skate off
-- them (less cut and pierce damage), blunt blows shatter them (more crush
-- damage). The runtime applies the multipliers inside the game's own damage
-- computation and carries the look mark to ExCamera, which draws the plates.
-- Might and Quicken, the Body page's other powers, live in body.lua; Petrify, Weaken and Slow in
-- petrify.lua; casts by NPCs, on other mods' request, in companions.lua.
local defaults = require("config")
local effect = require("effect")
local body = require("body")
local petrify = require("petrify")
local companions = require("companions")
local regenerate = require("regenerate")

local cfg = {}
for k, v in pairs(defaults) do cfg[k] = v end
effect.init(cfg)
body.init(cfg)
petrify.init(cfg)
companions.init(cfg, petrify)
regenerate.init(cfg)

local ROWS = {
    {key = "cost", label = "Cost", type = "number", default = defaults.cost, min = 0, max = 0.5, step = 0.01, format = "percent",
     help = "Focus paid when your skin hardens"},
    {key = "drain", label = "Drain", type = "number", default = defaults.drain, min = 0, max = 0.1, step = 0.002, format = "percent",
     help = "Focus drained each second while it lasts. Sustain halves it"},
    {type = "header", label = "Damage taken"},
    {key = "cut", label = "Cut", type = "number", default = defaults.cut, min = 0.05, max = 1, step = 0.05, format = "percent",
     help = "Cut damage you take while stone"},
    {key = "pierce", label = "Pierce", type = "number", default = defaults.pierce, min = 0.05, max = 1.5, step = 0.05, format = "percent",
     help = "Pierce damage you take while stone"},
    {key = "crush", label = "Crush", type = "number", default = defaults.crush, min = 1, max = 3, step = 0.1, format = "percent",
     help = "Crush (blunt) damage you take while stone"},
    {key = "look", label = "Rock look", type = "toggle", default = defaults.look,
     help = "Draws your skin as rock plates while it lasts. Needs ExCamera"},
    {key = "notices", label = "Messages", type = "toggle", default = defaults.notices,
     help = "On-screen messages when it starts and ends"},
}
-- The same rows without the sub-header and % display, for a runtime before 0.28.0-r42.
local PLAIN = {}
for _, row in ipairs(ROWS) do
    if row.key then
        local copy = {}
        for k, v in pairs(row) do if k ~= "format" then copy[k] = v end end
        PLAIN[#PLAIN + 1] = copy
    end
end

if api.has_capability("ui.settings") and settings and settings.define then
    if not pcall(settings.define, "Stone Skin", ROWS) then settings.define("Stone Skin", PLAIN) end
    for _, row in ipairs(PLAIN) do
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
-- The wheel's own reaction to a cast; the game's thaumaturgy sounds stand in where the runtime has
-- no powers.wheel, and the cast plays the channel motion where it has powers.gesture.
local function wheel(outcome, sound, power)
    local shown = powers and powers.wheel and pcall(powers.wheel, power or cfg.power, outcome)
    local name = (outcome == "fail" and not shown) and cfg.sounds.fail or (outcome ~= "fail" and cfg.sounds[sound])
    if name and api.has_capability("ui.sound") and ui and ui.sound then pcall(ui.sound, name, cfg.sounds.volume) end
    if outcome ~= "fail" and sound == "start" and powers and powers.gesture then pcall(powers.gesture, "channel") end
end

-- A brief arc of the game's own (the arc builder Energy's Shock uses) from the casting hand.
local function arc(spec)
    if spec and effects and effects.spawn_arc and api.has_capability("effects.arc") then
        pcall(effects.spawn_arc, spec)
    end
end

-- Held by the power (not by a game script): the drain applies and the next cast releases it.
local by_power = false
local POWER = cfg.power & 0x3FFFF
-- Might and Quicken (scripts/body.lua).
local BODY_POWERS = {[cfg.might.power] = "might", [cfg.quicken.power] = "quicken", [cfg.regenerate.power] = "regenerate", [cfg.mend.power] = "mend"}
-- Which module holds each (Regenerate: scripts/regenerate.lua); each takes the power name.
local HOLDER = {might = body, quicken = body, regenerate = regenerate, mend = regenerate}
-- Petrify, Weaken and Slow (scripts/petrify.lua).
local CURSES = {[cfg.petrify.power] = "petrify", [cfg.weaken.power] = "weaken", [cfg.slow.power] = "slow"}

if api.has_capability("powers.cast") then
    -- The spell book's wheel lists only schools the character knows a power in; the Body page opens anyway.
    if powers.open_school then pcall(powers.open_school, cfg.body_school) end
    events.on("power.cast", function(event)
        local power = event.power & 0x3FFFF
        local curse = CURSES[power]
        if curse then
            local p = cfg[curse]
            local c = caster()
            if c and c.focus and c.focus < p.cost then
                say("Not enough focus.")
                wheel("fail", nil, power)
                return
            end
            -- NPC changes are staged from timer callbacks; focus is paid only if someone is caught.
            timers.after(0, function()
                if petrify.cast(curse) == 0 then
                    say("No foe within reach.")
                    wheel("fail", nil, power)
                    return
                end
                spend(p.cost)
                wheel("cast", nil, power)
                if powers.gesture then pcall(powers.gesture, "thrust") end
                arc(p.arc)
                if api.has_capability("ui.sound") and ui and ui.sound then pcall(ui.sound, p.sound, cfg.hit_volume) end
            end)
            return
        end
        local name = BODY_POWERS[power]
        if name then
            if HOLDER[name].held(name) then
                HOLDER[name].stop(name)
                wheel("cast", "release", power)
                return
            end
            local c = caster()
            if c and c.focus and c.focus < cfg[name].cost then
                say("Not enough focus.")
                wheel("fail", nil, power)
                return
            end
            spend(cfg[name].cost)
            HOLDER[name].start(name)
            if HOLDER[name] ~= body then arc(cfg[name].arc) end   -- body.start draws its own
            wheel("cast", "start", power)
            return
        end
        if power ~= POWER then return end
        if by_power and effect.held() then
            by_power = false
            effect.stop()
            wheel("cast", "release")
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
        arc(cfg.stone_arc)
        wheel("cast", "start")
    end)
end

-- Struck while stone: the player's own hit sounds already come from the golem-stone material
-- (effect.lua, characters.set_hit_sound); for an NPC turned to stone, which that call cannot reach,
-- and for the player on a runtime without it, one of the game's own golem hit sounds (Sound.rpk
-- hitglm01..06) plays through ui.sound with a slight random pitch.
if api.has_capability("events.combat") then
    events.on("character.hit", function(e)
        local native = api.has_capability("characters.hit_sound") and characters.set_hit_sound ~= nil
        local stone = (e.is_player and effect.active() and not native)
            or (not e.is_player and (petrify.is_stone(e) or companions.is_stone(e)))
        if stone and (e.health_damage or 0) + (e.balance_damage or 0) > 0
            and api.has_capability("ui.sound") and ui and ui.sound then
            pcall(ui.sound, cfg.hit_sounds[math.random(#cfg.hit_sounds)], cfg.hit_volume)
        end
    end)
end

-- Other mods ask an NPC to cast (companions.lua): addons.send(<this mod>, "body.cast",
-- {caster, power, seconds}). NPC changes are staged from timer callbacks, so it runs from one.
if addons and addons.on then
    addons.on("body.cast", function(value, from_id)
        if type(value) ~= "table" or type(value.power) ~= "string" then
            log.warn("body.cast from " .. tostring(from_id) .. " needs {caster, power}")
            return
        end
        timers.after(0, function() companions.cast(value.caster, value.power, value.seconds) end)
    end)
end

-- Game scripts (dialogue, zones, items) can drive it too: LuaEvent(StoneSkin, n).
if api.has_capability("events.script") then
    events.on("script.event", function(e)
        -- An NPC's cast for another mod: LuaEvent(BodyCast<Power>, <caster record id>). NPC changes are
        -- staged from timer callbacks, so it runs from one.
        local power = companions.EVENTS[e.name]
        if power then
            local caster = math.tointeger(e.number)
            timers.after(0, function() companions.cast(caster, power) end)
            return
        end
        if e.name ~= cfg.event then return end
        local n = e.number or 0
        by_power = false
        if n > 0 then effect.start(n)
        elseif n < 0 then effect.hold()
        else effect.stop() end
    end)
end

local function anything_on()
    if by_power or effect.active() or petrify.active() or companions.active() then
        return true
    end
    for name, holder in pairs(HOLDER) do
        if holder.held(name) then return true end
    end
    return false
end

-- Once a second, but only while some Body power is on: with nothing on, no runtime call is made.
local function tick_work()
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
    local c = caster()
    local sustain = (c and c.techniques and c.techniques.sustain) and 0.5 or 1
    for _, name in ipairs({"might", "quicken", "regenerate", "mend"}) do
        if HOLDER[name].held(name) then
            local drain = cfg[name].drain * sustain
            if c and c.focus and c.focus < drain then
                HOLDER[name].stop(name)
                say("Your focus runs dry.")
            else
                spend(drain)
            end
        end
    end
    body.tick()
    regenerate.tick()
    local lvl = world and world.level and api.has_capability("world.read") and world.level() or nil
    petrify.tick(cfg.tick_seconds, lvl and lvl.name or "")
    companions.tick(cfg.tick_seconds, lvl and lvl.name or "")
    effect.tick()
end

local function tick()
    if not anything_on() then return end
    if profile and profile.scope then
        profile.scope("body.tick", tick_work)
    else
        tick_work()
    end
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
        body.reset()
        regenerate.reset()
        petrify.reset()
        companions.reset()
    end
end)
