-- Which characters are stone: a stable draw from the level name and the
-- character's record id, so the same NPC is stone every time the level loads
-- and nothing has to be saved.
local pick = {}

-- 32-bit FNV-1a over the bytes of `text`.
local function fnv(text)
    local h = 0x811C9DC5
    for i = 1, #text do
        h = ((h ~ text:byte(i)) * 0x01000193) & 0xFFFFFFFF
    end
    return h
end

-- 0..9999 for this character in this level.
function pick.roll(level, record_id)
    return fnv((level or "") .. "#" .. tostring(record_id)) % 10000
end

-- share is a percent (0..100).
function pick.is_stone(level, record_id, share)
    if not record_id or record_id == 0 or share <= 0 then return false end
    return pick.roll(level, record_id) < math.floor(share * 100 + 0.5)
end

return pick
