-- Runs scripts/main.lua against a stub of the runtime (API.md 0.28.0 plus the
-- requested characters.set_damage_scale / characters.set_mark in
-- RUNTIME-REQUESTS.md). Usage: lua harness.lua <mod folder>
local root = assert(arg[1], "mod folder")
local ELIXIR = 0x5A0

local function new(opts)
    opts = opts or {}
    local s = {logs = {}, notes = {}, handlers = {}, item_handlers = {}, timers = {}, afters = {}, now = 100,
               level = "exanima01", values = {}, save = opts.save, spawned = {}, consumed = 0}
    local caps = {
        ["events.lifecycle"] = true, timers = true, ["world.read"] = true, ["ui.settings"] = true, ["ui.notify"] = true,
        ["events.script"] = true, ["events.item_use"] = true, ["items.read"] = true, ["inventory.read"] = true,
        ["inventory.transfer"] = true, ["world.spawn"] = true, ["storage.save"] = true,
        ["characters.damage_scale"] = not opts.no_runtime, ["characters.marks"] = not opts.no_runtime,
    }
    local env = {math = math, string = string, table = table, ipairs = ipairs, pairs = pairs,
                 tonumber = tonumber, tostring = tostring, type = type, error = error, assert = assert}
    env.log = {info = function(m) s.logs[#s.logs + 1] = "info: " .. m end,
               warn = function(m) s.logs[#s.logs + 1] = "warn: " .. m end}
    env.api = {has_capability = function(name) return caps[name] == true end}
    env.events = {on = function(name, a, b)
        if name == "item.use" then s.item_handlers[a] = b else s.handlers[name] = a end
    end}
    env.timers = {
        every = function(sec, fn) s.timers[#s.timers + 1] = fn return #s.timers end,
        after = function(sec, fn) s.afters[#s.afters + 1] = fn return 1000 + #s.afters end,
        cancel = function(id) s.timers[id] = false return true end,
        now = function() return s.now end,
    }
    env.ui = {notify = function(t) s.notes[#s.notes + 1] = t end}
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
    env.save_data = {get = function() return s.save end, set = function(t) assert(#t <= 4096) s.save = t return true end}
    env.inventory = {snapshot = function()
        return {position = {0, 0, 0}, spawn_item = function(self, id, pos)
            assert(math.type(id) == "integer" and #pos == 3) s.spawned[#s.spawned + 1] = id return true end}
    end}
    env.characters = {}
    if not opts.no_runtime then
        env.characters.set_damage_scale = function(id, spec)
            assert(id == "player", "player only")
            if spec then for _, k in ipairs({"cut", "pierce", "crush"}) do assert(type(spec[k]) == "number" and spec[k] > 0, k) end end
            s.scale = spec
            return true
        end
        env.characters.set_mark = function(id, name, value)
            assert(id == "player" and type(name) == "string" and math.type(value) == "integer")
            s.mark = value ~= 0 and value or nil
            return true
        end
    end
    env.require = function(name)
        if name == "elixir" then return {elixir_item_id = ELIXIR} end
        return assert(loadfile(root .. "/scripts/" .. name .. ".lua", "t", env))()
    end
    assert(loadfile(root .. "/scripts/main.lua", "t", env))()
    s.session = function() s.handlers["runtime.phase"]({phase = "session"}) end
    s.tick = function() for _, fn in ipairs(s.timers) do if fn then fn() end end end
    s.run_afters = function() local a = s.afters s.afters = {} for _, fn in ipairs(a) do fn() end end
    s.change = function(key, value) s.values[key] = value s.handlers["settings.changed"]({key = key, value = value}) end
    s.script = function(n) s.handlers["script.event"]({name = "StoneSkin", value = tostring(n), number = n}) end
    s.drink = function(id)
        local event = {item = {id = id, model = "Bottle_Med A1"}, target = {kind = "other"}}
        event.consume = function() s.consumed = s.consumed + 1 return true end
        return s.item_handlers["Bottle_Med A1"](event)
    end
    return s
end

local passed = 0
local function case(name, fn) fn() passed = passed + 1 print("ok  " .. name) end

case("drinking the elixir turns the player to stone for the set duration, then it ends", function()
    local s = new() s.session()
    assert(s.drink(ELIXIR) == true and s.consumed == 1)
    assert(s.scale.cut == 0.35 and s.scale.pierce == 0.6 and s.scale.crush == 1.6 and s.mark == 1)
    s.now = s.now + 59 s.tick() assert(s.scale)
    s.now = s.now + 2 s.tick() assert(s.scale == nil and s.mark == nil)
    assert(#s.notes == 2)
end)

case("other bottles with the same model are left to the game", function()
    local s = new() s.session()
    assert(s.drink(0x485) == false and s.consumed == 0 and s.scale == nil)
end)

case("a second elixir extends, it does not stack", function()
    local s = new() s.session()
    s.drink(ELIXIR) s.now = s.now + 30 s.drink(ELIXIR)
    s.now = s.now + 59 s.tick() assert(s.scale)
    s.now = s.now + 2 s.tick() assert(s.scale == nil)
    assert(#s.notes == 2, "one start, one end notice")
end)

case("game scripts can time, hold and end it", function()
    local s = new() s.session()
    s.script(5) assert(s.scale) s.now = s.now + 6 s.tick() assert(s.scale == nil)
    s.script(-1) s.now = s.now + 1000 s.tick() assert(s.scale)
    s.script(0) assert(s.scale == nil)
end)

case("settings apply while stone; look off drops only the mark", function()
    local s = new() s.session() s.drink(ELIXIR)
    s.change("crush", 2.5) s.tick() assert(s.scale.crush == 2.5)
    s.change("look", false) s.tick() assert(s.mark == nil and s.scale)
end)

case("a level change asks the runtime again", function()
    local s = new() s.session() s.drink(ELIXIR)
    s.scale, s.mark = nil, nil
    s.level = "exanima02" s.tick() assert(s.scale and s.mark == 1)
end)

case("leaving the session ends it", function()
    local s = new() s.session() s.drink(ELIXIR)
    s.handlers["runtime.phase"]({phase = "menu"})
    assert(s.timers[1] == false)
    s.session() s.tick() assert(s.scale == nil)
end)

case("one starter elixir per save", function()
    local s = new() s.session() s.run_afters()
    assert(#s.spawned == 1 and s.spawned[1] == ELIXIR and s.save:find("gift=1"))
    s.handlers["runtime.phase"]({phase = "menu"}) s.session() s.run_afters()
    assert(#s.spawned == 1)
    local t = new() t.change("starter", false) t.session() t.run_afters() assert(#t.spawned == 0)
end)

case("without the requested runtime calls it only warns, once each", function()
    local s = new{no_runtime = true} s.session() s.drink(ELIXIR)
    for _ = 1, 5 do s.tick() end
    local warns = 0
    for _, l in ipairs(s.logs) do if l:find("^warn") then warns = warns + 1 end end
    assert(warns == 2, "warns " .. warns)
end)

print(passed .. " passed")
