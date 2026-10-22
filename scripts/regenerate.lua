-- Regenerate and Mend: sustained Body powers that heal through the Injuries mod
-- (com.necrosis.injuries), which owns the wounds; these only ask, they never touch them.
--   Regenerate: while held, your own body knits itself back together: each second it asks Injuries
--     to mend `amount` of your wounds and broken limbs, worst first by that mod's own rules.
--   Mend (Regenerate turned outward): while held, your hand knits the body of the ally you are
--     touching: each second the nearest follower or friend within `reach` is healed the same way.
-- The request is an "injuries.heal" message {target = "player" or {handle = ...}, amount = n} through
-- the runtime's addons.send (the shape Injuries takes, as relayed by the coordinator 2026-10-22;
-- amount is in Injuries' own units). An ally is targeted by its own handle (a characters.read row).
local regenerate = {}

local cfg
local held = {regenerate = false, mend = false}
local warned = false

function regenerate.init(config) cfg = config end
function regenerate.held(name) return held[name or "regenerate"] end
function regenerate.start(name) held[name or "regenerate"] = true end
function regenerate.stop(name) held[name or "regenerate"] = false end

-- True when the request was sent.
local function heal(target, amount)
    if addons and addons.send then
        local ok, result = pcall(addons.send, cfg.regenerate.injuries, "injuries.heal", {target = target, amount = amount})
        return ok and result ~= false
    end
    if not warned then
        warned = true
        log.warn("Regenerate and Mend need the runtime's addons.send to reach Injuries: they heal nothing")
    end
    return false
end

local function distance(a, b)
    local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function row_key(row)
    local at = row.position
    return string.format("%d:%.1f:%.1f:%.1f", row.record_id or 0, at[1], at[2], at[3])
end

local function is_ally(row, mind)
    if row.is_player or row.dead or not mind or mind.fights_player then
        return false
    end
    if mind.mode == "follow" or mind.handler == "follow" then
        return true
    end
    local toward = mind.toward_player
    return toward ~= nil and toward.trust ~= nil and toward.trust >= cfg.mend.ally_trust
end

-- The handle of the nearest ally within reach, or nil. Allies come from the awareness rows; their
-- handles from the characters.read rows of the same pulse, matched by record id and position.
local function ally_in_reach()
    if not (api.has_capability("characters.awareness") and api.has_capability("characters.read")) then
        return nil
    end
    local view = characters.awareness()
    local ok, bodies = pcall(characters.snapshot)
    if not view or not ok or not bodies then return nil end
    local handles, here = {}, nil
    for _, row in ipairs(bodies.characters) do
        if row.is_player then here = row.position end
        if row.position and row.handle ~= nil then handles[row_key(row)] = row.handle end
    end
    if not here then return nil end
    local best, nearest = nil, cfg.mend.reach
    for _, row in ipairs(view.characters) do
        if row.position and is_ally(row, row.awareness) then
            local d = distance(row.position, here)
            local handle = handles[row_key(row)]
            if handle ~= nil and d <= nearest then
                best, nearest = handle, d
            end
        end
    end
    return best
end

-- Once a second while held (main.lua drains the focus).
function regenerate.tick()
    if held.regenerate then
        heal("player", cfg.regenerate.amount)
    end
    if held.mend then
        local ally = ally_in_reach()
        if ally ~= nil then
            heal({handle = ally}, cfg.mend.amount)
        end
    end
end

function regenerate.reset() held.regenerate, held.mend = false, false end

return regenerate
