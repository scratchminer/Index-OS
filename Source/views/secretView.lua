import("CoreLibs/crank")
import("CoreLibs/object")

local anm = playdate.graphics.animator
local gfx = playdate.graphics
local geo = playdate.geometry
local img = playdate.graphics.image
local imt = playdate.graphics.imagetable
local snd = playdate.sound
local spr = playdate.graphics.sprite
local tmr = playdate.timer

secretCombo = {
	"up",
	"up",
	"down",
	"down",
	"left",
	"right",
	"left",
	"right",
	"B",
	"A"
}

class("SecretView").extends(View)

local drawBackground = function()
	gfx.setPattern({0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe})
	gfx.fillRect(0, 0, 400, 240)
	gfx.setColor(gfx.kColorBlack)
end

local textTable
local letterOImg
local letterSImg
local creditsImg

local clickSound

local textSprite
local letterOSprite
local letterSSprite
local creditsSprite

local textSpriteAnim
local animTimer
local soundTimer
local doneTimer
local clickTimer

local drawOffset = 0
local prevBarOffset

local forceRefresh = nil

function SecretView:init()
	SecretView.super.init(self)
	
	gfx.setDrawOffset(0, 0)
	drawOffset = 0
	spr.setBackgroundDrawingCallback(drawBackground)
	
	if textImg == nil then
		textTable = self.loadImageTable("images/credits/logoText")
		letterOImg = self.loadImage("images/credits/logoLetterO")
		letterSImg = self.loadImage("images/credits/logoLetterS")
		creditsImg = self.loadImage("images/credits/credits")
	end
	
	if clickSound == nil then
		clickSound = self.loadSound("sounds/click")
	end
	
	letterOSprite = spr.new(letterOImg)
	letterSSprite = spr.new(letterSImg)
	
	textSprite = spr.new()
	textSprite.tableIndex = 1
	textSprite.hasAnimator = true
	
	function textSprite:update()
		if textSpriteAnim ~= nil and textSpriteAnim:ended() then
			flipBack:play()
			textSpriteAnim = nil
		end
		
		if textSpriteAnim == nil and self.tableIndex < #textTable then
			self.tableIndex = self.tableIndex + 0.5
		end
		
		self:setImage(textTable[math.floor(self.tableIndex)])
	end
	
	textSpriteAnim = anm.new(1500, geo.point.new(200, -50), geo.point.new(200, 110), playdate.easingFunctions.outBounce)
	
	textSprite:setAnimator(textSpriteAnim)
	textSprite:add()
	
	animTimer = tmr.new(2000, function()
		letterOSprite:setAnimator(anm.new(750, geo.point.new(200, -50), geo.point.new(200, 110), playdate.easingFunctions.outBounce))
		letterOSprite:add()
		
		animTimer = tmr.new(250, function()
			letterSSprite:setAnimator(anm.new(750, geo.point.new(200, -50), geo.point.new(200, 110), playdate.easingFunctions.outBounce))
			letterSSprite:add()
			
			animTimer:remove()
			animTimer = nil
			
			soundTimer = tmr.new(300, function()
				snd.playSystemSound(snd.kSoundDenial)
			end)
		end)
		
		soundTimer = tmr.new(300, function()
			snd.playSystemSound(snd.kSoundDenial)
		end)
	end)
	
	soundTimer = tmr.new(500, function()
		moveEndSound:play()
	end)
	
	creditsSprite = spr.new(creditsImg)
	creditsSprite:setCenter(0.5, 0)
	creditsSprite:moveTo(200, 300)
	creditsSprite:add()
	
	doneTimer = tmr.new(3250, function()
		doneTimer:remove()
		doneTimer = nil
	end)
	
	gfx.setLineCapStyle(gfx.kLineCapStyleRound)
	gfx.setLineWidth(6)
end

function SecretView.AButtonDown()
	forceRefresh = -2
end

function SecretView.leftButtonUp()
end

function SecretView.rightButtonUp()
end

function SecretView.cranked(change, acceleratedChange)
	if doneTimer == nil then
		drawOffset = drawOffset - (change / 2)
		if drawOffset > 0 then
			drawOffset = 0
		elseif drawOffset < -1120 then
			drawOffset = -1120
		end
		
		gfx.setDrawOffset(0, drawOffset)
	end
end

function SecretView:deinit()
	textSprite:remove()
	letterOSprite:remove()
	letterSSprite:remove()
	creditsSprite:remove()
	
	if animTimer ~= nil then
		animTimer:remove()
		animTimer = nil
	end
	if soundTimer ~= nil then
		soundTimer:remove()
		soundTimer = nil
	end
	if doneTimer ~= nil then
		doneTimer:remove()
		doneTimer = nil
	end
	if clickTimer ~= nil then
		clickTimer:remove()
		clickTimer = nil
	end
	
	flipBack:stop()
	moveEndSound:stop()
	
	gfx.setLineCapStyle(gfx.kLineCapStyleSquare)
	gfx.setLineWidth(1)
	
	drawOffset = 0
	forceRefresh = nil
end

function SecretView:draw()
	if doneTimer == nil and playdate.getCrankTicks(5) ~= 0 then
		if drawOffset < 0 and drawOffset > -1120 then
			clickSound:play()
		end
	end
	
	if doneTimer == nil and playdate.buttonIsPressed("up") then
		drawOffset = drawOffset + 3
		if drawOffset > 0 then
			drawOffset = 0
		else
			if clickTimer == nil then
				clickSound:play()
				clickTimer = tmr.new(300, function()
					if clickTimer ~= nil then
						clickTimer:remove()
						clickTimer = nil
					end
				end)
			end
		end
	end
	
	if doneTimer == nil and playdate.buttonIsPressed("down") then
		drawOffset = drawOffset - 3
		if drawOffset < -1120 then
			drawOffset = -1120
		else
			if clickTimer == nil then
				clickSound:play()
				clickTimer = tmr.new(300, function()
					if clickTimer ~= nil then
						clickTimer:remove()
						clickTimer = nil
					end
				end)
			end
		end
	end
	
	local barYOffset = 0
	if barAnim ~= nil then
		barYOffset = barAnim.value
		
		if barAnim.currentTime >= barAnim.duration then
			barAnim:remove()
			barAnim = nil
		end
	end
	
	if barYOffset ~= prevBarOffset then
		bottomBarSprite:moveTo(200, 240 - barYOffset)
		prevBarOffset = barYOffset
	end
	
	tmr.updateTimers()
	spr.update()
	
	local lineStart = (drawOffset + 240) / -1120 * 190 + 45
	local lineEnd = drawOffset / -1120 * 190 + 45
	
	if lineEnd > 212 then
		gfx.setPattern({0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa})
	else
		gfx.setColor(gfx.kColorBlack)
	end
	
	gfx.setDrawOffset(0, 0)
	gfx.drawLine(394, lineStart, 394, lineEnd)
	gfx.setDrawOffset(0, drawOffset)
	
	if forceRefresh ~= nil and not playdate.buttonIsPressed("A") then
		return forceRefresh
	end
end