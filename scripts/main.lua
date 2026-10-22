-- Stone Skin: some humanoids have craggy stone plates for skin. Edges skate off
-- them (less cut and pierce damage), blunt blows shatter them (more crush damage).
-- The runtime applies the damage multipliers inside the game's own damage
-- computation and carries the look mark to ExCamera, which draws the plates.
local defaults = require("config")
local pick = require("pick")

local cfg = {}
for k, v in pairs(defaults) do cfg[k] = v end

local has_settings = api.has_capability("ui.settings") and settings and settings.define
local ROWS = {
    {key = "enabled", label = "Stone skin", type = "toggle", default = defaults.enabled,
     help = "Some humanoids have stone plates for skin: hard to cut, easy to shatter"},
    {key = "share", label = "Stone share %", type = "number", default = defaults.share, min = 0, max = 100, step = 5,
     help = "Percent of each level's other humanoids that are stone (the same ones every visit)"},
    {key = "cut", label = "Cut damage", type = "number", default = defaults.cut, min = 0.05, max = 1, step = 0.05,
     help = "Multiplier on cut damage a stone character takes"},
    {key = "pierce", label = "Pierce damage", type = "number", default = defaults.pierce, min = 0.05, max = 1.5, step = 0.05,
     help = "Multiplier on pierce damage a stone character takes"},
    {key = "crush", label = "Crush damage", type = "number", default = defaults.crush, min = 1, max = 3, step = 0.1,
     help = "Multiplier on crush (blunt) damage a stone character takes"},
    {key = "look", label = "Stone look", type = "toggle", default = defaults.look,
     help = "Draw stone characters with rock plates (needs ExCamera)"},
    {key = "player", label = "Stone player", type = "toggle", default = defaults.player,
     help = "Your own character is stone too"},
}

if has_settings then
    settings.define("Stone Skin", ROWS)
    for _, row in ipairs(ROWS) do
        local v = settings.get(row.key)
        if v ~= nil then cfg[row.key] = v end
    end
    events.on("settings.changed", function(e)
        if cfg[e.key] ~= nil then cfg[e.key] = e.value end
    end)
end

local function can(cap, fn) return api.has_capability(cap) and fn ~= nil end
local warned = {}
local function warn_once(key, text)
    if not warned[key] then warned[key] = true log.warn(text) end
end

-- What this addon has asked the runtime for, per character in this level.
local applied = {}   -- key -> {scale = "cut/pierce/crush" or nil, mark = 0 or 1}
local level_name = nil
local MAX_CHANGES = 32  -- per scan; the rest wait for the next one

local function scale_key()
    return string.format("%.2f/%.2f/%.2f", cfg.cut, cfg.pierce, cfg.crush)
end

local function apply(target, key, stone)
    local want_scale = stone and scale_key() or nil
    local want_mark = (stone and cfg.look) and 1 or 0
    local have = applied[key] or {mark = 0}
    local changed = 0
    if want_scale ~= have.scale then
        if can("characters.damage_scale", characters.set_damage_scale) then
            local spec = stone and {cut = cfg.cut, pierce = cfg.pierce, crush = cfg.crush} or nil
            if characters.set_damage_scale(target, spec) then have.scale = want_scale changed = 1 end
        else
            warn_once("scale", "characters.damage_scale is not granted: stone characters take normal damage")
        end
    end
    if want_mark ~= have.mark then
        if can("characters.marks", characters.set_mark) then
            if characters.set_mark(target, cfg.mark, want_mark) then have.mark = want_mark changed = 1 end
        else
            warn_once("mark", "characters.marks is not granted: stone characters look normal")
        end
    end
    applied[key] = (have.scale or have.mark ~= 0) and have or nil
    return changed
end

local function scan()
    local lvl = world and world.level and api.has_capability("world.read") and world.level() or nil
    local name = lvl and lvl.name or ""
    if name ~= level_name then
        -- The runtime forgets scales and marks at a level change.
        applied, level_name = {}, name
    end
    local snap = characters.snapshot()
    if not snap or not snap.characters then return end
    local changes, seen = 0, {}
    for _, c in ipairs(snap.characters) do
        if changes >= MAX_CHANGES then break end
        local id = c.record_id
        if c.is_player then
            changes = changes + apply("player", "player", cfg.enabled and cfg.player)
        elseif id and id ~= 0 and not seen[id] then
            seen[id] = true
            changes = changes + apply(id, id, cfg.enabled and pick.is_stone(name, id, cfg.share))
        end
    end
end

local timer = nil
events.on("runtime.phase", function(e)
    if e.phase == "session" then
        if not timer then timer = timers.every(cfg.scan_seconds, scan) end
    else
        if timer then timers.cancel(timer) timer = nil end
        applied, level_name = {}, nil
    end
end)
