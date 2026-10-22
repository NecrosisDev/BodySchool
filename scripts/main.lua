-- Stone Skin: for a while (or while held) the player's skin turns to craggy
-- stone plates. Edges skate off them (less cut and pierce damage), blunt blows
-- shatter them (more crush damage). The runtime applies the multipliers inside
-- the game's own damage computation and carries the look mark to ExCamera,
-- which draws the plates.
local defaults = require("config")
local effect = require("effect")

local cfg = {}
for k, v in pairs(defaults) do cfg[k] = v end
effect.init(cfg)

local ROWS = {
    {key = "duration", label = "Duration (s)", type = "number", default = defaults.duration, min = 10, max = 600, step = 10,
     help = "How long a timed stone skin lasts"},
    {key = "cut", label = "Cut damage", type = "number", default = defaults.cut, min = 0.05, max = 1, step = 0.05,
     help = "Multiplier on cut damage while you are stone"},
    {key = "pierce", label = "Pierce damage", type = "number", default = defaults.pierce, min = 0.05, max = 1.5, step = 0.05,
     help = "Multiplier on pierce damage while you are stone"},
    {key = "crush", label = "Crush damage", type = "number", default = defaults.crush, min = 1, max = 3, step = 0.1,
     help = "Multiplier on crush (blunt) damage while you are stone"},
    {key = "look", label = "Stone look", type = "toggle", default = defaults.look,
     help = "Draw your skin as rock plates while it lasts (needs ExCamera)"},
    {key = "notices", label = "Show notices", type = "toggle", default = defaults.notices},
    {key = "starter", label = "Starter elixir", type = "toggle", default = defaults.starter,
     help = "One Stoneskin Elixir at your feet the first time a save is played with the mod"},
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

-- Game scripts (dialogue, zones, items) drive it: LuaEvent(StoneSkin, n).
if api.has_capability("events.script") then
    events.on("script.event", function(e)
        if e.name ~= cfg.event then return end
        local n = e.number or 0
        if n > 0 then effect.start(n)
        elseif n < 0 then effect.hold()
        else effect.stop() end
    end)
end

-- The Stoneskin Elixir: double-click it, then click anything; it is drunk and leaves the pack.
local ELIXIR = require("elixir").elixir_item_id
local function is_elixir(id)
    return ELIXIR and id and (id == ELIXIR or (id & 0xFFFF) == ELIXIR)
end
if ELIXIR and api.has_capability("events.item_use") then
    events.on("item.use", cfg.elixir_model, function(event)
        if not is_elixir(event.item and event.item.id) then return false end
        if event.consume and api.has_capability("inventory.transfer") then event:consume() end
        effect.start(cfg.duration)
        return true
    end)
end

-- First play of a save with the mod: one elixir at the player's feet.
local function gift()
    if not (cfg.starter and ELIXIR and api.has_capability("storage.save") and api.has_capability("world.spawn")) then return end
    local saved = save_data.get() or ""
    if saved:find("gift=1", 1, true) then return end
    local player = inventory.snapshot and inventory.snapshot()
    if not (player and player.spawn_item and player.position) then return end
    local p = player.position
    if player:spawn_item(ELIXIR, {p[1] + 40, p[2], p[3]}) then save_data.set(saved .. "gift=1;") end
end

local timer = nil
events.on("runtime.phase", function(e)
    if e.phase == "session" then
        if not timer then timer = timers.every(cfg.tick_seconds, effect.tick) end
        timers.after(3, gift)
    else
        if timer then timers.cancel(timer) timer = nil end
        effect.reset()
    end
end)
