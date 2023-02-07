local gfx <const> = playdate.graphics

class("Tile").extends()

function Tile:init(x, y)
    self.position = Vector2.new(x, y)
    self.feature = Ground(self, Vector2.new(x,y))
    self.actor = nil
    self.item = nil
    self.effects = {}
    self.triggers = {}

    self.seen = false
    self.visibilityState = { unknown = 0, lit = 1, dim = 2, seen = 3 }
    self.currentVisibilityState = self.visibilityState.unknown

    self.glow = false

    self.lightLevel = 0
    self.lightSources = {}
end

function Tile:update()
    for i, trigger in ipairs(triggers) do
        if trigger ~= nil then
            trigger:update()
        end
    end
end

function Tile:enter(actor)
    self.actor = actor
end

function Tile:exit(actor)
    -- on exit
    self.actor = nil
end

function Tile:addItem(item)
    -- if have item, move to another tile
end

function Tile:removeItem(item)
    self.item = nil
end

function Tile:resetLightLevel(baseLight)
    self.lightLevel = baseLight or 0
    self.lightSources = {}
end

function Tile:addLightLevel(level, source)
    if (self.lightSources[source] == nil) then
        self.lightSources[source] = source
        self.lightLevel += level
        -- TODO could optimize vis calls, if tile already had been called ignore (but what if the first check was dim and then lit)
        -- this shouldnt matter since light should always applies strongest first
    else
        --pDebug:log("source attempting to apply again")
    end
end