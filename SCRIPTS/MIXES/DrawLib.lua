--[[

  == Drawing Library (and other useful functions)
  
  This is a standalone library of various functions, mostly used to draw shapes on the LCD
  but also some rounding and calculations routines.
  
  Load as a mixer script.
  
  --------------
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

]]

-- Useful macros
FW 	= 6					-- Font text width (std size)
FH 	= 8					-- Font height (std size)

--EVT_ENTER_FIRST = 0x62	-- 2|0x60
--EVT_MENU_FIRST  = 0x60	-- 0|0x60

-- ASCII code mapping for char() function
local aMp = {
	" ","!",'"',"#","$","%","&","'","(",")","*","+",",","-",".","/",
	"0","1","2","3","4","5","6","7","8","9", ":",";","<","=",">","?","@",
	"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
	"[","\\","]","^","_","`",
	"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
	"{","|","}","~"
}


------- Utility functions

local function char(c)
	if tonumber(c) == nil or c < 32 then
		return ""
--	else
--		return "\0" .. c
	elseif c < 127 then
		return aMp[c-31]
	else
		return "_"
	end
end

local function round(n)
  return math.floor((math.floor(n*2) + 1) * 0.5)
end

local function adjForPrecision(v, p)
	if (p == 1) then 
		return v * 0.1
	elseif (p == 2) then 
		return v * 0.01
	elseif (p == 3) then 
		return v * 0.001
	else
		return v
	end
end

-- Adjust a given value's precision to make sure it fits into 3 display digits (and possibly a decimal point)
---> val : original value to adjust
---> prec : original precision (this decides which if we want to reduce or increase the returned precision)
-- Returns: 
---< new value, new precision, true/false flag indicating if magnitude was changed (eg. A to mA).
local function adjustTo3Digits(val, prec)
	local ret = false
	if (prec == PREC2) then
		if (val >= 10) then
			prec = PREC1
			val = round(val * 10)
		else
			val = val * 100
		end
	elseif (prec == PREC1) then
		if (val >= 100) then
			prec = 0
			val = round(val)
			ret = true
		else
			val = val * 10
		end
	elseif (prec == 0) then
		if (val > 9999) then
			val = val * 0.01
			prec = PREC1
			ret = true
		elseif (val > 999 ) then
			val = val * 0.1
			prec = PREC2
			ret = true
		end
	end
	return val, prec, ret
end

-- returns angle in degrees between given x/y coordinates
local function angleFromCoord(x1, y1, x2, y2)
	return math.deg(math.atan2(y2 - y1, x2 - x1))
end

local function compassNormalize(a)
	if a < 0 then
		a = a + 360
	elseif a >= 360 then
		a = a - 360
	end
	return a
end

-- Returns a new X, Y coordinate at given x,y location plus the given length offset by the given angle
local function getXYAtAngle(x, y, a, l)
	a = compassNormalize(a)
	return x + math.sin(math.rad(a)) * l, y - math.cos(math.rad(a)) * l
end

-- Calculate compass bearing between two cartesian points. Input lat/lon in degrees, returns bearing in degrees
-- ** This is expensive, don't do it too often! **
local function calcBearing(lat1, lon1, lat2, lon2)
	if (lat1 == lat2 and lon1 == lon2) then
		return -1
	end
	lat1, lon1, lat2, lon2 = math.rad(lat1), math.rad(lon1), math.rad(lat2), math.rad(lon2)
	local lat2c = math.cos(lat2)
	local e = math.sin(lon2 - lon1) * lat2c
	local n = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * lat2c * math.cos(lon2 - lon1)
	local brg = math.deg(math.atan2(e, n))

	return compassNormalize(brg)
end


----- Drawing functions for telemetry scripts ---

local function drawSkinnyColon(x, y, flags)
	flags = flags or 0
	y = y + 2
	lcd.drawPoint(x, y)
	y = y + 3
	lcd.drawPoint(x, y)
end

--local function drawLineAtAngle(x, y, r1, r2, a)
--	lcd.drawLine(getXYAtAngle(x, y, a, r1), getXYAtAngle(x, y, a, r2), SOLID, FORCE)
--end

