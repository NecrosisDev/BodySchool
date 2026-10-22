-- Runs scripts/main.lua against a stub of the runtime (API.md 0.28.0 plus the
-- requested characters.set_damage_scale / characters.set_mark in
-- RUNTIME-REQUESTS.md). Usage: lua harness.lua <mod folder>
local root = assert(arg[1], "mod folder")

local function new(opts)
    opts = opts or {}
    local s = {logs = {}, scales = {}, marks = {}, handlers = {}, timers = {}, level = "exanima01", chars = {}, values = {}}
    local caps = {
        ["events.lifecycle"] = true, timers = true, ["characters.read"] = true, ["world.read"] = true,
        ["ui.settings"] = true, ["characters.damage_scale"] = not opts.no_scale, ["characters.marks"] = not opts.no_marks,
    }
    local env = {math = math, string = string, table = table, ipairs = ipairs, pairs = pairs,
                 tonumber = tonumber, tostring = tostring, type = type, error = error, assert = assert}
    env.log = {info = function(m) s.logs[#s.logs + 1] = "info: " .. m end,
               warn = function(m) s.logs[#s.logs + 1] = "warn: " .. m end}
    env.api = {has_capability = function(name) return caps[name] == true end}
    env.events = {on = function(name, fn) s.handlers[name] = fn end}
    env.timers = {
        every = function(sec, fn) s.timers[#s.timers + 1] = fn return #s.timers end,
        cancel = function(id) s.timers[id] = false return true end,
    }
    env.settings = {
        define = function(title, rows)
            assert(not s.rows, "define once") assert(#rows >= 1 and #rows <= 32)
            for _, r in ipairs(rows) do
                assert(#r.label <= 40, r.label) assert(not r.help or #r.help <= 160, r.key)
                if r.type == "number" then assert(r.min < r.max and r.step > 0 and (r.max - r.min) / r.step <= 1000) end
            end
            s.rows = rows
        end,
        get = function(key)
            if s.values[key] ~= nil then return s.values[key] end
            for _, r in ipairs(s.rows) do if r.key == key then return r.default end end
        end,
    }
    env.world = {level = function() return {name = s.level, loaded = true} end}
    env.characters = {
        snapshot = function()
            local list = {}
            for _, c in ipairs(s.chars) do list[#list + 1] = {record_id = c.id, is_player = c.player, name = "x"} end
            return {characters = list}
        end,
    }
    if not opts.no_scale then
        env.characters.set_damage_scale = function(id, spec)
            assert(id == "player" or math.type(id) == "integer", "record id or \"player\"")
            if spec then
                for _, k in ipairs({"cut", "pierce", "crush"}) do assert(type(spec[k]) == "number" and spec[k] > 0, k) end
            end
            s.scales[id] = spec
            return true
        end
    end
    if not opts.no_marks then
        env.characters.set_mark = function(id, name, value)
            assert(type(name) == "string" and math.type(value) == "integer")
            s.marks[id] = value ~= 0 and value or nil
            return true
        end
    end
    local modules = {}
    env.require = function(name)
        modules[name] = modules[name] or assert(loadfile(root .. "/scripts/" .. name .. ".lua", "t", env))()
        return modules[name]
    end
    assert(loadfile(root .. "/scripts/main.lua", "t", env))()
    s.session = function() s.handlers["runtime.phase"]({phase = "session"}) end
    s.tick = function() for _, fn in ipairs(s.timers) do if fn then fn() end end end
    s.change = function(key, value) s.values[key] = value s.handlers["settings.changed"]({key = key, value = value}) end
    return s
end

local function npcs(s, n)
    s.chars = {{id = 0, player = true}}
    for i = 1, n do s.chars[#s.chars + 1] = {id = 1000 + i} end
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local passed = 0
local function case(name, fn) fn() passed = passed + 1 print("ok  " .. name) end

case("about the configured share of NPCs is stone, and the same ones each time", function()
    local a, b = new(), new()
    npcs(a, 30) npcs(b, 30)
    a.session() b.session()
    for _ = 1, 3 do a.tick() end  -- 32 changes per scan: two per stone NPC
    b.tick() b.tick() b.tick()
    local n = count(a.scales)
    assert(n >= 1 and n <= 12, "stone count " .. n)
    for id in pairs(a.scales) do assert(b.scales[id], "same pick") assert(a.marks[id] == 1) end
    assert(not a.scales.player and not a.marks.player, "player stays flesh by default")
    local pick = dofile(arg[1] .. "/scripts/pick.lua")
    local stone = 0
    for id = 1, 10000 do if pick.is_stone("exanima01", id, 15) then stone = stone + 1 end end
    assert(stone > 1300 and stone < 1700, "share over many ids " .. stone)
end)

case("stone characters get the configured multipliers", function()
    local s = new() npcs(s, 40) s.session() s.tick() s.tick() s.tick()
    local _, spec = next(s.scales)
    assert(spec.cut == 0.35 and spec.pierce == 0.6 and spec.crush == 1.6)
    s.change("crush", 2.5) s.tick() s.tick() s.tick()
    for _, sp in pairs(s.scales) do assert(sp.crush == 2.5) end
end)

case("turning it off clears every scale and mark", function()
    local s = new() npcs(s, 40) s.session() for _ = 1, 4 do s.tick() end
    assert(count(s.scales) > 0)
    s.change("enabled", false) for _ = 1, 4 do s.tick() end
    assert(count(s.scales) == 0 and count(s.marks) == 0)
end)

case("stone look off clears marks only", function()
    local s = new() npcs(s, 40) s.session() for _ = 1, 4 do s.tick() end
    local n = count(s.scales)
    s.change("look", false) for _ = 1, 4 do s.tick() end
    assert(count(s.marks) == 0 and count(s.scales) == n)
end)

case("stone player", function()
    local s = new() npcs(s, 2) s.change("player", true) s.session() s.tick()
    assert(s.scales.player and s.marks.player == 1)
end)

case("a level change re-applies, since the runtime forgot", function()
    local s = new() s.level = "exanima02" npcs(s, 40) s.session() for _ = 1, 4 do s.tick() end
    s.scales, s.marks = {}, {}
    s.level = "exanima03" for _ = 1, 4 do s.tick() end
    assert(count(s.scales) > 0)
end)

case("without the requested runtime calls it only warns, once each", function()
    local s = new{no_scale = true, no_marks = true} npcs(s, 40) s.session()
    for _ = 1, 5 do s.tick() end
    local warns = 0
    for _, l in ipairs(s.logs) do if l:find("^warn") then warns = warns + 1 end end
    assert(warns == 2, "warns " .. warns)
end)

case("leaving the session stops the scan", function()
    local s = new() npcs(s, 4) s.session()
    s.handlers["runtime.phase"]({phase = "menu"})
    assert(s.timers[1] == false)
    s.session() assert(#s.timers == 2)
end)

print(passed .. " passed")
