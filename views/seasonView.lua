import("CoreLibs/object")

import("groupUtils")
import("views/cardView")

class("SeasonView").extends(CardView)

function SeasonView:init(seasonName)
	SeasonView.super.init(self)
	local numberLookup = {
		"① ",
		"② ",
	}
	
	local seasonNum = tonumber(seasonName:match("Season ([0-9]+)"))
	
	self.displayName = numberLookup[seasonNum] .. seasonName
	self.folderName = seasonName
end

function SeasonView:activate(fromLeft, currentGame)
	self:useGroup(self.folderName)
	SeasonView.super.activate(self, fromLeft, currentGame)
end