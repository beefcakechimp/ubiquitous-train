-- Joker registry and two-pass scoring pipeline
local Jokers = {}

-- Two-pass pipeline: additive bonuses fire before multiplicative bonuses so
-- order-of-registration doesn't create asymmetric results.
-- on_chips_add(ctx)  → mutates ctx.chips and/or ctx.mult_add
-- on_mult_multiply(ctx) → mutates ctx.mult (multiplication only)

local REGISTRY = {
    peacock = {
        name = "Peacock",
        description = "+4 Mult if Flush played",
        rarity = "common", cost = 5, sell_value = 3,
        on_chips_add = function(ctx)
            local h = ctx.hand_id
            if h == "flush" or h == "straight_flush" or h == "royal_flush" then
                ctx.mult_add = ctx.mult_add + 4
            end
        end,
    },
    bull = {
        name = "Bull",
        description = "+2 Chips per Gold held",
        rarity = "common", cost = 5, sell_value = 3,
        on_chips_add = function(ctx)
            ctx.chips = ctx.chips + ctx.run.gold * 2
        end,
    },
    lusty_heart = {
        name = "Lusty Heart",
        description = "x2 Mult if any Hearts played",
        rarity = "uncommon", cost = 6, sell_value = 4,
        on_mult_multiply = function(ctx)
            for _, c in ipairs(ctx.played) do
                if c.suit == "Hearts" then
                    ctx.mult = ctx.mult * 2
                    return
                end
            end
        end,
    },
    nurses_touch = {
        name = "Nurse's Touch",
        description = "+3 Mult per face card played",
        rarity = "common", cost = 5, sell_value = 3,
        on_chips_add = function(ctx)
            for _, c in ipairs(ctx.scoring) do
                local r = c.rank
                if r == "J" or r == "Q" or r == "K" then
                    ctx.mult_add = ctx.mult_add + 3
                end
            end
        end,
    },
    lucky_charm = {
        name = "Lucky Charm",
        description = "1-in-5 chance: x4 Mult",
        rarity = "uncommon", cost = 6, sell_value = 4,
        on_mult_multiply = function(ctx)
            if math.random(5) == 1 then
                ctx.mult = ctx.mult * 4
            end
        end,
    },
    voyeur = {
        name = "Voyeur",
        description = "+1 Mult per discard used this fight",
        rarity = "common", cost = 5, sell_value = 3,
        on_chips_add = function(ctx)
            ctx.mult_add = ctx.mult_add + ctx.run.voyeur_discards
        end,
    },
    temptress = {
        name = "Temptress",
        description = "x1.5 Mult on first hand each boss",
        rarity = "uncommon", cost = 6, sell_value = 4,
        on_mult_multiply = function(ctx)
            if not ctx.run.temptress_used then
                ctx.mult = math.floor(ctx.mult * 1.5)
                ctx.run.temptress_used = true
            end
        end,
    },
    tease = {
        name = "Tease",
        description = "+8 Chips per unplayed card in hand",
        rarity = "common", cost = 5, sell_value = 3,
        on_chips_add = function(ctx)
            local unplayed = #ctx.run.hand - #ctx.played
            ctx.chips = ctx.chips + unplayed * 8
        end,
    },
    the_big_reveal = {
        name = "The Big Reveal",
        description = "x3 Mult at boss's final stage",
        rarity = "rare", cost = 8, sell_value = 5,
        on_mult_multiply = function(ctx)
            local b = ctx.run.active_boss
            if b and b.stage == b.max_stages then
                ctx.mult = ctx.mult * 3
            end
        end,
    },
    seductress = {
        name = "Seductress",
        description = "+2 Mult per hand played this fight",
        rarity = "uncommon", cost = 6, sell_value = 4,
        on_chips_add = function(ctx)
            ctx.mult_add = ctx.mult_add + ctx.run.hands_played * 2
        end,
    },
    straightlaced = {
        name = "Straight-Laced",
        description = "+12 Mult if Straight or better",
        rarity = "rare", cost = 8, sell_value = 5,
        on_chips_add = function(ctx)
            local strong = {
                straight=true, flush=true, full_house=true,
                four_of_a_kind=true, straight_flush=true, royal_flush=true,
            }
            if strong[ctx.hand_id] then
                ctx.mult_add = ctx.mult_add + 12
            end
        end,
    },
}

-- Always-available joker pool for the first run
local STARTER_IDS = {"peacock", "bull", "nurses_touch", "tease"}

-- Additional jokers unlocked after defeating specific bosses
Jokers.UNLOCK_TABLE = {
    head_pharmacist  = {"voyeur",          "temptress"},
    strict_professor = {"seductress",      "straightlaced"},
    ceo_of_sin       = {"the_big_reveal",  "lusty_heart", "lucky_charm"},
}

function Jokers.get_def(id)
    return REGISTRY[id]
end

function Jokers.create_instance(id)
    local def = REGISTRY[id]
    if not def then return nil end
    local inst = { id = id }
    for k, v in pairs(def) do inst[k] = v end
    return inst
end

-- Two-pass scoring pipeline.
-- Returns: chips, mult, damage
function Jokers.score_pipeline(run, hand_id, base_chips, base_mult, played_cards, scoring_cards)
    local ctx = {
        run      = run,
        hand_id  = hand_id,
        chips    = base_chips,
        mult_add = 0,
        mult     = base_mult,
        played   = played_cards,
        scoring  = scoring_cards,
    }

    -- Pass 1: additive chip and mult bonuses
    for _, joker in ipairs(run.jokers) do
        local def = REGISTRY[joker.id]
        if def and def.on_chips_add then
            def.on_chips_add(ctx)
        end
    end
    ctx.mult = ctx.mult + ctx.mult_add

    -- Pass 2: multiplicative mult scaling
    for _, joker in ipairs(run.jokers) do
        local def = REGISTRY[joker.id]
        if def and def.on_mult_multiply then
            def.on_mult_multiply(ctx)
        end
    end

    local damage = math.max(0, math.floor(ctx.chips * ctx.mult))
    return ctx.chips, ctx.mult, damage
end

-- Returns jokers available to appear in the shop (not yet owned, in unlocked set)
function Jokers.get_pool(run, unlocked_ids)
    local owned = {}
    for _, j in ipairs(run.jokers) do owned[j.id] = true end

    local unlocked_set = {}
    for _, id in ipairs(STARTER_IDS) do unlocked_set[id] = true end
    if unlocked_ids then
        for _, id in ipairs(unlocked_ids) do unlocked_set[id] = true end
    end

    local pool = {}
    for id in pairs(unlocked_set) do
        if not owned[id] and REGISTRY[id] then
            table.insert(pool, Jokers.create_instance(id))
        end
    end
    return pool
end

return Jokers
