local gfx <const> = playdate.graphics

class("ScreenManager").extends()

function ScreenManager:init()
    self.fps = false
    self.profiler = true
    self.targetFPS = 30
    
    self.screenDimensions = {
        x = 400,
        y = 240
    }

    self.levelFont_8px = { font = gfx.font.new('assets/fonts/IBM/IBM_EGA_8x8'), size = 8 }
    self.levelFont_10px = { font = gfx.font.new('assets/fonts/Rainbow100_re_40'), size = 10 }
    self.levelFont_16px = { font = gfx.font.new('assets/fonts/IBM/IBM_EGA_8x8_2x'), size = 16 }

    self.logFont_6px = { font = playdate.graphics.font.newFamily({
        [playdate.graphics.font.kVariantNormal] = "assets/fonts/DOS/dos-jpn12-6x12",
        [playdate.graphics.font.kVariantBold] = "assets/fonts/DOS/dos-jpn12-6x12", -- TODO make bold
    }), size = 6, lineCount = 5 }
    self.logFont_8px = { font = playdate.graphics.font.newFamily({
        [playdate.graphics.font.kVariantNormal] = "assets/fonts/Log/CompaqThin_8x16",
        [playdate.graphics.font.kVariantBold] = "assets/fonts/Log/Nix8810_M15",
    }), size = 8, lineCount = 4 }
    self.logFont_12px = { font = playdate.graphics.font.newFamily({
        [playdate.graphics.font.kVariantNormal] = "assets/fonts/Log/Portfolio_6x8_2x",
        [playdate.graphics.font.kVariantBold] = "assets/fonts/Log/Portfolio_6x8_2x", -- TODO make bold
    }), size = 12, lineCount = 4 }

    self.currentLevelFont, self.currentLogFont = nil, nil

    -- Maxmimum characters that can fit on the screen
    self.gridScreenMax = { x = 0, y = 0 }

    -- lit, dim but seen, unseen but known
    self.levelGlyphs = {} -- alloc an estimate?
    self.levelGlyphs_faded = {}
    self.drawnGlyphs = {}

    -- change viewports states this way? can use something similar for font sizes
    self.screenState = {
        full = function()
            
        end,
        log = function()
            
        end,
        square = function()
        
        end }
    self.currentScreenState = self.screenState.full

    self.defaultDrawMode = playdate.graphics.kDrawModeNXOR -- change to color

    playdate.display.setRefreshRate(self.targetFPS)

    self.bgColor = gfx.kColorBlack

    self.levelManager, self.logManager = nil, nil
    self._redrawScreen = true

    self._redrawLevel = false
    self._redrawLog = false

    self.screenBorder = Border(2, 2, 400-4, 240-4, 4, gfx.kColorBlack)

    self:setLevelFont("16px")
    self:setLogFont("8px")
    self:resetDrawnGlyphs()
end

function ScreenManager:setLevelColor(color)
    self.bgColor = color
    gfx.setBackgroundColor(self.bgColor)
    self._redrawScreen = true
end

function ScreenManager:update() end
function ScreenManager:lateUpdate() end

function ScreenManager:draw()
    local drew = false

    if self._redrawScreen then
        frameProfiler:startTimer("Draw: Screen")

        gfx.clear()
        --gfx.sprite.update()
        self.levelManager:draw()
        self.logManager:draw()
        self.screenBorder:draw()
        
        self._redrawScreen = false

        self._redrawLevel = false
        self._redrawLog = false
        drew = true

        frameProfiler:endTimer("Draw: Screen")
    end

    if (self._redrawLevel == true) then
        frameProfiler:startTimer("Draw: Level")

        self.levelManager:draw()
        self._redrawLevel = false
        drew = true

        frameProfiler:endTimer("Draw: Level")
    end

    if (self._redrawLog == true) then
        frameProfiler:startTimer("Draw: Log")

        self.logManager:draw()
        self._redrawLog = false
        drew = true

        frameProfiler:endTimer("Draw: Log")
    end

    if self.fps then
        playdate.drawFPS(0,0)
    end

    if (drew) then frameProfiler:frameEnd() end
end

function ScreenManager:redrawScreen()
    self:resetDrawnGlyphs()
    self._redrawScreen = true
end

function ScreenManager:redrawLevel()
    self._redrawLevel = true
end

