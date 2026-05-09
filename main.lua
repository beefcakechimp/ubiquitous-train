-- main.lua  –  Thirsty Cards
-- Entry point: delegates everything to the game state machine.
local GS = require("src.gamestate")

function love.load()
    GS.init()
end

function love.update(dt)
    GS.update(dt)
end

function love.draw()
    GS.draw()
end

function love.mousepressed(x, y, button)
    GS.mousepressed(x, y, button)
end

function love.keypressed(key)
    GS.keypressed(key)
end
