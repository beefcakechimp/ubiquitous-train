-- State machine: routes love.* callbacks to the active scene
local UI     = require("src.ui")
local Run    = require("src.run")
local Shop   = require("src.shop")
local Deck   = require("src.deck")
local Bosses = require("src.bosses")
local Jokers = require("src.jokers")

local GS = {}

-- Global mutable state for the current session
local state       = "menu"   -- "menu" | "combat" | "shop" | "victory" | "gameover"
local run         = nil
local shop        = nil
local unlocked_ids = {}       -- joker ids unlocked across runs (session-scoped)
local mx, my      = 0, 0     -- current mouse position

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function start_new_run()
    run   = Run.new()
    shop  = nil
    state = "combat"
end

local function enter_shop()
    -- Grant gold reward for the boss just defeated
    run.gold = run.gold + run.active_boss.gold_reward

    -- Unlock jokers tied to this boss
    local new_unlocks = Jokers.UNLOCK_TABLE[run.active_boss.id] or {}
    for _, id in ipairs(new_unlocks) do
        local already = false
        for _, uid in ipairs(unlocked_ids) do
            if uid == id then already = true; break end
        end
        if not already then table.insert(unlocked_ids, id) end
    end

    shop  = Shop.generate(run, unlocked_ids)
    state = "shop"
end

local function enter_next_combat()
    run.boss_index = run.boss_index + 1
    run.active_boss = Bosses.get(run.boss_index)
    Run.start_fight(run)
    shop  = nil
    state = "combat"
end

-- ─── Public interface ─────────────────────────────────────────────────────────

function GS.init()
    UI.init()
    math.randomseed(os.time())
end

function GS.update(dt)
    mx, my = love.mouse.getPosition()

    if state == "combat" and run then
        Run.update(run, dt)
        UI.update(dt, run, mx, my)
    elseif state == "shop" and shop then
        Shop.update(shop, dt)
    end
end

function GS.draw()
    if state == "menu" then
        UI.draw_menu(mx, my)

    elseif state == "combat" then
        UI.draw_combat(run, mx, my)

    elseif state == "shop" then
        UI.draw_shop(shop, run, mx, my)

    elseif state == "victory" then
        UI.draw_victory(run, mx, my)

    elseif state == "gameover" then
        UI.draw_gameover(run, mx, my)
    end
end

function GS.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- ── MENU ──
    if state == "menu" then
        if UI.menu_start_clicked(x, y) then
            start_new_run()
        end

    -- ── COMBAT ──
    elseif state == "combat" then
        -- Card selection
        local card_idx = UI.card_at_mouse(run, x, y)
        if card_idx then
            Deck.toggle_select(run.hand, run.hand[card_idx], run.max_select)
            return
        end

        -- Joker sell (click on joker)
        local jn = #run.jokers
        for i = 1, jn do
            local jx = 960 + (i-1) * (78 + 6)
            local jy = 20
            if UI.point_in(x, y, jx, jy, 78, 110) then
                local ok, msg = Shop.sell_joker(run, i)
                Run.set_message(run, msg, 2)
                return
            end
        end

        -- Buttons
        local btn = UI.button_at_mouse(x, y)
        if btn == "play" then
            local outcome = Run.play_hand(run)
            if outcome == "boss_defeated" then
                if run.boss_index >= Bosses.count() then
                    state = "victory"
                else
                    enter_shop()
                end
            elseif outcome == "gameover" then
                state = "gameover"
            end

        elseif btn == "discard" then
            Run.discard(run)
        end

    -- ── SHOP ──
    elseif state == "shop" then
        local kind, idx = UI.shop_card_at_mouse(shop, run, x, y)
        if kind == "card" then
            local ok, msg = Shop.buy_card(shop, run, idx)
            Shop.set_message(shop, msg, 2.5)

        elseif kind == "joker" then
            local ok, msg = Shop.buy_joker(shop, run, idx)
            Shop.set_message(shop, msg, 2.5)

        elseif kind == "sell_joker" then
            local ok, msg = Shop.sell_joker(run, idx)
            Shop.set_message(shop, msg, 2.5)

        elseif kind == "reroll" then
            local ok, msg = Shop.reroll(shop, run, unlocked_ids)
            Shop.set_message(shop, msg, 2.5)

        elseif kind == "continue" then
            enter_next_combat()
        end

    -- ── VICTORY / GAMEOVER ──
    elseif state == "victory" then
        if UI.victory_replay_clicked(x, y) then
            start_new_run()
        end

    elseif state == "gameover" then
        if UI.gameover_replay_clicked(x, y) then
            start_new_run()
        end
    end
end

function GS.keypressed(key)
    if key == "escape" then
        if state == "combat" or state == "shop" then
            state = "menu"
            run   = nil
            shop  = nil
        end
    end

    -- Debug shortcut: skip to next boss (Shift+N)
    if key == "n" and love.keyboard.isDown("lshift") and state == "combat" then
        run.active_boss.hp = 0
        if run.boss_index >= Bosses.count() then
            state = "victory"
        else
            enter_shop()
        end
    end
end

return GS
