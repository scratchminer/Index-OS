import("CoreLibs/animator")
import("CoreLibs/easing")
import("CoreLibs/frameTimer")
import("CoreLibs/graphics")
import("CoreLibs/object")
import("CoreLibs/sprites")
import("CoreLibs/timer")

import("game")
import("groupUtils")
import("view")
import("views/secretView")

local anm = playdate.graphics.animator
local dts = playdate.datastore
local fle = playdate.file
local frt = playdate.frameTimer
local geo = playdate.geometry
local gfx = playdate.graphics
local spr = playdate.graphics.sprite
local img = playdate.graphics.image
local snd = playdate.sound
local sys = playdate.system
local tmr = playdate.timer

class("CardView").extends(View)

local kBatteryIndexLow = 1
local kBatteryIndexQuarter = 2
local kBatteryIndexHalf = 3
local kBatteryIndexThreeQuarters = 4
local kBatteryIndexAlmostFull = 5
local kBatteryIndexFull = 6
local kBatteryChargingDock = 7
local kBatteryChargingUSB = 8

local drawBackground = function()
	gfx.setPattern({0x33, 0xcc, 0x33, 0xcc, 0x33, 0xcc, 0x33, 0xcc})
	gfx.fillRect(0, 0, 400, 240)
	gfx.setColor(gfx.kColorBlack)
end

local getBatteryIndex = function()
	local pct = playdate.getBatteryPercentage()
	local pwr = playdate.getPowerStatus()
	
	if pct >= 99.5 then
		return kBatteryIndexFull
	elseif pwr.charging and pwr.screws then
		return kBatteryChargingDock
	elseif pwr.charging and pwr.USB then
		return kBatteryChargingUSB
	elseif pct < 99.5 and pct >= 87.5 then
		return kBatteryIndexAlmostFull
	elseif pct < 87.5 and pct >= 67.5 then
		return kBatteryIndexThreeQuarters
	elseif pct < 67.5 and pct >= 37.5 then
		return kBatteryIndexHalf
	elseif pct < 37.5 and pct >= prefs.showBatteryBelowThreshold then
		return kBatteryIndexQuarter
	elseif pct < prefs.showBatteryBelowThreshold then
		return kBatteryIndexLow
	end
end

local getPrintableTime = function()
	local time = playdate.getTime()
	local hr, min = time.hour, time.minute
	
	if sys.display24HourTime() == false then
		local ampm = " AM"
		if hr >= 12 then
			hr = hr - 12
			ampm = " PM"
		end
		if hr == 0 then
			hr = 12
		end
		return string.format("%d:%02d", hr, min) .. ampm
	else
		return string.format("%02d:%02d", hr, min)
	end
end

local folderName

local topBarImage

local batterySprite, batteryIndex
topBarSprite = nil
bottomBarSprite = nil
normalFont = nil
boldFont = nil

local barRegularImage
local barHoldingImage
local barCopyImage
local barMoveImage
local barCancelImage
local barInfoImage
local barRemoveImage
local barDeleteImage
local barLogoImage

local batteryTable

local infoOpenSound
local infoCloseSound
local folderDeleteSound
local listOpenSound
local listCloseSound

local moveStartSound
moveEndSound = nil

local gameMove

local gameList
selectedIndex = 1
local prevIndex

local displayName

local lastPercentage
local lastTime

cooldown = false

inInfoView = false
local infoViewAnim
local infoViewTimer
local infoViewSprite
local infoViewCard
local deleteFolderAnim

inListView = false
local listViewAnim
local listViewTimer
local listViewSprite
local listViewCard
local listViewY
local listViewYAnim
local listViewTextSprite
local listViewTextOffset
local listViewTextAnim

local defaultIconImg = img.new("images/defaultIcon")

local allowMoving
local allowVerticalMove

local keyTimer
local animTimer
local lastFrameTime
local onNextFrame = false

local crankAccum = 0

local jitter = 0
local shakeBackForth = 0

local prevOffY
local offY
local offYAnim
local offXAnim

local launchAnim
local delaunchAnim
local lastLaunchAnimVal

barAnim = nil
local prevBarOffset
local forceRefresh

local secretComboIndex = 1

local emptyImage = img.new(350, 155, gfx.kColorClear)

local loadAll = function(dontReload)
	if gameMove == nil or gameMove.index == nil then
		if dontReload then
			for i = 1, #gameList do
				if gameList[i] ~= nil and gameList[i].loaded then
					gameList[i]:destroySprite()
				end
			end
		else
			offY = offY or (selectedIndex - 1) * 200
			local lower = math.floor(offY / 200) - 1
			local upper = math.ceil(offY / 200) + 1
			
			for i = 1, lower - 1 do
				if gameList[i] ~= nil and gameList[i].state ~= kGameStateUnwrapping then
					if gameList[i] ~= nil and gameList[i].state ~= nil then
						gameList[i]:destroySprite()
					end
				end
			end
			
			for i = upper + 1, #gameList do
				if gameList[i] ~= nil and gameList[i].state ~= kGameStateUnwrapping then
					if gameList[i] ~= nil and gameList[i].state ~= nil then
						gameList[i]:destroySprite()
					end
				end
			end
		end
	else
		if dontReload then
			for i = 1, #gameList do
				if type(gameList[i]) == "table" then
					gameList[i]:destroySprite()
				end
			end
		else
			local scrnIndex
			local scrnIndex2
			
			if selectedIndex < gameMove.index then
				scrnIndex = selectedIndex - 1
				scrnIndex2 = selectedIndex
			elseif selectedIndex > gameMove.index then
				scrnIndex = selectedIndex
				scrnIndex2 = selectedIndex - 1
			else
				scrnIndex = selectedIndex - 1
				scrnIndex2 = selectedIndex + 1
			end
			
			for i = 1, #gameList do
				if i ~= scrnIndex and i ~= scrnIndex2 and type(gameList[i]) == "table" then
					gameList[i]:destroySprite()
				end
			end
		end
	end
	
	if not dontReload then
		if gameMove == nil or gameMove.index == nil then
			local lower = math.floor(offY / 200) - 1
			local upper = math.ceil(offY / 200) + 1
			
			for i = lower - 1, upper + 1 do
				if gameList[i] ~= nil and not gameList[i].loadCardImages then
					gameList[i] = Game(gameList[i])
				end
				
				if gameList[i] ~= nil and not gameList[i].loaded then
					gameList[i]:loadCardImages()
					gameList[i].cardSprite:moveBy(0, (i - 1) * 200)
				end
			end
			
			if gameList[selectedIndex].state == kGameStateIdle then
				gameList[selectedIndex]:queueIdle()
			end
		else
			local scrnIndex
			local scrnIndex2
			
			if selectedIndex < gameMove.index then
				scrnIndex = selectedIndex - 1
				scrnIndex2 = selectedIndex
			elseif selectedIndex > gameMove.index then
				scrnIndex = selectedIndex
				scrnIndex2 = selectedIndex + 1
			else
				scrnIndex = selectedIndex - 1
				scrnIndex2 = selectedIndex + 1
			end
			
			if gameList[scrnIndex] ~= nil and not gameList[scrnIndex].loadCardImages then
				gameList[scrnIndex] = Game(gameList[scrnIndex])
			end
			
			if gameList[scrnIndex] ~= nil and not gameList[scrnIndex].loaded then
				gameList[scrnIndex]:loadCardImages()
				gameList[scrnIndex].cardSprite:moveTo(200, 120)
				gameList[scrnIndex].cardSprite:moveBy(0, (selectedIndex - 2) * 200)
			end
			
			if gameList[scrnIndex2] ~= nil and not gameList[scrnIndex2].loadCardImages then
				gameList[scrnIndex2] = Game(gameList[scrnIndex2])
			end
			
			if gameList[scrnIndex2] ~= nil and not gameList[scrnIndex2].loaded then
				gameList[scrnIndex2]:loadCardImages()
				gameList[scrnIndex2].cardSprite:moveTo(200, 120)
				gameList[scrnIndex2].cardSprite:moveBy(0, (selectedIndex - 1) * 200)
			end
		end
	end
end

local makeTopBar = function()
	if topBarSprite ~= nil then
		topBarSprite:remove()
		topBarSprite = nil
	end
	
	topBarSprite = spr.new(topBarImage:copy())
	topBarSprite:setCenter(0.5, 0)
	topBarSprite:moveTo(200, 0)
	topBarSprite:setZIndex(2000)
	topBarSprite:setIgnoresDrawOffset(true)
	
	function topBarSprite:update()
		local doUpdate = offX ~= 0
		
		local now = getPrintableTime()
		if lastTime ~= now then
			lastTime = now
			doUpdate = true
		end
		
		local pct = playdate.getBatteryPercentage()
		if lastPercentage ~= pct then
			lastPercentage = pct
			doUpdate = true
		end
		
		if doUpdate then
			local image = topBarImage:copy()
		
			gfx.pushContext(image)
			gfx.setFont(normalFont)
			gfx.setImageDrawMode(gfx.kDrawModeNXOR)
		
			gfx.drawText(lastTime, 16, 2)
			gfx.drawTextAligned("◂ " .. displayName .. " ▸", 200, 2, kTextAlignment.center)
		
			local pwr = playdate.getPowerStatus()
		
			if prefs.showBatteryPercentage or pwr.charging or pwr.USB or pwr.screws or pct < prefs.showBatteryBelowThreshold then
				if pct < 50 or pct > 100 then
					pct = math.floor(pct)
				else
					pct = math.ceil(pct)
				end
			
				gfx.drawTextAligned(string.format("%d%%", pct), 342, 2, kTextAlignment.right)
			end
			gfx.popContext()
			
			self:setImage(image)
		end
		
		if gameList[selectedIndex].state ~= kGameStateLaunching then
			refreshPageSprites(self.y)
		end
		
		if listViewTimer ~= nil or inListView then
			self:setAnimator(listViewAnim)
		end
	end
	
	topBarSprite:add()
