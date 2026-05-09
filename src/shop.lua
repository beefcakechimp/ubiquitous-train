-- Shop: generation, buy, sell, reroll
local Jokers = require("src.jokers")
local Deck   = require("src.deck")

local Shop = {}

local JOKER_PRICES = { common=5, uncommon=6, rare=8 }

local RANKS = {"2","3","4","5","6","7","8","9","10","J","Q","K","A"}
local SUITS = {"Hearts","Diamonds","Clubs","Spades"}
local SUIT_FANCY = { Hearts="♥", Diamonds="♦", Clubs="♣", Spades="♠" }
local RANK_VALUES = {
    ["2"]=2,["3"]=3,["4"]=4,["5"]=5,["6"]=6,["7"]=7,["8"]=8,
    ["9"]=9,["10"]=10,["J"]=11,["Q"]=12,["K"]=13,["A"]=14
}
local RANK_CHIPS = {
    ["2"]=2,["3"]=3,["4"]=4,["5"]=5,["6"]=6,["7"]=7,["8"]=8,
    ["9"]=9,["10"]=10,["J"]=10,["Q"]=10,["K"]=10,["A"]=11
}

local function card_price(rank)
    if rank == "A" then return 5
    elseif rank == "J" or rank == "Q" or rank == "K" then return 4
    else return 3 end
end

local function random_shop_card()
    local rank = RANKS[math.random(#RANKS)]
    local suit = SUITS[math.random(#SUITS)]
    local c = {
        rank = rank, suit = suit,
        symbol   = SUIT_FANCY[suit],
        rank_val = RANK_VALUES[rank],
        chip_val = RANK_CHIPS[rank],
        is_shame = false, is_starter = false,
        hover_offset = 0, select_offset = 0,
        is_hovered = false, is_selected = false,
        price     = card_price(rank),
        sell_value = 2,
    }
    return c
end

local function pick_jokers(run, unlocked_ids, count)
    local pool = Jokers.get_pool(run, unlocked_ids)
    -- Fisher-Yates shuffle pool
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local slots = {}
    for i = 1, math.min(count, #pool) do
        local jok = pool[i]
        local def = Jokers.get_def(jok.id)
        jok.price     = JOKER_PRICES[def and def.rarity or "common"] or 5
        jok.sell_value = math.floor(jok.price / 2)
        slots[i] = { item = jok, sold = false }
    end
    return slots
end

-- Build a fresh shop; unlocked_ids is the list of extra-unlocked joker ids
function Shop.generate(run, unlocked_ids)
    local shop = {
        card_slots  = {},
        joker_slots = {},
        reroll_cost = 1,
        message     = "",
        msg_timer   = 0,
    }
    for i = 1, 3 do
        shop.card_slots[i] = { item = random_shop_card(), sold = false }
    end
    shop.joker_slots = pick_jokers(run, unlocked_ids, 2)
    return shop
end

function Shop.reroll(shop, run, unlocked_ids)
    if run.gold < shop.reroll_cost then
        return false, "Need " .. shop.reroll_cost .. " gold to reroll!"
    end
    run.gold = run.gold - shop.reroll_cost
    shop.reroll_cost = shop.reroll_cost + 1
    shop.card_slots = {}
    for i = 1, 3 do
        shop.card_slots[i] = { item = random_shop_card(), sold = false }
    end
    shop.joker_slots = pick_jokers(run, unlocked_ids, 2)
    return true, "Shop rerolled!"
end

function Shop.buy_card(shop, run, slot_index)
    local slot = shop.card_slots[slot_index]
    if not slot or slot.sold then return false, "Not available!" end
    if run.gold < slot.item.price then
        return false, "Need " .. slot.item.price .. " gold!"
    end
    run.gold = run.gold - slot.item.price
    table.insert(run.deck, slot.item)
    slot.sold = true
    local name = slot.item.rank .. " of " .. slot.item.suit
    return true, "Bought " .. name .. "!"
end

function Shop.buy_joker(shop, run, slot_index)
    local slot = shop.joker_slots[slot_index]
    if not slot or slot.sold then return false, "Not available!" end
    if #run.jokers >= 5 then return false, "Joker slots full (max 5)!" end
    if run.gold < slot.item.price then
        return false, "Need " .. slot.item.price .. " gold!"
    end
    run.gold = run.gold - slot.item.price
    table.insert(run.jokers, slot.item)
    slot.sold = true
    return true, "Bought " .. slot.item.name .. "!"
end

function Shop.sell_joker(run, joker_index)
    local j = run.jokers[joker_index]
    if not j then return false, "No joker to sell!" end
    local gold = j.sell_value or 3
    local name = j.name
    run.gold = run.gold + gold
    table.remove(run.jokers, joker_index)
    return true, "Sold " .. name .. " for " .. gold .. " gold!"
end

function Shop.update(shop, dt)
    if shop.msg_timer > 0 then
        shop.msg_timer = shop.msg_timer - dt
    end
end

function Shop.set_message(shop, msg, duration)
    shop.message  = msg
    shop.msg_timer = duration or 2.5
end

return Shop
