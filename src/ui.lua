-- All love.graphics calls live here; no other module may draw to screen.
local UI = {}

-- ─── Layout constants (1280×720) ───────────────────────────────────────────
UI.W = 1280
UI.H = 720

-- Left panel – boss portrait
local BOSS_X  = 20
local BOSS_Y  = 40
local BOSS_W  = 275
local BOSS_H  = 370
local HP_X    = 20
local HP_Y    = 420
local HP_W    = 275
local HP_H    = 22
local DLG_X   = 20
local DLG_Y   = 452

-- Right panel – joker display
local JKR_X       = 960
local JKR_Y       = 20
local JKR_W       = 78
local JKR_H       = 110
local JKR_SPACING = 6

-- HUD (top-right)
local HUD_X = 960
local HUD_Y = 150

-- Score popup
local POP_X = 330
local POP_Y = 200

-- Buttons
local BTN_PLAY    = { x=490, y=482, w=150, h=42 }
local BTN_DISCARD = { x=660, y=482, w=140, h=42 }

-- Hand cards
UI.CARD_W        = 92
UI.CARD_H        = 130
local CARD_SPACING   = 10
local HAND_CENTER_X  = 640
local HAND_BASE_Y    = 548
local HOVER_LIFT     = 22     -- px up when hovered
local SELECT_LIFT    = 44     -- px up when selected (adds to hover)
local ANIM_SPEED     = 20     -- lerp speed constant

-- ─── Color palette ──────────────────────────────────────────────────────────
local C = {
    bg        = {0.05, 0.05, 0.10},
    panel     = {0.08, 0.08, 0.16},
    border    = {0.25, 0.25, 0.45},
    text      = {0.95, 0.95, 0.95},
    text_dim  = {0.60, 0.60, 0.70},
    gold      = {1.00, 0.85, 0.20},
    green     = {0.20, 0.85, 0.40},
    red       = {0.88, 0.20, 0.20},
    purple    = {0.68, 0.28, 0.88},
    blue      = {0.30, 0.55, 0.95},
    card_bg   = {0.98, 0.97, 0.92},
    card_hov  = {0.84, 0.91, 1.00},
    card_sel  = {1.00, 0.95, 0.60},
    card_shame= {0.30, 0.05, 0.30},
    btn       = {0.18, 0.28, 0.48},
    btn_hov   = {0.28, 0.42, 0.68},
    btn_danger= {0.48, 0.12, 0.12},
    joker_bg  = {0.28, 0.14, 0.42},
    joker_hov = {0.40, 0.20, 0.58},
    hearts    = {0.90, 0.18, 0.18},
    diamonds  = {0.88, 0.28, 0.10},
    clubs     = {0.08, 0.08, 0.08},
    spades    = {0.08, 0.08, 0.08},
}

-- ─── Fonts ──────────────────────────────────────────────────────────────────
local F = {}

function UI.init()
    F.sm    = love.graphics.newFont(12)
    F.md    = love.graphics.newFont(15)
    F.lg    = love.graphics.newFont(20)
    F.xl    = love.graphics.newFont(28)
    F.xxl   = love.graphics.newFont(42)
    F.title = love.graphics.newFont(60)
    F.rank  = love.graphics.newFont(18)
    F.suit  = love.graphics.newFont(24)
end

-- ─── Helpers ────────────────────────────────────────────────────────────────
local function sc(r, g, b, a) love.graphics.setColor(r, g, b, a or 1) end
local function sc_t(t, a)     love.graphics.setColor(t[1], t[2], t[3], a or 1) end
local function sf(font)       love.graphics.setFont(font) end

local function rect(mode, x, y, w, h, r)
    love.graphics.rectangle(mode, x, y, w, h, r or 0, r or 0)
end

local function draw_panel(x, y, w, h, r)
    sc_t(C.panel)
    rect("fill", x, y, w, h, r or 6)
    sc_t(C.border)
    love.graphics.setLineWidth(1.5)
    rect("line", x, y, w, h, r or 6)
    love.graphics.setLineWidth(1)
end

-- ─── Mouse helpers ──────────────────────────────────────────────────────────
function UI.point_in(mx, my, x, y, w, h)
    return mx >= x and mx <= x+w and my >= y and my <= y+h
end

