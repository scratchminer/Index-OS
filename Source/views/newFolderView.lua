import("CoreLibs/animator")
import("CoreLibs/object")
import("CoreLibs/timer")

import("view")

local anm = playdate.graphics.animator
local gfx = playdate.graphics
local snd = playdate.sound
local tmr = playdate.timer

class("NewFolderView").extends(View)

local kRowUppercase = 1
local kRowLowercase = 2
local kRowSymbols = 3
local kRowMenu = 4

local characters = {
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"abcdefghijklmnopqrstuvwxyz",
	"0123456789,./:;\'<=>?_[]{}`~\\|!@#$%^&*()-+",
}

local symbolPos, letterPos, menuPos

local currentRow

local currentText
keyboardFont = nil
local textChanged = true

local keyTimer
local anim
local widthAnim

local crankAccum

local shakeBackForth = 0
local jitter = 0
local invertShake = false

local denialSound
local keySound
local clickSound

local nextView

local escapeText = function(text)
	local drawnText = text:gsub("*", "**")
	return drawnText:gsub("_", "__")
end

local getSelectedWidth = function()
	local width = 35
	if currentRow == kRowMenu and menuPos ~= 2 then
		width = 52
	elseif currentRow == kRowMenu then
		width = 40
	end
	return width
end

local setKeyboardPos = function(change)	
	local currentPos
	
	textChanged = true
	
	if currentRow == kRowSymbols then
		symbolPos = symbolPos + change
		currentPos = symbolPos
	elseif currentRow == kRowUppercase or currentRow == kRowLowercase then
		letterPos = letterPos + change
		currentPos = letterPos
	else
		local oldPos = menuPos
		local oldWidth = getSelectedWidth()
		
		menuPos = menuPos + change
		
		if oldPos == 2 or menuPos == 2 then
			widthAnim = anm.new(50, oldWidth, getSelectedWidth())
		end
		
		if menuPos < 1 then
			menuPos = 1
			if denialSound:isPlaying() == false then
				shakeBackForth = -3
				denialSound:play()
			end
		elseif menuPos > #characters[currentRow] then
			menuPos = #characters[currentRow]
			if denialSound:isPlaying() == false then
				shakeBackForth = 3
				denialSound:play()
			end
		else
			clickSound:play()
		end
		return
	end
	
	if currentPos < 1 then
		currentPos = #characters[currentRow]
	elseif currentPos > #characters[currentRow] then
		currentPos = 1
	end
	
	if currentRow == kRowSymbols then
		symbolPos = currentPos
	elseif currentRow == kRowUppercase or currentRow == kRowLowercase then
		letterPos = currentPos
	end
	
	clickSound:play()
end

local getRowVertical = function(rowNum)
	return 38 * (rowNum - 1) + 84
end

function NewFolderView:init()
	NewFolderView.super.init(self)
	
	if boldFont == nil then
		boldFont = self.loadFont("fonts/roobert11Bold")
		gfx.setFont(boldFont, "bold")
	end
	if keyboardFont == nil then
		keyboardFont = self.loadFont("fonts/roobertKeyboard")
	end
	
	self.loadedObjects = {}
	self.loadedObjects["img_cancel"] = self.loadImage("images/keyboard/cancel")
	self.loadedObjects["img_space"] = self.loadImage("images/keyboard/space")
	self.loadedObjects["img_delete"] = self.loadImage("images/keyboard/delete")
	self.loadedObjects["img_ok"] = self.loadImage("images/keyboard/ok")
	
	clickSound = self.loadSound("sounds/keyboardClick")
	keySound = self.loadSound("sounds/keyboardKey")
	denialSound = self.loadSound("systemsfx/04-denial-trimmed")
	
	currentRow = kRowUppercase
	symbolPos = 1
	letterPos = 1
	menuPos = 2
	
	currentText = ""
	menuRow = {
		self.loadedObjects["img_cancel"],
		self.loadedObjects["img_space"],
		self.loadedObjects["img_delete"],
		self.loadedObjects["img_ok"],
	}
	characters[kRowMenu] = menuRow
	
	gfx.setDrawOffset(0, 0)
	
	gfx.clear(gfx.kColorWhite)
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(2)
	gfx.setLineCapStyle(gfx.kLineCapStyleSquare)
	
	gfx.drawLine(39, 75, 361, 75)
	gfx.setLineWidth(1)
	
	gfx.setFont(normalFont)
	gfx.drawTextAligned("📁 *New Folder Name:*\n" .. escapeText(currentText), 200, 24, kTextAlignment.center)
	
	nextView = nil
	textChanged = true
	
	crankAccum = 0
