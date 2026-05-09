-- Poker hand detection and base scoring values
local Hands = {}

local HAND_TYPES = {
    { id="royal_flush",     name="Royal Flush",      chips=100, mult=8 },
    { id="straight_flush",  name="Straight Flush",   chips=100, mult=8 },
    { id="four_of_a_kind",  name="Four of a Kind",   chips=60,  mult=7 },
    { id="full_house",      name="Full House",        chips=40,  mult=4 },
    { id="flush",           name="Flush",             chips=35,  mult=4 },
    { id="straight",        name="Straight",          chips=30,  mult=4 },
    { id="three_of_a_kind", name="Three of a Kind",   chips=30,  mult=3 },
    { id="two_pair",        name="Two Pair",           chips=20,  mult=2 },
    { id="pair",            name="Pair",               chips=10,  mult=2 },
    { id="high_card",       name="High Card",          chips=5,   mult=1 },
}

local HAND_LOOKUP = {}
for _, ht in ipairs(HAND_TYPES) do HAND_LOOKUP[ht.id] = ht end

local function rank_counts(cards)
    local counts = {}
    for _, c in ipairs(cards) do
        counts[c.rank_val] = (counts[c.rank_val] or 0) + 1
    end
    return counts
end

local function is_flush(cards)
    if #cards < 5 then return false end
    local suit = cards[1].suit
    for i = 2, #cards do
        if cards[i].suit ~= suit then return false end
    end
    return true
end

local function is_straight(cards)
    if #cards < 5 then return false end
    local vals, seen = {}, {}
    for _, c in ipairs(cards) do
        if not seen[c.rank_val] then
            table.insert(vals, c.rank_val)
            seen[c.rank_val] = true
        end
    end
    if #vals ~= #cards then return false end
    table.sort(vals)
    -- Normal consecutive run
    if vals[#vals] - vals[1] == #vals - 1 then return true end
    -- Wheel: A-2-3-4-5
    if vals[#vals] == 14 and vals[1] == 2 and vals[2] == 3
       and vals[3] == 4 and vals[4] == 5 then
        return true
    end
    return false
end

local function count_groups(rcounts)
    local groups = {}
    for rv, cnt in pairs(rcounts) do
        table.insert(groups, {rv = rv, cnt = cnt})
    end
    table.sort(groups, function(a, b)
        if a.cnt ~= b.cnt then return a.cnt > b.cnt end
        return a.rv > b.rv
    end)
    return groups
end

-- Detect best hand from 1-5 cards; shame cards are ignored for detection
-- Returns: hand_id (string), scoring_cards (table)
function Hands.detect(cards)
    if not cards or #cards == 0 then return "high_card", {} end

    local clean = {}
    for _, c in ipairs(cards) do
        if not c.is_shame then table.insert(clean, c) end
    end
    if #clean == 0 then return "high_card", {} end

    local flush    = is_flush(clean)
    local straight = is_straight(clean)
    local rcounts  = rank_counts(clean)
    local groups   = count_groups(rcounts)
    local top      = groups[1] and groups[1].cnt or 0
    local second   = groups[2] and groups[2].cnt or 0

    if flush and straight then
        local vals = {}
        for _, c in ipairs(clean) do table.insert(vals, c.rank_val) end
        table.sort(vals)
        if vals[1] == 10 and vals[#vals] == 14 then
            return "royal_flush", clean
        end
        return "straight_flush", clean
    elseif top == 4 then
        return "four_of_a_kind", clean
    elseif top == 3 and second == 2 then
        return "full_house", clean
    elseif flush then
        return "flush", clean
    elseif straight then
        return "straight", clean
    elseif top == 3 then
        return "three_of_a_kind", clean
    elseif top == 2 and second == 2 then
        return "two_pair", clean
    elseif top == 2 then
        return "pair", clean
    else
        return "high_card", clean
    end
end

function Hands.get_type(id)
    return HAND_LOOKUP[id]
end

function Hands.type_name(id)
    local ht = HAND_LOOKUP[id]
    return ht and ht.name or "Unknown"
end

-- Preview damage for currently selected cards (no side effects)
function Hands.preview(cards, jokers, run)
    if not cards or #cards == 0 then return 0, 0, 0, "" end
    local hand_id, scoring = Hands.detect(cards)
    local ht = HAND_LOOKUP[hand_id]
    local base_chips = ht.chips
    local base_mult  = ht.mult
    -- Add individual card chips
    for _, c in ipairs(scoring) do
        if not c.is_shame then
            base_chips = base_chips + c.chip_val
        end
    end
    return base_chips, base_mult, base_chips * base_mult, Hands.type_name(hand_id)
end

return Hands