-- Returns card index (1-based) in run.hand at mouse pos, or nil
function UI.card_at_mouse(run, mx, my)
    if not run or not run.hand then return nil end
    local n = #run.hand
    if n == 0 then return nil end
    local total_w = n * UI.CARD_W + (n-1) * CARD_SPACING
    local sx = HAND_CENTER_X - total_w / 2
    -- Iterate in reverse so top-drawn cards are hit first
    for i = n, 1, -1 do
        local cx = sx + (i-1) * (UI.CARD_W + CARD_SPACING)
        local c  = run.hand[i]
        local cy = HAND_BASE_Y + c.hover_offset + c.select_offset
        if UI.point_in(mx, my, cx, cy, UI.CARD_W, UI.CARD_H) then
            return i
        end
    end
    return nil
end

-- Returns "play", "discard", or nil
function UI.button_at_mouse(mx, my)
    if UI.point_in(mx, my, BTN_PLAY.x, BTN_PLAY.y, BTN_PLAY.w, BTN_PLAY.h) then
        return "play"
    end
    if UI.point_in(mx, my, BTN_DISCARD.x, BTN_DISCARD.y, BTN_DISCARD.w, BTN_DISCARD.h) then
        return "discard"
    end
    return nil
end

-- Shop hit-testing
-- run is needed to detect sell-joker hit areas (owned joker count)
function UI.shop_card_at_mouse(shop, run, mx, my)
    -- Cards displayed at y=175
    for i, slot in ipairs(shop.card_slots) do
        if not slot.sold then
            local x = 80 + (i-1) * 220
            local y = 175
            if UI.point_in(mx, my, x, y, UI.CARD_W, UI.CARD_H) then
                return "card", i
            end
        end
    end
    -- Jokers displayed at y=355
    for i, slot in ipairs(shop.joker_slots) do
        if not slot.sold then
            local x = 80 + (i-1) * 320
            local y = 355
            if UI.point_in(mx, my, x, y, 140, 90) then
                return "joker", i
            end
        end
    end
    -- Sell buttons for owned jokers (position matches draw_shop)
    for i = 1, #(run and run.jokers or {}) do
        local bx = 80 + (i-1) * 170
        local sx, sy, sw, sh = bx + 6, 530, 70, 18
        if UI.point_in(mx, my, sx, sy, sw, sh) then
            return "sell_joker", i
        end
    end
    -- Reroll button
    if UI.point_in(mx, my, 880, 590, 180, 40) then
        return "reroll", 0
    end
    -- Continue button
    if UI.point_in(mx, my, 530, 650, 220, 46) then
        return "continue", 0
    end
    return nil, nil
end

-- ─── Animation update (call every frame from love.update) ───────────────────
function UI.update(dt, run, mx, my)
    if not run or not run.hand then return end
    local n = #run.hand
    local total_w = n * UI.CARD_W + (n-1) * CARD_SPACING
    local sx = HAND_CENTER_X - total_w / 2

    for i, c in ipairs(run.hand) do
        local cx = sx + (i-1) * (UI.CARD_W + CARD_SPACING)
        local cy = HAND_BASE_Y + c.hover_offset + c.select_offset
        c.is_hovered = UI.point_in(mx, my, cx, cy, UI.CARD_W, UI.CARD_H)

        local target_hover  = (c.is_hovered and not c.is_selected) and -HOVER_LIFT  or 0
        local target_select = c.is_selected                         and -SELECT_LIFT or 0

        -- Frame-rate-independent lerp via e^(-k·dt)
        local k = ANIM_SPEED
        c.hover_offset  = c.hover_offset  + (target_hover  - c.hover_offset)  * (1 - math.exp(-k * dt))
        c.select_offset = c.select_offset + (target_select - c.select_offset) * (1 - math.exp(-k * dt))
    end
end

-- ─── Card rendering ──────────────────────────────────────────────────────────
local function suit_color(card)
    if card.is_shame then return C.card_shame end
    local s = card.suit
    if s == "Hearts"   then return C.hearts   end
    if s == "Diamonds" then return C.diamonds  end
    if s == "Clubs"    then return C.clubs     end
    return C.spades
end

