-- The Body page's inversions: instant powers that do to the foes around you, for a few seconds, the
-- opposite of what Stone Skin, Might and Quicken do for you.
--   Petrify (Stone Skin turned outward): every foe fighting you within reach turns to stone: drawn
--     with the stone plates (the ExCamera mark Stone Skin uses), taking damage as stone does (cut and
--     pierce glance off, crush shatters), frozen (animation rate 0.02; 0.5 on runtimes before r38), their
--     arms barely driving (motor strength 0.25) and fighting with no skill at all (boost_ai, which
--     restores their own when it lapses).
--   Weaken (Might inverted): their motor strength drops, so their weapons drag and their blows and
--     pushes land softer.
--   Slow (Quicken inverted): their animation rate drops: swings, recoveries and steps all lag.
-- Each foe is targeted by its own handle (a characters.read row), so lookalikes sharing its record id
-- are left alone; only when the runtime gives no handle does the record id stand in. When a curse
-- ends, or the level changes, everything is given back.
local petrify = {}

local cfg
local cursed = {}   -- handle (or record id) -> {target = runtime target, kinds = {petrify = seconds left, ...}}
local level = nil

function petrify.init(config) cfg = config end
function petrify.active() return next(cursed) ~= nil end

-- Whether the character in a character.hit event is petrified.
function petrify.is_stone(event)
    local c = cursed[event.handle or event.record_id]
    return c ~= nil and c.kinds.petrify ~= nil
end

local function call(fn, ...)
    if fn then
        local ok, result = pcall(fn, ...)
        return ok and result ~= false
    end
    return false
end

-- Sends what one character should hold now, from all its curses together (nil clears each).
local function apply(entry)
    local c, t, p = entry.kinds, entry.target, cfg.petrify
    if api.has_capability("characters.marks") then
        call(characters.set_mark, t, cfg.mark, c.petrify and 1 or 0)
    end
    if api.has_capability("characters.damage_scale") then
        call(characters.set_damage_scale, t, c.petrify and {cut = p.cut, pierce = p.pierce, crush = p.crush} or nil)
    end
    if api.has_capability("characters.body") then
        -- Stone outranks Slow and Weaken: a petrified foe is held as still as the runtime allows.
        -- Runtimes from r38 take `anim_rate` (frozen); older ones refuse it, and their floor stands in.
        if c.petrify then
            if not call(characters.set_anim_rate, t, p.anim_rate) then
                call(characters.set_anim_rate, t, p.anim_rate_floor)
            end
        else
            call(characters.set_anim_rate, t, c.slow and cfg.slow.multiplier or nil)
        end
        call(characters.set_strength, t, (c.petrify and p.strength) or (c.weaken and cfg.weaken.multiplier) or nil)
    end
end

local function distance(a, b)
    local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function row_key(row)
    local at = row.position
    return string.format("%d:%.1f:%.1f:%.1f", row.record_id or 0, at[1], at[2], at[3])
end

-- characters.read rows (which carry `handle`) by record id and position, which match the awareness
-- rows of the same pulse; nil without characters.read.
local function bodies()
    if not api.has_capability("characters.read") then return nil end
    local ok, view = pcall(characters.snapshot)
    if not ok or not view then return nil end
    local rows = {}
    for _, row in ipairs(view.characters) do
        if row.position then rows[row_key(row)] = row end
    end
    return rows
end

-- From a timer: puts curse `kind` ("petrify", "weaken" or "slow") on every foe fighting you within its
-- reach of the caster, up to `most`. The caster is the player (`caster` nil), or an NPC given as a
-- record id or a table with a `handle` (a companion's cast, companions.lua). Returns how many it
-- caught (0 when no one was close enough).
function petrify.cast(kind, caster)
    if not api.has_capability("characters.awareness") then
        return 0
    end
    local view = characters.awareness()
    if not view then return 0 end
    local by_key = bodies() or {}
    local caster_handle = type(caster) == "table" and caster.handle or nil
    local caster_id = type(caster) == "number" and caster or nil
    local function is_caster(row)
        if caster == nil then return row.is_player end
        if row.is_player then return false end
        local body = row.position and by_key[row_key(row)]
        if caster_handle ~= nil then return body ~= nil and body.handle == caster_handle end
        return row.record_id == caster_id
    end
    local here
    for _, row in ipairs(view.characters) do
        if not here and is_caster(row) then here = row.position end
    end
    if not here then return 0 end
    local spec, caught = cfg[kind], 0
    for _, row in ipairs(view.characters) do
        local mind = row.awareness
        if caught < spec.most and not row.is_player and not row.dead and mind and mind.fights_player
            and row.position and not is_caster(row) and distance(row.position, here) <= spec.reach then
            local body = by_key[row_key(row)]
            local handle = body and body.handle
            local key = handle or ((row.record_id or 0) ~= 0 and row.record_id) or nil
            if key ~= nil then
                local entry = cursed[key] or {target = handle ~= nil and {handle = handle} or row.record_id, kinds = {}}
                cursed[key] = entry
                entry.kinds[kind] = spec.seconds
                apply(entry)
                -- Stone fights with no skill at all; boost_ai gives their own back by itself.
                if kind == "petrify" and row.boost_ai and api.has_capability("characters.ai.write") then
                    pcall(row.boost_ai, row, {skill = 0, seconds = spec.seconds})
                end
                caught = caught + 1
            end
        end
    end
    return caught
end

-- Once a second: counts every curse down and gives each character back what a lapsed curse took. The
-- runtime forgets marks and scales at a level change, so a new level clears the list.
function petrify.tick(seconds, level_name)
    if level ~= nil and level_name ~= level then
        level, cursed = level_name, {}
        return
    end
    level = level_name
    for key, entry in pairs(cursed) do
        for kind, left in pairs(entry.kinds) do
            entry.kinds[kind] = left - seconds > 0 and left - seconds or nil
        end
        apply(entry)   -- also re-sent while held: the game rewrites the animation rate after a knockdown
        if next(entry.kinds) == nil then
            cursed[key] = nil
        end
    end
    if next(cursed) == nil then
        level = nil   -- nothing held: main.lua stops ticking, so the next cast starts fresh
    end
end

function petrify.reset()
    cursed, level = {}, nil
end

return petrify
