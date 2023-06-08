import("CoreLibs/timer")
import("CoreLibs/frameTimer")
import("CoreLibs/graphics")
import("CoreLibs/object")
import("CoreLibs/sprites")

import("clock")

local aft = playdate.geometry.affineTransform
local dis = playdate.display
local dts = playdate.datastore
local fle = playdate.file
local frt = playdate.frameTimer
local flp = playdate.sound.fileplayer
local gfx = playdate.graphics
local img = playdate.graphics.image
local smp = playdate.sound.sampleplayer
local spr = playdate.graphics.sprite
local sys = playdate.system
local tmr = playdate.timer
local vid = playdate.graphics.video

kGameStateIdle = 1
kGameStatePressed = 2
kGameStateLaunching = 3
kGameStateAppearing = 4
kGameStateUnwrapping = 5

garbageTimer = nil

local frameCounter = 1

local launcherCardImg = img.new("images/launcher/launcherCard")
local launcherPressedImg = img.new("images/launcher/launcherPressed")
local launcherIconImg = img.new("images/launcher/launcherIcon")

local blackImg = img.new(400, 240, gfx.kColorBlack)
local emptyFolderImg = img.new("images/groupEmpty")
local emptyFolderIconImg = img.new("images/groupEmptyIcon")

local seasonIcons = fle.listFiles("images/icons/season1")

local launchImage
local newLaunchImage

local underlayVideo, underlayMaskVideo
local fadeOutVideo, fadeOutMaskVideo
local unwrapVideo, unwrapMaskVideo, unwrapLowerMaskVideo
local unwrapSound = smp.new("sounds/unwrap")

local patternWithRibbon = img.new(400, 240)

local patternMask = img.new(400, 240, gfx.kColorBlack)
local ribbon = img.new(400, 240, gfx.kColorBlack)
local ribbonMask = img.new(400, 240, gfx.kColorBlack)
local fadeOut = img.new(400, 240, gfx.kColorBlack)
local fadeOutMask = img.new(400, 240, gfx.kColorBlack)
local underlayMask = img.new(400, 240, gfx.kColorBlack)
local underlay = img.new(400, 240, gfx.kColorBlack)

local wrappedIcons = {
	img.new("images/icons/wrapped/1"),
	img.new("images/icons/wrapped/2"),
	img.new("images/icons/wrapped/3"),
	img.new("images/icons/wrapped/4")
}

local ribbonImg = img.new("images/wrapped")
local patternMaskImg = img.new("images/wrappedMask")

local defaultLaunchSound = flp.new("systemsfx/03-action-trimmed")

cardImagePool = table.create(50, 0)
iconImagePool = table.create(50, 0)

local endsWith = function(str, ending)
	return "" == ending or string.sub(str, -string.len(ending)) == ending
end

local startsWith = function(str, beginning)
	return "" == beginning or string.sub(str, 1, string.len(beginning)) == beginning
end

local parseAnimFile = function(animFile)
	if animFile == nil then
		return {loop = 0}
	end
	
	local info = {}
	local line = animFile:readline()
	local frames = {}
	local introFrames
	local addFramesToTable = function(frameTable, frameValues)
		for word in string.gmatch(frameValues, "%s*([^,]+)") do
			local r = 1
			local frame = tonumber(word)
			if frame == nil then
				frame, r = string.match(word, "(%d+) -x -(%d+)")
				if frame ~= nil then
					frame = tonumber(frame)
				end
				if r ~= nil then
					r = tonumber(r)
				end
			end
			if frame ~= nil and frame > 0 and r ~= nil and r > 0 then
				for i = 1, r do
					table.insert(frameTable, frame)
				end
			end
		end
	end
	
	while line ~= nil do
		local key, value = string.match(line, "%s*(.-)%s*=%s*(.+)")
		if key ~= nil and value ~= nil then
			key = key:lower()
			if "frames" == key then
				addFramesToTable(frames, value)
			elseif "introframes" == key then
				introFrames = {}
				addFramesToTable(introFrames, value)
			elseif "loopcount" == key then
				local count = tonumber(value)
				if count ~= nil and count > 0 then
					info.loop = count
				end
			end
			line = animFile:readline()
		end
	end
	
	if #frames > 0 then
		info.frames = frames
		info.introFrames = introFrames
	end
	
	info.loop = info.loop or 0
	
	return info
end

local tryLoad = function(path, image)
	local success, err
	if image ~= nil then
		success, err = image:load(path)
	else
		success = false
	end
	
	if success then
		return image
	else
		return img.new(path)
	end
end

