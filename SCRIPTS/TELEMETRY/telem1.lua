--[[
	Telemetry display script for AutoQuad Telemetry Handler Component
	
	** Requires AQTelem.lua, DrawLib.lua, and TFlds2xx.lua (corresponding to OTx version)
	** installed in SCRIPTS/MIXES folder and activated in "Custom Scripts" settings of the model.
	
  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  A copy of the GNU General Public License is available at <http://www.gnu.org/licenses/>.

  Copyright (c)2015-2016 by Maxim Paperno. All rights reserved.
  
  Parts inspired by/borrowed from:
  - http://diydrones.com/forum/topics/amp-to-frsky-x8r-sport-converter
  - https://github.com/chsw/MavLink_FrSkySPort
  - https://github.com/scottflys/mavsky 
  - https://github.com/wolkstein/MavLink_FrSkySPort
  - and others
	
  Many thanks to the OpenTx project and all predecessors!
  
]]

--[[

The following data is parsed and collected in the background by AQTelem.lua mixer script, not available with regular openTx getValue().
You can use these values directly with aq.mav.<var>  The following table shows the default values.

aq.mav = {
	hasConnected = false,  -- Has connected at all
	isConnected = false,   -- Is currently connected
	lastHeard = 0,         -- Timestamp of last heartbeat received
	gpsHdop = nil,         -- Horizontal GPS accuracy in meters
	gpsVdop = nil,         -- Vertical GPS accuracy in meters
	gpsFix = 0,            -- GPS fix type: 0=none, 2=2D, 3=3D
	gpsSats = 255,         -- GPS satellites visible (not used with AQ)
	heading = -1,          -- Actual yaw heading, not GPS course, if available
	battPercent = nil,     -- Battery percent remaining as reported by MAV
	imuTemp = nil,         -- Temperature reported by MAV
	wptNum = 0,            -- Next waypoint number, if any
	wptDist = 0,           -- Next waypoint distance
	brgToHome = -1,        -- Bearing to home position in compass degrees
	brgFromHome = -1,      -- Bearing from home position in compass degrees
	statusFlags = 0,       -- 32 bit array of status indicators (AQ_NAV_STATUS_xxx enumeration)
}

AQTelem (aq) also provides the following functions (see AQTelem.lua for details):

	aq.getMessageAt(n)
	aq.getLatestMessage()
	aq.getStatus()
	aq.getDop(which)
	aq.drawTopPanel(h, timid)
	aq.drawBottomPanel(h, msgTO)

DrawLib (dlib) provides a library of LCD drawing functions as well as some basic calculation and formatting utilities (see DrawLib.lua for details).

]]

-- settings
local SHOW_CURR  = false  -- show current (amps/w/mAh) measurements.  Press [MENU] button to toggle. This setting defines the default view. 
local LMST       = 20    -- Last Message Show Timeout: seconds to display last text message received in the footer
local TIMID      = 1     -- Which timer to show on the top line, 1 or 2. 
local VSPD_SCAL  = 20    -- vertical speed graph scaling (deg. per meter/sec): 45 deg (constant) / 2.25 m/s (variable) = 20 degrees per meter. Eg. for double resolution: 45 / 1.125 = 40 */m
local DIR_TYPE   = 1     -- 1=show actual compass direction to MAV; 2=compass dir. from mav (opposite of 1); 3=show relative heading from MAV heading to home; 4=mav course; 5=mav heading (if avail)
                         --    Quick-press [ENT] button to toggle through different direction types. This setting defines the default view. 

