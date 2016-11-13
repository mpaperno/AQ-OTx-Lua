--[[

  == Telemetry field name mapping abstraction layer for OpenTX * 2.0 * series
  
  Provides constant names of telemetry values used in AutoQuad Lua scripts, regardless of OTx version.
  
  Load as a mixer script.
  
  Usage:  g_fld.<name>   eg:  getValue(g_fld.rssi)
  
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

  Copyright (c)2016 by Maxim Paperno. All rights reserved.

]]

g_fld = {
	mainV   = "vfas",
	mainA   = "current",
	mainW   = "power",
	mainAh  = "consumption",
	cellVlo = "cell-min",             -- lowest cell value
	
	txV     = "tx-voltage",
	rssi    = "rssi",
	rpm     = "rpm",
	fuel    = "fuel",
	temp1   = "temp1",             -- first temperature sensor (ID: 0x0400), contains GNSS status data
	temp2   = "temp2",             -- second temperature sensor (ID: 0x0410), contains various AQ status data
	
	alt     = "altitude",
	vSpd    = "vertical-speed",
	aSpd    = "air-speed",
	
	gpsSpd  = "gps-speed",
	gpsAlt  = "gps-altitude",
	gpsCrs  = "heading",
	
	hmDist  = "distance",           -- distance to "home" (pilot-lat/lon)
	
	-- suffix to append to string value name to get min/max
	sfxMin  = "-min",
	sfxMax  = "-max"
}

-- abstract getting GNSS lat/lon data
-- `field` should be one of:  "lat", "lon", "pilot-lat", or "pilot-lon"
g_fld.getGNSS = function(field)
	local ret = 0
	if (field == "lat") then
		ret = getValue("latitude")
	elseif (field == "lon") then
		ret = getValue("longitude")
	elseif (field == "pilot-lat") then
		ret = getValue("pilot-latitude")
	elseif (field == "pilot-lon") then
		ret = getValue("pilot-longitude")
	end
	return ret
end

local function run()
end

return {run=run}