local function draw_card(card, x, y)
    local w, h = UI.CARD_W, UI.CARD_H

    -- Shadow
    sc(0, 0, 0, 0.35)
    rect("fill", x+3, y+4, w, h, 7)

    -- Body
    if card.is_shame then
        sc_t(C.card_shame)
    elseif card.is_selected then
        sc_t(C.card_sel)
    elseif card.is_hovered then
        sc_t(C.card_hov)
    else
        sc_t(C.card_bg)
    end
    rect("fill", x, y, w, h, 7)

    -- Border
    if card.is_selected then
        sc_t(C.gold)
        love.graphics.setLineWidth(2.5)
        rect("line", x, y, w, h, 7)
        love.graphics.setLineWidth(1)
    elseif card.is_hovered then
        sc_t(C.blue)
        rect("line", x, y, w, h, 7)
    else
        sc(0.7, 0.7, 0.7)
        rect("line", x, y, w, h, 7)
    end

    -- Rank and suit text
    local sc_c = suit_color(card)
    sc_t(sc_c)

    sf(F.rank)
    love.graphics.print(card.rank,   x + 6, y + 5)
    sf(F.sm)
    love.graphics.print(card.symbol, x + 6, y + 24)

    -- Centre symbol (large)
    sf(F.suit)
    local sym_w = F.suit:getWidth(card.symbol)
    love.graphics.print(card.symbol, x + w/2 - sym_w/2, y + h/2 - 14)

    -- Bottom-right (mirrored)
    sf(F.sm)
    love.graphics.print(card.symbol, x + w - 16, y + h - 34)
    sf(F.rank)
    local rank_w = F.rank:getWidth(card.rank)
    love.graphics.print(card.rank,   x + w - rank_w - 5, y + h - 52)

    -- Shame label overlay
    if card.is_shame then
        sc(1, 0.4, 1)
        sf(F.sm)
        love.graphics.printf("SHAME\n-5 Chips", x+2, y + h/2 - 16, w-4, "center")
    end
end

-- Draw the hand of cards centered at HAND_CENTER_X
local function draw_hand(run)
    if not run or not run.hand then return end
    local n = #run.hand
    if n == 0 then return end
    local total_w = n * UI.CARD_W + (n-1) * CARD_SPACING
    local sx = HAND_CENTER_X - total_w / 2

    -- Draw non-selected cards first so selected appear on top
    for pass = 1, 2 do
        for i, c in ipairs(run.hand) do
            if (pass == 1) == (not c.is_selected) then
                local cx = sx + (i-1) * (UI.CARD_W + CARD_SPACING)
                local cy = HAND_BASE_Y + c.hover_offset + c.select_offset
                draw_card(c, cx, cy)
            end
        end
    end
end

-- ─── Boss portrait ──────────────────────────────────────────────────────────
local function draw_boss_portrait(boss)
    local sc_col = boss.stage_colors and boss.stage_colors[boss.stage]
                   or {0.2, 0.2, 0.4}

    -- Background
    sc_t(sc_col)
    rect("fill", BOSS_X, BOSS_Y, BOSS_W, BOSS_H, 8)

    -- Border (flashes gold when stage changes)
    sc_t(C.blue)
    love.graphics.setLineWidth(2)
    rect("line", BOSS_X, BOSS_Y, BOSS_W, BOSS_H, 8)
    love.graphics.setLineWidth(1)

    -- Stage label
    sc_t(C.text)
    sf(F.sm)
    love.graphics.print("Stage " .. boss.stage .. "/" .. boss.max_stages,
                         BOSS_X + 8, BOSS_Y + 8)

    -- Art placeholder
    sc(1, 1, 1, 0.35)
    sf(F.md)
    local labels = {
        [1] = "[Fully Composed]",
        [2] = "[Losing Composure]",
        [3] = "[Full Reveal]",
        [4] = "[Grand Finale]",
    }
    local lbl = labels[boss.stage] or "[Art Here]"
    love.graphics.printf(lbl, BOSS_X, BOSS_Y + BOSS_H/2 - 10, BOSS_W, "center")

    -- Boss title at bottom of portrait
    sc_t(C.text)
    sf(F.md)
    love.graphics.printf(boss.name,  BOSS_X, BOSS_Y + BOSS_H - 42, BOSS_W, "center")
    sc_t(C.text_dim)
    sf(F.sm)
    love.graphics.printf(boss.title or "", BOSS_X, BOSS_Y + BOSS_H - 24, BOSS_W, "center")
end

