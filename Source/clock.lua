-- This file was cleaned up and modified from the decompiled Panic launcher.
-- The original file was presumably written by Dan Messing sometime in 2020.

import("CoreLibs/graphics")

kClockTileHeight = 199

local gfx = playdate.graphics
local img = playdate.graphics.image
local geo = playdate.geometry

local drawCircleAtPoint = playdate.graphics.drawCircleAtPoint
local fillPolygon = playdate.graphics.fillPolygon

local ticks = 20
local kClockFaceRadius = 75
local kSecondHandRadius = 4
local kSecondHandDiameter = 8

local af = geo.affineTransform.new()
local kHandWidth = 3
local kMinuteHandHeight = 67
local kHourHandHeight = 50

local hourHandPattern = {0x00, 0xff, 0x00, 0xff, 0x00, 0xff, 0x00, 0xff}

local hours = 0
local minutes = 0
local seconds = 0

function clockNeedsUpdate()
	local timeTable = playdate.getTime()
	return timeTable.hour ~= hours or timeTable.minute ~= minutes or timeTable.second ~= seconds
end

function renderClockImage(width, height)
	local timeTable = playdate.getTime()
	hours = timeTable.hour
	minutes = timeTable.minute
	seconds = timeTable.second
	
	local center = geo.point.new(width / 2, height / 2)
	local secondPoint = center:copy()
	local mPolygon = geo.polygon.new(center.x - kHandWidth, center.y - kMinuteHandHeight + 5, center.x - kHandWidth + 1, center.y - kMinuteHandHeight + 2, center.x, center.y - kMinuteHandHeight + 2, center.x + kHandWidth - 1, center.y - kMinuteHandHeight + 2, center.x + kHandWidth, center.y - kMinuteHandHeight + 5, center.x + kHandWidth, center.y, center.x - kHandWidth, center.y, center.x - kHandWidth, center.y - kMinuteHandHeight + 5)
	local hPolygon = geo.polygon.new(center.x - kHandWidth, center.y - kHourHandHeight + 5, center.x - kHandWidth + 1, center.y - kHourHandHeight + 2, center.x, center.y - kHourHandHeight + 2, center.x + kHandWidth - 1, center.y - kHourHandHeight + 2, center.x + kHandWidth, center.y - kHourHandHeight + 5, center.x + kHandWidth, center.y, center.x - kHandWidth, center.y, center.x - kHandWidth, center.y - kHourHandHeight + 5)
	
	local cardImage = img.new(width, height)
	gfx.pushContext(cardImage)
	
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRoundRect(0, 0, width, height, 4)
	gfx.setColor(gfx.kColorWhite)
	gfx.drawCircleAtPoint(center, kClockFaceRadius, kClockFaceRadius)
	
	af:reset()
	
	af:translate(-center.x, -center.y)
	af:translate(0, -(kClockFaceRadius + 8))
	af:rotate(seconds * 6)
	af:translate(center.x, center.y)
	secondPoint.x = center.x
	secondPoint.y = center.y
	af:transformPoint(secondPoint)
	drawCircleAtPoint(secondPoint, kSecondHandRadius, kSecondHandRadius)
	gfx.setColor(gfx.kColorWhite)
	drawCircleAtPoint(center, kHandWidth, kHandWidth)
	
	af:reset()
	
	af:translate(-center.x, -center.y)
	af:rotate(minutes * 6 + seconds * 0.1)
	af:translate(center.x, center.y)
	local mPolyT = af:transformedPolygon(mPolygon)
	fillPolygon(mPolyT)
	
	af:reset()
	
	af:translate(-center.x, -center.y)
	af:rotate(hours * 30 + minutes * 0.5)
	af:translate(center.x, center.y)
	local hPolyT = af:transformedPolygon(hPolygon)
	gfx.setPattern(hourHandPattern)
	fillPolygon(hPolyT)
	
	gfx.popContext()
	
	return cardImage
end