end

function NewFolderView.leftButtonDown()
	if keyTimer ~= nil then
		keyTimer:remove()
	end
	
	keyTimer = tmr.keyRepeatTimerWithDelay(300, 90, function()
		if not playdate.buttonIsPressed("left") then
			return
		end
		setKeyboardPos(-1)
	end)
end

function NewFolderView.leftButtonUp()
	if keyTimer ~= nil then
		keyTimer:remove()
	end
end

function NewFolderView.rightButtonDown()
	keyTimer = tmr.keyRepeatTimerWithDelay(300, 90, function()
		if not playdate.buttonIsPressed("right") then
			return
		end
		setKeyboardPos(1)
	end)
end

function NewFolderView.rightButtonUp()
	if keyTimer ~= nil then
		keyTimer:remove()
	end
end

function NewFolderView.upButtonDown()
	if keyTimer ~= nil then
		keyTimer:remove()
	end
	
	if currentRow == kRowMenu then
		widthAnim = anm.new(50, getSelectedWidth(), 35)
	end
	
	currentRow = currentRow - 1
	
	if currentRow < 1 then
		currentRow = 1
		if denialSound:isPlaying() == false then
			jitter = -3
			denialSound:play()
		end
	else
		anim = anm.new(50, getRowVertical(currentRow + 1), getRowVertical(currentRow))
		snd.playSystemSound(snd.kSoundSelectPrevious)
	end
end

function NewFolderView.downButtonDown()
	if keyTimer ~= nil then
		keyTimer:remove()
	end
	
	currentRow = currentRow + 1
	
	if currentRow == kRowMenu then
		widthAnim = anm.new(50, 35, getSelectedWidth())
	end
	
	if currentRow > kRowMenu then
		currentRow = kRowMenu
		if denialSound:isPlaying() == false then
			jitter = 3
			denialSound:play()
		end
	else
		anim = anm.new(50, getRowVertical(currentRow - 1), getRowVertical(currentRow))
		snd.playSystemSound(snd.kSoundSelectNext)
	end
end

function NewFolderView.AButtonDown()
	if keyTimer ~= nil then
		keyTimer:remove()
	end
	
	keyTimer = tmr.keyRepeatTimerWithDelay(1000, 300, function()
		if not playdate.buttonIsPressed("A") then
			return
		end
		
		if currentRow == kRowUppercase or currentRow == kRowLowercase then
			currentText = currentText .. characters[currentRow]:sub(letterPos, letterPos)
			keySound:play()
		elseif currentRow == kRowSymbols then
			currentText = currentText .. characters[currentRow]:sub(symbolPos, symbolPos)
			keySound:play()
		elseif currentRow == kRowMenu then
			if menuPos == 2 then
				currentText = currentText .. " "
				keySound:play()
			elseif menuPos == 3 then
				currentText = currentText:sub(1, -2)
				keySound:play()
			elseif menuPos == 4 then
				if currentText ~= "" and not groupExists(currentText) then
					nextView = currentText
					return
				elseif denialSound:isPlaying() == false then
					invertShake = true
					shakeBackForth = 3
					denialSound:play()
				end
			end
		end
		
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(0, 0, 400, 70)
		gfx.setFont(normalFont)
		gfx.drawTextAligned("📁 *New Folder Name:*\n" .. escapeText(currentText), 200, 24, kTextAlignment.center)
	end)
end

function playdate.AButtonUp()
	if keyTimer ~= nil then
		keyTimer:remove()
	end
	
	if currentRow == kRowMenu and menuPos == 1 then
		nextView = ""
	end
end

function NewFolderView.BButtonDown()
	if keyTimer ~= nil then
		keyTimer:remove()
	end
	
	keyTimer = tmr.keyRepeatTimerWithDelay(1000, 300, function()
		if not playdate.buttonIsPressed("B") then
			return
		end
		
		if #currentText > 0 then
			currentText = currentText:sub(1, -2)
		else
			keyTimer = nil
			nextView = ""
		end
		
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(0, 0, 400, 70)
		gfx.setFont(normalFont)
		gfx.drawTextAligned("📁 *New Folder Name:*\n" .. escapeText(currentText), 200, 24, kTextAlignment.center)
	end)