end

function CardView:init()
	forceRefresh = nil
	
	if normalFont == nil then
		normalFont = self.loadFont("fonts/roobert11")
		gfx.setFont(normalFont)
	end
	
	if boldFont == nil then
		boldFont = self.loadFont("fonts/roobert11Bold")
		gfx.setFont(boldFont, "bold")
	end
	
	if infoViewCard == nil then
		infoViewCard = self.loadImage("images/infoCard")
		listViewCard = self.loadImage("images/listCard")
	end
	
	if topBarSprite == nil then
		topBarImage = self.loadImage("images/topBar")
		makeTopBar()
	end
	
	if barRegularImage == nil then
		barRegularImage = self.loadImage("images/bottomBar")
		barHoldingImage = self.loadImage("images/bottomBarHolding")
		barCopyImage = self.loadImage("images/bottomBarCopy")
		barMoveImage = self.loadImage("images/bottomBarMove")
		barCancelImage = self.loadImage("images/bottomBarCancel")
		barInfoImage = self.loadImage("images/bottomBarInfo")
		barRemoveImage = self.loadImage("images/bottomBarRemove")
		barDeleteImage = self.loadImage("images/bottomBarDelete")
		barLogoImage = self.loadImage("images/bottomBarLogo")
	end
	
	if bottomBarSprite == nil then
		bottomBarSprite = spr.new(barRegularImage)
		function bottomBarSprite:setImageWithUpdate(img)
			if img == barDeleteImage then
				deleteFolderAnim = tmr.new(4000, 0, 400, playdate.easingFunctions.outQuad)
				deleteFolderAnim.timerEndedCallback = function()
					folderDeleteSound:play()
					deleteFolder(folderName)
					if deleteFolderAnim ~= nil then
						deleteFolderAnim:remove()
						deleteFolderAnim = nil
					end
					
					if inInfoView then
						CardView.BButtonUp()
					end
					forceRefresh = -3
					cooldown = true
				end
			else
				self:setImage(img)
				if deleteFolderAnim ~= nil then
					deleteFolderAnim:remove()
					deleteFolderAnim = nil
				end
			end
		end
		
		function bottomBarSprite:update()
			if deleteFolderAnim ~= nil then
				local img = barDeleteImage:copy()
				gfx.pushContext(img)
				gfx.setColor(gfx.kColorXOR)
				gfx.fillRect(0, 1, deleteFolderAnim.value, 27)
				gfx.setColor(gfx.kColorBlack)
				gfx.popContext()
				self:setImage(img)
			end
		end
	end
	
	bottomBarSprite:setCenter(0.5, 1)
	bottomBarSprite:moveTo(200, 240)
	bottomBarSprite:setZIndex(2000)
	bottomBarSprite:setIgnoresDrawOffset(true)
	bottomBarSprite:add()
	
	if batterySprite == nil then
		batteryTable = self.loadImageTable("images/battery")
		batteryIndex = getBatteryIndex()
		batterySprite = spr.new(batteryTable[batteryIndex])
		batterySprite:setCenter(1, 1)
		batterySprite:moveTo(384, 20)
		batterySprite:setZIndex(2001)
		batterySprite:setIgnoresDrawOffset(true)
		batterySprite:add()
	end
	
	if moveStartSound == nil then
		moveStartSound = self.loadSound("sounds/gameMoveStart")
		moveEndSound = self.loadSound("sounds/gameMoveEnd")
		infoOpenSound = self.loadSound("sounds/infoViewOpen")
		infoCloseSound = self.loadSound("sounds/infoViewClose")
		listOpenSound = self.loadSound("sounds/listViewOpen")
		listCloseSound = self.loadSound("sounds/listViewClose")
		folderDeleteSound = self.loadSound("sounds/folderDelete")
	end
end

function CardView:useGroup(groupStr, currentGame)
	if gameList ~= nil then
		loadAll(true)
	end
	
	self.groupName = groupStr
	local group, idx = getGroupByName(self.groupName)
	local loadFaster = false
	
	if self.groupName ~= "System" then
		local sortFuncs = {
			["First Title"] = function(e1, e2)
				return e1 ~= nil and e2 ~= nil and e1:getTitle():upper() < e2:getTitle():upper()
			end,
			
			["Last Title"] = function(e1, e2)
				return e1 ~= nil and e2 ~= nil and e1:getTitle():upper() > e2:getTitle():upper()
			end,
			
			["First Author"] = function(e1, e2)
				return e1 ~= nil and e2 ~= nil and e1:getStudio():upper() < e2:getStudio():upper()
			end,
			
			["Last Author"] = function(e1, e2)
				return e1 ~= nil and e2 ~= nil and e1:getStudio():upper() > e2:getStudio():upper()
			end,
			
			["Most Recent"] = function(e1, e2)
				if e1 == nil or e2 == nil then
					return false
				end
				
				local d1 = folderPrefs.gamePlayedTimes[e1:getPath()] or 0
				local d2 = folderPrefs.gamePlayedTimes[e2:getPath()] or 0
				
				return d1 > d2
			end,
			
			["Least Recent"] = function(e1, e2)
				if e1 == nil or e2 == nil then
					return false
				end
				
				local d1 = folderPrefs.gamePlayedTimes[e1:getPath()] or 0
				local d2 = folderPrefs.gamePlayedTimes[e2:getPath()] or 0
				
				return d1 < d2
			end,
		}
		
		if prefs.sortGamesBy ~= "Custom" then
			table.sort(group, sortFuncs[prefs.sortGamesBy])
		end
	end
	
	for i, game in ipairs(group) do
		if type(game) == "userdata" then
			loadFaster = true
			break
		end
	end
	
	for index, game in ipairs(group) do
		if game:getPath() == currentGame then
			selectedIndex = index
			break
		end
	end
	
	if #group == 0 then
		table.insert(group, Game())
	end
	
	if selectedIndex == nil then
		selectedIndex = 1
	end
	selectedIndex = selectedIndex <= #group and selectedIndex or #group
	
	if loadFaster then
		group = loadGroupFaster(idx, selectedIndex)
	end
	
	self.gameList = group
end

