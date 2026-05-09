local Deck = {}

local RANKS  = {"2","3","4","5","6","7","8","9","10","J","Q","K","A"}
local SUITS  = {"Hearts","Diamonds","Clubs","Spades"}
local SUIT_FANCY = { Hearts="♥", Diamonds="♦", Clubs="♣", Spades="♠" }
local RANK_VALUES = {
    ["2"]=2,["3"]=3,["4"]=4,["5"]=5,["6"]=6,["7"]=7,["8"]=8,
    ["9"]=9,["10"]=10,["J"]=11,["Q"]=12,["K"]=13,["A"]=14
}
local RANK_CHIPS = {
    ["2"]=2,["3"]=3,["4"]=4,["5"]=5,["6"]=6,["7"]=7,["8"]=8,
    ["9"]=9,["10"]=10,["J"]=10,["Q"]=10,["K"]=10,["A"]=11
}

local function make_card(rank, suit, is_starter)
    return {
        rank=rank, suit=suit,
        symbol=SUIT_FANCY[suit],
        rank_val=RANK_VALUES[rank], chip_val=RANK_CHIPS[rank],
        is_shame=false, is_starter=is_starter or false,
        hover_offset=0, select_offset=0,
        is_hovered=false, is_selected=false,
    }
end

function Deck.build_standard()
    local cards = {}
    for _, suit in ipairs(SUITS) do
        for _, rank in ipairs(RANKS) do
            table.insert(cards, make_card(rank, suit, true))
        end
    end
    return cards
end

function Deck.new_shame_card()
    return {
        rank="X", suit="Sin", symbol="*",
        rank_val=0, chip_val=-5,
        is_shame=true, is_starter=false,
        hover_offset=0, select_offset=0,
        is_hovered=false, is_selected=false,
    }
end

function Deck.shuffle(pile)
    for i = #pile, 2, -1 do
        local j = math.random(i)
        pile[i], pile[j] = pile[j], pile[i]
    end
    return pile
end

function Deck.draw(draw_pile, discard_pile, hand, n)
    for _ = 1, n do
        if #draw_pile == 0 then
            if #discard_pile == 0 then break end
            for _, c in ipairs(discard_pile) do
                c.is_selected=false; c.hover_offset=0; c.select_offset=0
                table.insert(draw_pile, c)
            end
            for k = #discard_pile, 1, -1 do discard_pile[k] = nil end
            Deck.shuffle(draw_pile)
        end
        table.insert(hand, table.remove(draw_pile, 1))
    end
end

function Deck.discard_selected(hand, discard_pile)
    local count, i = 0, 1
    while i <= #hand do
        if hand[i].is_selected then
            local c = table.remove(hand, i)
            c.is_selected=false; c.hover_offset=0; c.select_offset=0
            table.insert(discard_pile, c)
            count = count + 1
        else i = i + 1 end
    end
    return count
end

function Deck.move_to_discard(hand, discard_pile, played_cards)
    local played_set = {}
    for _, c in ipairs(played_cards) do played_set[c] = true end
    local i = 1
    while i <= #hand do
        if played_set[hand[i]] then
            local c = table.remove(hand, i)
            c.is_selected=false; c.hover_offset=0; c.select_offset=0
            table.insert(discard_pile, c)
        else i = i + 1 end
    end
end

function Deck.toggle_select(hand, card, max_selected)
    if card.is_selected then card.is_selected = false; return true end
    local count = 0
    for _, c in ipairs(hand) do if c.is_selected then count=count+1 end end
    if count < max_selected then card.is_selected = true; return true end
    return false
end

function Deck.get_selected(hand)
    local out = {}
    for _, c in ipairs(hand) do if c.is_selected then table.insert(out, c) end end
    return out
end

function Deck.deselect_all(hand)
    for _, c in ipairs(hand) do c.is_selected = false end
end

return Deck
