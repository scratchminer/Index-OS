import("CoreLibs/object")

local fnt = playdate.graphics.font
local img = playdate.graphics.image
local imt = playdate.graphics.imagetable
local smp = playdate.sound.sampleplayer
local flp = playdate.sound.fileplayer

class("View").extends()

function View:init() end
function View:deinit() end

function View.loadImage(imagePath)
	local image, err = img.new(imagePath)
	if err then
		print("Load error: " .. err)
	end
	
	if image then
		return image
	end
end

function View.loadImageTable(imageTablePath)
	local imageTable, err = imt.new(imageTablePath)
	if err then
		print("Load error: " .. err)
	end
	
	if imageTable then
		return imageTable
	end
end

function View.loadSound(soundPath)
	local sound, err = smp.new(soundPath)
	if err then
		print("Load error: " .. err)
	end
	
	if sound then
		return sound
	end
end

function View.loadMusic(musicPath)
	local music = flp.new(musicPath)
	if err then
		print("Load error: " .. err)
	end
	
	if music then
		return music
	end
end

function View.loadFont(fontPath)
	local font = fnt.new(fontPath)
	if err then
		print("Load error: " .. err)
	end
	
	if font then
		return font
	end
end