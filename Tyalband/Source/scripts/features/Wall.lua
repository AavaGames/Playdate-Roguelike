class("Wall").extends(Feature)

function Wall:init(theLevel, startPosition)
    Wall.super.init(self, theLevel, startPosition)
    self.glyph = "#"
    self.name = "Wall"
    self.description = "A cold stone wall."

    self.collision = true
    self.renderWhenSeen = true

    self.moveCost = 1
end

function Wall:interact(actor)
    if (actor:isa(Player)) then 
        gameManager.logManager:addToRound(self.description)
    end
end