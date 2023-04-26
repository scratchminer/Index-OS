import("CoreLibs/object")

import("groupUtils")
import("views/cardView")

class("MyGamesView").extends(CardView)

function MyGamesView:init()
	MyGamesView.super.init(self)
	self.displayName = "🎁 Sideloaded"
	self.folderName = "Sideloaded"
end

function MyGamesView:activate(fromLeft, currentGame)
	self:useGroup("Sideloaded")
	MyGamesView.super.activate(self, fromLeft, currentGame)
end