function ScreenManager:redrawLog()
    self._redrawLog = true
end

function ScreenManager:setLevelFont(value)
    if value == "8px" then
        self.currentLevelFont = self.levelFont_8px
    elseif value == "10px" then
        self.currentLevelFont = self.levelFont_10px
    elseif value == "16px" then
        self.currentLevelFont = self.levelFont_16px
    end
    self.gridScreenMax.x = math.floor(self.screenDimensions.x / self.currentLevelFont.size)
    self.gridScreenMax.y = math.floor(self.screenDimensions.y / self.currentLevelFont.size)
    self:resetFontGlyphs()
    self:redrawScreen()
    collectgarbage()
end

function ScreenManager:setLogFont(value)
    if value == "6px" then
        self.currentLogFont = self.logFont_6px
    elseif value == "8px" then
        self.currentLogFont = self.logFont_8px
    elseif value == "12px" then
        self.currentLogFont = self.logFont_12px
    end
    if (self.logManager ~= nil) then
        self.logManager:resplitLines()
    end
    self:redrawScreen()
end

function ScreenManager:getGlyph(char, lightLevel)
    if (self.levelGlyphs[char] == nil) then
        self.levelGlyphs[char] = self.currentLevelFont.font:getGlyph(char)
        self.levelGlyphs_faded[char] = self.levelGlyphs[char]:fadedImage(0.5, playdate.graphics.image.kDitherTypeBayer2x2)
    end
    
    if lightLevel >= 2 then -- lit
        return self.levelGlyphs[char]
    else -- dim or seen
        return self.levelGlyphs_faded[char]
    end
end

function ScreenManager:drawGlyph(char, tile, drawCoord, screenCoord)
    local drawnGlyph = self.drawnGlyphs[screenCoord.x][screenCoord.y]

    if (drawnGlyph.char == "" and char == "") then
        -- nothing changed
    else
        local tileLit = tile ~= nil and tile.lightLevel > 0
        local tileLightLevel = tile ~= nil and tile.lightLevel or 0

        if (drawnGlyph.char == char and drawnGlyph.lightLevel == tileLightLevel) then
            -- no need to redraw if everything is the same
        else
            -- TODO figure out if this could work. Using glyph as eraser rather than a rect

            -- if (drawnGlyph.lit == true and tileLit == false) then
            --     -- tile is now NOT lit, needs to be filled in, no need to erase glyph
            --     gfx.setColor(self.bgColor)
            --     gfx.fillRect(drawCoord.x, drawCoord.y, self.currentLevelFont.size, self.currentLevelFont.size)
            -- elseif (drawnGlyph.glyph ~= nil) then
            --     -- lit state the same as previous
            --     print("erasing " .. drawnGlyph.char)
            --     gfx.setImageDrawMode(gfx.kDrawModeXOR) -- same color as bg
            --     local glyph = self:getGlyph(drawnGlyph.char, true, 2)
            --     glyph:draw(drawCoord.x, drawCoord.y)
            -- end

            gfx.setColor(self.bgColor)
            gfx.fillRect(drawCoord.x, drawCoord.y, self.currentLevelFont.size, self.currentLevelFont.size)
            
            -- draw new and update table
            self.drawnGlyphs[screenCoord.x][screenCoord.y] = { char = char, lightLevel = tileLightLevel, lit = tileLit, glyph = nil}
            if (char ~= "") then
                local glyph = self:getGlyph(char, tile.lightLevel)
                self.drawnGlyphs[screenCoord.x][screenCoord.y].glyph = glyph
                if (tile.lightLevel > 0) then -- draw light around rect
                    gfx.setColor(gfx.kColorWhite)
                    gfx.fillRect(drawCoord.x, drawCoord.y, self.currentLevelFont.size, self.currentLevelFont.size)
                end
                glyph:draw(drawCoord.x, drawCoord.y)
            end
        end
    end
end

function ScreenManager:resetFontGlyphs()
    self.levelGlyphs = {}
    self.levelGlyphs_faded = {}
end

function ScreenManager:resetDrawnGlyphs()
    for x = 0, self.gridScreenMax.x, 1 do
        self.drawnGlyphs[x] = {}
        for y = 0, self.gridScreenMax.y, 1 do
            self.drawnGlyphs[x][y] = { char = "", lightLevel = 0, lit = false, glyph = nil}
        end
    end
end