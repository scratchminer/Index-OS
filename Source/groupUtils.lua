import("game")

import("views/systemView")
import("views/folderView")
import("views/myGamesView")
import("views/catalogView")
import("views/seasonView")

local dts = playdate.datastore
local fle = playdate.file
local snd = playdate.sound
local sys = playdate.system

gameGroups = {}
local groupQueue = {}
local gameFolders
local asyncGameLoader

local loadingGroup

local getViewArg = function(groupName)
	if groupName == nil then
		return nil
	end
		
	if groupName == "System" or groupName == "Sideloaded" or groupName == "Catalog" then
		return nil
	end
	
	if groupName:find("Season ([0-9]+)") then
		local seasonNum = groupName:match("Season ([0-9]+)")
		seasonNum = tonumber(seasonNum, 10)
		if seasonNum ~= nil then
			return seasonNum
		end
	end
	
	return groupName
end

local loadGroupAsync = function(index)
	-- go through each group twice, in case we miss a game
	for j, game in ipairs(gameGroups[index]) do
		if type(game) == "userdata" then
			coroutine.yield(j, Game(game))
		end
	end
	for j, game in ipairs(gameGroups[index]) do
		if type(game) == "userdata" then
			coroutine.yield(j, Game(game))
		end
	end
end

function loadNextGame()
	if #groupQueue > 0 or loadingGroup ~= nil then
		if asyncGameLoader == nil or coroutine.status(asyncGameLoader) == "dead" or loadingGroup == nil then
			asyncGameLoader = coroutine.create(loadGroupAsync)
			loadingGroup = table.remove(groupQueue)
			if loadingGroup == nil then
				return
			end
		end
		
		if loadingGroup ~= nil then
			local _, index, game = coroutine.resume(asyncGameLoader, loadingGroup)
			if index ~= nil then
				gameGroups[loadingGroup][index] = game
			end
		end
	end
end

function loadGameGroups()
	sys.updateGameList()
	reloadGameGroups()
end

function loadGroupFaster(groupIndex, index)
	for i = index - 3, index + 3 do
		if i >= 1 and i <= #gameGroups[groupIndex] then
			local game = gameGroups[groupIndex][i]
			
			if type(game) == "userdata" then
				gameGroups[groupIndex][i] = Game(game)
			end
		end
	end
	
	return gameGroups[groupIndex]
end

function groupExists(groupName)
	for _, group in ipairs(gameGroups) do
		if group.name == groupName then
			return true
		end
	end
	
	return false
end