local loadCardImage = function(self, imagePath, useDefault)
	local path = self.extraInfo.imagePath
	if useDefault then
		path = self.path
	end
	
	if imagePath ~= "" then
		path = path .. "/" .. imagePath
	end
	
	local cardImage = tryLoad(path, table.remove(cardImagePool))
	if cardImage ~= nil then
		return true, cardImage
	else
		if self.extraInfo.imagePath ~= nil then
			cardImage = tryLoad(self.extraInfo.imagePath .. "/card", table.remove(cardImagePool))
		end
		if cardImage == nil then
			cardImage = tryLoad(self.path .. "/card", table.remove(cardImagePool))
		end
		if cardImage == nil then
			cardImage = self:getDummyCard(350, 155)
		end
		
		return false, cardImage
	end
end

local loadIcon = function(self, imagePath, useDefault)
	local path = self.extraInfo.imagePath
	if useDefault then
		path = self.path
	end
	
	if imagePath ~= "" then
		path = path .. "/" .. imagePath
	end
	
	local w, h = gfx.imageSizeAtPath(path)
	
	w = math.floor(w or 32)
	h = math.floor(h or 32)
	
	local cardImage = tryLoad(path, table.remove(iconImagePool))
	if cardImage ~= nil then
		return true, cardImage
	else
		if self.extraInfo.imagePath ~= nil then
			cardImage = tryLoad(self.extraInfo.imagePath .. "/icon", table.remove(iconImagePool))
		end
		if cardImage == nil then
			cardImage = tryLoad(self.path .. "/icon", table.remove(iconImagePool))
		end
		
		return false, cardImage
	end
end

local loadPresentAnims = function()
	underlayVideo = vid.new("videos/unwrap/underlay")
	underlayMaskVideo = vid.new("videos/unwrap/underlayMask")
	
	fadeOutVideo = vid.new("videos/unwrap/fadeOut")
	fadeOutMaskVideo = vid.new("videos/unwrap/fadeOutMask")
	
	unwrapVideo = vid.new("videos/unwrap/unwrap")
		
	unwrapMaskVideo = vid.new("videos/unwrap/unwrapMask")
	unwrapLowerMaskVideo = vid.new("videos/unwrap/unwrapLowerMask")
end

function unloadPresentAnims()
	underlayVideo = nil
	underlayMaskVideo = nil
	fadeOutVideo = nil
	fadeOutMaskVideo = nil
	unwrapVideo = nil
	unwrapMaskVideo = nil
	unwrapLowerMaskVideo = nil
	collectgarbage()
end

class("Game").extends()

