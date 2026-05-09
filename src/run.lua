-- Active run state: deck, gold, jokers, boss progress, fight state
local Deck   = require("src.deck")
local Hands  = require("src.hands")
local Jokers = require("src.jokers")
local Bosses = require("src.bosses")

local Run = {}

local HAND_SIZE   = 8
local MAX_SELECT  = 5
local MAX_DISCARD = 3
local MAX_HANDS   = 5   -- hands allowed per boss fight before game over

function Run.new()
    local run = {
        -- Progress
        boss_index  = 1,
        active_boss = Bosses.get(1),

        -- Deck pools
        deck        = Deck.build_standard(),
        draw_pile   = {},
        discard_pile = {},
        hand        = {},

        -- Jokers (max 5)
        jokers      = {},

        -- Economy
        gold        = 0,

        -- Fight-scoped state (reset per boss)
        max_discards        = MAX_DISCARD,
        discards_remaining  = MAX_DISCARD,
        max_hands           = MAX_HANDS,
        hands_remaining     = MAX_HANDS,
        hand_size           = HAND_SIZE,
        max_select          = MAX_SELECT,
        hands_played        = 0,
        voyeur_discards     = 0,
        temptress_used      = false,
        debuffs             = {},   -- { effect, amount, rounds, message }

        -- Scoring display state
        last_chips     = 0,
        last_mult      = 0,
        last_damage    = 0,
        last_hand_name = "",
        popup_timer    = 0,

        -- Message display
        message       = "",
        msg_timer     = 0,
        boss_msg      = "",
        boss_msg_timer = 0,
        stage_flash_timer = 0,

        -- Run stats
        total_damage = 0,
    }

    -- Seed draw pile from deck
    for _, c in ipairs(run.deck) do
        table.insert(run.draw_pile, c)
    end
    Deck.shuffle(run.draw_pile)
    Deck.draw(run.draw_pile, run.discard_pile, run.hand, run.hand_size)

    return run
end

-- Reset fight-scoped state and deal a fresh hand for the next boss
function Run.start_fight(run)
    run.discards_remaining  = run.max_discards
    run.hands_remaining     = run.max_hands
    run.hands_played        = 0
    run.voyeur_discards     = 0
    run.temptress_used      = false
    run.debuffs             = {}
    run.last_damage         = 0
    run.popup_timer         = 0
    run.message             = ""
    run.boss_msg            = ""
    run.stage_flash_timer   = 0

    -- Return all cards to draw pile (clear shame cards from prior boss)
    run.draw_pile   = {}
    run.discard_pile = {}
    for _, c in ipairs(run.hand) do
        c.is_selected  = false
        c.hover_offset = 0
        c.select_offset = 0
    end
    run.hand = {}

    for _, c in ipairs(run.deck) do
        if not c.is_shame then
            c.is_selected  = false
            c.hover_offset = 0
            c.select_offset = 0
            table.insert(run.draw_pile, c)
        end
    end
    Deck.shuffle(run.draw_pile)
    Deck.draw(run.draw_pile, run.discard_pile, run.hand,
              Run.effective_hand_size(run))
end

-- Hand size after applying Detention-style debuffs
function Run.effective_hand_size(run)
    local reduction = 0
    for _, d in ipairs(run.debuffs) do
        if d.effect == "reduce_hand_size" then
            reduction = reduction + d.amount
        end
    end
    return math.max(1, run.hand_size - reduction)
end

-- Tick down debuff rounds; called after each hand played
local function tick_debuffs(run)
    local i = 1
    while i <= #run.debuffs do
        run.debuffs[i].rounds = run.debuffs[i].rounds - 1
        if run.debuffs[i].rounds <= 0 then
            table.remove(run.debuffs, i)
        else
            i = i + 1
        end
    end
end

-- Set a timed display message
function Run.set_message(run, msg, duration)
    run.message  = msg
    run.msg_timer = duration or 2.5
end

function Run.set_boss_msg(run, msg, duration)
    run.boss_msg       = msg
    run.boss_msg_timer = duration or 3