-- Draw a full or partial circle of dots or lines
---> x, y : center coordinates
---> r : radius in pixels
---> fr, to : draw only from/to degrees of the circle (eg. 0, 360 to draw a full circle, 0, 180 for half circle, etc). Default: 0 and 359
---> n : frequency of dots/lines in degrees. Default: 15
---> l : length of dot/line. null or zero to draw a dot, positive value draws a line (tick mark) of that length from outer point towards center of circle. Default: 0
---> solid : (true/false) draw a solid circle, not just dots. Resolution ("roundness") of circle depends on n (frequency) parameter. Default: false
local function drawCircle(x, y, r, fr, to, n, l, solid)
	fr = fr or 0
	to = to or 359
	n = n or 15
	l = l or 0
	local px, py, lx, ly, ra, c, s
	fr, to = fr - 90, to - 90
	for a = fr, to, n do
		ra = math.rad(a)
		c = math.cos(ra)
		s = math.sin(ra)
		px = x + r * c
		py = y + r * s
		if (l > 0) then
			lx = x + (r-l) * c
			ly = y + (r-l) * s
			lcd.drawLine(lx, ly, px, py, SOLID, FORCE)
		end
		if (solid and a ~= to) then
			ra = math.rad(a + n)
			c = math.cos(ra)
			s = math.sin(ra)
			lx = x + r * c
			ly = y + r * s
			lcd.drawLine(px, py, lx, ly, SOLID, FORCE)
		elseif (l == 0) then
			lcd.drawPoint(px, py)
		end
	end
end

---> x, y : center of virtual circle
---> a : angle from x,y
---> s : tail width / 2
---> t : tail offset from center (indent/outdent), if any. 0 or 1 is no offset (flat tail), which is default
---> l : arrow length
---> xo, yo : x and y offsets for the whole arrow (zero for none). arrow length must be > offset
---> sa : tail offset-to-side angle
---- f : fill true/false *not working!*
local function drawArrow(x, y, a, s, t, l, xo, yo, sa) --, f
	s = s or 5
	t = t or 0
	l = l or 16
	xo = xo or 0
	yo = yo or 0
	sa = sa or 90
	
	local xTail, yTail = getXYAtAngle(x, y, a - 180, t)
	local xLeft, yLeft = getXYAtAngle(xTail, yTail, a - sa, s)
	local xRight, yRight = getXYAtAngle(xTail, yTail, a + sa, s)
	local xNose, yNose = getXYAtAngle(xTail, yTail, a, l)
	
	if (xo ~= 0 or xy ~= 0) then
		xLeft, yLeft = xLeft + xo, yLeft + yo
		xRight, yRight = xRight + xo, yRight + yo
		xTail, yTail = xTail + xo, yTail + yo
	end
	
	if (t > 1 and sa ~= 90) then
		lcd.drawLine(xTail, yTail, xLeft, yLeft, SOLID, FORCE)
		lcd.drawLine(xTail, yTail, xRight, yRight, SOLID, FORCE)
	else
		lcd.drawLine(xLeft, yLeft, xRight, yRight, SOLID, FORCE)
	end
	lcd.drawLine(xLeft, yLeft, xNose, yNose, SOLID, FORCE)
	lcd.drawLine(xRight, yRight, xNose, yNose, SOLID, FORCE)
	
--	if (f) then
--		x, y = 0, 0
--		a = angleFromCoord(xLeft, yLeft, xRight, yRight) + 90
--		lcd.drawText(5, 5, a, SMLSIZE)
--		for i=1, s * 2, 1 do
--			xTail, yTail = getXYAtAngle(xLeft, yLeft, a, i)
--			xTail, yTail = round(xTail), round(yTail)
--			if (xTail ~= x or yTail ~= y) then
--				lcd.drawLine(xTail, yTail, xNose, yNose, SOLID, FORCE)
--				lcd.drawText(5, 5 + (i*6), xTail.." "..yTail, SMLSIZE)
--				x, y = xTail, yTail
--			end
--		end
--	end
end

