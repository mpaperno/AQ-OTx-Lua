--[[

  == Telemetry field name mapping abstraction layer for OpenTX * 2.1 * series
  
  Provides constant names of telemetry values used in AutoQuad Lua scripts, regardless of OTx version.
  
  Load as a mixer script.
  
  In OTx 2.1+ all the telemetry field names can be changed, and in some cases the values must be created (calculated field).
  Also different languages may use entirely different field names.
  
  Instead of hunting all over the other scripts to change field names, they're all defined here in one place. To save precious memory, 
  only the fields we actually used are defined here.
  
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
	mainV   = "VFAS",
	mainA   = "Curr",
	mainW   = "Pwr",              -- calculated field (?)
	mainAh  = "mAh",              -- calculated field
	cellVlo = "CelL",             -- lowest cell value, calculated field
	
	txV     = "tx-voltage",
	rssi    = "RSSI",
	rpm     = "RPM",
	fuel    = "FUEL",             -- ?
	temp1   = "aqGS",             -- first temperature sensor (ID: 0x0400), contains GNSS status data
	temp2   = "aqST",             -- second temperature sensor (ID: 0x0410), contains various AQ status data
	
	alt     = "Alt",
	vSpd    = "VSpd",
	aSpd    = "ASpd",
	
	gpsSpd  = "GSpd",
	gpsAlt  = "GAlt",
	gpsCrs  = "GCrs",             -- default for this is apparently "Hdg" which is just "wrong" in many ways... :)
	
	hmDist  = "GDst",             -- distance to "home", calculated field (between GPS.lat/lon and GPS.pilot-lat/lon)
	
	-- suffix to append to string value name to get min/max
	sfxMin  = "-",
	sfxMax  = "+"
}

-- abstract getting GNSS lat/lon data.  eg:  gpsLat = g_fld.getGNSS("lat")
-- `field` should be one of:  "lat", "lon", "pilot-lat", or "pilot-lon"
g_fld.getGNSS = function(field)
	local ret = getValue("GPS")
	if (type(ret) == "table") then
		ret = ret[field]
	else
		ret = nil
	end
	return ret
end

local function run()
end

return {run=run}