end

function NewFolderView.BButtonUp()
	if keyTimer ~= nil then
		keyTimer:remove()
	end
end

function NewFolderView.cranked(change, accelChange)
	if math.abs(change) < 2 then
		crankAccum = 0
		return
	end
	
	crankAccum = crankAccum + change
	
	if crankAccum > 60 then
		crankAccum = 0
		setKeyboardPos(1)
	elseif crankAccum < -60 then
		crankAccum = 0
		setKeyboardPos(-1)
	end
end

function NewFolderView:renderKeyboard()
	if jitter ~= 0 or shakeBackForth ~= 0 then
		textChanged = true
	elseif anim ~= nil and anim:ended() == false then
		textChanged = true
	elseif widthAnim ~= nil and widthAnim:ended() == false then
		textChanged = true
	end
	
	if textChanged == true then
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(0, 80, 400, 160)
		
		gfx.setFont(keyboardFont)
		for row = 1, #characters do
			local currentPos
			if row == kRowUppercase or row == kRowLowercase then
				currentPos = letterPos
			elseif row == kRowSymbols then
				currentPos = symbolPos
			elseif row == kRowMenu then
				currentPos = menuPos
			end
			
			if row ~= kRowMenu then
				local stringToDisplay = ""
				local startOffset = #characters[row] - 7
				local endOffset = #characters[row] + 7
				for i = currentPos + startOffset, currentPos + endOffset do
					local index = ((i - 1) % #characters[row]) + 1
					stringToDisplay = stringToDisplay .. characters[row]:sub(index, index)
				end
								
				local substr = escapeText(stringToDisplay:sub(1, 6))
				stringToDisplay = escapeText(stringToDisplay)
				
				local xOffset = math.floor(200 - (gfx.getTextSize(stringToDisplay) / 2))
				local offBy = math.floor(197 - gfx.getTextSize(substr))
				
				gfx.drawText(stringToDisplay, xOffset + offBy, getRowVertical(row))
			else
				for index, image in ipairs(characters[row]) do
					local width, height = image:getSize()
					
					local offBy = 200 - (50 * (currentPos - index))
					local yOffset = math.floor(getRowVertical(row) + 18 - (height / 2))
					
					image:draw(offBy - (width / 2), yOffset)
				end
			end
		end
		
		gfx.setColor(gfx.kColorXOR)
		
		local yCoord = getRowVertical(currentRow)
		if anim ~= nil and anim:ended() == false then
			yCoord = anim:currentValue()
		end
		
		local width = getSelectedWidth()
		if widthAnim ~= nil and widthAnim:ended() == false then
			width = widthAnim:currentValue()
		end
		
		local xCoord = 200 - (width / 2)
		gfx.fillRoundRect(xCoord + shakeBackForth, yCoord + jitter, width, 36, 3)
		
		-- because the W is so wide, it might cut into the box if we're next to it, so this fixes that
		if currentRow == kRowUppercase and (letterPos == 22 or letterPos == 24) then
			gfx.setColor(gfx.kColorBlack)
			gfx.drawRoundRect(xCoord + shakeBackForth, yCoord + jitter, width, 36, 3)
		end
		
		textChanged = false
	end
end

function NewFolderView:deinit()
	if keyTimer ~= nil then
		keyTimer:remove()
	end
	textChanged = false
	
	gfx.setFont(normalFont)
end

function NewFolderView:draw()
	self:renderKeyboard()
	
	if shakeBackForth < 0 then
		shakeBackForth = shakeBackForth + 1
	elseif shakeBackForth > 0 then
		shakeBackForth = shakeBackForth - 1
		if invertShake then
			shakeBackForth = -shakeBackForth
		end
	end
	
	if jitter < 0 then
		jitter = jitter + 1
	elseif jitter > 0 then
		jitter = jitter - 1
	end
	
	if shakeBackForth == 0 then
		invertShake = false
	end
	
	if math.abs(shakeBackForth) == 1 or math.abs(jitter) == 1 then
		textChanged = true
	end
	
	tmr.updateTimers()
	
	if nextView ~= nil then
		if keyTimer ~= nil then
			keyTimer:remove()
		end
		keyTimer = nil
	end
	return nextView
end