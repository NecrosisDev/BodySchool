-- The stone skin on the player: on for a number of seconds, or held until
-- released. While on, the runtime scales the player's damage per type and
-- carries the look mark to ExCamera. Triggers (main.lua) only call start, hold
-- and stop.
local effect = {}

local cfg
local state = {on = false, held = false, ends = 0, applied = nil, level = nil}

function effect.init(config) cfg = config end
function effect.active() return state.on end
function effect.held() return state.on and state.held end
function effect.remaining()
    if not state.on then return 0 end
    if state.held then return math.huge end
    return math.max(0, state.ends - timers.now())
end

local function can(cap, fn) return api.has_capability(cap) and fn ~= nil end
local warned = {}
local function warn_once(key, text)
    if not warned[key] then warned[key] = true log.warn(text) end
end
local function notify(text)
    if cfg.notices and can("ui.notify", ui and ui.notify) then ui.notify(text) end
end

-- What the runtime should hold now ("off" when nothing); asks again only for what
-- changed. state.applied nil means unknown, so the next sync always asks.
local function sync()
    local want = state.on and string.format("%.2f/%.2f/%.2f/%s", cfg.cut, cfg.pierce, cfg.crush, tostring(cfg.look)) or "off"
    if want == state.applied then return end
    local ok = true
    if can("characters.damage_scale", characters.set_damage_scale) then
        ok = characters.set_damage_scale("player", state.on and {cut = cfg.cut, pierce = cfg.pierce, crush = cfg.crush} or nil) and ok
    else
        warn_once("scale", "characters.damage_scale is not granted: stone skin changes no damage")
    end
    if can("characters.marks", characters.set_mark) then
        ok = characters.set_mark("player", cfg.mark, (state.on and cfg.look) and 1 or 0) and ok
    else
        warn_once("mark", "characters.marks is not granted: stone skin has no look")
    end
    if ok then state.applied = want end
end

function effect.start(seconds)
    seconds = seconds or cfg.duration
    local was = state.on
    state.on = true
    if not state.held then state.ends = math.max(state.ends, timers.now() + seconds) end
    if not was then notify("Your skin hardens into stone.") end
    sync()
end

function effect.hold()
    local was = state.on
    state.on, state.held = true, true
    if not was then notify("Your skin hardens into stone.") end
    sync()
end

function effect.stop()
    if not state.on then return end
    state.on, state.held, state.ends = false, false, 0
    notify("The stone crumbles from your skin.")
    sync()
end

-- Settings changed: the next tick asks the runtime again.
function effect.refresh() state.applied = nil end

function effect.tick()
    local lvl = world and world.level and api.has_capability("world.read") and world.level() or nil
    local name = lvl and lvl.name or ""
    if name ~= state.level then
        -- The runtime forgets scales and marks at a level change.
        state.level, state.applied = name, nil
    end
    if state.on and not state.held and timers.now() >= state.ends then effect.stop() end
    sync()
end

-- Leaving the session: the effect ends with it.
function effect.reset()
    state.on, state.held, state.ends, state.applied, state.level = false, false, 0, nil, nil
end

return effect
