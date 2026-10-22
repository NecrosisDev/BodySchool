-- Body powers cast by an NPC. Another mod decides who casts what and when (Endless wires its
-- companions); this module only applies the effect to the caster with the same runtime calls the
-- player's powers use, and gives everything back when it lapses. The game cannot cast mod schools
-- for an NPC (its cast dispatcher 0x1d8340 fails schools 3 and 5), so nothing native is involved.
--
-- How another mod asks (main.lua listens):
--   * addons.send("com.necrosis.stoneskin", "body.cast", {caster = <handle table or record id>,
--     power = "stone" | "might" | "quicken" | "petrify" | "weaken" | "slow", seconds = optional});
--     a caster given as a characters.read row (or any table with its `handle`) is that one
--     character; a record id is every live character with it;
--   * a game script line LuaEvent(BodyCast<Power>, <caster record id>), Power one of Stone, Might,
--     Quicken, Petrify, Weaken, Slow; the power's own duration applies.
-- Self powers (stone, might, quicken) change the caster; the curses (petrify, weaken, slow) catch
-- the foes fighting the player around the caster, through petrify.lua.
local companions = {}

local cfg, petrify
local state = {}   -- handle (or record id) -> {target = runtime target, powers = {power = seconds left}}
local level = nil

local SELF = {stone = true, might = true, quicken = true}
local CURSE = {petrify = true, weaken = true, slow = true}
-- LuaEvent names, for game scripts.
companions.EVENTS = {BodyCastStone = "stone", BodyCastMight = "might", BodyCastQuicken = "quicken",
                     BodyCastPetrify = "petrify", BodyCastWeaken = "weaken", BodyCastSlow = "slow"}

function companions.init(config, curses) cfg, petrify = config, curses end
function companions.active() return next(state) ~= nil end

-- Whether the character in a character.hit event is a companion turned to stone.
function companions.is_stone(event)
    local s = state[event.handle] or state[event.record_id]
    return s ~= nil and s.powers.stone ~= nil
end

local function call(fn, ...)
    if fn then
        local ok, result = pcall(fn, ...)
        return ok and result ~= false
    end
    return false
end

local function apply(entry)
    local a, t = entry.powers, entry.target
    if api.has_capability("characters.damage_scale") then
        call(characters.set_damage_scale, t, a.stone and {cut = cfg.cut, pierce = cfg.pierce, crush = cfg.crush} or nil)
    end
    if api.has_capability("characters.marks") then
        call(characters.set_mark, t, cfg.mark, (a.stone and cfg.look) and 1 or 0)
    end
    if api.has_capability("characters.body") then
        call(characters.set_strength, t, a.might and cfg.might.multiplier or nil)
        call(characters.set_anim_rate, t, a.quicken and cfg.quicken.multiplier or nil)
    end
end

-- The state key and runtime target for a caster given as a record id or a table with a handle.
local function resolve(caster)
    if type(caster) == "table" and caster.handle ~= nil then
        return caster.handle, {handle = caster.handle}
    end
    if math.type(caster) == "integer" and caster ~= 0 then
        return caster, caster
    end
    return nil
end

-- From a timer: `caster` casts `power` for `seconds` (or the power's own duration). Returns true when
-- the effect was applied (for a curse: when it caught someone).
function companions.cast(caster, power, seconds)
    local key, target = resolve(caster)
    if key == nil then
        return false
    end
    if CURSE[power] then
        return petrify.cast(power, target) > 0
    end
    if not SELF[power] then
        return false
    end
    seconds = seconds or cfg.companions.seconds[power]
    if type(seconds) ~= "number" or seconds <= 0 then
        return false
    end
    local entry = state[key] or {target = target, powers = {}}
    state[key] = entry
    entry.powers[power] = math.min(seconds, cfg.companions.longest)
    apply(entry)
    if api.has_capability("ui.sound") and ui and ui.sound then
        pcall(ui.sound, cfg.sounds.start, cfg.companions.volume)
    end
    return true
end

-- Once a second: lapses what has run out and gives it back; a level change clears everything (the
-- runtime forgets marks and scales then).
function companions.tick(seconds, level_name)
    if level ~= nil and level_name ~= level then
        level, state = level_name, {}
        return
    end
    level = level_name
    for key, entry in pairs(state) do
        for power, left in pairs(entry.powers) do
            entry.powers[power] = left - seconds > 0 and left - seconds or nil
        end
        apply(entry)   -- also re-sent while running: the game rewrites the animation rate after a knockdown
        if next(entry.powers) == nil then
            state[key] = nil
        end
    end
    if next(state) == nil then
        level = nil   -- nothing held: main.lua stops ticking, so the next cast starts fresh
    end
end

function companions.reset()
    state, level = {}, nil
end

return companions
