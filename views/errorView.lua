import("CoreLibs/object")
import("CoreLibs/graphics")

import("view")

local gfx = playdate.graphics
local dis = playdate.display

class("ErrorView").extends(View)

function ErrorView:init()
	ErrorView.super.init(self)
end

function ErrorView:draw()
	gfx.drawTextAligned([[
*Error*

Index OS uses system APIs
only available from the System folder.
Please place this PDX there.]], 200, 70, kTextAlignment.center, 2)
	dis.flush()
	playdate.stop()
	
	return nil
end