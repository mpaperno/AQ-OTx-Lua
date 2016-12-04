--[[
	Telemetry values debug script for AutoQuad Telemetry Handler Component
	
	** Requires AQTelem.lua installed in SCRIPTS/MIXES folder and activated in "Custom Scripts" settings the model.
	
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

local debugLabelWidth = 60
local debugRowHeight = 7
local debugColWidth = 70
local nextCol = 1
local nextRow = 1

local function printData(label, val)
	if (val ~= nil and tonumber(val) == nil) then
		val = getValue(val)
	end
	if (val == nil) then
		val = "nil"
	end
	local x = (nextCol - 1) * debugColWidth
	local y = nextRow * debugRowHeight - 6
	lcd.drawText(x, y, label, SMLSIZE)
	lcd.drawText(x + debugLabelWidth - 20, y, val, SMLSIZE)
	if (nextRow < 9) then nextRow = nextRow + 1 end
end

local function printNum(label, val, precision)
	if (val ~= nil and tonumber(val) == nil) then
		val = getValue(val)
	end
	if (val ~= nil) then
		val = math.floor(val * precision) / precision
	end
	printData(label, val)
end

local function run(event)
	if checkAQLibs == nil or checkAQLibs() ~= 0 then
		return
	end
	local ver, vradio, vmaj = getVersion()
	
	lcd.clear()
	
	nextRow = 1
	nextCol = 1
	if (vmaj == nil) then  -- OTx 2.0.x
		printData("dte", "dte")
	--	printData("a1", "a1")
		printData("a2", "a2")
		printData("a3", "a3")
		printData("a4", "a4")
		printData("accx", "accx")
		printData("accy", "accy")
		printData("accz", "accz")
	
		nextRow = 1
		nextCol = 2
	end
	
--	printData("current", "current")
--	printData("msgcnt", aq.messages.count)
--	printData("fuel", "fuel")
	printNum("lat", g_fld.getGNSS("lat"), 10000)
	printNum("long", g_fld.getGNSS("lon"), 10000)
	printData("gps-alt", g_fld.gpsAlt)
	printData("gps-spd", g_fld.gpsSpd)
	printData("air-spd", g_fld.ASpd)
	printData("gps-crs", g_fld.gpsCrs)
	printData("distance", g_fld.hmDist)
	printData("alt", g_fld.alt)
	printData("vert-spd", g_fld.vSpd)

	nextRow = 1
	nextCol = 3
	printData("temp1", g_fld.temp1)
	printData("temp2", g_fld.temp2)
	printData("rpm", g_fld.rpm)
	printData("stat", aq.mav.statusFlags)
	printData("hdng", aq.mav.heading)
	printData("imu-tmp", aq.mav.imuTemp)
	printData("batt%", aq.mav.battPercent)
	printData("wp#", aq.mav.wptNum)
	printData("wp-dist", aq.mav.wptDist)

--	printData("curr-max", "current-max")
--	printData("consump", "consumption")
--	printData("dte", "dte")

end

return {run=run}