function CardView:activate(swipeInFrom, currentGame)
	gameList = self.gameList
	folderName = self.groupName
	displayName = self.displayName
	
	spr.setBackgroundDrawingCallback(drawBackground)
	
	if type(swipeInFrom) == "string" and swipeInFrom:sub(-1, -1) == "-" then
		local swipe = swipeInFrom:sub(1, -2)
		
		if swipe == "right" then
			offXAnim = tmr.new(150, 400, 0, playdate.easingFunctions.outCubic)
		elseif swipe == "left" then
			offXAnim = tmr.new(150, -400, 0, playdate.easingFunctions.outCubic)
		end
	elseif swipeInFrom == "right" then
		offXAnim = tmr.new(80, 400, 0, playdate.easingFunctions.outCubic)
	elseif swipeInFrom == "left" then	
		offXAnim = tmr.new(80, -400, 0, playdate.easingFunctions.outCubic)
	end
	
	if gameList[selectedIndex].state ~= nil then
		gameList[selectedIndex]:queueIdle()
	end
	
	local anchorStart, anchorEnd = (selectedIndex - 3 < 1), (selectedIndex + 3 > #gameList)
	if anchorStart or #gameList <= 5 then
		listViewY = selectedIndex * 36 - 32
		listViewTextOffset = 0
	elseif anchorEnd and #gameList > 5 then
		listViewY = 76 + (selectedIndex + 2 - #gameList) * 36 
		listViewTextOffset = (5 - #gameList) * 36
	else
		listViewY = 76
		listViewTextOffset = (3 - selectedIndex) * 36
	end
	
	if inListView then
		listViewTextAnim = anm.new(1, geo.point.new(200, listViewTextSprite.y), geo.point.new(200, listViewTextOffset))
		listViewTextSprite.refresh = true
	end
	
	if gameMove ~= nil then
		if not isSystemGroup(prevViewGroup) and isSystemGroup(folderName) then
			bottomBarSprite:setImageWithUpdate(barRemoveImage)
			bottomBarSprite:moveTo(200, 240)
		elseif folderName == "System" or isSystemGroup(folderName) and isSystemGroup(prevViewGroup) then
			bottomBarSprite:setImageWithUpdate(barCancelImage)
			bottomBarSprite:moveTo(200, 240)
		elseif isSystemGroup(prevViewGroup) and not isSystemGroup(folderName) then
			bottomBarSprite:setImageWithUpdate(barCopyImage)
			bottomBarSprite:moveTo(200, 240)
		else
			bottomBarSprite:setImageWithUpdate(barMoveImage)
			bottomBarSprite:moveTo(200, 240)
		end
	elseif not inInfoView and not inListView then
		bottomBarSprite:setImageWithUpdate(barRegularImage)
		bottomBarSprite:moveTo(200, 240)
	elseif inListView then
		bottomBarSprite:moveTo(200, 288)
	elseif inInfoView then
		bottomBarSprite:moveTo(infoViewAnim:currentValue():unpack())
	end
	
	if keyTimer ~= nil then
		keyTimer:remove()
		keyTimer = nil
	end
	
	if currentGame ~= "" then
		barAnim = tmr.new(300, -84, 0)
	end
	
	prevIndex = selectedIndex
	
	if inInfoView then
		gfx.setFont(normalFont)
		gfx.pushContext(infoViewSprite:getImage())
		gameList[selectedIndex]:drawInfoText()
		gfx.popContext()
	end
	
	allowMoving = true
	allowVerticalMove = true
	onNextFrame = true
	
	animTimer = tmr.new(75)
	
	crankAccum = 0
end

function CardView.upButtonDown()
	if launchAnim ~= nil or (folderName == "System" and gameMove ~= nil) then
		jitter = 4
		if playdate.getCurrentTimeMilliseconds() > 500 then
			snd.playSystemSound(snd.kSoundDenial)
		end
		return
	end
	
	if gameList[selectedIndex] ~= nil and gameList[selectedIndex].state == kGameStatePressed then
		return
	end
	
	if keyTimer ~= nil then
		keyTimer:remove()
		keyTimer = nil
	end
	
	keyTimer = tmr.keyRepeatTimerWithDelay(300, 40, function()
		if not playdate.buttonIsPressed("up") or not allowVerticalMove or playdate.buttonIsPressed("left") or playdate.buttonIsPressed("right") then
			return
		end
		
		if selectedIndex <= 1 then
			jitter = 4
			if playdate.getCurrentTimeMilliseconds() > 500 then
				snd.playSystemSound(snd.kSoundDenial)
			end
		elseif playdate.getCurrentTimeMilliseconds() > 500 then
			selectedIndex = selectedIndex - 1
			snd.playSystemSound(snd.kSoundSelectPrevious)
			
			if inInfoView then
				infoViewSprite:setImage(infoViewCard:copy())
				gfx.pushContext(infoViewSprite:getImage())
				gameList[selectedIndex]:drawInfoText()
				gfx.popContext()
				return
			end
			
			if inListView then
				local anchorStart, anchorEnd = (selectedIndex - 3 < 1), (selectedIndex + 3 > #gameList)
				local yTarget, textTarget
				
				if anchorStart or #gameList <= 5 then
					yTarget = selectedIndex * 36 - 32
					textTarget = 0
				elseif anchorEnd and #gameList > 5 then
					yTarget = 76 + (selectedIndex + 2 - #gameList) * 36 
					textTarget = (5 - #gameList) * 36
				else
					yTarget = 76
					textTarget = (3 - selectedIndex) * 36
				end
				
				local txtOffset = listViewTextOffset or 0
				local y = listViewY or 16
				
				listViewTextAnim = anm.new(100, geo.point.new(200, txtOffset), geo.point.new(200, textTarget), playdate.easingFunctions.outCubic)
				listViewTextSprite:setAnimator(listViewTextAnim)
				
				listViewYAnim = anm.new(100, geo.point.new(200, y), geo.point.new(200, yTarget), playdate.easingFunctions.outCubic)
			end
			
			if offYAnim ~= nil then
				offY = offYAnim.value
				offYAnim:remove()
			end
			if gameMove == nil then
				offYAnim = tmr.new(100, offY, (selectedIndex - 1) * 200, playdate.easingFunctions.outCubic)
			else
				offYAnim = tmr.new(100, offY, (selectedIndex - 1.5) * 200)
			end
			
			if animTimer ~= nil then
				animTimer:remove()
			end
			animTimer = tmr.new(75)
			onNextFrame = true
		end
	end)
end

function CardView.downButtonDown()
	if launchAnim ~= nil or (folderName == "System" and gameMove ~= nil) then
		jitter = inListView and -2 or -4
		if playdate.getCurrentTimeMilliseconds() > 500 then
			snd.playSystemSound(snd.kSoundDenial)
		end
		return
	end
	
	if gameList[selectedIndex] ~= nil and gameList[selectedIndex].state == kGameStatePressed then
		return
	end
	
	if keyTimer ~= nil then
		keyTimer:remove()
		keyTimer = nil
	end
	
	keyTimer = tmr.keyRepeatTimerWithDelay(300, 40, function()
		if not playdate.buttonIsPressed("down") or not allowVerticalMove or playdate.buttonIsPressed("left") or playdate.buttonIsPressed("right") then
			return
		end
		
		if selectedIndex == #gameList and gameMove ~= nil and gameMove.index == nil and gameList[selectedIndex].state ~= nil then
			selectedIndex = selectedIndex + 1
			snd.playSystemSound(snd.kSoundSelectNext)
			
			if offYAnim ~= nil then
				offY = offYAnim.value
				offYAnim:remove()
			end
			
			offYAnim = tmr.new(100, offY, (selectedIndex - 1.5) * 200)
		elseif selectedIndex >= #gameList then
			jitter = -4
			if playdate.getCurrentTimeMilliseconds() > 500 then
				snd.playSystemSound(snd.kSoundDenial)
			end
		elseif playdate.getCurrentTimeMilliseconds() > 500 then
			selectedIndex = selectedIndex + 1
			snd.playSystemSound(snd.kSoundSelectNext)
			
			if inInfoView then
				infoViewSprite:setImage(infoViewCard:copy())
				gfx.pushContext(infoViewSprite:getImage())
				gameList[selectedIndex]:drawInfoText()
				gfx.popContext()
				return
			end
			
			if inListView then
				local anchorStart, anchorEnd = (selectedIndex - 3 < 1), (selectedIndex + 3 > #gameList)
				local yTarget, textTarget
				
				if anchorStart or #gameList <= 5 then
					yTarget = selectedIndex * 36 - 32
					textTarget = 0
				elseif anchorEnd and #gameList > 5 then
					yTarget = 76 + (selectedIndex + 2 - #gameList) * 36 
					textTarget = (5 - #gameList) * 36
				else
					yTarget = 76
					textTarget = (3 - selectedIndex) * 36
				end
				
				local txtOffset = listViewTextOffset or 0
				local y = listViewY or 16
				
				listViewTextAnim = anm.new(100, geo.point.new(200, txtOffset), geo.point.new(200, textTarget), playdate.easingFunctions.outCubic)
				listViewTextSprite:setAnimator(listViewTextAnim)
				
				listViewYAnim = anm.new(100, geo.point.new(200, y), geo.point.new(200, yTarget), playdate.easingFunctions.outCubic)
			end
			
			if offYAnim ~= nil then
				offY = offYAnim.value
				offYAnim:remove()
			end
			if gameMove == nil then
				offYAnim = tmr.new(100, offY, (selectedIndex - 1) * 200, playdate.easingFunctions.outCubic)
			else
				offYAnim = tmr.new(100, offY, (selectedIndex - 1.5) * 200)
			end
			
			if animTimer ~= nil then
				animTimer:remove()
			end
			animTimer = tmr.new(75)
			onNextFrame = true
		end
	end)
end

function CardView.BButtonDown()	
	if cooldown == true then
		cooldown = false
		return
	end
	
	if keyTimer ~= nil then
		keyTimer:remove()
		keyTimer = nil
	end
	
	if infoViewTimer ~= nil then
		return
	end
	
	if playdate.buttonIsPressed("A") or inListView then
		return
	end
	
	if not inListView and gameList[selectedIndex].state == nil then
		bottomBarSprite:setImageWithUpdate(isSystemGroup(folderName) and barInfoImage or barDeleteImage)
		return
	end
	
	local launchedGame = gameList[selectedIndex]
	if launchedGame.state ~= nil and launchedGame.data:getInstalledState() == launchedGame.data.kPDGameStateFreshlyInstalled then
		return
	end
	
	if launchedGame.state ~= nil and launchAnim == nil and not inInfoView and not inListView then
		if prefs.sortGamesBy == "Custom" and launchedGame.id == "com.panic.launcher" then
			shakeBackForth = -2
			snd.playSystemSound(snd.kSoundDenial)
		elseif prefs.sortGamesBy == "Custom" then
			launchAnim = anm.new(1000, 0, 200)
		end
		
		bottomBarSprite:setImageWithUpdate(barHoldingImage)
		bottomBarSprite:moveTo(200, 240)
		allowVerticalMove = false
	end
end

function CardView.AButtonDown()
	if keyTimer ~= nil then
		keyTimer:remove()
		keyTimer = nil
	end
	
	bottomBarSprite:setImageWithUpdate(barRegularImage)
	
	if not playdate.buttonIsPressed("B") then
		local launchedGame = gameList[selectedIndex]
		
		if launchedGame.state == nil then
			shakeBackForth = -2
			snd.playSystemSound(snd.kSoundDenial)
			return
		end
		
		if launchedGame.data:getInstalledState() ~= launchedGame.data.kPDGameStateFreshlyInstalled then
			launchedGame:press()
		end
	end
	if launchAnim ~= nil then
		launchAnim = nil
		delaunchAnim = anm.new(100, lastLaunchAnimVal, 0)
	end
	if deleteFolderAnim ~= nil then
		deleteFolderAnim = nil
	end
end

function CardView.BButtonUp()
	if cooldown == true then
		bottomBarSprite:setImageWithUpdate(barRegularImage)
		cooldown = false
		return
	end
	
	if deleteFolderAnim ~= nil then
		bottomBarSprite:setImageWithUpdate(barRegularImage)
	end
	
	if inListView then
		listViewAnim = anm.new(250, geo.point.new(200, topBarSprite.y), geo.point.new(200, 0), playdate.easingFunctions.inOutBack)
		listViewTextAnim = anm.new(250, geo.point.new(200, topBarSprite.y + listViewTextOffset - 200), geo.point.new(200, listViewTextOffset - 200), playdate.easingFunctions.inOutBack)
		batterySprite:setAnimator(anm.new(250, geo.point.new(384, 20 + topBarSprite.y), geo.point.new(384, 20), playdate.easingFunctions.inOutBack))
		
		listViewTextSprite:setAnimator(listViewTextAnim)
		listViewSprite:setAnimator(listViewAnim)
		
		barAnim = tmr.new(300, -84, 0)
		inListView = false
		
		if not listCloseSound:isPlaying() then
			listCloseSound:play()
		end
		
		listViewTimer = tmr.new(250, function()
			listViewSprite:remove()
			listViewSprite = nil
			listViewTextSprite:remove()
			listViewTextSprite = nil
			
			if listViewTimer ~= nil then
				listViewTimer:remove()
				listViewTimer = nil
			end
			
			CardView.BButtonUp()
			cooldown = true
		end)
		
		onNextFrame = true
		return
	elseif inInfoView and infoViewTimer == nil then
		inInfoView = false
		infoViewAnim = anm.new(300, geo.point.new(200, bottomBarSprite.y), geo.point.new(200, 240), playdate.easingFunctions.outBack)
		infoViewSprite:setAnimator(infoViewAnim)
		bottomBarSprite:setAnimator(infoViewAnim)
		
		barAnim = tmr.new(300, -84, 0)
		
		batterySprite:add()
		
		infoViewTimer = tmr.new(300, function()
			if infoViewSprite ~= nil then
				infoViewSprite:remove()
				infoViewSprite = nil
			end
			
			if infoViewTimer ~= nil then
				infoViewTimer:remove()
				infoViewTimer = nil
			end
		end)
		
		if not infoCloseSound:isPlaying() then
			infoCloseSound:play()
		end
		
		allowVerticalMove = true
		onNextFrame = true
		
		bottomBarSprite:setImageWithUpdate(barRegularImage)
		return
	end
	
	if gameMove == nil and not inListView and infoViewTimer == nil then
		if launchAnim ~= nil then
			launchAnim = nil
			if gameList[selectedIndex].id ~= nil then
				bottomBarSprite:setImageWithUpdate(barRegularImage)
				bottomBarSprite:moveTo(200, 240)
				delaunchAnim = anm.new(100, lastLaunchAnimVal, 0)
				gameList[selectedIndex]:queueIdle()
			end
		end
		
		infoViewAnim = anm.new(300, geo.point.new(200, bottomBarSprite.y), geo.point.new(200, 28), playdate.easingFunctions.outBack)
		infoViewSprite = spr.new(infoViewCard:copy())
		infoViewSprite:setCenter(0.5, 0)
		infoViewSprite:setZIndex(2000)
		infoViewSprite:setIgnoresDrawOffset(true)
		infoViewSprite:setAnimator(infoViewAnim)
		bottomBarSprite:setAnimator(infoViewAnim)
		
		infoViewSprite:add()
		removePageSprites()
		
		gfx.pushContext(infoViewSprite:getImage())
		gameList[selectedIndex]:drawInfoText()
		gfx.popContext()
		
		barAnim = tmr.new(300, 0, -84)
		inInfoView = true
		
		if not infoOpenSound:isPlaying() then
			infoOpenSound:play()
		end
		
		infoViewTimer = tmr.new(300, function()
			batterySprite:remove()
			
			if infoViewTimer ~= nil then
				infoViewTimer:remove()
				infoViewTimer = nil
			end
			
			if gameList[selectedIndex].state ~= nil then
				loadAll(true)
			end
		end)
		
		bottomBarSprite:setImageWithUpdate(barInfoImage)
	elseif gameMove ~= nil then
		if gameMove.index ~= nil then
			gameMove:destroySprite()
		end
		
		if folderName ~= "System" and ((isSystemGroup(folderName) and prevViewGroup == folderName) or not isSystemGroup(folderName)) then
			if copyGame(gameMove.path, getCurrentFolderName(), selectedIndex) then
				moveEndSound:play()
				removeGame(gameMove.path, prevViewGroup)
				forceRefresh = 0
			end
		elseif not isSystemGroup(prevViewGroup) and isSystemGroup(folderName) then
			if removeGame(gameMove.path, prevViewGroup) then
				forceRefresh = 0
			end
		else
			snd.playSystemSound(snd.kSoundDenial)
		end
		
		loadAll(true, prevIndex)
		
		if selectedIndex > #gameList then
			selectedIndex = #gameList
		end
		
		gameMove.cardSprite:remove()
		gameMove = nil
		
		loadAll(false, selectedIndex)
		
		bottomBarSprite:setImageWithUpdate(barRegularImage)
		onNextFrame = true
	end
	
	allowVerticalMove = true
end

function CardView.AButtonUp()
	if inInfoView and playdate.buttonIsPressed("B") and infoViewTimer == nil then
		inInfoView = false
		infoViewAnim = anm.new(300, geo.point.new(200, bottomBarSprite.y), geo.point.new(200, 240), playdate.easingFunctions.outBack)
		infoViewSprite:setAnimator(infoViewAnim)
		bottomBarSprite:setAnimator(infoViewAnim)
		
		barAnim = tmr.new(300, -84, 0)
		
		batterySprite:add()
		
		infoViewTimer = tmr.new(300, function()
			if infoViewSprite ~= nil then
				infoViewSprite:remove()
				infoViewSprite = nil
			end
			
			if infoViewTimer ~= nil then
				infoViewTimer:remove()
				infoViewTimer = nil
			end
			
			if launchAnim ~= nil then
				launchAnim = nil
				if gameList[selectedIndex].id ~= nil then
					delaunchAnim = anm.new(100, lastLaunchAnimVal, 0)
					gameList[selectedIndex]:queueIdle()
				end
			end
			batterySprite:setAnimator(anm.new(300, geo.point.new(384, 20 + topBarSprite.y), geo.point.new(384, 220), playdate.easingFunctions.outBack))
			listViewAnim = anm.new(300, geo.point.new(200, topBarSprite.y), geo.point.new(200, 200), playdate.easingFunctions.outBack)
			listViewSprite = spr.new(listViewCard)
			listViewSprite:setCenter(0.5, 1)
			listViewSprite:setZIndex(1998)
			listViewSprite:setIgnoresDrawOffset(true)
			listViewSprite:setAnimator(listViewAnim)
			listViewSprite:add()
			
			local anchorStart, anchorEnd = (selectedIndex - 3 < 1), (selectedIndex + 3 > #gameList)
			if anchorStart or #gameList <= 5 then
				listViewY = selectedIndex * 36 - 32
				listViewTextOffset = 0
			elseif anchorEnd and #gameList > 5 then
				listViewY = 76 + (selectedIndex + 2 - #gameList) * 36 
				listViewTextOffset = (5 - #gameList) * 36
			else
				listViewY = 76
				listViewTextOffset = (3 - selectedIndex) * 36
			end
			
			listViewTextSprite = spr.new()
			listViewTextSprite:setCenter(0.5, 0)
			listViewTextSprite:setZIndex(1999)
			listViewTextSprite:setIgnoresDrawOffset(true)
			
			function listViewTextSprite:update()
				if listViewAnim ~= nil then
					self:setClipRect(28, 0, 380, listViewAnim:currentValue().y)
				end
				
				if self.refresh == true or (offXAnim ~= nil and self.refresh == true) then
					local image = img.new(392, math.max(38 * #gameList + 8, 190))
					gfx.pushContext(image)
					
					local yPos = 14
					for i = 1, #gameList do
						local text = gameList[i]:getTitle():gsub("*", "**"):gsub("_", "__")
						gfx.drawTextInRect("*" .. text .. "*", 24, yPos, 300, 24, nil, "...", kTextAlignment.left)
						yPos = yPos + 36
					end
					
					gfx.popContext()
					self:setImage(image)
					
					if listViewTextAnim ~= nil then
						self:setAnimator(listViewTextAnim)
					end
					
					self.refresh = false
				end
			end
			
			listViewTextAnim = anm.new(300, geo.point.new(200, listViewTextOffset - 200), geo.point.new(200, topBarSprite.y + listViewTextOffset), playdate.easingFunctions.outBack)
			listViewTextSprite:setAnimator(listViewTextAnim)
			listViewTextSprite:add()
			listViewTextSprite.refresh = true
			
			barAnim = tmr.new(300, barAnim and barAnim.value or 0, -84)
			inListView = true
			
			if not listOpenSound:isPlaying() then
				listOpenSound:play()
			end
			
			for _, game in ipairs(gameList) do
				game:queueIdle()
			end
			
			listViewTimer = tmr.new(300, function()
				allowMoving = true
				if listViewTimer ~= nil then
					listViewTimer:remove()
					listViewTimer = nil
				end
				
				topBarSprite:removeAnimator()
				
				if gameList[selectedIndex].state ~= nil then
					loadAll(true)
				end
			end)
			
			allowVerticalMove = true
			cooldown = true
		end)
		
		if not infoCloseSound:isPlaying() then
			infoCloseSound:play()
		end
		
		allowVerticalMove = true
		
		bottomBarSprite:setImageWithUpdate(barRegularImage)
		
		loadAll(false)
		return
	end
	
	if inListView and not playdate.buttonIsPressed("B") and secretComboIndex ~= #secretCombo then
		listViewAnim = anm.new(300, geo.point.new(200, topBarSprite.y), geo.point.new(200, 0), playdate.easingFunctions.inOutBack)
		listViewTextAnim = anm.new(300, geo.point.new(200, topBarSprite.y + listViewTextOffset - 200), geo.point.new(200, listViewTextOffset - 200), playdate.easingFunctions.inOutBack)
		batterySprite:setAnimator(anm.new(300, geo.point.new(384, 20 + topBarSprite.y), geo.point.new(384, 20), playdate.easingFunctions.inOutBack))
		
		listViewTextSprite:setAnimator(listViewTextAnim)
		listViewSprite:setAnimator(listViewAnim)
		
		barAnim = tmr.new(300, barAnim and barAnim.value or -84, 0)
		inListView = false
		
		if not listCloseSound:isPlaying() then
			listCloseSound:play()
		end
		
		listViewTimer = tmr.new(300, function()
			allowVerticalMove = true
			
			listViewTextSprite:remove()
			listViewTextSprite = nil
			listViewSprite:remove()
			listViewSprite = nil
			
			if listViewTimer ~= nil then
				listViewTimer:remove()
				listViewTimer = nil
			end
			
			topBarSprite:removeAnimator()
			for _, game in ipairs(gameList) do
				game:queueIdle()
			end
		end)
		
		onNextFrame = true
		tmr.performAfterDelay(300, function()
			if gameList[selectedIndex].state ~= nil then
				if gameList[selectedIndex].data:getInstalledState() == gameList[selectedIndex].data.kPDGameStateFreshlyInstalled then
					gameList[selectedIndex]:queueUnwrap()
					allowVerticalMove = false
				elseif gameList[selectedIndex].id == "com.panic.launcher" then
					snd.playSystemSound(snd.kSoundAction)
					tmr.performAfterDelay(180, function()
						sys.switchToGame(gameList[selectedIndex].path)
					end)
				elseif gameList[selectedIndex].cardSprite ~= nil then
					gameList[selectedIndex].cardSprite:setZIndex(32767)
					barAnim = tmr.new(300, barYOffset, -84)
					willLaunchGame()
					gameList[selectedIndex]:queueLaunch()
				end
			end
		end)
	elseif inInfoView and not playdate.buttonIsPressed("B") and secretComboIndex ~= #secretCombo then
		allowMoving = false
		allowVerticalMove = false
		
		if infoViewTimer ~= nil then
			infoViewTimer.timerEndedCallback()
		end
		if listViewTimer ~= nil then
			listViewTimer.timerEndedCallback()
		end
		
		inInfoView = false
		infoViewAnim = anm.new(200, geo.point.new(200, bottomBarSprite.y), geo.point.new(200, 240))
		infoViewSprite:setAnimator(infoViewAnim)
		bottomBarSprite:setAnimator(infoViewAnim)
		
		topBarSprite:removeAnimator()
		barAnim = tmr.new(300, -84, 0)
		batterySprite:add()
		
		infoViewTimer = tmr.new(200, function()
			if infoViewSprite ~= nil then
				infoViewSprite:remove()
				infoViewSprite = nil
			end
			
			if infoViewTimer ~= nil then
				infoViewTimer:remove()
				infoViewTimer = nil
			end
		end)
		
		bottomBarSprite:setImageWithUpdate(barRegularImage)
		onNextFrame = true
		
		tmr.performAfterDelay(300, function()
			if gameList[selectedIndex].state ~= nil and gameList[selectedIndex].state ~= kGameStateUnwrapping then
				if gameList[selectedIndex].data:getInstalledState() == gameList[selectedIndex].data.kPDGameStateFreshlyInstalled then
					gameList[selectedIndex]:queueUnwrap()
					allowVerticalMove = false
				elseif gameList[selectedIndex].id == "com.panic.launcher" then
					snd.playSystemSound(snd.kSoundAction)
					tmr.performAfterDelay(180, function()
						sys.switchToGame(gameList[selectedIndex].path)
					end)
				elseif gameList[selectedIndex].cardSprite ~= nil then
					gameList[selectedIndex].cardSprite:setZIndex(32767)
					barAnim = tmr.new(300, barYOffset, -84)
					willLaunchGame()
					gameList[selectedIndex]:queueLaunch()
				end
			end
		end)
	elseif not (inInfoView or inListView) and not playdate.buttonIsPressed("B") and gameList[selectedIndex].state ~= kGameStateUnwrapping then
		if gameList[selectedIndex].state ~= nil and gameList[selectedIndex].data:getInstalledState() == gameList[selectedIndex].data.kPDGameStateFreshlyInstalled then
			gameList[selectedIndex]:queueUnwrap()
			allowVerticalMove = false
		elseif gameList[selectedIndex].id == "com.panic.launcher" then
			snd.playSystemSound(snd.kSoundAction)
			tmr.performAfterDelay(180, function()
				sys.switchToGame(gameList[selectedIndex].path)
			end)
		elseif gameList[selectedIndex].state ~= nil and gameList[selectedIndex].cardSprite ~= nil then
			gameList[selectedIndex].cardSprite:setZIndex(32767)
			barAnim = tmr.new(300, barYOffset, -84)
			willLaunchGame()
			gameList[selectedIndex]:queueLaunch()
			allowMoving = false
			allowVerticalMove = false
		end
	elseif not inInfoView and (playdate.buttonIsPressed("B") or secretComboIndex == #secretCombo) and gameMove == nil and listViewTimer == nil then
		if infoViewTimer ~= nil then
			infoViewTimer.timerEndedCallback()
		end
		
		if launchAnim ~= nil then
			launchAnim = nil
			if gameList[selectedIndex].id ~= nil then
				delaunchAnim = anm.new(100, lastLaunchAnimVal, 0)
				gameList[selectedIndex]:queueIdle()
			end
		end
		
		if inListView == false then
			batterySprite:setAnimator(anm.new(300, geo.point.new(384, 20 + topBarSprite.y), geo.point.new(384, 220), playdate.easingFunctions.outBack))
			listViewAnim = anm.new(300, geo.point.new(200, topBarSprite.y), geo.point.new(200, 200), playdate.easingFunctions.outBack)
			listViewSprite = spr.new(listViewCard)
			listViewSprite:setCenter(0.5, 1)
			listViewSprite:setZIndex(1998)
			listViewSprite:setIgnoresDrawOffset(true)
			listViewSprite:setAnimator(listViewAnim)
			listViewSprite:add()
			
			local anchorStart, anchorEnd = (selectedIndex - 3 < 1), (selectedIndex + 3 > #gameList)
			if anchorStart or #gameList <= 5 then
				listViewY = selectedIndex * 36 - 32
				listViewTextOffset = 0
			elseif anchorEnd and #gameList > 5 then
				listViewY = 76 + (selectedIndex + 2 - #gameList) * 36 
				listViewTextOffset = (5 - #gameList) * 36
			else
				listViewY = 76
				listViewTextOffset = (3 - selectedIndex) * 36
			end
			
			listViewTextSprite = spr.new()
			listViewTextSprite:setCenter(0.5, 0)
			listViewTextSprite:setZIndex(1999)
			listViewTextSprite:setIgnoresDrawOffset(true)
			
			function listViewTextSprite:update()
				if listViewAnim ~= nil then
					self:setClipRect(28, 0, 380, listViewAnim:currentValue().y)
				end
				
				if self.refresh == true or (offXAnim ~= nil and self.refresh == true) then
					local image = img.new(392, math.max(38 * #gameList + 8, 190))
					gfx.pushContext(image)
					
					local yPos = 14
					for i = 1, #gameList do
						local text = gameList[i].data and gameList[i]:getListedTitle():gsub("*", "**"):gsub("_", "__") or "Loading..."
						text = gameList[i].state and text or gameList[i]:getTitle()
						
						gfx.drawTextInRect("*" .. text .. "*", 24, yPos, 300, 24, nil, "...", kTextAlignment.left)
						yPos = yPos + 36
					end
					
					gfx.popContext()
					self:setImage(image)
					
					if listViewTextAnim ~= nil then
						self:setAnimator(listViewTextAnim)
					end
					
					self.refresh = false
				end
			end
			
			listViewTextAnim = anm.new(300, geo.point.new(200, listViewTextOffset - 200), geo.point.new(200, topBarSprite.y + listViewTextOffset), playdate.easingFunctions.outBack)
			listViewTextSprite:setAnimator(listViewTextAnim)
			listViewTextSprite:add()
			listViewTextSprite.refresh = true
			
			barAnim = tmr.new(300, barAnim and barAnim.value or 0, -84)
			inListView = true
			
			if not listOpenSound:isPlaying() then
				listOpenSound:play()
			end
			
			for _, game in ipairs(gameList) do
				if game.id ~= nil then
					game:queueIdle()
				end
			end
			
			listViewTimer = tmr.new(300, function()
				allowMoving = true
				if listViewTimer ~= nil then
					listViewTimer:remove()
					listViewTimer = nil
				end
				
				topBarSprite:removeAnimator()
				
				if gameList[selectedIndex].state ~= nil then
					loadAll(true)
				end
			end)
			
			allowVerticalMove = true
			cooldown = true
		else
			if secretComboIndex == #secretCombo then
				listViewAnim = anm.new(300, geo.point.new(200, 200), geo.point.new(200, -84), playdate.easingFunctions.inOutBack)
				listViewTextAnim = anm.new(300, geo.point.new(200, listViewTextOffset), geo.point.new(200, listViewTextOffset - 284), playdate.easingFunctions.inOutBack)
				batterySprite:setAnimator(anm.new(300, geo.point.new(384, 220), geo.point.new(384, -64), playdate.easingFunctions.inOutBack))
			else
				listViewAnim = anm.new(300, geo.point.new(200, 200), geo.point.new(200, 0), playdate.easingFunctions.inOutBack)
				listViewTextAnim = anm.new(300, geo.point.new(200, listViewTextOffset), geo.point.new(200, listViewTextOffset - 200), playdate.easingFunctions.inOutBack)
				batterySprite:setAnimator(anm.new(300, geo.point.new(384, 220), geo.point.new(384, 20), playdate.easingFunctions.inOutBack))
			end
			
			listViewTextSprite:setAnimator(listViewTextAnim)
			listViewSprite:setAnimator(listViewAnim)
			
			barAnim = tmr.new(300, barAnim and barAnim.value or -84, 0)
			inListView = false
			
			if not listCloseSound:isPlaying() then
				listCloseSound:play()
			end
			
			if gameList[selectedIndex].state ~= nil then
				loadAll(false)
				for _, game in ipairs(gameList) do
					if game.id ~= nil then
						game:queueIdle()
					end
				end
			end
			
			listViewTimer = tmr.new(300, function()
				allowVerticalMove = true
				
				listViewTextSprite:remove()
				listViewTextSprite = nil
				listViewSprite:remove()
				listViewSprite = nil
				
				if listViewTimer ~= nil then
					listViewTimer:remove()
					listViewTimer = nil
				end
				
				topBarSprite:removeAnimator()
			end)
			
			cooldown = true
		end
	end
end

function CardView.leftButtonDown()
	if keyTimer ~= nil then
		keyTimer:remove()
		keyTimer = nil
	end
end

function CardView.leftButtonUp()
	if launchAnim == nil and allowMoving then
		if inInfoView then
			infoViewSprite:setImage(infoViewCard:copy())
		end
		if not flipBack:isPlaying() then
			flipBack:play()
		end
		playdate.leftButtonUp()
	end
end

function CardView.rightButtonDown()
	if keyTimer ~= nil then
		keyTimer:remove()
		keyTimer = nil
	end
end

function CardView.rightButtonUp()
	if launchAnim == nil and allowMoving then
		if inInfoView then
			infoViewSprite:setImage(infoViewCard:copy())
		end
		if not flipForward:isPlaying() then
			flipForward:play()
		end
		playdate.rightButtonUp()
	end
end

function CardView.upButtonUp()
	if keyTimer ~= nil then
		keyTimer:remove()
		keyTimer = nil
	end
	
	local game = playdate.getCurrentGame()
	if gameList[selectedIndex] ~= nil and gameList[selectedIndex].state ~= nil and gameMove == nil then
		local launcherPrefs = {selectedGamePath = game:getPath()}
		dts.write(launcherPrefs, "launcherprefs", true)
	end
end

function CardView.downButtonUp()
	if keyTimer ~= nil then
		keyTimer:remove()
		keyTimer = nil
	end
	
	local game = playdate.getCurrentGame()
	if gameList[selectedIndex] ~= nil and gameList[selectedIndex].state ~= nil and gameMove == nil then
		local launcherPrefs = {selectedGamePath = game:getPath()}
		dts.write(launcherPrefs, "launcherprefs", true)
	end
end

function CardView.cranked(change, accelChange)
	if math.abs(change) < 2 or not allowVerticalMove or playdate.buttonIsPressed("left") or playdate.buttonIsPressed("right") then
		local game = playdate.getCurrentGame()
		if gameList[selectedIndex].state ~= nil and gameMove == nil then
			local launcherPrefs = {selectedGamePath = game:getPath()}
			dts.write(launcherPrefs, "launcherprefs", true)
		end
		
		crankAccum = 0
		return
	end
	
	crankAccum = crankAccum + accelChange
	
	if crankAccum > 120 then
		if selectedIndex == #gameList and gameMove ~= nil and gameMove.index == nil and gameList[selectedIndex].state ~= nil then
			selectedIndex = selectedIndex + 1
			snd.playSystemSound(snd.kSoundSelectNext)
			
			if offYAnim ~= nil then
				offY = offYAnim.value
				offYAnim:remove()
			end
			offYAnim = tmr.new(100, offY, (selectedIndex - 1.5) * 200)
		elseif selectedIndex >= #gameList then
			jitter = inListView and -2 or -4
			
			if playdate.getCurrentTimeMilliseconds() > 500 then
				snd.playSystemSound(snd.kSoundDenial)
			end
		elseif playdate.getCurrentTimeMilliseconds() > 500 then
			selectedIndex = selectedIndex + 1
			snd.playSystemSound(snd.kSoundSelectNext)
			
			if inInfoView and gameList[selectedIndex] ~= nil then
				infoViewSprite:setImage(infoViewCard:copy())
				gfx.pushContext(infoViewSprite:getImage())
				gameList[selectedIndex]:drawInfoText()
				gfx.popContext()
				crankAccum = 0
				return
			end
			
			if inListView then
				local anchorStart, anchorEnd = (selectedIndex - 3 < 1), (selectedIndex + 3 > #gameList)
				local yTarget, textTarget
				
				if anchorStart or #gameList <= 5 then
					yTarget = selectedIndex * 36 - 32
					textTarget = 0
				elseif anchorEnd and #gameList > 5 then
					yTarget = 76 + (selectedIndex + 2 - #gameList) * 36 
					textTarget = (5 - #gameList) * 36
				else
					yTarget = 76
					textTarget = (3 - selectedIndex) * 36
				end
				
				local txtOffset = listViewTextOffset or 0
				local y = listViewY or 16
				
				listViewTextAnim = anm.new(100, geo.point.new(200, txtOffset), geo.point.new(200, textTarget), playdate.easingFunctions.outCubic)
				listViewTextSprite:setAnimator(listViewTextAnim)
				
				listViewYAnim = anm.new(100, geo.point.new(200, y), geo.point.new(200, yTarget), playdate.easingFunctions.outCubic)
			end
			
			if offYAnim ~= nil then
				offY = offYAnim.value
				offYAnim:remove()
			end
			if gameMove == nil or gameList[selectedIndex].state == nil then
				offYAnim = tmr.new(100, offY, (selectedIndex - 1) * 200, playdate.easingFunctions.outCubic)
			else
				offYAnim = tmr.new(100, offY, (selectedIndex - 1.5) * 200)
			end
			
			if animTimer ~= nil then
				animTimer:remove()
			end
			animTimer = tmr.new(75)
			onNextFrame = true
		end
		crankAccum = 0
	elseif crankAccum < -120 then
		if selectedIndex <= 1 then
			jitter = inListView and 2 or 4
			
			if playdate.getCurrentTimeMilliseconds() > 500 then
				snd.playSystemSound(snd.kSoundDenial)
			end
		elseif playdate.getCurrentTimeMilliseconds() > 500 then
			selectedIndex = selectedIndex - 1
			
			snd.playSystemSound(snd.kSoundSelectPrevious)
			
			if inInfoView and gameList[selectedIndex] ~= nil then
				infoViewSprite:setImage(infoViewCard:copy())
				gfx.pushContext(infoViewSprite:getImage())
				gameList[selectedIndex]:drawInfoText()
				gfx.popContext()
				crankAccum = 0
				return
			end
			
			if inListView then
				local anchorStart, anchorEnd = (selectedIndex - 3 < 1), (selectedIndex + 3 > #gameList)
				local yTarget, textTarget
				
				if anchorStart or #gameList <= 5 then
					yTarget = selectedIndex * 36 - 32
					textTarget = 0
				elseif anchorEnd and #gameList > 5 then
					yTarget = 76 + (selectedIndex + 2 - #gameList) * 36 
					textTarget = (5 - #gameList) * 36
				else
					yTarget = 76
					textTarget = (3 - selectedIndex) * 36
				end
				
				local txtOffset = listViewTextOffset or 0
				local y = listViewY or 16
				
				listViewTextAnim = anm.new(100, geo.point.new(200, txtOffset), geo.point.new(200, textTarget), playdate.easingFunctions.outCubic)
				listViewTextSprite:setAnimator(listViewTextAnim)
				
				listViewYAnim = anm.new(100, geo.point.new(200, y), geo.point.new(200, yTarget), playdate.easingFunctions.outCubic)
			end
			
			if offYAnim ~= nil then
				offY = offYAnim.value
				offYAnim:remove()
			end
			if gameMove == nil or gameList[selectedIndex].state == nil then
				offYAnim = tmr.new(100, offY, (selectedIndex - 1) * 200, playdate.easingFunctions.outCubic)
			else
				offYAnim = tmr.new(100, offY, (selectedIndex - 1.5) * 200)
			end
			
			if animTimer ~= nil then
				animTimer:remove()
			end
			animTimer = tmr.new(75)
			onNextFrame = true
		end
		crankAccum = 0
	end
end

function CardView:deinit()
	if keyTimer ~= nil then
		keyTimer:remove()
		keyTimer = nil
	end
	if offYAnim ~= nil then
		offYAnim:remove()
		offYAnim = nil
	end
	if animTimer ~= nil then
		animTimer:remove()
	end
	animTimer = tmr.new(75)
	
	prevIndex = selectedIndex
	loadAll(true)
	
	gfx.unlockFocus()
	
	self.gameList = gameList
end

function CardView:draw(shake)
	local buttons = {"A", "B", "up", "down", "left", "right"}
	for _, btn in ipairs(buttons) do
		if playdate.buttonJustReleased(btn) then
			if secretCombo[secretComboIndex] == btn then
				secretComboIndex = secretComboIndex + 1
				if secretComboIndex > #secretCombo then
					if infoViewTimer ~= nil then
						infoViewTimer.timerEndedCallback()
					end
					
					if inInfoView then
						CardView.BButtonUp()
					end
					if inListView then
						CardView.AButtonUp()
					end
					
					bottomBarSprite:setImageWithUpdate(barLogoImage)
					secretComboIndex = 1
					forceRefresh = SecretView
				end
			else
				secretComboIndex = 1
			end
		end
	end
	
	local newBatteryIndex = getBatteryIndex()
	if batteryTable ~= nil and batteryIndex ~= newBatteryIndex then
		batteryIndex = newBatteryIndex
		batterySprite:setImage(batteryTable[batteryIndex])
		batterySprite:markDirty()
	end
	
	if selectedIndex < 1 then
		selectedIndex = 1
	elseif (selectedIndex > #gameList and (gameMove == nil or prevViewGroup == currentFolder)) then
		selectedIndex = #gameList
	end
	
	local first = prefs.sortGamesBy == "Custom" and (launchAnim ~= nil or (delaunchAnim ~= nil and not delaunchAnim:ended()))
	
	if animTimer ~= nil and animTimer.currentTime >= animTimer.duration then
		onNextFrame = true
		
		animTimer:remove()
		animTimer = nil
	end
	
	if onNextFrame == true and first == false then
		loadAll(true)
		loadAll(false)
		prevIndex = selectedIndex
		onNextFrame = false
	elseif onNextFrame == true then
		prevIndex = selectedIndex
		onNextFrame = false
	end
	
	local cardImg, unlocked
	if gameList[selectedIndex] == nil then
		cardImg, unlocked = nil, true
	elseif gameMove == nil and not inListView then
		cardImg, unlocked = gameList[selectedIndex]:getCardImage(first)
		if gameList[selectedIndex].state == kGameStateUnwrapping then
			allowVerticalMove = unlocked
		end
	end
	
	if (gameMove == nil or gameMove.index == nil) and not inListView and not inInfoView then
		if gameList[selectedIndex - 1] ~= nil and gameList[selectedIndex - 1].state == kGameStateUnwrapping then
			gameList[selectedIndex - 1]:queueIdle()
			gameList[selectedIndex - 1].cardSprite:setImage(gameList[selectedIndex - 1].extraInfo.cardStill)
		end
		
		if gameList[selectedIndex + 1] ~= nil and gameList[selectedIndex + 1].state == kGameStateUnwrapping then
			gameList[selectedIndex + 1]:queueIdle()
			gameList[selectedIndex + 1].cardSprite:setImage(gameList[selectedIndex + 1].extraInfo.cardStill)
		end
		
		if gameList[selectedIndex] ~= nil and gameList[selectedIndex].cardSprite ~= nil then
			if animTimer ~= nil then
				gameList[selectedIndex].cardSprite:moveTo(200, 120)
				gameList[selectedIndex].cardSprite:moveBy(0, (selectedIndex - 1) * 200)
				gameList[selectedIndex].cardSprite:add()
			end
		end
	elseif not inListView and not inInfoView then
		local scrnIndex
		local scrnIndex2
		
		if selectedIndex < gameMove.index then
			scrnIndex = selectedIndex - 1
			scrnIndex2 = selectedIndex
		elseif selectedIndex > gameMove.index then
			scrnIndex = selectedIndex
			scrnIndex2 = selectedIndex + 1
		else
			scrnIndex = selectedIndex - 1
			scrnIndex2 = selectedIndex + 1
		end
		
		if gameList[scrnIndex] ~= nil and gameList[scrnIndex].state == kGameStateUnwrapping then
			gameList[scrnIndex]:queueIdle()
			gameList[scrnIndex].cardSprite:setImage(gameList[scrnIndex].extraInfo.cardStill)
		end
		
		if gameList[scrnIndex2] ~= nil and gameList[scrnIndex2].state == kGameStateUnwrapping then
			gameList[scrnIndex2]:queueIdle()
			gameList[scrnIndex2].cardSprite:setImage(gameList[scrnIndex2].extraInfo.cardStill)
		end
	end
	
	if cardImg ~= nil then
		if gameList[selectedIndex].data then
			if gameList[selectedIndex].data:getInstalledState() == gameList[selectedIndex].data.kPDGameStateFreshlyInstalled and gameList[selectedIndex]:shouldUnwrap() then
				gameList[selectedIndex].data:setInstalledState(gameList[selectedIndex].data.kPDGameStateInstalled)
				sys.clearLastGameDownloadPath()
				sys.saveGameList()
			end
		end
		
		if delaunchAnim ~= nil and not delaunchAnim:ended() and gameList[selectedIndex].id ~= "com.panic.launcher" then
			cardImg = cardImg:copy()
			gfx.pushContext(cardImg)
			gfx.setColor(gfx.kColorXOR)
			gfx.fillCircleAtPoint(175, 77, delaunchAnim:currentValue())
			gfx.popContext()
			
			gameList[selectedIndex].cardSprite:setImage(cardImg)
			gameList[selectedIndex].cardSprite:markDirty()
		elseif launchAnim ~= nil then
			lastLaunchAnimVal = launchAnim:currentValue()
			cardImg = cardImg:copy()
			gfx.pushContext(cardImg)
		
			gfx.setColor(gfx.kColorXOR)
			gfx.fillCircleAtPoint(175, 77, lastLaunchAnimVal)
		
			gfx.popContext()
			
			gameList[selectedIndex].cardSprite:setImage(cardImg)
			gameList[selectedIndex].cardSprite:markDirty()
		
			if gameMove == nil and launchAnim:ended() and prefs.sortGamesBy == "Custom" then
				local gameMoveImg = cardImg
				local oldMask = gameMoveImg:getMaskImage() or img.new(350, 155, gfx.kColorWhite)
				
				local gameMoveMask = img.new(350, 155)
				
				gfx.pushContext(gameMoveMask)
				gfx.setImageDrawMode(gfx.kDrawModeInverted)
				oldMask:draw(0, 0)
				gfx.popContext()
				
				local finalMoveImg = img.new(352, 160)
				
				gfx.pushContext(finalMoveImg)
				gfx.setImageDrawMode(gfx.kDrawModeWhiteTransparent)
				gameMoveMask:draw(2, 2)
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
				gameMoveImg:draw(0, 0)
				gfx.popContext()
				
				launchAnim = nil
				gameMove = Game()
				
				gameMove.path = gameList[selectedIndex].path
				gameMove.state = kGameStateIdle
				gameMove.cardSprite = spr.new(finalMoveImg)
				gameMove.cardSprite:moveTo(200, 114)
				gameMove.cardSprite:setZIndex(1000)
				gameMove.cardSprite:setIgnoresDrawOffset(true)
				gameMove.cardSprite:setClipRect(25, 43, 350, 155)
				gameMove.cardSprite:add()
				
				if folderName ~= "System" then
					gameMove.index = selectedIndex
					createEmptyFolder(folderName)
				end
				
				gameList[selectedIndex]:destroySprite()
				
				loadAll(true, prevIndex)
				loadAll(false, prevIndex)
				prevViewGroup = folderName
				
				if folderName == "System" then
					bottomBarSprite:setImageWithUpdate(barCancelImage)
					
					if gameList[selectedIndex] ~= nil and gameList[selectedIndex].cardSprite ~= nil then
						local image = gameList[selectedIndex]:getCardImage(true)
						gameList[selectedIndex].cardSprite:setImage(image)
						gameList[selectedIndex].cardSprite:markDirty()
					end
				else
					bottomBarSprite:setImageWithUpdate(barMoveImage)
				end
				
				moveStartSound:play()
				allowMoving = true
				allowVerticalMove = true
			end
		end
	end
	
	if gameList[selectedIndex].id == "com.panic.launcher" then
		gameList[selectedIndex]:getCardImage()
	end
	
	local offX = 0
	
	if gameMove ~= nil and folderName ~= "System" then
		offY = (selectedIndex - 1.5) * 200
	elseif gameList[selectedIndex] ~= nil and gameList[selectedIndex].state == kGameStateIdle or gameList[selectedIndex].state == nil then
		offY = (selectedIndex - 1) * 200
	end
	
	prevOffY = offY
	if offYAnim ~= nil and inListView == false then
		offY = offYAnim.value
		if offYAnim.currentTime >= offYAnim.duration then
			offYAnim:remove()
			offYAnim = nil
			allowVerticalMove = true
			allowMoving = true
		end
	end
	
	if offXAnim ~= nil then
		offX = offXAnim.value
		
		if offXAnim.currentTime >= offXAnim.duration then
			offXAnim:remove()
			offXAnim = nil
			allowVerticalMove = true
			allowMoving = true
		elseif allowVerticalMove == true then
			allowVerticalMove = false
			allowMoving = false
		end
	end
	
	if shakeBackForth ~= 0 then
		if shakeBackForth < 0 then
			shakeBackForth = -shakeBackForth
		elseif shakeBackForth > 0 then
			shakeBackForth = shakeBackForth - 1
			shakeBackForth = -shakeBackForth
		end
	elseif allowMoving == false then
		allowMoving = true
	end
	
	if unlocked == false or shakeBackForth ~= 0 or offXAnim ~= nil or offYAnim ~= nil or animTimer ~= nil or launchAnim ~= nil then
		allowMoving = false
	end
	
	if inListView then
		allowMoving = offXAnim == nil
	end
	
	gfx.setDrawOffset(inListView and 0 or offX + shake + shakeBackForth, -offY)
	
	if jitter ~= 0 then
		gfx.setDrawOffset(offX, -offY + jitter)
		if jitter < 0 then
			jitter = jitter + 1
		elseif jitter > 0 then
			jitter = jitter - 1
		end
		
		if listViewSprite ~= nil then
			listViewSprite.justAdded = true
		end
	end
	
	tmr.updateTimers()
	frt.updateTimers()
	
	local barYOffset = nil
	
	local frameNum, numFrames
	if gameList[selectedIndex] ~= nil then
		frameNum, numFrames = gameList[selectedIndex]:getLaunchParams()
	end
	
	if barAnim ~= nil then
		barYOffset = barAnim.value
		
		if barAnim.currentTime >= barAnim.duration then
			barAnim:remove()
			barAnim = nil
		end
	elseif frameNum ~= nil then
		barYOffset = -math.ceil(42 * (frameNum / 2))
	end
	
	if inInfoView and barAnim == nil then
		barYOffset = -84
	end
	if inListView and barAnim == nil then
		barYOffset = -84
	end
	
	if not inListView and not inInfoView and barAnim == nil and gameList[selectedIndex].state ~= kGameStateLaunching then
		barYOffset = 0
	end
	
	if not inListView and deleteFolderAnim ~= nil then
		local val = deleteFolderAnim.currentTime // 500
		local angle = math.rad(deleteFolderAnim.currentTime) * 1.5
		
		local s, c = math.sin(angle), math.cos(angle)
		local ns, nc = math.sin(-angle), math.cos(-angle)
		
		if inInfoView then
			bottomBarSprite:moveTo(200 + val * nc, 27 + val * ns)
			infoViewSprite:moveTo(200 + val * c, 27 + val * s)
		else
			bottomBarSprite:moveTo(200 + val * nc, 240 + val * ns)
		end
	end
	
	if barYOffset ~= nil and barYOffset ~= prevBarOffset then
		if not inListView then
			batterySprite:moveTo(384, 20 + barYOffset)
			topBarSprite:moveTo(200, barYOffset)
		end
		
		if not inInfoView then
			bottomBarSprite:moveTo(200, 240 - barYOffset)
		end
		
		prevBarOffset = barYOffset
	end
	
	spr.update()
	
	if inListView or listViewAnim ~= nil and not listViewAnim:ended() then
		local lower = 16
		local offX = 368
		
		if offXAnim ~= nil then
			offX = offXAnim.value * 0.92
			
			listViewYAnim = nil
			
			if offX < 0 then
				lower = 384 + offX
			end
		end
		
		local anchorStart, anchorEnd = (selectedIndex - 3 < 1), (selectedIndex + 3 > #gameList)
		if anchorStart or #gameList <= 5 then
			listViewY = selectedIndex * 36 - 32
			listViewTextOffset = 0
		elseif anchorEnd and #gameList > 5 then
			listViewY = 76 + (selectedIndex + 2 - #gameList) * 36 
			listViewTextOffset = (5 - #gameList) * 36
		else
			listViewY = 76
			listViewTextOffset = (3 - selectedIndex) * 36
		end
		
		local off = listViewY
		local oldOff = off
		
		if listViewYAnim ~= nil and not listViewYAnim:ended() then
			listViewY = listViewYAnim:currentValue().y
			off = listViewY
			oldOff = listViewTextOffset + 4
		end
		if listViewTimer ~= nil and listViewTimer.timeLeft >= 0 then
			off = listViewAnim:currentValue().y - 200 + listViewY
			oldOff = off
		end
		
		local x, y = gfx.getDrawOffset()
		
		local boundLow, boundHigh
		if anchorStart or #gameList <= 5 then
			boundLow = 1
			boundHigh = #gameList <= 5 and #gameList or 5
		elseif anchorEnd and #gameList > 5 then
			boundLow = #gameList - 5
			boundHigh = #gameList
		else
			boundLow = selectedIndex - 2
			boundHigh = selectedIndex + 2
		end
		
		if listViewTimer == nil and listViewTextAnim ~= nil then
			boundLow = boundLow - 1
			boundHigh = boundHigh + 1
		end
		
		gfx.setScreenClipRect(0, 0, 400, 196)
		
		for i = boundLow, boundHigh do
			if i >= 1 and i <= #gameList then
				local yo = (i - selectedIndex) * 36
				
				gfx.setDrawOffset(0, yo)
				local icon = gameList[i]:getIcon(i ~= selectedIndex)
				
				if i == selectedIndex and gameList[selectedIndex].state ~= nil then
					gfx.setColor(gfx.kColorXOR)
					gfx.fillRoundRect(lower, off - jitter, math.abs(offX), 38, 3)
					gfx.fillRoundRect(348, off - jitter + 2, 34, 34, 2)
				end
				
				if icon ~= nil then
					local offset = oldOff
					
					if oldOff == listViewTextOffset + 4 then
						gfx.setDrawOffset(0, (i - 1) * 36)
						offset = listViewTextAnim:currentValue().y + 4
					end
					icon:draw(349, offset + 3)
				elseif icon == nil and i == selectedIndex then
					defaultIconImg:draw(349, off - jitter + 3)
				end
			end
		end
		
		gfx.setDrawOffset(x, y)
	end
	
	if forceRefresh == -1 then
		CardView.BButtonUp()
		cooldown = true
	end
	
	return forceRefresh
end

function CardView.gameWillResume()
	if keyTimer ~= nil then
		keyTimer:remove()
		keyTimer = nil
	end
	
	if gameMove ~= nil and not playdate.buttonIsPressed("B") then
		CardView.BButtonUp()
	end
end

function playdate.getCurrentGame()
	if gameList ~= nil and gameList[selectedIndex] ~= nil then
		return type(gameList[selectedIndex].data) == "userdata" and gameList[selectedIndex].data or nil
	end
	
	return nil
end