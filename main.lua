-- main.lua
-- Project: Thirsty Cards (One-Woman Studio Prototype)

function love.load()
    -- 1. WINDOW SETUP
    love.window.setTitle("Thirsty Cards - Vertical Slice")
    window_width = love.graphics.getWidth()
    window_height = love.graphics.getHeight()

    -- 2. PROFESSIONAL PALETTE
    colors = {
        bg = {0.05, 0.05, 0.1},
        text = {0.9, 0.9, 0.9},
        accent = {0.4, 0.7, 1.0},
        card_white = {1, 1, 1},
        card_hover = {0.8, 0.9, 1.0},
        health_red = {0.8, 0.2, 0.2}
    }

    -- 3. CHARACTER DATA (The Boss/Target)
    character = {
        name = "Head Pharmacist",
        max_composure = 100,
        composure = 100,
        stage = 1,
        message = "Click the card to play a hand!"
    }

    -- 4. CARD DATA (The Balatro Loadout)
    card_w = 140
    card_h = 200
    my_card = {
        name = "Triage Nurse",
        rank = "A",
        suit = "Hearts",
        x = (window_width / 2) - 70, -- Centered horizontally
        y = 350,
        base_y = 350,               -- Reference for the hover lift
        is_hovered = false
    }

    -- 5. IMAGE HANDLING
    local info = love.filesystem.getInfo("viking_stage1.png")
    if info then
        card_image = love.graphics.newImage("viking_stage1.png")
    else
        card_image = nil
    end
end

function love.update(dt)
    -- Get Mouse Position
    local mx, my = love.mouse.getPosition()

    -- Check for Card Hover (Simple Hitbox)
    if mx > my_card.x and mx < my_card.x + card_w and
       my > my_card.y and my < my_card.y + card_h then
        
        my_card.is_hovered = true
        -- "Lift" the card smoothly toward a target height
        my_card.y = my_card.y - (my_card.y - (my_card.base_y - 20)) * 0.1
    else
        my_card.is_hovered = false
        -- Drop the card back to base height
        my_card.y = my_card.y - (my_card.y - my_card.base_y) * 0.1
    end
end

function love.mousepressed(x, y, button, istouch)
    -- If Left Click and Hovering over the card
    if button == 1 and my_card.is_hovered then
        if character.composure > 0 then
            play_hand()
        else
            -- Reset game if they won
            character.composure = character.max_composure
            character.stage = 1
            character.message = "New Round Started!"
        end
    end
end

function play_hand()
    -- Balatro-lite Scoring logic
    local base_damage = math.random(8, 15)
    local luck_mult = (math.random() > 0.8) and 2 or 1 -- 20% chance for x2
    local total = base_damage * luck_mult
    
    character.composure = character.composure - total
    character.message = "Dealt " .. total .. " Damage!"

    -- Logic for Stage Reveals
    if character.composure <= 60 and character.stage == 1 then
        character.stage = 2
        character.message = "Stage 2: She's losing her cool!"
    elseif character.composure <= 0 then
        character.composure = 0
        character.stage = 3
        character.message = "Stage 3: FULL REVEAL UNLOCKED"
    end
end

function love.draw()
    -- Background
    love.graphics.setBackgroundColor(colors.bg)

    -- --- DRAW UI ---
    love.graphics.setColor(colors.text)
    love.graphics.print("TARGET: " .. character.name, 50, 40)
    love.graphics.print(character.message, 50, 300)

    -- --- DRAW COMPOSURE BAR ---
    love.graphics.setColor(0.2, 0.2, 0.2) -- Bar Background
    love.graphics.rectangle("fill", 50, 70, 200, 15)
    
    love.graphics.setColor(colors.health_red)
    local bar_width = (character.composure / character.max_composure) * 200
    love.graphics.rectangle("fill", 50, 70, bar_width, 15)

    -- --- DRAW CHARACTER REVEAL BOX ---
    -- This is where your AI art will eventually sit
    if character.stage == 1 then
        love.graphics.setColor(0.2, 0.2, 0.4) -- Professional Blue
    elseif character.stage == 2 then
        love.graphics.setColor(0.6, 0.2, 0.6) -- Flustered Purple
    else
        love.graphics.setColor(1, 0.8, 0.2) -- Victory Gold
    end
    love.graphics.rectangle("line", 350, 40, 250, 350)
    love.graphics.print("Stage " .. character.stage .. " Image Placeholder", 370, 200)

    -- --- DRAW THE PHYSICAL CARD ---
    if my_card.is_hovered then
        love.graphics.setColor(colors.card_hover)
    else
        love.graphics.setColor(colors.card_white)
    end
    
    -- Card Shadow/Body
    love.graphics.rectangle("fill", my_card.x, my_card.y, card_w, card_h, 10, 10)
    
    -- Card Art/Details
    love.graphics.setColor(0, 0, 0) -- Text color
    love.graphics.print(my_card.name, my_card.x + 15, my_card.y + 15)
    
    if card_image then
        -- Scale the image to fit the card
        local scale = (card_w - 20) / card_image:getWidth()
        love.graphics.draw(card_image, my_card.x + 10, my_card.y + 40, 0, scale, scale)
    else
        -- Simple placeholder if no image found
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.rectangle("fill", my_card.x + 10, my_card.y + 40, card_w - 20, 100)
    end
    
    -- Bottom card info
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(my_card.rank .. " of " .. my_card.suit, my_card.x + 15, my_card.y + 175)
end