end

-- Play the currently selected cards.
-- Returns: "ok", "gameover", or "boss_defeated"
function Run.play_hand(run)
    local selected = Deck.get_selected(run.hand)
    if #selected == 0 then
        Run.set_message(run, "Select cards to play!", 2)
        return "ok"
    end

    -- Detect and score the hand
    local hand_id, scoring_cards = Hands.detect(selected)
    local ht = Hands.get_type(hand_id)
    local base_chips = ht.chips
    local base_mult  = ht.mult

    -- Add individual card chip values (shame cards subtract)
    for _, c in ipairs(selected) do
        base_chips = base_chips + c.chip_val
    end

    -- Joker scoring pipeline
    local chips, mult, damage = Jokers.score_pipeline(
        run, hand_id, base_chips, base_mult, selected, scoring_cards)
    damage = math.max(0, damage)

    -- Store display values
    run.last_chips     = chips
    run.last_mult      = mult
    run.last_damage    = damage
    run.last_hand_name = Hands.type_name(hand_id)
    run.popup_timer    = 3
    run.total_damage   = run.total_damage + damage

    -- Apply damage to boss
    local result = Bosses.apply_damage(run.active_boss, damage)

    -- Update fight counters
    run.hands_played    = run.hands_played + 1
    run.hands_remaining = run.hands_remaining - 1
    run.temptress_used  = run.temptress_used  -- (temptress sets this itself)

    -- Move played cards to discard and refill
    Deck.move_to_discard(run.hand, run.discard_pile, selected)
    Deck.draw(run.draw_pile, run.discard_pile, run.hand,
              Run.effective_hand_size(run) - #run.hand)

    -- Tick debuffs after each hand
    tick_debuffs(run)

    -- Boss attack
    local action = run.active_boss.on_player_hand(run.active_boss, run)
    if action then
        if action.type == "debuff" then
            table.insert(run.debuffs, {
                effect  = action.effect,
                amount  = action.amount,
                rounds  = action.rounds,
                message = action.message,
            })
        elseif action.type == "shame" then
            local shame = Deck.new_shame_card()
            local pos = math.random(1, math.max(1, #run.draw_pile))
            table.insert(run.draw_pile, pos, shame)
            -- Also add to deck so it persists on reshuffle (within this fight)
            table.insert(run.deck, shame)
        end
        Run.set_boss_msg(run, action.message, 3)
    end

    -- Check stage change for flash effect
    if result.stage_changed then
        run.stage_flash_timer = 1.5
        local dialogue = run.active_boss.dialogue[result.new_stage] or ""
        Run.set_boss_msg(run, "STAGE " .. result.new_stage .. "! \"" .. dialogue .. "\"", 4)
    end

    -- Return outcome
    if result.defeated then
        return "boss_defeated"
    elseif run.hands_remaining <= 0 then
        return "gameover"
    end
    return "ok"
end

-- Discard selected cards and refill
-- Returns: "ok" or error string
function Run.discard(run)
    local selected = Deck.get_selected(run.hand)
    if #selected == 0 then
        Run.set_message(run, "Select cards to discard!", 2)
        return "ok"
    end
    if run.discards_remaining <= 0 then
        Run.set_message(run, "No discards remaining!", 2)
        return "ok"
    end

    local count = Deck.discard_selected(run.hand, run.discard_pile)
    run.discards_remaining = run.discards_remaining - 1
    run.voyeur_discards    = run.voyeur_discards + 1

    Deck.draw(run.draw_pile, run.discard_pile, run.hand,
              Run.effective_hand_size(run) - #run.hand)
    return "ok"
end

function Run.update(run, dt)
    if run.msg_timer > 0        then run.msg_timer        = run.msg_timer        - dt end
    if run.boss_msg_timer > 0   then run.boss_msg_timer   = run.boss_msg_timer   - dt end
    if run.popup_timer > 0      then run.popup_timer       = run.popup_timer      - dt end
    if run.stage_flash_timer > 0 then run.stage_flash_timer = run.stage_flash_timer - dt end
end

return Run