-- Draw a status bar style graph indicating percentage (or whatever). The bar is divided into 4 sections of slightly different shades.
-- The bar can be vertical or horizontal, depending on which dimension is larger.
-- If a time value is passed in the last argument, and value is <= 25%, the status bar will blink
---> x, y, w, h : position and size of graph
---> val : the value to show (bar is this much "full")
---> tim : a time value to use as comparison to current time to decide if bar should blink
local function drawPercentGraph(x, y, w, h, val, tim)
	local vert = (h > w)
	local scale, slen, shade
	local oX, oY = x, y
	if (vert) then
		scale = h / 100
	else
		scale = w / 100
	end
	slen = math.floor(scale * 25)
	if (vert) then
		-- vertical version with end caps
		--lcd.drawRectangle(x, y, w, slen * 4 + 2)
		--x, y, h, w, oY = x+1, y+1, h-2, w-2, oY+1
		-- version w/out end caps
		lcd.drawLine(x, y, x, y + slen * 4 - 1, SOLID, 0)
		lcd.drawLine(x + w - 1, y, x + w - 1, y + slen * 4 - 1, SOLID, 0)
		x, w = x+1, w-2
	else
		lcd.drawRectangle(x, y, slen * 4 + 2, h)
		x, y, h, w, oY = x+1, y+1, h-2, w-2, oY+1
	end
	if (val) then
		val = math.min(math.max(val, 0), 100)
		-- draw 25%/50%/75%/100% background gradient
		if (vert) then
			y = y + h - slen
		end
		for i = 1, 4 do
			if (tim and i == 1 and math.fmod(getTime() - tim, 120) < 60) then
				shade = 8
			else
				shade = 4 - i
			end
			if (vert) then
				lcd.drawFilledRectangle(x, y, w, slen, GREY(shade))
				y = y - slen
			else
				lcd.drawFilledRectangle(x, y, slen, h, GREY(shade))
				x = x + slen
			end
		end
		-- now "erase" the used percentage
		slen = round(100 * scale - val * scale)
		if (vert) then
			lcd.drawFilledRectangle(oX + 1, oY, w, math.min(h, slen), ERASE)
		else
			slen = math.min(w, slen)
			lcd.drawFilledRectangle(x - slen, oY, slen, h, ERASE)
		end
	-- no valid value
	else
		if (vert) then
			for i, v in ipairs({"n","o"," ","d","a","t","a"}) do
				lcd.drawText(x+1, y, v, SMLSIZE)
				y = y + FH-2
				if (y + FH - 1 > oY + h) then
					break
				end
			end
		else
			lcd.drawText(x + w / 2 - (FW-1) * 3, y, "no data", SMLSIZE)
		end
	end
end

-- draw minimum/maximum values for vfas/cell-min/current/power
----> x,y : LCD coordinates at which to draw
----> val : name of value to draw, one of:  "batt", "cell", "current", "power"
----> which : which value to draw: "min" or "max"
----> size : font size, one of : 0 (default), SMLSIZE, MIDSIZE, DBLSIZE
local function drawMinMaxValue(x, y, val, which, size)
	size = size or 0
	local prec = PREC1
	local unit = "v"
	local lval = val
	local a = false
	if (val == "batt") then
		lval = g_fld.mainV
	elseif (val == "cell") then
		lval = g_fld.cellVlo
		prec = PREC2
		unit = "cv"
	elseif (val == "current") then
		lval = g_fld.mainA
		unit = "A"
	elseif (val == "power") then
		lval = g_fld.mainW
		prec = 0
		unit = "w"
	end
	if (which == "min") then
		lval = lval .. g_fld.sfxMin
		lcd.drawText(x, y, "\193", SMLSIZE)
	else
		lval = lval .. g_fld.sfxMax
		lcd.drawText(x, y, "\192", SMLSIZE)
	end
	lval = getValue(lval)
	lval, prec, a = adjustTo3Digits(lval, prec)
	if (a) then
		if (unit == "w") then
			unit = "kW"
		elseif (unit == "A") then
			unit = "mA"
		elseif (unit == "v") then
			unit = "mV"
		end
	end
	lcd.drawNumber(lcd.getLastPos(), y, lval, prec + size + LEFT)
	if (size == MIDSIZE) then
		y = y + 5
	elseif (size == DBLSIZE) then
		y = y + 9
	elseif (size == 0) then
		y = y + 1
	end
	lcd.drawText(lcd.getLastPos(), y, unit, SMLSIZE)
end


dlib = {
	char					= char,
	round					= round,
	adjForPrecision	= adjForPrecision,
	adjustTo3Digits   = adjustTo3Digits,
	compassNormalize  = compassNormalize,
	getXYAtAngle      = getXYAtAngle,
	angleFromCoord    = angleFromCoord,
	calcBearing			= calcBearing,
	drawSkinnyColon   = drawSkinnyColon,
	drawCircle        = drawCircle,
	drawArrow         = drawArrow,
	drawPercentGraph  = drawPercentGraph,
	drawMinMaxValue   = drawMinMaxValue,
}

local function run()
end

return {run=run}