function reloadGameGroups()
	gameGroups = sys.getInstalledGameList()
	
	local newGameGroups = {}
	gameFolders = dts.read("Index OS/folders") or {}
	
	local nameChanges = {
		["User"] = "Sideloaded",
		["Purchased"] = "Catalog",
	}
	
	for index, group in ipairs(gameGroups) do
		local name = group.name
		local newName = name
		
		if name:find("Season%-([0-9]+)") then
			local seasonNum = name:match("Season%-([0-9]+)")
			seasonNum = tonumber(seasonNum, 10)
			
			if seasonNum ~= nil then
				newName = "Season " .. tostring(seasonNum)
			end
		elseif nameChanges[name] ~= nil then
			newName = nameChanges[name]
		end
		
		group.name = newName
		
		if #group > 0 then
			table.insert(newGameGroups, group)
		end
	end
	
	local viewOrder = {
		["System"] = 1,
		["Sideloaded"] = 2,
		["Catalog"] = 3,
	}
	
	local sortFuncs = {
		["First Title"] = function(v1, v2)
			local a1 = getViewArg(v1.name)
			local a2 = getViewArg(v2.name)
			
			if prefs.sortSystemFolders then
				a1 = v1.name
				a2 = v2.name
			end
			
			if a1 ~= nil and type(a1) == type(a2) then
				return a1 < a2
			else
				local index1 = viewOrder[v1.name]
				local index2 = viewOrder[v2.name]
				
				if v1.name:find("Season ([0-9]+)") then
					index1 = 4
				end
				if v2.name:find("Season ([0-9]+)") then
					index2 = 4
				end
				
				if index1 ~= nil and index2 == nil then
					return false
				elseif index1 == nil and index2 ~= nil then
					return true
				elseif index1 ~= nil and index2 ~= nil then
					return index1 < index2
				end
			end
		end,
		
		["Last Title"] = function(v1, v2)
			local a1 = getViewArg(v1.name)
			local a2 = getViewArg(v2.name)
			
			if prefs.sortSystemFolders then
				a1 = v1.name
				a2 = v2.name
			end
			
			if a1 ~= nil and type(a1) == type(a2) then
				return a1 > a2
			else
				local index1 = viewOrder[v1.name]
				local index2 = viewOrder[v2.name]
				
				if v1.name:find("Season ([0-9]+)") then
					index1 = 4
				end
				if v2.name:find("Season ([0-9]+)") then
					index2 = 4
				end
				
				if index1 ~= nil and index2 == nil then
					return false
				elseif index1 == nil and index2 ~= nil then
					return true
				elseif index1 ~= nil and index2 ~= nil then
					return index1 < index2
				end
			end
		end,
		
		["Newest"] = function(v1, v2)
			local d1 = getGroupModTime(v1)
			local d2 = getGroupModTime(v2)
			
			local a1 = getViewArg(v1.name)
			local a2 = getViewArg(v2.name)
			
			if prefs.sortSystemFolders then
				a1 = v1.name
				a2 = v2.name
			end
			
			if a1 ~= nil and type(a1) == type(a2) then
				return d1 > d2
			else
				local index1 = viewOrder[v1.name]
				local index2 = viewOrder[v2.name]
				
				if v1.name:find("Season ([0-9]+)") then
					index1 = 4
				end
				if v2.name:find("Season ([0-9]+)") then
					index2 = 4
				end
				
				if index1 ~= nil and index2 == nil then
					return false
				elseif index1 == nil and index2 ~= nil then
					return true
				elseif index1 ~= nil and index2 ~= nil then
					return index1 < index2
				end
			end
		end,
		
		["Oldest"] = function(v1, v2)
			local d1 = getGroupModTime(v1)
			local d2 = getGroupModTime(v2)
			
			local a1 = getViewArg(v1.name)
			local a2 = getViewArg(v2.name)
			
			if prefs.sortSystemFolders then
				a1 = v1.name
				a2 = v2.name
			end
			
			if a1 ~= nil and type(a1) == type(a2) then
				return d1 < d2
			else
				local index1 = viewOrder[v1.name]
				local index2 = viewOrder[v2.name]
				
				if v1.name:find("Season ([0-9]+)") then
					index1 = 4
				end
				if v2.name:find("Season ([0-9]+)") then
					index2 = 4
				end
				
				if index1 ~= nil and index2 == nil then
					return false
				elseif index1 == nil and index2 ~= nil then
					return true
				elseif index1 ~= nil and index2 ~= nil then
					return index1 < index2
				end
			end
		end,
		
		["Default"] = function(v1, v2)
			local a1 = getViewArg(v1.name)
			local a2 = getViewArg(v2.name)
			
			if prefs.sortSystemFolders then
				a1 = v1.name
				a2 = v2.name
			end
			
			if a1 ~= nil and type(a1) == type(a2) then
				return a1 < a2
			else
				local index1 = viewOrder[v1.name]
				local index2 = viewOrder[v2.name]
				
				if v1.name:find("Season ([0-9]+)") then
					index1 = 4
				end
				if v2.name:find("Season ([0-9]+)") then
					index2 = 4
				end
				
				if index1 ~= nil and index2 == nil then
					return false
				elseif index1 == nil and index2 ~= nil then
					return true
				elseif index1 ~= nil and index2 ~= nil then
					return index1 < index2
				end
			end
		end
	}
	
	for name, folder in pairs(gameFolders) do
		local folderTable = {}
		folderTable.name = name
		
		for i, path in ipairs(folder) do
			folderTable[i] = getGameAtPath(path)
		end
		
		local indexOf = #newGameGroups + 1
		
		for index, group in pairs(gameGroups) do
			if group.name == name then
				for _, game in ipairs(group) do
					if not table.indexOfElement(folder, game:getPath()) then
						table.insert(folderTable, game)
					end
				end
				
				indexOf = index
				break
			end
		end
		
		newGameGroups[indexOf] = folderTable
	end
	
	gameGroups = table.deepcopy(newGameGroups)
	table.sort(gameGroups, sortFuncs[prefs.sortBy])
	
	groupQueue = {}
	for index = 1, #gameGroups do
		groupQueue[index] = index
	end