-- ─── HP bar ─────────────────────────────────────────────────────────────────
local function draw_hp_bar(boss)
    local pct = math.max(0, boss.hp / boss.max_hp)

    sc(0.12, 0.06, 0.06)
    rect("fill", HP_X, HP_Y, HP_W, HP_H, 4)

    local r = 0.2 + 0.7 * (1 - pct)
    local g = 0.8 * pct
    sc(r, g, 0.08)
    rect("fill", HP_X, HP_Y, HP_W * pct, HP_H, 4)

    sc_t(C.text)
    sf(F.sm)
    love.graphics.printf(boss.hp .. " / " .. boss.max_hp,
                          HP_X, HP_Y + 4, HP_W, "center")
end

-- ─── Joker display (right panel) ─────────────────────────────────────────────
local function draw_jokers(jokers, mx, my)
    sf(F.sm)
    sc_t(C.text_dim)
    love.graphics.print("JOKERS", JKR_X, JKR_Y - 16)

    for i, j in ipairs(jokers) do
        local jx = JKR_X + (i-1) * (JKR_W + JKR_SPACING)
        local jy = JKR_Y
        local hov = UI.point_in(mx, my, jx, jy, JKR_W, JKR_H)

        sc_t(hov and C.joker_hov or C.joker_bg)
        rect("fill", jx, jy, JKR_W, JKR_H, 6)
        sc_t(C.purple)
        rect("line", jx, jy, JKR_W, JKR_H, 6)

        sc_t(C.gold)
        sf(F.sm)
        love.graphics.printf(j.name, jx + 2, jy + 6, JKR_W - 4, "center")

        sc_t(C.text_dim)
        love.graphics.printf(j.description or "", jx + 2, jy + 26, JKR_W - 4, "center")

        -- Sell hint on hover
        if hov then
            sc(0.9, 0.5, 0.1)
            love.graphics.printf("Sell: " .. (j.sell_value or 3) .. "g",
                                  jx, jy + JKR_H - 18, JKR_W, "center")
        end
    end
end

-- ─── HUD (hands / discards / gold) ──────────────────────────────────────────
local function draw_hud(run)
    local x = HUD_X
    local y = HUD_Y

    sf(F.md)
    sc_t(C.gold)
    love.graphics.print("Gold: " .. run.gold, x, y)

    sc_t(C.blue)
    love.graphics.print("Hands:   " .. run.hands_remaining .. " / " .. run.max_hands, x, y + 26)

    sc_t(C.green)
    love.graphics.print("Discards: " .. run.discards_remaining .. " / " .. run.max_discards, x, y + 52)

    -- Active debuffs
    if #run.debuffs > 0 then
        sc_t(C.red)
        sf(F.sm)
        for i, d in ipairs(run.debuffs) do
            love.graphics.print("[" .. d.effect .. " -" .. d.amount
                                 .. " (" .. d.rounds .. "r)]", x, y + 80 + (i-1)*16)
        end
    end
end

-- ─── Score popup ─────────────────────────────────────────────────────────────
local function draw_score_popup(run)
    if run.popup_timer <= 0 then return end
    local alpha = math.min(1, run.popup_timer / 1.5)

    draw_panel(POP_X, POP_Y, 380, 90, 8)

    sc_t(C.gold, alpha)
    sf(F.lg)
    love.graphics.printf(run.last_hand_name, POP_X, POP_Y + 8, 380, "center")

    sc_t(C.text, alpha)
    sf(F.md)
    local s = math.floor(run.last_chips) .. " chips  x  "
              .. string.format("%.1f", run.last_mult) .. " mult"
              .. "  =  " .. run.last_damage .. " dmg"
    love.graphics.printf(s, POP_X, POP_Y + 38, 380, "center")
end

-- ─── Hand preview (chips×mult estimate while cards are selected) ─────────────
local function draw_hand_preview(run)
    local selected = {}
    for _, c in ipairs(run.hand) do
        if c.is_selected then table.insert(selected, c) end
    end
    if #selected == 0 then return end

    local Hands = require("src.hands")
    local Jokers = require("src.jokers")
    local hand_id, scoring = Hands.detect(selected)
    local ht = Hands.get_type(hand_id)
    local chips = ht.chips
    local mult  = ht.mult
    for _, c in ipairs(selected) do chips = chips + c.chip_val end
    -- Preview doesn't run full joker pipeline (side effects), just base
    local preview_dmg = math.max(0, math.floor(chips * mult))

    sf(F.sm)
    sc_t(C.text_dim)
    local preview = Hands.type_name(hand_id) .. ": ~" .. preview_dmg .. " dmg"
    love.graphics.printf(preview, BTN_PLAY.x, BTN_PLAY.y - 18, 300, "left")
