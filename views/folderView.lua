import("CoreLibs/object")

import("groupUtils")
import("views/cardView")

class("FolderView").extends(CardView)

function FolderView:init(folderName)
	FolderView.super.init(self)
	self.displayName = "📁 " .. folderName
	self.folderName = folderName
end

function FolderView:activate(fromLeft, currentGame)
	self:useGroup(self.folderName)
	FolderView.super.activate(self, fromLeft, currentGame)
end