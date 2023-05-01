import("CoreLibs/object")
import("CoreLibs/graphics")

import("view")

local gfx = playdate.graphics
local fnt = playdate.graphics.font
local img = playdate.graphics.image
local dis = playdate.display

class("ErrorView").extends(View)

local normalFont = fnt.new("fonts/roobert11")
local boldFont = fnt.new("fonts/roobert11Bold")
local setupQR = img.new("images/setupQR")

function ErrorView:init()
	ErrorView.super.init(self)
	gfx.setFont(normalFont)
	gfx.setFont(boldFont, "bold")
end

function ErrorView:draw()
	gfx.drawTextAligned([[
*Privilege Error*
Index OS uses system APIs, meaning you
cannot sideload this app normally. For
instructions on how to set up Index, visit:]], 200, 10, kTextAlignment.center, 2)
	gfx.drawTextAligned([[🌐*scratchminer.github.io/
Index-OS-Website/setup*]], 130, 160, kTextAlignment.left, 2)
	setupQR:draw(20, 140)
	dis.flush()
	playdate.stop()
	
	return nil
end