end

-- ─── Buttons ─────────────────────────────────────────────────────────────────
local function draw_button(lbl, btn, mx, my, danger)
    local hov = UI.point_in(mx, my, btn.x, btn.y, btn.w, btn.h)
    if danger then
        sc_t(hov and {0.65, 0.18, 0.18} or C.btn_danger)
    else
        sc_t(hov and C.btn_hov or C.btn)
    end
    rect("fill", btn.x, btn.y, btn.w, btn.h, 6)
    sc_t(C.text)
    sf(F.md)
    love.graphics.printf(lbl, btn.x, btn.y + btn.h/2 - 8, btn.w, "center")
end

-- ─── Messages ────────────────────────────────────────────────────────────────
local function draw_messages(run)
    if run.boss_msg_timer > 0 then
        sc_t(C.gold)
        sf(F.md)
        love.graphics.printf(run.boss_msg, DLG_X, DLG_Y, 600, "left")
    elseif run.msg_timer > 0 then
        sc_t(C.text)
        sf(F.md)
        love.graphics.printf(run.message, DLG_X, DLG_Y, 600, "left")
    else
        -- Default dialogue
        local boss = run.active_boss
        sc_t(C.text_dim)
        sf(F.sm)
        love.graphics.printf('"' .. (boss.dialogue[boss.stage] or "") .. '"',
                              DLG_X, DLG_Y, 600, "left")
    end
end

-- ─── Stage flash overlay ─────────────────────────────────────────────────────
local function draw_stage_flash(run)
    if run.stage_flash_timer > 0 then
        local alpha = math.min(0.4, run.stage_flash_timer / 1.5 * 0.4)
        sc_t(C.gold, alpha)
        rect("fill", 0, 0, UI.W, UI.H)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PUBLIC DRAW FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

function UI.draw_combat(run, mx, my)
    -- Background
    love.graphics.setBackgroundColor(C.bg)
    sc_t(C.bg)
    rect("fill", 0, 0, UI.W, UI.H)

    -- Boss name header
    sc_t(C.text)
    sf(F.xl)
    love.graphics.print(run.active_boss.name, BOSS_X + BOSS_W + 20, BOSS_Y)
    sc_t(C.text_dim)
    sf(F.sm)
    love.graphics.print("Boss " .. run.boss_index .. " / " .. require("src.bosses").count(),
                         BOSS_X + BOSS_W + 20, BOSS_Y + 32)

    draw_boss_portrait(run.active_boss)
    draw_hp_bar(run.active_boss)
    draw_jokers(run.jokers, mx, my)
    draw_hud(run)
    draw_score_popup(run)
    draw_hand_preview(run)
    draw_messages(run)

    -- Separator line above hand
    sc_t(C.border)
    love.graphics.setLineWidth(1)
    love.graphics.line(20, HAND_BASE_Y - 14, UI.W - 20, HAND_BASE_Y - 14)

    draw_hand(run)

    draw_button("PLAY HAND", BTN_PLAY, mx, my, false)
    draw_button("DISCARD",   BTN_DISCARD, mx, my, true)

    draw_stage_flash(run)
end