function Game:init(game)
	if unwrapVideo == nil then
		loadPresentAnims()
	end
	
	self.extraInfo = {}
	
	if game ~= nil then
		self.data = game
		
		self.state = kGameStateIdle
	
		self.title = self.data:getTitle() or "(No title)"
		self.author = self.data:getStudio() or "(Unknown)"
		self.version = self.data:getVersion()
		self.id = self.data:getBundleID() or "(No bundle ID)"
		self.path = self.data:getPath()
		
		self.looping = true
		self:refreshMetadata()
		
		if self.extraInfo.launchSoundPath ~= nil then
			self.launchSound = flp.new(self.extraInfo.launchSoundPath) or defaultLaunchSound
		end
		
		self.wrappingPattern = self:getWrappingPattern()
		
		if self.id == "com.panic.launcher" then
			self.extraInfo.cardStill = launcherCardImg
			self:createSprite()
			return
		end
		
		local useDefault = self.extraInfo.imagePath == nil or not fle.isdir(self.extraInfo.imagePath)
		
		if self.extraInfo.cardStill == nil then
			local _, image
			
			if self.extraInfo.imagePath ~= nil and useDefault then
				_, image = loadCardImage(self, "", false)
			else
				_, image = loadCardImage(self, "card", useDefault)
			end
			
			self.extraInfo.cardStill = image
		end
		
		self:createSprite()
		
		self.extraInfo.animated = fle.exists((self.extraInfo.imagePath or self.path) .. "/card-highlighted/")
		
		if self.extraInfo.animated then
			self.extraInfo.cardImage = {}
			
			if self.extraInfo.cardAnimation == nil then
				local animFile = fle.open((self.extraInfo.imagePath or self.path) .. "/card-highlighted/animation.txt")
				self.extraInfo.cardAnimation = parseAnimFile(animFile)
				if animFile ~= nil then
					animFile:close()
				end
			end
			
			if self.extraInfo.cardAnimation.frames == nil then
				local animImage = self.extraInfo.imagePath or self.path
				if endsWith(animImage, "/") then
					animImage = string.sub(animImage, -2)
				end
				
				local files = fle.listFiles(animImage .. "/card-highlighted/")
				
				for i, file in ipairs(files) do
					table.insert(self.extraInfo.cardImage, "card-highlighted/" .. tostring(i) .. ".pdi")
				end
				
				self:enterFrame(1)
			else
				local frameNums = {}
				local index = 1
				
				while index <= #self.extraInfo.cardAnimation.frames do
					local frameNum = self.extraInfo.cardAnimation.frames[index]
					
					local animImage = self.extraInfo.imagePath or self.path
					if endsWith(animImage, "/") then
						animImage = string.sub(animImage, -2)
					end
					
					animImage = animImage .. "/card-highlighted/" .. tostring(frameNum) .. ".pdi"
					table.insert(self.extraInfo.cardImage, "card-highlighted/" .. tostring(frameNum) .. ".pdi")
					
					index = index + 1
				end
				
				self:enterFrame(self.extraInfo.cardAnimation.frames[1])
			end
		else
			self.extraInfo.cardImage = self.extraInfo.cardStill
		end
		
		local _, icon = loadIcon(self, "icon", useDefault)
		self.extraInfo.iconStill = icon
		
		if fle.exists((self.extraInfo.imagePath or self.path) .. "/icon-highlighted/") then
			self.extraInfo.iconImage = {}
			
			if self.extraInfo.iconAnimation == nil then
				local animImage = self.extraInfo.imagePath or self.path
				if endsWith(animImage, "/") then
					animImage = string.sub(animImage, -2)
				end
				
				local animFile = fle.open(animImage .. "/icon-highlighted/animation.txt")
				self.extraInfo.iconAnimation = parseAnimFile(animFile)
				if animFile ~= nil then
					animFile:close()
				end
			end
			
			if self.extraInfo.iconAnimation.frames == nil then
				local animImage = self.extraInfo.imagePath or self.path
				if endsWith(animImage, "/") then
					animImage = string.sub(animImage, -2)
				end
				
				local files = fle.listFiles(animImage .. "/icon-highlighted/")
				
				for i, file in ipairs(files) do
					table.insert(self.extraInfo.iconImage, "icon-highlighted/" .. tostring(i) .. ".pdi")
				end
				
				self:enterIcon(1)
			else
				local frameNums = {}
				local index = 1
				
				while index <= #self.extraInfo.iconAnimation.frames do
					local frameNum = self.extraInfo.iconAnimation.frames[index]
					
					local animImage = self.extraInfo.imagePath or self.path
					if endsWith(animImage, "/") then
						animImage = string.sub(animImage, -2)
					end
					
					animImage = animImage .. "/icon-highlighted/" .. tostring(frameNum) .. ".pdi"
					table.insert(self.extraInfo.iconImage, "icon-highlighted/" .. tostring(frameNum) .. ".pdi")
					
					index = index + 1
				end
				
				self:enterIcon(self.extraInfo.iconAnimation.frames[1])
			end
		elseif fle.exists("images/icons/season1/" .. self.id .. ".pdi") then
			self.extraInfo.iconStill = img.new("images/icons/season1/" .. self.id)
			self.extraInfo.iconImage = self.extraInfo.iconStill
		else
			self.extraInfo.iconImage = self.extraInfo.iconStill
		end
		
		self.frameIndex = 0
		self.loopCount = 0
	else
		self.extraInfo.cardStill = emptyFolderImg
		self.extraInfo.iconStill = emptyFolderIconImg
		self:createSprite()
	end
end

function Game:refreshMetadata()
	local metadata = sys.getMetadata(self.path .. "/pdxinfo")
	self.extraInfo = {}
		
	if metadata ~= nil then
		if metadata.imagePath ~= nil and metadata.imagePath ~= "" and fle.isdir(self.path .. "/" .. metadata.imagePath) then
			self.extraInfo.hasCardImage = true
			
			if startsWith(metadata.imagePath, "/") then
				metadata.imagePath = string.sub(metadata.imagePath, 2)
			end
			if endsWith(metadata.imagePath, "/") then
				metadata.imagePath = string.sub(metadata.imagePath, 1, -2)
			end
			self.extraInfo.imagePath = self.path .. "/" .. metadata.imagePath
			if endsWith(self.extraInfo.imagePath, ".png") then
				self.extraInfo.imagePath = self.extraInfo.imagePath:sub(1, -5)
			end
		end
		
		if metadata.launchSoundPath ~= nil and metadata.launchSoundPath ~= "" then
			if startsWith(metadata.launchSoundPath, "/") then
				metadata.launchSoundPath = string.sub(metadata.launchSoundPath, 2)
			end
			
			if string.sub(metadata.launchSoundPath, -4, -4) == "." then
				metadata.launchSoundPath = string.sub(metadata.launchSoundPath, 1, -5)
			end
			self.extraInfo.launchSoundPath = self.path .. "/" .. metadata.launchSoundPath
		else
			self.extraInfo.launchSoundPath = "systemsfx/03-action-trimmed"
		end
		
		self.extraInfo.pdxversion = metadata.pdxversion
		self.extraInfo.description = metadata.description or "No description provided."
		self.extraInfo.contentWarning = metadata.contentWarning
		self.extraInfo.contentWarning2 = metadata.contentWarning2
	else
		self.extraInfo.hasCardImage = false
		self.extraInfo.cardAnimation = {}
		self.extraInfo.description = "No description provided."
	end
	
	self.extraInfo = self.extraInfo
end

function Game:queueAppear()
	if self.state ~= nil then
		frameCounter = 1
		self.state = kGameStateAppearing
	end