TINSIZE = 0x0400			-- Tiny size font from lcd.h. Set this to =SMLSIZE if using sqt5 font (doesn't have TINSIZE)
--TINSIZE = SMLSIZE		-- uncomment this if using sqt5 font
--CONDENSED = 0x08		-- Condensed size font from lcd.h (not used)

-- internals

local batPctFlashTim = 0
local PANEL_H = FH   -- pixel height of top and bottom panels (header/footer)
LMST = LMST * 100    -- convert to seconds and adjust for system timer in 10ms increments
TIMID = TIMID -1     -- actual timer index starts at zero


function checkAQLibs()
	if (aq == nil or dlib == nil) then
		lcd.drawText(0, 20, "Please install AQTelem.lua and DrawLib.lua", SMLSIZE)
		lcd.drawText(0, 30, "in /SCRIPTS/MIXES folder on SD card and", SMLSIZE)
		lcd.drawText(0, 40, "activate them on the \"Custom Scripts\" page.", SMLSIZE)
		return 1
	else
		return 0
	end
end

----- Drawing functions --------

-- Voltage and current --

local function drawVoltage(x, y, val)
	local prec = PREC1
	local dval
	if (val == "batt") then
		dval = getValue(g_fld.mainV) * 10
	elseif (val == "cell") then
		dval = getValue(g_fld.cellVlo) * 100
		prec = PREC2
	end
	lcd.drawNumber(x + FW * 5, y, dval, DBLSIZE + prec)
	x = lcd.getLastPos()
	if (val == "cell") then
		lcd.drawText(x, y+2, "C", SMLSIZE)
	end
	lcd.drawText(x, y+9, "V", SMLSIZE)
end

local function drawBatteryPercent(x, y, size)
	size = size or MIDSIZE
	local blink = 0
	local val = aq.mav.battPercent
	x = x + FW * 2
	if (size == DBLSIZE) then
		x = x + FW
	end
	if (val) then
		val = math.min(math.max(val, 0), 100)
		if (val <= 25) then
			blink = BLINK
			if (not batPctFlashTim) then
				batPctFlashTim = getTime()
			end
		else
			batPctFlashTim = false
		end
		lcd.drawNumber(x, y, val, size + blink)
	else
		lcd.drawText(x, y, "--", size)
	end
	x = lcd.getLastPos()+1
	lcd.drawText(x, y-1, "v", SMLSIZE)
	lcd.drawText(x, y+6, "%", SMLSIZE)
end

local function drawCurrent(x, y, which)
	local val, prec, unit
	if (which == "power") then
		val = g_fld.mainW
		unit = "W"
		prec = 0
	else
		val = g_fld.mainA
		unit = "A"
		prec = PREC1
	end
	val = getValue(val)
	val, prec = dlib.adjustTo3Digits(val, prec)
	lcd.drawNumber(x + FW * 5, y, val, DBLSIZE + prec)
	x = lcd.getLastPos()
	if (which == "power" and prec > 0) then
		lcd.drawText(x, y+2, "K", SMLSIZE)
	end
	lcd.drawText(x, y+9, unit, SMLSIZE)
end

local function drawTotalCurrent(x, y)
	local val, prec = dlib.adjustTo3Digits(getValue(g_fld.mainAh), 0)
	lcd.drawNumber(x + FW * 4, y, val, MIDSIZE + prec)
	x = lcd.getLastPos()
	lcd.drawText(x, y+5, "Ah", SMLSIZE)
	if (prec == 0) then
		lcd.drawText(x, y-2, "m", SMLSIZE)
	end
	
end


-- GPS information --

-- Draw horizontal/vertitical GPS accuracy indicator
---> x, y : LCD coordinates at which to draw
---> which : "H" for horizontal accuracy, or "V" for vertical
---> size : font size (default MIDSIZE)
---> hVal : "high" value at which to blink the display (only if 3D lock), default is 2m (or higher)
---> gVal : "good" value at which to inverse the display, default is 1m (or lower)
-- returns:
---< w, h : width and height of resulting display in LCD pixels
local function drawDop(x, y, which, size, hVal, gVal)
	size = size or 0
	hVal = hVal or 2
	gVal = gVal or 1
	local h, oX = FH, x
	local lflags = 0
	local val = aq.getDop(which)
	local prec = PREC2
	if (val and aq.mav.gpsFix and aq.mav.isConnected) then
		if (aq.mav.gpsFix > 2) then
			if (val <= gVal) then
				lflags = lflags + INVERS
			elseif (val > hVal) then
				lflags = lflags + BLINK
			end
		end
		if val > 40 then
			lcd.drawText(x, y, ">", SMLSIZE + lflags)
			x = lcd.getLastPos()
			val = 40
			prec = 0
		else
			val, prec = dlib.adjustTo3Digits(val, prec)
		end
		lcd.drawNumber(x, y, val, size + lflags + prec + LEFT)
	else
		lcd.drawText(x, y, "---", size + lflags)
	end

	if (size == MIDSIZE) then
		h = h + 4
	elseif (size == DBLSIZE) then
		h = h + 7
	elseif (size == SMLSIZE) then
		h = h - 1
	end
	
	x = lcd.getLastPos()
--	if (size > 0 and size ~= SMLSIZE) then
--		lcd.drawText(x, y - 1, "m", lflags + SMLSIZE)
--	end
	lcd.drawText(x, y + h - FH + 1, which, lflags + SMLSIZE)
	
	return lcd.getLastPos() - oX + 1, h
end

-- Draw GPS fix type indicator (none/2D/3D)
---> x, y : LCD coordinates at which to draw
-- returns:
---< w, h : width and height of resulting display in LCD pixels
local function drawGPSFix(x, y)
	if (aq.mav.gpsFix == nil or not aq.mav.isConnected) then
		lcd.drawText(x+2, y-1, "No", SMLSIZE)
		lcd.drawText(x, y+FH-1, "GPS", SMLSIZE)
	elseif (aq.mav.gpsFix == 3) then
		lcd.drawText(x, y, "3D", MIDSIZE + INVERS)
	elseif (aq.mav.gpsFix == 2) then
		lcd.drawText(x, y, "2D", MIDSIZE)
	else
		lcd.drawText(x+2, y-1, "No", SMLSIZE + BLINK)
		lcd.drawText(x, y+FH-1, "Fix", SMLSIZE + BLINK)
	end
	
	return lcd.getLastPos() - x + 1, FH + 4	-- w, h
end

local function drawGpsStatus(x, y)
	local lx, ly = x+3, y+2
	local w, h = drawGPSFix(lx, ly)
	lx = lx + w + 5
--	ly = ly + 1
	w, h = drawDop(lx, ly, "H", MIDSIZE, 2.5, 1)  -- flash when above 2.5m & 3D lock; inverse text when below 1m
	lx = lx + w + 3
	w = drawDop(lx, ly+3, "V", 0, 99, 1)  -- smaller text size, don't flash, inverse text when below 1m (zero to disable)
	
	--lcd.drawFilledRectangle(x, y, lx + w + 3 - x, ly + h + 2 - y, FILL_WHITE + GREY(8) + ROUND)
	lcd.drawRectangle(x, y, lx + w + 1 - x, ly + h + 2 - y)
end


-- Altitude and vertical speed --

local function drawAltitude(x, y)
	lcd.drawNumber(x + FW * 6 + 1, y, getValue(g_fld.alt) * 100, MIDSIZE + PREC2)
	lcd.drawText(lcd.getLastPos(), y + 5, "m", SMLSIZE)
end

local function drawVertSpeed(x, y, ind, size)
	size = size or 0
	local val = getValue(g_fld.vSpd)
	if (ind) then
		ind = "\126"
		if (val > 0) then
			ind = "\192"
		elseif (val < 0) then
			ind = "\193"
		end
		-- "fancier" arrows, redundant with vertical speed gauge
--		if (val > 1.5) then
--			ind = "\192"
--		elseif (val > 0) then
--			ind = "\194"
--		elseif (val < -1.5) then
--			ind = "\193"
--		elseif (val < 0) then
--			ind = "\195"
--		end
		lcd.drawText(x, y + 2, ind, 0)
		val = math.abs(val)
		x = lcd.getLastPos()
		if (size == 0) then
			x = x + 1
		else
			x = x + 4
		end 
	end
	if (size == 0) then
		y = y + 4
	end 
	lcd.drawNumber(x, y, val * 100, size + PREC2 + LEFT)
	x = lcd.getLastPos()
	if (size == 0) then
		y = y - 4
	else
		y = y - 1
	end 
	lcd.drawText(x, y, "m", SMLSIZE)
	lcd.drawText(x, y + 6, "s", SMLSIZE)
end

local function drawVSpeedGauge(x, y, r)
	local ang = getValue(g_fld.vSpd)
	ang = ang * VSPD_SCAL * -1
	ang = math.max(math.min(ang, 50), -50) + 90
	dlib.drawCircle(x, y, r, 45, 135, 5, 0)
	dlib.drawCircle(x, y, r-1, 45, 135, 15, 1)
	
-- drawArrow(x, y, a, s, t, l, xo, yo, sa)
---> x, y : center of virtual circle
---> a : angle from x,y to outer edge
---> s : tail width / 2
---> t : tail offset from center (indent/outdent), if any. 0 or 1 is no offset (flat tail), which is default
---> l : arrow length
---> xo : x offset for the whole arrow, defines arrow length
	dlib.drawArrow(x, y, ang, 2, 0, r, r / 2 + 1) -- fill: (ang < 90)
end


-- Distance to home and direction arrow --

-- Distance to home
local function drawDistance(x, y)
	local val, prec = dlib.adjustTo3Digits(getValue(g_fld.hmDist), PREC1)
	x = x + FW * 4
	if (prec == PREC1) then x = x + 2 end
	lcd.drawNumber(x, y, val, MIDSIZE + prec)
	lcd.drawText(lcd.getLastPos(), y + 5, "m", SMLSIZE)
end

-- Draws a direction arrow and degrees to/from one of several bearings
-- the bearing used is determined by DIR_TYPE variable, and toggled with [ENT] key
---> x, y : LCD coordinates at which to draw
---> d    : arrow length
local function drawDirectionArrow(x, y, d)
	local ang, lbl = -1, " to"
	if (DIR_TYPE == 5) then	-- magnetic heading
		ang = aq.mav.heading
	elseif (aq.mav.gpsFix > 2) then
		if (DIR_TYPE == 1) then	-- to mav
			ang =  aq.mav.brgFromHome
		elseif (DIR_TYPE == 2 or DIR_TYPE == 3) then	-- from mav or relative bearing
			ang = aq.mav.brgToHome
		elseif (DIR_TYPE == 4) then	-- gps course
			ang = getValue(g_fld.gpsCrs)
		end
	end
--	ang = math.fmod(getTime(), 360)  -- simulator

	if (ang == -1) then
		lcd.drawText(x, y-2, "X", 0)
	else
		if (DIR_TYPE == 3) then	-- relative bearing
			ang = getValue(g_fld.gpsCrs) - ang
		end
		ang = dlib.compassNormalize(dlib.round(ang))
		dlib.drawArrow(x, y, ang, 3, 5, d, 0, 0, 90)
	end
	y = y - 6
	x = x + d - 1
	if (ang == -1) then
		lcd.drawText(x, y, "---", 0)
	else
		lcd.drawNumber(x + (FW-1) * 3, y, ang, 0)
	end
	lcd.drawText(lcd.getLastPos(), y, "@", SMLSIZE)
	
	if (DIR_TYPE == 2) then	-- from mav
		lbl = "frm"
	elseif (DIR_TYPE == 3) then	-- relative bearing
		lbl = "rel"
	elseif (DIR_TYPE == 4) then	-- gps course
		lbl = "crs"
	elseif (DIR_TYPE == 5) then	-- magnetic heading
		lbl = "hdg"
	end
	lcd.drawText(x, y+FH, lbl, SMLSIZE)
end


----- Main functions --------

local function run(event)
	local x, y, colW, rowH, tmp

	if checkAQLibs() ~= 0 then
		return
	end
	
	-- button press handlers
	if (event == EVT_MENU_BREAK) then
		-- toggle power/current displays
		SHOW_CURR = not SHOW_CURR
	elseif (event == EVT_ENTER_BREAK) then
		-- cycle through different bearings for direction arrow
		DIR_TYPE = DIR_TYPE + 1
		if (DIR_TYPE > 5) then DIR_TYPE = 1 end
	end
	
	lcd.clear()
	
	-- Top line of screen with flight mode, timer, RSSI, etc.
	aq.drawTopPanel(PANEL_H, TIMID)
	-- Bottom line with latest text message, if any. Optional.
	aq.drawBottomPanel(PANEL_H, LMST)

	-- typical data display column width and row height to help line things up
	colW = FW * 6 + 3
	rowH = FH * 2 + 1
	
	-- first column
	
	x = 0
	y = PANEL_H
	-- Battery voltage (vfas)
	drawVoltage(x, y, "batt")
	y = y + rowH
	if (SHOW_CURR) then
		-- Amps
		drawCurrent(0, y, "current")
		y = y + rowH
		-- cumulative current draw in (m)Ah
		drawTotalCurrent(x + 1, y + 1)
	else
		-- Battery percent indicator (show this here if NOT showing amps/watts data)
		drawBatteryPercent(2, y, DBLSIZE)
		y = y + rowH
		dlib.drawPercentGraph(1, y, colW * 3 - 10, 9, aq.mav.battPercent, batPctFlashTim)
	end
	
	-- second column
	
	x = x + colW
	y = PANEL_H
	-- Voltage of lowest cell (or total V/cell count)
	drawVoltage(x, y, "cell")
	y = y + rowH
	if (SHOW_CURR) then
		-- Watts
		drawCurrent(x, y, "power")
		y = y + rowH
		-- Battery percent indicator (show this here if showing amps/watts data)
		drawBatteryPercent(x, y + 1, MIDSIZE)
		dlib.drawPercentGraph(lcd.getLastPos(), y + 4, colW * 2 - (FW) * 5 + 3, 9, aq.mav.battPercent, batPctFlashTim)
	end
	
	-- third column
	
	-- minimum/maximum values for voltages and current/power
	x = x + colW
	y = PANEL_H + 1
	dlib.drawMinMaxValue(x, y, "batt", "min")
	dlib.drawMinMaxValue(x, y + 8, "cell", "min")
	y = y + rowH + 1
	if (SHOW_CURR) then
		dlib.drawMinMaxValue(x, y, "current", "max")
		dlib.drawMinMaxValue(x, y + 8, "power", "max")
	end

	-- fourth column (right half of LCD)
	
	x = x + colW - 5 --(FW + 2) * 4
	y = PANEL_H
	
	-- vertical divider
	lcd.drawLine(x-3, y, x-3, LCD_H - PANEL_H - 1, DOTTED, GREY(3))
	
	-- GPS status box
	drawGpsStatus(x, y + 1)
	y = y + rowH + 2
	
	-- relative altitude
	drawAltitude(x, y)
	
	-- vertical speed
	drawVertSpeed(lcd.getLastPos() + 3, y, true, MIDSIZE)
	y = y + rowH
	
	-- distance to home
	x = x - 1
	lcd.drawText(x, y+FH/2, "D", 0)
	dlib.drawSkinnyColon(lcd.getLastPos(), y + FH / 2)
	x = lcd.getLastPos() + 2
	drawDistance(x, y)
	
	-- heading indicator with arrow and text
	drawDirectionArrow(lcd.getLastPos() + 9, y+3, 13)
	
	-- vertical speed gauge at right of screen
	drawVSpeedGauge(LCD_W - LCD_H / 2 - 1, LCD_H / 2, LCD_H/2)
	
	-- [ENT] button prompt
	lcd.drawText(LCD_W-4, LCD_H-PANEL_H-6, "C", TINSIZE)
	
end

return {run=run}