-- ─── Shop scene ──────────────────────────────────────────────────────────────
function UI.draw_shop(shop, run, mx, my)
    love.graphics.setBackgroundColor(C.bg)
    sc_t(C.bg)
    rect("fill", 0, 0, UI.W, UI.H)

    -- Header
    sc_t(C.gold)
    sf(F.xxl)
    love.graphics.printf("SHOP", 0, 30, UI.W, "center")

    sc_t(C.text)
    sf(F.lg)
    love.graphics.printf("Gold: " .. run.gold, 0, 90, UI.W, "center")

    -- Card slots
    sc_t(C.text_dim)
    sf(F.sm)
    love.graphics.print("Cards for sale:", 80, 155)

    for i, slot in ipairs(shop.card_slots) do
        local cx = 80 + (i-1) * 220
        local cy = 175
        if slot.sold then
            sc(0.2, 0.2, 0.2)
            rect("fill", cx, cy, UI.CARD_W, UI.CARD_H, 7)
            sc_t(C.text_dim)
            sf(F.sm)
            love.graphics.printf("SOLD", cx, cy + UI.CARD_H/2 - 8, UI.CARD_W, "center")
        else
            local hov = UI.point_in(mx, my, cx, cy, UI.CARD_W, UI.CARD_H)
            local fake_card = slot.item
            -- temporarily fake hover state for draw
            local orig_hov = fake_card.is_hovered
            fake_card.is_hovered = hov
            fake_card.hover_offset  = 0
            fake_card.select_offset = 0
            draw_card(fake_card, cx, cy)
            fake_card.is_hovered = orig_hov

            -- Price tag
            sc_t(C.gold)
            sf(F.sm)
            love.graphics.printf(slot.item.price .. "g", cx, cy + UI.CARD_H + 4, UI.CARD_W, "center")
        end
    end

    -- Joker slots
    sc_t(C.text_dim)
    sf(F.sm)
    love.graphics.print("Jokers for sale:", 80, 335)

    for i, slot in ipairs(shop.joker_slots) do
        local jx = 80 + (i-1) * 320
        local jy = 355
        local jw, jh = 140, 90
        if slot.sold then
            sc(0.2, 0.2, 0.2)
            rect("fill", jx, jy, jw, jh, 6)
            sc_t(C.text_dim)
            sf(F.sm)
            love.graphics.printf("SOLD", jx, jy + jh/2 - 8, jw, "center")
        else
            local hov = UI.point_in(mx, my, jx, jy, jw, jh)
            sc_t(hov and C.joker_hov or C.joker_bg)
            rect("fill", jx, jy, jw, jh, 6)
            sc_t(C.purple)
            rect("line", jx, jy, jw, jh, 6)

            sc_t(C.gold)
            sf(F.md)
            love.graphics.printf(slot.item.name, jx + 4, jy + 8, jw - 8, "center")
            sc_t(C.text_dim)
            sf(F.sm)
            love.graphics.printf(slot.item.description or "", jx + 4, jy + 32, jw - 8, "center")
            sc_t(C.gold)
            love.graphics.printf(slot.item.price .. " gold", jx, jy + jh - 20, jw, "center")
        end
    end

    -- Owned jokers with sell buttons
    if #run.jokers > 0 then
        sc_t(C.text_dim)
        sf(F.sm)
        love.graphics.print("Your Jokers:", 80, 488)
        for i, j in ipairs(run.jokers) do
            local bx = 80 + (i-1) * 170
            local by = 506
            sc_t(C.joker_bg)
            rect("fill", bx, by, 155, 46, 5)
            sc_t(C.gold)
            sf(F.sm)
            love.graphics.print(j.name, bx + 6, by + 5)
            -- Sell button
            local sx, sy, sw, sh = bx + 6, by + 24, 70, 18
            local hov = UI.point_in(mx, my, sx, sy, sw, sh)
            sc_t(hov and {0.65, 0.18, 0.18} or C.btn_danger)
            rect("fill", sx, sy, sw, sh, 3)
            sc_t(C.text)
            love.graphics.printf("Sell " .. j.sell_value .. "g", sx, sy + 2, sw, "center")
        end
    end

    -- Reroll button
    do
        local rx, ry, rw, rh = 880, 590, 180, 40
        local hov = UI.point_in(mx, my, rx, ry, rw, rh)
        sc_t(hov and C.btn_hov or C.btn)
        rect("fill", rx, ry, rw, rh, 6)
        sc_t(C.text)
        sf(F.md)
        love.graphics.printf("Reroll (" .. shop.reroll_cost .. "g)", rx, ry + 10, rw, "center")
    end

    -- Continue button
    do
        local cx2, cy2, cw, ch = 530, 650, 220, 46  -- matches shop_card_at_mouse
        local hov = UI.point_in(mx, my, cx2, cy2, cw, ch)
        sc_t(hov and C.btn_hov or C.btn)
        rect("fill", cx2, cy2, cw, ch, 6)
        sc_t(C.green)
        sf(F.lg)
        love.graphics.printf("Continue →", cx2, cy2 + 10, cw, "center")
    end

    -- Shop message
    if shop.msg_timer and shop.msg_timer > 0 then
        sc_t(C.gold)
        sf(F.md)
        love.graphics.printf(shop.message or "", 0, 620, UI.W, "center")
    end
end

