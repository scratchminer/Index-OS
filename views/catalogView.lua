import("CoreLibs/object")

import("groupUtils")
import("views/cardView")

class("CatalogView").extends(CardView)

function CatalogView.init(self)
	CatalogView.super.init(self)
	self.displayName = "✨ Catalog"
	self.folderName = "Catalog"
end

function CatalogView:activate(fromLeft, currentGame)
	self:useGroup("Catalog")
	CatalogView.super.activate(self, fromLeft, currentGame)
end