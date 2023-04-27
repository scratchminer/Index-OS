import("CoreLibs/graphics")
import("CoreLibs/math")
import("CoreLibs/sprites")

import("game")
import("groupUtils")
import("views/errorView")
import("views/cardView")
import("views/newFolderView")

prefs = nil
folderPrefs = nil
setView = nil

viewList = nil

local dis = playdate.display
local fle = playdate.file
local dts = playdate.datastore
local gfx = playdate.graphics
local img = playdate.graphics.image
local inh = playdate.inputHandlers
local snd = playdate.sound
local spr = playdate.graphics.sprite
local sys = playdate.system
local tmr = playdate.timer

local currentGame

local currentViewIndex
local viewArg

local shake = 0
local invertShake = false

local selectedImage
local unselectedImage

flipForward = nil
flipBack = nil

local kViewPageLeft = 145
local kViewPageWidth = 108
local kViewPageRight = kViewPageLeft + kViewPageWidth
local kViewPageVertical = 28

local pageSprites = table.create(15, 0)

function refreshPageSprites(offset)
	removePageSprites()
	offset = offset or 0
	
	local lerp = playdate.math.lerp
	for i = 1, #viewList do
		local pageSprite = spr.new()
		
		if i == currentViewIndex then
			pageSprite:setImage(selectedImage)
		else
			pageSprite:setImage(unselectedImage)
		end
		
		pageSprite:setIgnoresDrawOffset(true)
		pageSprite:setZIndex(32767)
		
		local fraction
		fraction = ((i - 1) / #viewList) + (0.5 / #viewList)
		
		pageSprite:moveTo(lerp(kViewPageLeft, kViewPageRight, fraction), offset + kViewPageVertical)
		
		pageSprite:add()
		table.insert(pageSprites, pageSprite)
	end
end

function removePageSprites()
	for index, sprite in ipairs(pageSprites) do
		sprite:remove()
		pageSprites[index] = nil
	end
end

function willLaunchGame()
	removePageSprites()
	unloadPresentAnims()
	playdate.getSystemMenu():removeAllMenuItems()
	playdate.setMenuImage(nil)
end

function getCurrentFolderName()
	return viewList[currentViewIndex].name
end

local refreshViewList = function(firstCall)
	local selectedGame, selectedFolder
	
	local launcherPrefs = dts.read("launcherprefs") or {}
	
	if firstCall then
		selectedGame = sys.getLastGameDownloadPath() or launcherPrefs.selectedGamePath or "/System/Settings.pdx"
		loadGameGroups()
	else
		local game = playdate.getCurrentGame()
		if game ~= nil then
			selectedGame = game:getPath()
		else
			selectedGame = launcherPrefs.selectedGamePath or "/System/Settings.pdx"
		end
	end
	
	selectedFolder = folderPrefs.selectedFolder
	viewList = getViewList()
	
	folderPrefs.folderModTimes = folderPrefs.folderModTimes or {}
	for _, view in ipairs(viewList) do
		folderPrefs.folderModTimes[view.name] = getGroupModTime(view)
	end
	
	local targetGroup
	
	targetGroup, currentViewIndex = findGameGroup({path = selectedGame})
	
	if targetGroup == nil then
		if selectedFolder == nil then
			targetGroup, currentViewIndex = getGroupByName("System")
			currentGame = "/System/Settings.pdx"
			folderPrefs.selectedFolder = "System"
		else
			targetGroup, currentViewIndex = getGroupByName(selectedFolder)
		end
	else
		currentGame = currentGame or selectedGame
	end
	
	local viewClass, _ = findViewForGroup(targetGroup)
	viewClass = viewClass or currentView
end

local pushView = function(nextView)
	inh.pop()
	currentView:deinit()
	currentView = nextView()
	if currentView.activate ~= nil then
		currentView:activate()
	end
	
	inh.push(currentView)
end

local savePrefs = function()
	setView(0)
	dts.write(prefs, "/Data/Index OS/prefs", true)
end

local setupMenu = function()
	local sysMenu = playdate.getSystemMenu()
	if #sysMenu:getMenuItems() == 0 then
		local sortGameOptions = {
			"First Title",
			"Last Title",
			"First Author",
			"Last Author",
			"Newest",
			"Oldest",
			"Custom",
		}
		
		local result, error = sysMenu:addMenuItem("new folder", function()
			local sysMenu = playdate.getSystemMenu()
			sysMenu:removeAllMenuItems()
			pushView(NewFolderView)
		end)
		if result == nil then
			print("Menu item add error: " .. error)
		end
		
		local result, error = sysMenu:addOptionsMenuItem("sort", sortGameOptions, prefs.sortGamesBy, function(newValue)
			prefs.sortGamesBy = newValue
			savePrefs()
		end)
		if result == nil then
			print("Menu item add error: " .. error)
		end
	end
end

function setView(nextView, fromRight)
	if nextView ~= nil then
		local swipeInFrom = false
		
		if fromRight == true then
			swipeInFrom = "right"
		elseif fromRight == false then
			swipeInFrom = "left"
		end
		
		inh.pop()
		
		if nextView == 0 then
			dts.write(folderPrefs, "Index OS/folderSettings", true)
			
			reloadGameGroups()
			refreshViewList(false)
			
			currentView:deinit()
			
			local group, index = getGroupByName(currentView.folderName, gameGroups)
			
			currentView = findViewForGroup(group)
			currentViewIndex = index
			
			if currentView.activate ~= nil then
				currentView:activate(false, "")
			end
		elseif nextView == -1 then
			refreshViewList(false)
			currentView:deinit()
			setupMenu()
			
			currentView = viewList[1].view
			currentViewIndex = 1
			
			if currentView.activate ~= nil then
				currentView:activate(swipeInFrom, "")
			end
			
			local game = playdate.getCurrentGame()
			if game ~= nil then
				local launcherPrefs = {selectedGamePath = game:getPath()}
				dts.write(launcherPrefs, "launcherprefs", true)
			end
		elseif nextView == -2 then
			refreshViewList(false)
			currentView:deinit()
			setupMenu()
			
			currentView = viewList[1].view
			currentViewIndex = 1
			
			if currentView.activate ~= nil then
				currentView:activate(swipeInFrom, getGroupByName(viewList[1].name)[1]:getPath())
			end
			
			local game = playdate.getCurrentGame()
			if game ~= nil then
				local launcherPrefs = {selectedGamePath = game:getPath()}
				dts.write(launcherPrefs, "launcherprefs", true)
			end
		elseif nextView == -3 then
			refreshViewList(false)
			currentView:deinit()
			
			local prevViewIndex = currentViewIndex
			
			currentView = viewList[1].view
			currentViewIndex = 1
			
			local swipe
			if prevViewIndex < currentViewIndex then
				swipe = "left-"
			else
				swipe = "right-"
			end
			
			if currentView.activate ~= nil then
				currentView:activate(swipe, "")
			end
			
			local game = playdate.getCurrentGame()
			if game ~= nil then
				local launcherPrefs = {selectedGamePath = game:getPath()}
				dts.write(launcherPrefs, "launcherprefs", true)
			end
		elseif type(nextView) == "number" then
			if currentView ~= nil then
				currentView:deinit()
			end
			setupMenu()
			
			currentView = viewList[nextView].view
			currentViewIndex = nextView
			
			if currentView.activate ~= nil then
				currentView:activate(swipeInFrom, "")
			end
			
			local game = playdate.getCurrentGame()
			
			if game ~= nil then
				local launcherPrefs = {selectedGamePath = game:getPath()}
				dts.write(launcherPrefs, "launcherprefs", true)
			end
		elseif type(nextView) == "table" then
			if currentView ~= nil then
				currentView:deinit()
			end
			
			local sysMenu = playdate.getSystemMenu()
			sysMenu:removeAllMenuItems()
			
			currentView = nextView()
			if currentView.activate ~= nil then
				currentView:activate(swipeInFrom, "")
			end
			
			local game = playdate.getCurrentGame()
			if game ~= nil then
				local launcherPrefs = {selectedGamePath = game:getPath()}
				dts.write(launcherPrefs, "launcherprefs", true)
			end
		elseif type(nextView) == "string" and playdate.getCurrentTimeMilliseconds() > 500 then
			currentView:deinit()
			setupMenu()
			
			if nextView ~= "" then
				createEmptyFolder(nextView)
				folderPrefs.selectedFolder = nextView
				
				refreshViewList(false)
				
				local group, index = getGroupByName(nextView, gameGroups)
				
				currentView = findViewForGroup(group)
				currentViewIndex = index
				
				if currentView.activate ~= nil then
					currentView:activate("right-", "")
				end
			else
				cooldown = true
				currentView = viewList[currentViewIndex].view
				
				if currentView.activate ~= nil then
					currentView:activate(false, "")
				end
			end
		end
		
		inh.push(currentView)
	end
end

function playdate.gameWillResume()
	if currentView.gameWillResume ~= nil then
		currentView.gameWillResume()
	end
end

function playdate.deviceWillLock()
	for _, view in ipairs(viewList) do
		folderPrefs.folderModTimes[view.name] = getGroupModTime(view)
	end
	
	local game = playdate.getCurrentGame()
	if game ~= nil then
		local launcherPrefs = {selectedGamePath = game:getPath()}
		dts.write(launcherPrefs, "launcherprefs", true)
	end
	
	dts.write(prefs, "/Data/Index OS/prefs", true)
	dts.write(folderPrefs, "Index OS/folderSettings", true)
	
	currentView:deinit()
end

function playdate.deviceWillSleep()
	for _, view in ipairs(viewList) do
		folderPrefs.folderModTimes[view.name] = getGroupModTime(view)
	end
	
	local game = playdate.getCurrentGame()
	if game ~= nil then
		local launcherPrefs = {selectedGamePath = game:getPath()}
		dts.write(launcherPrefs, "launcherprefs", true)
	end
	
	dts.write(launcherPrefs, "launcherprefs", true)
	dts.write(prefs, "/Data/Index OS/prefs", true)
	dts.write(folderPrefs, "Index OS/folderSettings", true)
	
	currentView:deinit()
end

function playdate.deviceDidUnlock()
	dis.setRefreshRate(40)
	
	prefs = dts.read("/Data/Index OS/prefs") or {}
	folderPrefs = dts.read("Index OS/folderSettings") or {}
	
	local launcherPrefs = dts.read("launcherprefs") or {}
	currentGame = sys.getLastGameDownloadPath() or launcherPrefs.selectedGamePath or "/System/Settings.pdx"
	
	refreshViewList(false)
	
	if currentView.activate ~= nil then
		currentView:activate(false, currentGame)
	end
end

function playdate.leftButtonUp()
	local newIndex = currentViewIndex - 1
	if newIndex < 1 then
		newIndex = #viewList
	end
	
	if currentViewIndex ~= newIndex then
		setView(newIndex, false)
	else
		if playdate.getCurrentTimeMilliseconds() > 500 then
			snd.playSystemSound(snd.kSoundDenial)
		end
		
		shake = 4
	end
end

function playdate.rightButtonUp()
	local newIndex = currentViewIndex + 1
	if newIndex > #viewList then
		newIndex = 1
	end
	
	if currentViewIndex ~= newIndex then
		setView(newIndex, true)
	else
		if playdate.getCurrentTimeMilliseconds() > 500 then
			snd.playSystemSound(snd.kSoundDenial)
		end
		
		shake = -4
	end
end

function playdate.gameWasWrapped(game)
	sys.saveGameList()
	reloadGameGroups()
end

function playdate.update()
	loadNextGame()
	
	local nextView = currentView:draw(shake)
	setView(nextView)
	
	if shake < 0 and not invertShake then
		shake = shake + 1
	elseif shake > 0 then
		shake = shake - 1
		if invertShake then
			shake = -shake
		end
	end
	if shake == 0 then
		invertShake = false
	end
end

if sys == nil then
	currentView = ErrorView()
else
	sys.setLaunchAnimationActive(false)
	dis.setRefreshRate(40)
	
	prefs = dts.read("/Data/Index OS/prefs") or {}
	folderPrefs = dts.read("Index OS/folderSettings") or {}
	
	if prefs.sortSystemFolders == nil then
		prefs.sortSystemFolders = false
	end
	
	if prefs.showBatteryPercentage == nil then
		prefs.showBatteryPercentage = false
	end
	
	prefs.showBatteryBelowThreshold = prefs.showBatteryBelowThreshold or 10
	
	local validSorts = {
		"Default",
		"First Title",
		"Last Title",
		"Newest",
		"Oldest",
	}
	
	local validGameSorts = {
		"First Title",
		"Last Title",
		"Newest",
		"Oldest",
		"Custom",
	}
	
	if not table.indexOfElement(validSorts, prefs.sortBy or "🅱️") then
		prefs.sortBy = nil
	end
	
	if not table.indexOfElement(validGameSorts, prefs.sortGamesBy or "🅱️") then
		prefs.sortGamesBy = nil
	end
	
	prefs.sortBy = prefs.sortBy or "Default"
	prefs.sortGamesBy = prefs.sortGamesBy or "Custom"
	
	selectedImage = img.new("images/viewSelected")
	unselectedImage = img.new("images/viewUnselected")
	
	refreshViewList(true)
	loadNextGame()
	
	flipForward = snd.sampleplayer.new("sounds/flipForward")
	flipBack = snd.sampleplayer.new("sounds/flipBack")
	
	currentView = viewList[currentViewIndex].view
	currentView:activate("right-", currentGame)
	
	inh.push(currentView)
	setupMenu()
end