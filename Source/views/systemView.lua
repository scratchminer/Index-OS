import("CoreLibs/object")

import("groupUtils")
import("views/cardView")

class("SystemView").extends(CardView)

function SystemView:init()
	SystemView.super.init(self)
	self.displayName = "🟨 System"
	self.folderName = "System"
end

function SystemView:activate(fromLeft, currentGame)
	self:useGroup("System", currentGame)
	SystemView.super.activate(self, fromLeft, currentGame)
end