end

function getGameAtPath(path)
	for _, group in ipairs(gameGroups) do
		for _, game in ipairs(group) do
			if game:getPath() == path then
				return game
			end
		end
	end
	return nil
end

function getLauncherPath()
	local systemGroup = getGroupByName("System")
	
	for _, game in ipairs(systemGroup) do
		if game:getTitle() == "Launcher" then
			return game:getPath()
		end
	end
end

function getGroupByName(groupName, groups)
	groups = groups or gameGroups
	
	for index, group in ipairs(groups) do
		if group.name == groupName then
			if groupName == "System" then
				local systemGroup = table.create(#group, 1)
				systemGroup.name = groupName
				
				local systemExclude = {
					"InputTest",
					"Setup",
					"SetupIntro",
					"FCC",
					"QA",
					"Index OS",
				}
				for _, game in ipairs(group) do
					if not table.indexOfElement(systemExclude, game:getTitle()) then
						table.insert(systemGroup, game)
					end
				end
				
				local systemGames = {
					"Catalog",
					"Poolsuite FM",
					"Settings",
				}
				table.sort(systemGroup, function(e1, e2)
					local index1 = table.indexOfElement(systemGames, e1:getTitle())
					local index2 = table.indexOfElement(systemGames, e2:getTitle())
										
					if index1 == nil and index2 == nil then
						return e1:getTitle() < e2:getTitle()
					elseif index1 ~= nil and index2 == nil then
						return true
					elseif index1 == nil and index2 ~= nil then
						return false
					else
						return index1 < index2
					end
				end)
				
				groups[index] = systemGroup
				return systemGroup, index
			end
			
			return group, index
		end
	end
end

function isSystemGroup(group)
	local systemGroups = {
		"System",
		"Sideloaded",
		"Catalog",
	}
	
	local groupName = group
	if type(group) == "table" then
		groupName = group.name
	end
	
	return (not not table.indexOfElement(systemGroups, groupName)) or groupName:sub(1, 7) == "Season "
end

function listFolder(folderName)
	if gameFolders[folderName] == nil then
		return {}
	end
	
	local listed = {}
	for _, path in ipairs(gameFolders[folderName]) do
		table.insert(listed, getGameAtPath(path))
	end
	
	return listed
end

function createEmptyFolder(folderName)
	if gameFolders[folderName] == nil then
		if isSystemGroup(folderName) and folderName ~= "System" then
			local group = getGroupByName(folderName)
			gameFolders[folderName] = {}
			
			for _, game in ipairs(group) do
				table.insert(gameFolders[folderName], game:getPath())
			end
			
			dts.write(gameFolders, "Index OS/folders", true)
	
			folderPrefs.folderModTimes[folderName] = playdate.getSecondsSinceEpoch()
			
			reloadGameGroups()
		elseif not isSystemGroup(folderName) then
			gameFolders[folderName] = {}
			dts.write(gameFolders, "Index OS/folders", true)
		
			folderPrefs.folderModTimes[folderName] = playdate.getSecondsSinceEpoch()
	
			reloadGameGroups()
		end
	end
end

function deleteFolder(folderName)
	if gameFolders[folderName] == nil then
		snd.playSystemSound(snd.kSoundDenial)
		return false
	end
	
	gameFolders[folderName] = nil
	folderPrefs.folderModTimes[folderName] = nil
	dts.write(gameFolders, "Index OS/folders", true)
	
	reloadGameGroups()
	return true
end

function copyGame(gamePath, folderName, toIndex, fromGroup)
	if gameFolders[folderName] == nil then
		snd.playSystemSound(snd.kSoundDenial)
		return false
	end
	
	if table.indexOfElement(gameFolders[folderName], gamePath) then
		table.remove(gameFolders[folderName], table.indexOfElement(gameFolders[folderName], gamePath))
	end
	
	if toIndex > #gameFolders[folderName] then
		table.insert(gameFolders[folderName], gamePath)
	else
		table.insert(gameFolders[folderName], toIndex, gamePath)
	end
	
	dts.write(gameFolders, "Index OS/folders", true)
	
	if not isSystemGroup(folderName) then
		folderPrefs.folderModTimes[folderName] = playdate.getSecondsSinceEpoch()
	end
	
	reloadGameGroups()
	return true
end

function removeGame(gamePath, folderName)
	if not isSystemGroup(folderName) and gameFolders[folderName] ~= nil and table.indexOfElement(gameFolders[folderName], gamePath) ~= nil then
		if table.indexOfElement(gameFolders[folderName], gamePath) then
			table.remove(gameFolders[folderName], table.indexOfElement(gameFolders[folderName], gamePath))
		end
		
		dts.write(gameFolders, "Index OS/folders", true)
		
		folderPrefs.folderModTimes[folderName] = playdate.getSecondsSinceEpoch()
		
		reloadGameGroups()
		return true
	else
		return false
	end
end

function findGameGroup(criteria)
	if type(criteria) ~= "table" then
		return nil
	end
	
	local groupToReturn, groupIndexToReturn
	
	for index, group in ipairs(gameGroups) do
		if type(group) == "table" then
			local found = false
			
			for _, game in ipairs(group) do	
				local satisfied = true
				for key, value in pairs(criteria) do
					if key == "title" and game:getTitle() ~= value then
						satisfied = false
						break
					elseif key == "path" and game:getPath() ~= value then
						satisfied = false
						break
					end
				end
				if satisfied then
					found = true
					break
				end
			end
			
			if found then
				groupToReturn = group
				groupIndexToReturn = index
				break
			end
		end
	end
		
	return groupToReturn, groupIndexToReturn
end

function findViewForGroup(group)
	local name
	
	if type(group) == "string" then
		name = group
	else
		name = group.name
	end
	
	if name == "System" then
		return SystemView()
	elseif name == "Sideloaded" then
		return MyGamesView()
	elseif name == "Catalog" then
		return CatalogView()
	elseif name:find("Season ([0-9]+)") then
		local seasonNum = name:match("Season ([0-9]+)")
		seasonNum = tonumber(seasonNum, 10)
		if seasonNum ~= nil then
			return SeasonView(name)
		end
	else
		return FolderView(name)
	end
end

function getGroupModTime(group)
	local groupName
	local isFolder = true
	
	if type(group.arg) == "string" then
		groupName = group.arg
	elseif group.name ~= nil then
		groupName = group.name
		isFolder = false
	end
	
	if isFolder == false then
		if groupName == "System" then
			return playdate.epochFromTime(fle.modtime("/System"))
		elseif groupName == "Sideloaded" then
			return playdate.epochFromTime(fle.modtime("/Games/User"))
		elseif groupName == "Catalog" then
			return playdate.epochFromTime(fle.modtime("/Games/Purchased"))
		elseif groupName:find("Season ([0-9]+)") then
			local seasonNum = tonumber(group.name:match("Season ([0-9]+)"), 10)
			local path = string.format("/Games/Seasons/Season-%03d", seasonNum)
			return playdate.epochFromTime(fle.modtime(path))
		else
			return playdate.epochFromTime(fle.modtime("/Games/Seasons/" .. groupName))
		end
	else
		folderPrefs.folderModTimes = folderPrefs.folderModTimes or {}
		
		if folderPrefs.folderModTimes[groupName] ~= nil then
			return folderPrefs.folderModTimes[groupName]
		else
			local newModTime = 0
			
			for _, game in ipairs(listFolder(groupName)) do
				local modTime = playdate.epochFromTime(fle.modtime(game:getPath()))
				if newModTime < modTime then
					newModTime = modTime
				end
			end
			
			return newModTime
		end
	end
end

function getViewList()
	local views = {}
	
	for _, group in ipairs(gameGroups) do
		local groupName
		local viewForGroup, viewArg = findViewForGroup(group)
		
		if type(group) == "string" then
			groupName = group
		elseif group.name ~= nil then
			groupName = group.name
		end
		
		table.insert(views, {
			view = viewForGroup,
			name = groupName
		})
	end
	
	return views
end