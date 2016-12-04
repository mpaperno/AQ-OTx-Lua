--[[
	Telemetry messages display script for AutoQuad Telemetry Handler Component
	
	** Requires AQTelem.lua and DrawLib.lua installed in SCRIPTS/MIXES folder and activated in "Custom Scripts" settings the model.
	
	Also relies on some shared functions in telem1.lua script.
	
  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  A copy of the GNU General Public License is available at <http://www.gnu.org/licenses/>.

  Copyright (c)2015 by Maxim Paperno
  
  Parts inspired by/borrowed from:
  - http://diydrones.com/forum/topics/amp-to-frsky-x8r-sport-converter
  - https://github.com/chsw/MavLink_FrSkySPort
  - https://github.com/scottflys/mavsky 
  - https://github.com/wolkstein/MavLink_FrSkySPort
  - and others
	
  Many thanks to the OpenTx project and all predecessors!
  
]]


local TIMID = 1			-- Which timer to show on the top line, 1 or 2 (or 3 if firmware supports it).

local page = 1
local linesPerPage = 6
local showMsgAge = false
local invTim = 0
local lastMsgShown = 0
--local lastRunTime = 0

local PANEL_H = FH	-- pixel height of top panel (header)

TIMID = TIMID -1     -- actual timer index starts at zero

local function run(event)
	if checkAQLibs == nil or checkAQLibs() ~= 0 then
		return
	end

	if (aq.messages.count == nil or aq.messages.first == nil) then
		return
	end

	local age, showFirst, showLast, y, d, m, rowY, lflags
	local row = 0
	local showMin = false
	local maxPages = math.ceil((aq.messages.count + 1 - aq.messages.first) / linesPerPage)
	
	-- handle key press events
	---- long-press plus key to display earlier messages (if any)
	if (event == EVT_PLUS_REPT) then
		if (page < maxPages) then
			page = page + 1
		else
			invTim = getTime()
		end
		killEvents(event)
	---- long-press minus key to display later messages (if not on last page already)
	elseif (event == EVT_MINUS_REPT) then
		if (page > 1) then
			page = page - 1
		else
			invTim = getTime()
		end
		killEvents(event)
	---- quick press enter key to switch age/count
	elseif (event == EVT_ENTER_BREAK) then
		showMsgAge = not showMsgAge
	end
	
	showFirst = aq.messages.count + 1 - (linesPerPage * page)
	if (showFirst < aq.messages.first) then
		showFirst = aq.messages.first
	end
	showLast = showFirst + linesPerPage - 1
	if (showLast > aq.messages.count) then
		showLast = aq.messages.count
	end
	
	lcd.clear()
	aq.drawTopPanel(PANEL_H, TIMID)
	
	if (aq.messages.count > 0) then
		y,d = 8,9
		for i = showFirst, showLast, 1 do
			m = aq.getMessageAt(i)
			if (m ~= nil and m.msg ~= nil and m.msg ~= "") then
				lflags = 0
				showMin = false
				rowY = y + row * d
				if (showMsgAge) then
					age = dlib.round((getTime() - m.ts) * 0.01)
					if (age > 99) then
						age = dlib.round(age / 60)
						showMin = true
					end
				else
					age = i
				end
				lcd.drawText(0, rowY+4, age, TINSIZE+lflags)
				if (showMin) then
					lcd.drawText(lcd.getLastPos(), rowY+3, "m", SMLSIZE+lflags)
				end
				lcd.drawPoint(lcd.getLastPos(), rowY+8)
--				if (rawlen(m.msg) > 35) then 
--					lflags = lflags + SMLSIZE
--				end
				if (i == aq.messages.count) then
					lastMsgShown = i
				else
					lflags = lflags + SMLSIZE
				end
				if (m.pri < aq.c.SEV_NOTE) then
					lflags = lflags + INVERS
				end
				lcd.drawText(11, rowY+2, m.msg, lflags)
				row = row + 1
			end
		end
	else
		y, d = 10, 7
		lcd.drawText(5, y, "Text messages from AQ will appear here. Up\n", SMLSIZE)
		lcd.drawText(5, y+d, " to "..aq.messages.arrayMaxLen.." messages are stored, "..linesPerPage.." are displayed", SMLSIZE)
		lcd.drawText(5, y+d*2, " per screen. If more than "..linesPerPage.." are available,", SMLSIZE)
		lcd.drawText(5, y+d*3, " long-press the +/- keys to scroll up/down.", SMLSIZE)
		lcd.drawText(5, y+d*4, "Each messsage shows its sequence number", SMLSIZE)
		lcd.drawText(5, y+d*5, " next to it. Click [ENT] to show message", SMLSIZE)
		lcd.drawText(5, y+d*6, " age (in sec/min) instead.", SMLSIZE)
	end
	
	-- page indicators
	local tflags, bflags = 0, 0
	if ((getTime() - invTim < 200 or lastMsgShown < aq.messages.count) and math.fmod(getTime() - invTim, 50) < 25) then
		bflags = INVERS
		if (lastMsgShown == aq.messages.count) then
			tflags = INVERS
		end
	end
	local x,y = LCD_W-5, 10
	-- up arrow if more pages available
	if (maxPages > page or aq.messages.count == 0) then
		lcd.drawText(x, y, "\192", SMLSIZE+tflags)
	end
--	lcd.drawText(x+1, y+8, tostring(page), TINSIZE+tflags)
--	lcd.drawText(x,   y+8+6, "/", SMLSIZE+tflags)
--	lcd.drawText(x+1, y+8+6+5, tostring(math.max(1,maxPages)), TINSIZE+tflags)
--	y = y+8+6+5+7
	y = y + 15
	-- down arrow
	if (page > 1 or aq.messages.count == 0) then
		lcd.drawText(x, y, "\193", SMLSIZE+bflags)
	end
	
	-- age/count mode indicator
	local ind = "A"
	if (showMsgAge) then
		ind = "C"
	end
	lcd.drawText(x+1, LCD_H-12, ind, SMLSIZE)
	
--	if (event ~= 0) then
--		print(event)
--	end
	
end

return {run=run}