end

function Game:queueUnwrap(index)
	if self.state ~= nil then
		if self.halfFrameTimer ~= nil then
			self.halfFrameTimer:remove()
			self.halfFrameTimer = nil
		end
		
		frameCounter = 1
		self.frameIndex = 1
		self.state = kGameStateUnwrapping
		
		unwrapSound:stop()
		unwrapSound:play()
	end
end

function Game:press()
	if self.state ~= nil then
		if self.halfFrameTimer ~= nil then
			self.halfFrameTimer:remove()
			self.halfFrameTimer = nil
		end
		self.state = kGameStatePressed
		
		local _, image = loadCardImage(self, "card-pressed", self.extraInfo.imagePath == nil)
		self.extraInfo.tilePressedImage = image
	end
end

function Game:queueLaunch()
	if self.state ~= nil then
		if self.halfFrameTimer ~= nil then
			self.halfFrameTimer:remove()
			self.halfFrameTimer = nil
		end
		self.frameIndex = 1
		
		self:loadLaunchImages()
		self.state = kGameStateLaunching
		self.launchSound:play()
	end
end

function Game:queueIdle()
	if self.state ~= nil then
		if self.halfFrameTimer ~= nil then
			self.halfFrameTimer:remove()
			self.halfFrameTimer = nil
		end
		
		self.frameIndex = 1
		self.loopCount = 0
		self.looping = true
		self.state = kGameStateIdle
	end
end

function Game:getDummyCard(w, h)
	local cardImg = self.dummyCard or img.new(w, h, gfx.kColorClear)
	
	gfx.pushContext(cardImg)

	gfx.setColor(gfx.kColorBlack)
	gfx.fillRoundRect(0, 0, w, h, 4)
	gfx.setImageDrawMode(gfx.kDrawModeInverted)

	local title = self.title
	local titleFont
	if gfx.getLargeUIFont ~= nil then
		titleFont = gfx.getLargeUIFont()
	end

	if title ~= nil then
		local height = titleFont:getHeight()
		gfx.drawTextInRect(title, 10, (h - height) / 2, w - 20, height, 0, "…", kTextAlignment.center, titleFont)
	end
	
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	gfx.popContext()
	
	self.dummyCard = cardImg
	return cardImg
end

function Game:leaveIcon()
	if self.data:getInstalledState() ~= self.data.kPDGameStateFreshlyInstalled then
		table.insert(iconImagePool, self.currentIcon)
	end
	
	self.currentIcon = self.extraInfo.iconStill
end

function Game:enterIcon(frameNum)
	if self.data:getInstalledState() == self.data.kPDGameStateFreshlyInstalled then
		self.currentIcon = wrappedIcons[frameNum]
	else
		local useDefault = self.extraInfo.imagePath == nil
		local _, image = loadIcon(self, "icon-highlighted/" .. tostring(frameNum), useDefault)
		self.currentIcon = image
	end
end

function Game:getIcon()
	if self.id == "com.panic.launcher" then
		return launcherIconImg
	end
	
	if self.extraInfo.iconAnimation == nil and self.data:getInstalledState() ~= self.data.kPDGameStateFreshlyInstalled then
		return self.extraInfo.iconStill
	end
	
	local numFrames, loop
	
	if self.data:getInstalledState() == self.data.kPDGameStateFreshlyInstalled then
		numFrames = #wrappedIcons
		loop = 0
	else
		numFrames = #self.extraInfo.iconImage
		loop = self.extraInfo.iconAnimation.loop
	end
	
	if self.data:getInstalledState() ~= self.data.kPDGameStateFreshlyInstalled and self.looping and self.extraInfo.iconAnimation.frames ~= nil and self.halfFrameTimer == nil then
		self.halfFrameTimer = frt.new(1)
		self.halfFrameTimer.timerEndedCallback = function()
			self:leaveIcon()
			
			self.frameIndex = self.frameIndex + 1
			local cycleDone = self.frameIndex > #self.extraInfo.iconImage
			
			if cycleDone then
				self.loopCount = self.loopCount + 1
				self.frameIndex = 1
				
				if self.extraInfo.iconAnimation.loop ~= 0 and self.loopCount >= self.extraInfo.iconAnimation.loop then
					self.looping = false
					self.frameIndex = #self.extraInfo.iconImage
					self:enterIcon(self.extraInfo.iconAnimation.frames[self.frameIndex])
					
					if self.halfFrameTimer ~= nil then
						self.halfFrameTimer:remove()
						self.halfFrameTimer = nil
					end
					return
				end
			end
			
			self:enterIcon(self.extraInfo.iconAnimation.frames[self.frameIndex])
		end
		
		self.halfFrameTimer.discardOnCompletion = false
		self.halfFrameTimer.repeats = true
	elseif self.looping and self.halfFrameTimer == nil then
		self.halfFrameTimer = tmr.new(self.data:getInstalledState() == self.data.kPDGameStateFreshlyInstalled and 100 or 25)
		self.halfFrameTimer.timerEndedCallback = function()
			self:leaveIcon()
			
			self.frameIndex = self.frameIndex + 1
			local cycleDone = self.frameIndex > numFrames
			
			if cycleDone then
				self.loopCount = self.loopCount + 1
				self.frameIndex = 1
			
				if loop ~= 0 and self.loopCount >= loop then
					self.looping = false
					self.frameIndex = numFrames
					self:enterIcon(self.frameIndex)
					
					if self.halfFrameTimer ~= nil then
						self.halfFrameTimer:remove()
						self.halfFrameTimer = nil
					end
					return
				end
			end
			
			self:enterIcon(self.frameIndex)
		end
		
		self.halfFrameTimer.discardOnCompletion = false
		self.halfFrameTimer.repeats = true
	end
	
	return self.currentIcon