-- ─── Menu scene ──────────────────────────────────────────────────────────────
function UI.draw_menu(mx, my)
    love.graphics.setBackgroundColor(C.bg)
    sc_t(C.bg)
    rect("fill", 0, 0, UI.W, UI.H)

    sc_t(C.gold)
    sf(F.title)
    love.graphics.printf("THIRSTY CARDS", 0, 160, UI.W, "center")

    sc_t(C.text_dim)
    sf(F.lg)
    love.graphics.printf("An Adult Deckbuilding Experience", 0, 250, UI.W, "center")

    sc_t(C.text_dim)
    sf(F.md)
    love.graphics.printf(
        "Play poker hands to drain bosses of their composure.\n"
     .. "Collect Jokers. Build your deck. Defeat 3 bosses to win.",
        200, 310, 880, "center")

    -- Start button
    local bx, by, bw, bh = 490, 420, 300, 56
    local hov = UI.point_in(mx, my, bx, by, bw, bh)
    sc_t(hov and C.btn_hov or C.btn)
    rect("fill", bx, by, bw, bh, 8)
    sc_t(C.text)
    sf(F.xl)
    love.graphics.printf("NEW GAME", bx, by + 12, bw, "center")

    -- Instruction
    sc_t(C.text_dim)
    sf(F.sm)
    love.graphics.printf("Select up to 5 cards • PLAY HAND or DISCARD • " ..
                          "5 hands per boss • 3 discards per boss",
                          100, 510, 1080, "center")
end

function UI.menu_start_clicked(mx, my)
    return UI.point_in(mx, my, 490, 420, 300, 56)
end

-- ─── Victory scene ───────────────────────────────────────────────────────────
function UI.draw_victory(run, mx, my)
    love.graphics.setBackgroundColor({0.04, 0.06, 0.04})
    sc_t({0.04, 0.06, 0.04})
    rect("fill", 0, 0, UI.W, UI.H)

    sc_t(C.gold)
    sf(F.title)
    love.graphics.printf("VICTORY!", 0, 130, UI.W, "center")

    sc_t(C.green)
    sf(F.xl)
    love.graphics.printf("All three bosses have been conquered.", 0, 250, UI.W, "center")

    sc_t(C.text)
    sf(F.lg)
    love.graphics.printf("Total damage dealt: " .. (run and run.total_damage or 0),
                          0, 310, UI.W, "center")
    love.graphics.printf("Gold remaining: " .. (run and run.gold or 0),
                          0, 345, UI.W, "center")

    -- Play Again button
    local bx, by, bw, bh = 490, 450, 300, 56
    local hov = UI.point_in(mx, my, bx, by, bw, bh)
    sc_t(hov and C.btn_hov or C.btn)
    rect("fill", bx, by, bw, bh, 8)
    sc_t(C.text)
    sf(F.xl)
    love.graphics.printf("PLAY AGAIN", bx, by + 12, bw, "center")
end

function UI.victory_replay_clicked(mx, my)
    return UI.point_in(mx, my, 490, 450, 300, 56)
end

-- ─── Game-over scene ─────────────────────────────────────────────────────────
function UI.draw_gameover(run, mx, my)
    love.graphics.setBackgroundColor({0.06, 0.02, 0.02})
    sc_t({0.06, 0.02, 0.02})
    rect("fill", 0, 0, UI.W, UI.H)

    sc_t(C.red)
    sf(F.title)
    love.graphics.printf("GAME OVER", 0, 130, UI.W, "center")

    sc_t(C.text)
    sf(F.lg)
    love.graphics.printf("You ran out of hands to play.", 0, 255, UI.W, "center")
    love.graphics.printf("The boss still stands at " ..
                          (run and run.active_boss and run.active_boss.hp or "?") .. " HP.",
                          0, 295, UI.W, "center")

    sf(F.md)
    love.graphics.printf("Total damage dealt: " .. (run and run.total_damage or 0),
                          0, 350, UI.W, "center")

    -- Try Again button
    local bx, by, bw, bh = 490, 440, 300, 56
    local hov = UI.point_in(mx, my, bx, by, bw, bh)
    sc_t(hov and C.btn_hov or C.btn)
    rect("fill", bx, by, bw, bh, 8)
    sc_t(C.text)
    sf(F.xl)
    love.graphics.printf("TRY AGAIN", bx, by + 12, bw, "center")
end

function UI.gameover_replay_clicked(mx, my)
    return UI.point_in(mx, my, 490, 440, 300, 56)
end

return UI