end

function Game:getCardImage(static)
	if self.state == nil then
		self.cardSprite:setImage(emptyFolderImg)
		return emptyFolderImg, true
	end
	
	if self.id == "com.panic.launcher" then
		if self.state == kGameStatePressed then
			self.cardSprite:setImage(launcherPressedImg)
			return launcherPressedImg, true
		else
			self.cardSprite:setImage(launcherCardImg)
			return launcherCardImg, true
		end
	end
	
	if not self.loaded then
		self.cardSprite:setImage(self.extraInfo.cardStill)
		return self.extraInfo.cardStill, true
	end
	
	if static == true then
		if self.halfFrameTimer ~= nil then
			self.halfFrameTimer:remove()
			self.halfFrameTimer = nil
		end
		
		local firstCardImage
		
		if self.extraInfo.animated and self.extraInfo.cardAnimation.frames ~= nil then
			self:leaveFrame()
			self:enterFrame(self.extraInfo.cardAnimation.frames[#self.extraInfo.cardAnimation.frames])
			firstCardImage = self.currentCard
		elseif self.extraInfo.animated then
			self:leaveFrame()
			self:enterFrame(#self.extraInfo.cardImage)
			firstCardImage = self.currentCard
		elseif not self.extraInfo.animated then
			firstCardImage = self.extraInfo.cardImage
		end
		
		return firstCardImage, true
	end
	
	if self.data:getInstalledState() == self.data.kPDGameStateFreshlyInstalled or self.state == kGameStateUnwrapping or self.state == kGameStateAppearing then
		if self.halfFrameTimer ~= nil then
			self.halfFrameTimer:remove()
			self.halfFrameTimer = nil
		end
		
		local setStencil = function(image)
			if image ~= nil then
				gfx.setStencilImage(image)
			else
				local clearStencil = gfx.clearStencil or gfx.clearStencilImage
				clearStencil()
			end
		end
		
		local renderVideoFrame = function(video, frameNum, image)
			
			if video:getContext() ~= image then
				image:clear(gfx.kColorBlack)
				video:setContext(image)
			end
			
			if frameNum <= video:getFrameCount() then
				video:renderFrame(frameNum)
			end
		end
		
		local pattern = self.wrappingPattern
		local redraw = true
		local canSwitch = true
		
		setStencil(nil)
		
		if self.state == kGameStateIdle then
			patternWithRibbon:clear(gfx.kColorClear)
			gfx.pushContext(patternWithRibbon)
			
			ribbon = ribbonImg:copy()
			patternMask = patternMaskImg:copy()
			ribbonMask:clear(gfx.kColorWhite)
			
		elseif self.state == kGameStateAppearing then
			frameCounter = math.floor(unwrapSound:getOffset() * appearVideo:getFrameRate()) + 1
			
			renderVideoFrame(appearLowerMaskVideo, frameCounter, ribbonMask)
			renderVideoFrame(appearVideo, frameCounter, ribbon)
			
			renderVideoFrame(appearMaskVideo, frameCounter, patternMask)
			
			canSwitch = frameCounter > 27
			
			if frameCounter >= appearVideo:getFrameCount() then
				self:queueIdle()
			end
			
			patternWithRibbon:clear(gfx.kColorClear)
			gfx.pushContext(patternWithRibbon)
		elseif self.state == kGameStateUnwrapping then
			local unwrapFrame = math.floor(unwrapSound:getOffset() * 20) + 1
			
			redraw = frameCounter ~= unwrapFrame
			
			if redraw then
				frameCounter = math.floor(unwrapSound:getOffset() * 20) + 1
				
				renderVideoFrame(fadeOutMaskVideo, frameCounter, fadeOutMask)
				renderVideoFrame(fadeOutVideo, frameCounter, fadeOut)
				renderVideoFrame(underlayMaskVideo, frameCounter, underlayMask)
				renderVideoFrame(underlayVideo, frameCounter, underlay)
				
				renderVideoFrame(unwrapLowerMaskVideo, frameCounter, ribbonMask)
				renderVideoFrame(unwrapVideo, frameCounter, ribbon)
				
				renderVideoFrame(unwrapMaskVideo, frameCounter, patternMask)
				
				canSwitch = frameCounter > 59
				
				if frameCounter >= unwrapVideo:getFrameCount() then
					self:queueIdle()
				end
				
				gfx.pushContext(patternWithRibbon)
				gfx.clear(gfx.kColorClear)
				
				self.extraInfo.cardStill:drawAnchored(200, 119, 0.5, 0.5)
				
				setStencil(fadeOutMask)
				fadeOut:draw(0, 0)
				
				setStencil(underlayMask)
				underlay:draw(0, 0)
			end
		end
		
		if redraw then
			setStencil(ribbonMask)
			ribbon:draw(0, 0)
			
			setStencil(patternMask)
			pattern:draw(0, 0)
			
			setStencil(nil)
			gfx.popContext()
		end
		
		self.cardSprite:setImage(patternWithRibbon)
		
		return patternWithRibbon, canSwitch
	else
		if self.state == kGameStateIdle then
			if self.extraInfo.animated and self.looping == true then
				if self.extraInfo.cardAnimation.frames ~= nil then
					if self.halfFrameTimer == nil then
						self.halfFrameTimer = frt.new(1)
						self.halfFrameTimer.timerEndedCallback = function()
							self:leaveFrame()
							
							self.frameIndex = self.frameIndex + 1
							local cycleDone = self.frameIndex > #self.extraInfo.cardAnimation.frames
							
							if cycleDone then
								self.loopCount = self.loopCount + 1
								self.frameIndex = 1
								
								if self.extraInfo.cardAnimation.loop ~= 0 and self.loopCount >= self.extraInfo.cardAnimation.loop then
									self.looping = false
									self.frameIndex = #self.extraInfo.cardAnimation.frames
									
									if self.halfFrameTimer ~= nil then
										self.halfFrameTimer:remove()
										self.halfFrameTimer = nil
									end
									return
								end
							end
							
							self:enterFrame(self.extraInfo.cardAnimation.frames[self.frameIndex])
						end
					
						self.halfFrameTimer.discardOnCompletion = false
						self.halfFrameTimer.repeats = true
					end
					return self.currentCard, true
				else
					if self.halfFrameTimer == nil then
						self.halfFrameTimer = frt.new(1)
						self.halfFrameTimer.timerEndedCallback = function()
							self:leaveFrame()
							
							self.frameIndex = self.frameIndex + 1
							
							local cycleDone = self.frameIndex > #self.extraInfo.cardImage
							
							if cycleDone then
								self.loopCount = self.loopCount + 1
								self.frameIndex = 1
							
								if self.extraInfo.cardAnimation.loop ~= 0 and self.loopCount >= self.extraInfo.cardAnimation.loop then
									self.looping = false
									self.frameIndex = #self.extraInfo.cardImage
									
									if self.halfFrameTimer ~= nil then
										self.halfFrameTimer:remove()
										self.halfFrameTimer = nil
									end
									return
								end
							end
							
							self:enterFrame(self.frameIndex)
						end
						
						self.halfFrameTimer.discardOnCompletion = false
						self.halfFrameTimer.repeats = true
					end
					return self.currentCard, true
				end
			elseif not self.extraInfo.animated then
				self.cardSprite:setImage(self.extraInfo.cardImage)
				return self.extraInfo.cardImage, true
			end
		elseif self.state == kGameStatePressed then
			if self.extraInfo.tilePressedImage == nil then
				local firstCardImage
				if self.extraInfo.animated and self.extraInfo.cardAnimation.frames ~= nil then
					firstCardImage = self.extraInfo.cardImage[self.extraInfo.cardAnimation.frames[#self.extraInfo.cardAnimation.frames]]
				elseif self.extraInfo.animated then
					firstCardImage = self.extraInfo.cardImage[#self.extraInfo.cardImage]
				elseif not self.extraInfo.animated then
					firstCardImage = self.extraInfo.cardImage
				end
				
				self.cardSprite:setImage(firstCardImage)
				self.cardSprite:markDirty()
				
				return firstCardImage, true
			end
			self.cardSprite:setImage(self.extraInfo.tilePressedImage)
			
			return self.extraInfo.tilePressedImage, true
		elseif self.state == kGameStateLaunching then
			if #self.extraInfo.launchImage > 1 then
				if self.halfFrameTimer == nil then
					sys.setLaunchAnimationActive(true)
					self.halfFrameTimer = frt.new(1)
					self.halfFrameTimer.timerEndedCallback = function()
						if not self.loaded then
							return
						end
						
						self:leaveFrame()
						self.frameIndex = self.frameIndex + 1
						
						if self.frameIndex > #self.extraInfo.launchImage then
							dts.write(prefs, "/Data/Index OS/prefs", true)
							dts.write(folderPrefs, "Index OS/folderSettings", true)
							
							sys.setLaunchAnimationActive(false)
							sys.switchToGame(self.path)
						else
							self:enterLaunchFrame(self.frameIndex)
						end
					end
					self.halfFrameTimer.discardOnCompletion = false
					self.halfFrameTimer.repeats = true
				end
				
				launchImage = self.currentCard
			elseif #self.extraInfo.launchImage == 1 then
				if self.halfFrameTimer == nil then
					sys.setLaunchAnimationActive(true)
					self.halfFrameTimer = tmr.new(150, function()
						dts.write(prefs, "/Data/Index OS/prefs", true)
						dts.write(folderPrefs, "Index OS/folderSettings", true)
						sys.setLaunchAnimationActive(false)
						sys.switchToGame(self.path)
					end)
					
					self:enterLaunchFrame(1)
					
					launchImage = self.currentCard:copy()
					local w, h = launchImage:getSize()
					displayImg = img.new(400, 240)
				end
				
				local newLaunchImage
				local w, h = launchImage:getSize()
				local alpha = self.halfFrameTimer.currentTime / 100
				
				if alpha < 1 then
					newLaunchImage = displayImg:copy()
					gfx.pushContext(newLaunchImage)
					blackImg:drawFaded(0, 0, alpha, img.kDitherTypeBayer4x4)
					gfx.popContext()
				else
					newLaunchImage = launchImage
				end
				
				self.cardSprite:setImage(newLaunchImage)
			else
				if self.halfFrameTimer == nil then
					sys.setLaunchAnimationActive(true)
					self.halfFrameTimer = tmr.new(100, function()
						dts.write(prefs, "/Data/Index OS/prefs", true)
						dts.write(folderPrefs, "Index OS/folderSettings", true)
						sys.setLaunchAnimationActive(false)
						sys.switchToGame(self.path)
					end)
					
					self:enterLaunchFrame(1)
					
					launchImage = self.currentCard:copy()
					local w, h = launchImage:getSize()
					displayImg = img.new(400, 240)
				end
				
				local newLaunchImage
				local w, h = launchImage:getSize()
				local alpha = self.halfFrameTimer.currentTime / 80
				
				newLaunchImage = displayImg:copy()
				gfx.pushContext(newLaunchImage)
				blackImg:drawFaded(0, 0, alpha, img.kDitherTypeBayer4x4)
				gfx.popContext()
				
				self.cardSprite:setImage(newLaunchImage)
			end
			
			return launchImage, false
		end
	end
end

function Game:createSprite()
	if self.cardSprite == nil then
		local cardSprite = spr.new()
		
		if self.id == "com.panic.clock" then
			cardSprite:setImage(renderClockImage(350, 155))
			cardSprite.update = function(self)
				if clockNeedsUpdate() then
					local w, h = self:getSize()
					self:setImage(renderClockImage(w, h))
				end
			end
		else
			local cardImg = self.extraInfo.cardStill
			cardSprite:setImage(cardImg)
		end
		
		cardSprite:setZIndex(300)
		
		self.cardSprite = cardSprite
	end
end

function Game:destroySprite()
	if not self.loaded then
		return
	end
	
	if self.cardSprite ~= nil and self.cardSprite.x ~= 0 or self.cardSprite.y ~= 0 then
		self.cardSprite:remove()
		self.cardSprite:moveTo(0, 0)
	end
	
	if self.halfFrameTimer ~= nil then
		self.halfFrameTimer:remove()
		self.halfFrameTimer = nil
	end
	
	self.loaded = false
end

function Game:loadCardImages()
	if self.loaded == true then
		return
	end
	
	if self.state == nil then
		if self.cardSprite == nil then
			self.cardSprite = spr.new(emptyFolderImg)
		end
	end
	
	self.cardSprite:moveTo(200, 120)
	self.cardSprite:setZIndex(300)
	self.cardSprite:add()
	self.loaded = true
end

function Game:leaveFrame()
	table.insert(cardImagePool, self.currentCard)
	self.currentCard = self.cardStill
end

function Game:enterFrame(frameNum)
	local useDefault = self.extraInfo.imagePath == nil
	local _, image = loadCardImage(self, "card-highlighted/" .. tostring(frameNum), useDefault)
	
	local w, h = image:getSize()
	if (w ~= 350 or h ~= 155) and self.id ~= "com.panic.launcher" then
		local mask = image:getMaskImage() or img.new(400, 240, gfx.kColorWhite)
		gfx.pushContext(mask)
		gfx.setColor(gfx.kColorBlack)
		gfx.fillRect(0, 0, 24, 240)
		gfx.fillRect(375, 0, 24, 240)
		gfx.fillRect(24, 0, 42, 350)
		gfx.fillRect(24, 197, 42, 350)
		gfx.popContext()
		image:setMaskImage(mask)
	end
	
	self.currentCard = image
	self.cardSprite:setImage(self.currentCard)
	self.cardSprite:markDirty()
end

function Game:enterLaunchFrame(frameNum)
	local image
	
	if self.extraInfo.launchImage[frameNum] ~= nil then
		useDefault = self.extraInfo.imagePath == nil
		_, image = loadCardImage(self, self.extraInfo.launchImage[frameNum], useDefault)
	else
		image = self.cardSprite:getImage()
	end

	self.currentCard = image 
	self.cardSprite:setImage(self.currentCard)
	self.cardSprite:markDirty()
end

function Game:loadLaunchImages()
	if self.extraInfo.launchImage ~= nil then
		return
	end
	
	local useDefault = self.extraInfo.imagePath == nil
	self.extraInfo.launchImage = {}
	
	local launchAnimated = fle.exists((self.extraInfo.imagePath or self.path) .. "/launchImages")
	
	local animImage = self.extraInfo.imagePath or self.path
	if endsWith(animImage, "/") then
		animImage = string.sub(animImage, -2)
	end
	
	if launchAnimated then
		local files = fle.listFiles(animImage .. "/launchImages/")
		for i, file in ipairs(files) do
			table.insert(self.extraInfo.launchImage, "launchImages/" .. tostring(i) .. ".pdi")
		end
	end
	
	animImage = animImage .. "/launchImage.pdi"
	if fle.exists(animImage) then
		table.insert(self.extraInfo.launchImage, "launchImage.pdi")
	end
end

function Game:shouldUnwrap()
	return self.state == kGameStateUnwrapping and frameCounter == 60
end

function Game:getLaunchParams()
	if self.state == kGameStateLaunching then
		return self.frameIndex, #self.extraInfo.launchImage
	end
end

function Game:getTitle()
	if self.state == nil then
		return "Empty Folder"
	elseif self.data:getInstalledState() == self.data.kPDGameStateFreshlyInstalled then
		return "???"
	else
		return self.title
	end
end

function Game:getStudio()
	if self.state == nil then
		return "(none)"
	elseif self.data:getInstalledState() == self.data.kPDGameStateFreshlyInstalled then
		return "???"
	else
		return self.author
	end
end

function Game:getPath()
	return self.path
end

function Game:drawInfoText()
	gfx.setFont(normalFont)
	
	if self.state == nil then
		local escapedTitle = "*" .. getCurrentFolderName():gsub("*", "**"):gsub("_", "__") .. "*\nEmpty Group"
		local escapedDescription = "Pick something up and move it over here!"
		gfx.drawTextInRect(escapedTitle, 8, 2, 384, 44)
		gfx.drawTextInRect(escapedDescription, 8, 55, 384, 110)
	elseif self.data:getInstalledState() == self.data.kPDGameStateFreshlyInstalled then
		local escapedTitle = "*???*\nby *???*"
		local escapedDescription = "Unwrap this game to see its details!"
		
		gfx.drawTextInRect(escapedTitle, 8, 2, 384, 44)
		gfx.drawTextInRect(escapedDescription, 8, 55, 384, 110)
	else
		local escapedTitle = "*" .. self.title:gsub("*", "**"):gsub("_", "__") .. "*\nby *" .. self.author:gsub("*", "**"):gsub("_", "__") .. "*"
		local escapedDescription = self.extraInfo.description:gsub("*", "**"):gsub("_", "__")
	
		local versionText
		if self.version == nil or self.version == "" then
			versionText = "No version\n" .. self.id
		else
			versionText = "v" .. self.version .. "\n" .. self.id
		end
		
		gfx.drawTextInRect(escapedTitle, 8, 2, 384, 44)
		gfx.drawTextInRect(escapedDescription, 8, 55, 384, 110)
		gfx.drawTextInRect(versionText, 8, 168, 384, 44, nil, "...", kTextAlignment.right)
	end
end

function Game:unloadCardImages()
	self:destroySprite()
	
	if not self.loaded then
		return
	end
	
	self.extraInfo.cardImage = nil
	
	if self.currentCard ~= nil then
		table.insert(cardImagePool, self.currentCard)
	end
	
	if self.extraInfo.tilePressedImage ~= nil then
		table.insert(cardImagePool, self.extraInfo.tilePressedImage)
		self.extraInfo.tilePressedImage = nil
	end
	self.extraInfo.launchImage = nil
	
	if self.dummyCard ~= nil then
		table.insert(cardImagePool, self.dummyCard)
		self.dummyCard = nil
	end
	
	if self.currentIcon ~= nil then
		table.insert(iconImagePool, self.currentIcon)
	end
end

function Game:getWrappingPattern()
	local pattern
	
	if nil ~= self.extraInfo.imagePath then
		local imagePath = self.extraInfo.imagePath .. "/wrapping-pattern"
		pattern = img.new(imagePath)
	end
	if pattern == nil then
		pattern = img.new(self.path .. "/wrapping-pattern") or img.new("images/defaultWrappingPattern")
	end
	
	return pattern
end