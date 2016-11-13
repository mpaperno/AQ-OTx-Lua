--[[

	== AutoQuad Telemetry Handler Component
	
	To be used with custom AQ-to-S.Port telemetry conversion systems.
	

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

 	Three outputs from this script are available as [i] Inputs in OpenTx for various things like logic switches, etc.
 	These can be used to set up audio alerts, eg. to announce flight mode or battery remaining percent.
 	Due to how OpenTx works, the outputs are expressed as percentages in the range of -100 to +100.

	For ALL outputs:
		-100% = not connected
		- 75% = no data (connection lost)

	mSTS -- MAV Status: 
		- 50% = critical (eg. battery)
		- 25% = disarmed
		   0% = armed
		+ 10% = active/flying manual mode
		+ 20% = altitude hold
		+ 30% = position hold
		+ 40% = mission mode
		+ 50% = guided mode
		
	gSTS -- GPS Status: 
		   0% = searching 
		+ 25% = 2D Fix
		+ 50% = 3D Fix
		+ 75% = Horizontal accuracy < 1m
		+100% = Vertical accuracy < 1m.
		
	bPCT -- Battery Remaining percent: 
		0% - 100% = actual reported value from MAV. Could be negative if voltage is below safety threshold.
		
	mEVT -- MAV Events: TODO
		
]]

-- local settings
local s = {
	hbTimeout = 5,       -- seconds w/out system status packet before link is considered lost
	brgUpdtIntvl = 3000  -- update bearing to/from MAV every this many ms
}

local outputs = {
	"mSTS",  -- Mav Status
	"gSTS",  -- GPS Status
	"bPCT"   -- Battery Remaining percent
}

-- this data is parsed and collected in the background, not available with regular openTx.getValue()
-- you can use these values directly with aq.mav.<var>
local mavData = {
	hasConnected = false,  -- Has connected at all
	isConnected = false,   -- Is currently connected
	lastHeard = 0,         -- Timestamp of last heartbeat received
	gpsHdop = nil,         -- Horizontal GPS accuracy in meters
	gpsVdop = nil,         -- Vertical GPS accuracy in meters
	gpsFix = 0,            -- GPS fix type: 0=none, 2=2D, 3=3D
--	gpsSats = 255,         -- GPS satellites visible (not used with AQ)
	heading = -1,          -- Actual yaw heading, not GPS course, if available
	battPercent = nil,     -- Battery percent remaining as reported by MAV
	imuTemp = nil,         -- Temperature reported by MAV
	wptNum = 0,            -- Next waypoint number, if any
	wptDist = 0,           -- Next waypoint distance
	brgToHome = -1,        -- Bearing to home position in compass degrees
	brgFromHome = -1,      -- Bearing from home position in compass degrees
	statusFlags = 0,       -- 32 bit array of status indicators (AQ_NAV_STATUS_xxx enumeration). Use getStatus() function to get textual status.
}

-- used for text messages parsing and storage
-- you can use these values directly with aq.messages.<var>
local msgs = {
	count = 0,        -- total messages received
	first = 0,        -- id of first available message in buffer
	latestTS = 0,     -- timestamp of last message received
	arrayMaxLen = 15,	-- maximum number of messages stored
	buff = "",        -- buff to store incoming characters (internal use)
	buffPrev = 0,     -- (internal use)
	priority = 5,     -- default priority (internal use)
	array = {}        -- array of messages (of message_t) (internal use)
}

-- constants
-- you can use these values directly with aq.c.<var>
local c = {
	-- Local constants
	ST_NO_CONN 	= 0,		-- never connected
	ST_CONN_LOST 	= 1,		-- connection lost
	
	---- Custom mode  AQ_NAV_STATUS enum. This represents the meanings for aq.mav.statusFlags variable.
	------ low bits hold flightmode
	AQST_INIT    = 0,             -- System is initializing
	AQST_SB      = 0x00000001,    -- b00 System is *armed* standing by, with no throttle input and no autonomous mode
	AQST_ACT     = 0x00000002,    -- b01 Flying (throttle input detected), assumed under manual control unless other mode bits are set
	AQST_AH      = 0x00000004,    -- b02 Altitude hold engaged 
	AQST_PH      = 0x00000008,    -- b03 Position hold engaged 
	AQST_GDED    = 0x00000010,    -- b04 Guided mode
	AQST_MISN    = 0x00000020,    -- b05 Autonomous mission execution mode
   AQST_LRTE    = 0x00000040,    -- b06 Manual limited rate-control mode is active
   AQST_RATE    = 0x00000080,    -- b07 Manual full rate-control "acro" mode is active
	
	AQST_RDY     = 0x00000100,    -- b08 Ready but *not armed*
	AQST_CAL     = 0x00000200,    -- b09 Calibration mode active
	
	AQST_NO_RC   = 0x00001000,    -- b12 No valid control input (eg. no radio link)
	AQST_FLO     = 0x00002000,    -- b13 Battery is low (stage 1 warning)
	AQST_FCRIT   = 0x00004000,    -- b14 battery is depleted (stage 2 warning)
	
	------ high bits hold flight modifiers
   AQST_SIM     = 0x00800000,    -- b23 HIL/SIL Simulator mode active
	AQST_DVH     = 0x01000000,    -- b24 Dynamic Velocity Hold is active
	AQST_DAO     = 0x02000000,    -- b25 Dynamic Altitude Override is active (AH with proportional manual adjustment)
	AQST_ATCEIL  = 0x04000000,    -- b26 Craft is at ceiling altitude
	AQST_CEIL    = 0x08000000,    -- b27 Ceiling altitude is set
	AQST_HF_D    = 0x10000000,    -- b28 Heading-Free dynamic mode active
	AQST_HF_L    = 0x20000000,    -- b29 Heading-Free locked mode active
	AQST_RTH     = 0x40000000,    -- b30 Automatic Return to Home is active
	AQST_FAIL    = 0x80000000,    -- b31 System is in failsafe recovery mode
	
	---- Message status (we only use a few)  MAV_SEVERITY enum
--	SEV_EMERCY	 = 0,	-- System is unusable. This is a "panic" condition. 
--	SEV_ALERT	 = 1,	-- Action should be taken immediately. Indicates error in non-critical systems.
	SEV_CRIT	    = 2,	-- Action must be taken immediately. Indicates failure in a primary system.
--	SEV_ERR      = 3,	-- Indicates an error in secondary/redundant systems.
	SEV_WARN	    = 4,	-- Indicates about a possible future error if this is not resolved within a given timeframe. Example would be a low battery warning.
	SEV_NOTE     = 5,	-- An unusual event has occurred, though not an error condition. This should be investigated for the root cause.
	SEV_INFO	    = 6,	-- Normal operational messages. Useful for logging. No action is required for these messages.
--	SEV_DBG      = 7,	-- Useful non-operational messages that can assist in debugging. These should not occur during normal operation.
}

-- system condition status bitmask
c.AQ_MSK_STAT = bit32.bor(bit32.bor(bit32.bor(c.AQST_SB, c.AQST_INIT), c.AQST_CAL), c.AQST_RDY)
-- flight modes status bitmask
c.AQ_MSK_FMOD = bit32.bor(bit32.bor(bit32.bor(bit32.bor(c.AQST_ACT, c.AQST_AH), c.AQST_PH), c.AQST_MISN), c.AQST_GDED)
-- critical alert status bitmask
c.AQ_MSK_CRIT = bit32.bor(bit32.bor(c.AQST_FCRIT, c.AQST_FAIL), c.AQST_NO_RC)


-- Following are text values for various status conditions, flight modes, flight modifiers, etc.
-- These are not exported, only used internally.  This is what getStatus() uses to return text descriptions.

-- connection status
local sN = {}
sN[c.ST_NO_CONN]   = "AQTelem - WAITING"
sN[c.ST_CONN_LOST] = "CONN LOST"

-- system status
local sF = {}
sF[c.AQST_INIT]    = "Sys Init"
sF[c.AQST_CAL]     = "Calibrating"
sF[c.AQST_RDY]     = "Disarmed"
sF[c.AQST_SB]      = "ARMED"

-- flight mode
local mF = {}
mF[c.AQST_ACT]     = "MANUAL"
mF[c.AQST_AH]      = "ALT Hold"
mF[c.AQST_PH]      = "POS Hold"
mF[c.AQST_GDED]    = "Guided"
mF[c.AQST_MISN]    = "Mission"

-- flight/mode modifiers and critical flags
local fF = {}
fF[c.AQST_LRTE]    = "LTD-ACRO"
fF[c.AQST_RATE]    = "ACRO"
fF[c.AQST_NO_RC]   = "NO RC"
fF[c.AQST_FLO]     = "BAT-LO"
fF[c.AQST_FCRIT]   = "BAT-CRIT"
fF[c.AQST_SIM]     = "SIM"
fF[c.AQST_DVH]     = "DVH"
fF[c.AQST_DAO]     = "DAO"
fF[c.AQST_ATCEIL]  = "AT-"
fF[c.AQST_CEIL]    = "CEIL"
fF[c.AQST_HF_D]    = "HF-D"
fF[c.AQST_HF_L]    = "HF-L"
fF[c.AQST_RTH]     = "RTH"
fF[c.AQST_FAIL]    = "FAILSF"


----- Functions -------

-- a message type object
local message_t = function()
	return {
		ts = 0,            -- timestamp
		pri = c.SEV_INFO,  -- priority enum
		msg = ""
	}
end

local function init()
	-- init messages array
	for i=1, msgs.arrayMaxLen do
		msgs.array[i] = message_t()
	end
	
	-- adjust for system timer in 10ms increments
	s.hbTimeout = s.hbTimeout * 100
	s.brgUpdtIntvl = s.brgUpdtIntvl / 10
end

----- Incoming data parsers -----------

-- Parse FUEL data type for system status/flight mode
local function setMavStatus()
	local v = getValue(g_fld.fuel)
	local i = bit32.band(bit32.rshift(v, 14), 0x3)
	local t = mavData.statusFlags
	
	if (i == 0) then
		t = bit32.band(t, 0xFFFFC000)
	elseif (i == 1) then
		t = bit32.band(t, 0xF0003FFF)
	elseif (i == 2) then
		t = bit32.band(t, 0x0FFFFFFF)
		mavData.lastHeard = getTime()
		mavData.hasConnected = true
	else
		return
	end
	v = bit32.lshift(bit32.band(v, 0x3FFF), i * 14)
	mavData.statusFlags = bit32.bor(t, v)
	
end

-- Parse TEMP1 data type for GPS fix type and DOPs
local function setGpsStatus()
	local val = getValue(g_fld.temp1)
	local temp = bit32.rshift(val, 14)
	local idx = bit32.band(temp, 0x3)
	
	temp = bit32.rshift(val, 12)
	mavData.gpsFix = bit32.band(temp, 0x3)
	temp = bit32.band(val, 0xFFF)
	if (idx == 0) then
		mavData.gpsHdop = temp * 0.01
	elseif (idx == 1) then
		mavData.gpsVdop = temp * 0.01
	elseif (idx == 2) then
		mavData.gpsSats = temp
	end
end

-- various values sent as Temperature 2.
local function setT2Values()
	local val = getValue(g_fld.temp2)
	local temp = bit32.rshift(val, 13)
	local idx = bit32.band(temp, 0x7)
	
	temp = bit32.band(val, 0x1FFF)
	if (idx == 0) then
		mavData.heading = temp * 0.1
	elseif (idx == 1) then
		mavData.imuTemp = temp * 0.1
	elseif (idx == 2 and temp ~= -1) then
		mavData.battPercent = temp
	elseif (idx == 3) then
		mavData.wptNum = temp
	elseif (idx == 4) then
		temp = bit32.rshift(val, 11)
		mavData.wptDist = dlib.adjForPrecision(bit32.band(val, 0x7FF), bit32.band(temp, 0x3))
	end
end

-- Update bearing to/from MAV
-- ** This is expensive, don't do it too often! **
local function setMavBearing()
	mavData.brgFromHome = dlib.calcBearing(g_fld.getGNSS("pilot-lat"), g_fld.getGNSS("pilot-lon"), g_fld.getGNSS("lat"), g_fld.getGNSS("lon"))
	mavData.brgToHome = mavData.brgFromHome - 180
	if mavData.brgToHome < 0 then
		mavData.brgToHome = mavData.brgToHome + 360
	end
end

----- Message functions --------

local function messageContentCheck()
	if (rawlen(msgs.buff) < 8) then
		if (msgs.priority < c.SEV_CRIT and msgs.buff == "Error") then
			msgs.priority = c.SEV_CRIT
		elseif (msgs.priority < c.SEV_WARN and msgs.buff == "Warning") then
			msgs.priority = c.SEV_WARN
		end
	end
end

-- Text messages sent 2 bytes at a time via RPM value
local function getTextMessage()
	local messageWord, highByte, lowByte
	local msg = ""
	messageWord = getValue(g_fld.rpm)

	if messageWord ~= msgs.buffPrev then
		highByte = bit32.rshift(messageWord, 8) -- use >>7 if RPM is set to 2 blades (LSB gets lost)
		highByte = bit32.band(highByte, 127)
		lowByte = bit32.band(messageWord, 127)

		if highByte ~= 0 then
			if highByte >= 48 and highByte <= 55 and msgs.buff == "" then
				msgs.priority = highByte - 48
				-- FIXME: AQ reports zero severity by default. To be fixed in AQ fw, but for now translate that to "notice" severity
				if (msgs.priority == 0) then
					msgs.priority = c.SEV_NOTE
				end
			else
				msgs.buff = msgs.buff .. dlib.char(highByte)
				messageContentCheck()
			end
			if lowByte ~= 0 then
				msgs.buff = msgs.buff .. dlib.char(lowByte)
				messageContentCheck()
			end
		end
		if highByte == 0 or lowByte == 0 then
			msg = msgs.buff
			msgs.buff = ""
			collectgarbage()
		end
		msgs.buffPrev = messageWord
	end
	return msg
end

local function checkForNewMessage()
	local temp = getTextMessage()
	if temp ~= "" then
		msgs.count = msgs.count + 1
		local idx = (msgs.count % msgs.arrayMaxLen) + 1
		msgs.array[idx].msg = temp
		msgs.array[idx].pri = msgs.priority
		msgs.array[idx].ts = getTime()
		msgs.latestTS = msgs.array[idx].ts
		msgs.priority = message_t().pri
      if (msgs.count - msgs.first) >= msgs.arrayMaxLen then
			msgs.first = msgs.count - msgs.arrayMaxLen + 1
		elseif msgs.first == 0 then
			msgs.first = 1
		end
	end
end

local function getMessageAt(n)
	local ret = message_t()
	if msgs.count >= n then
		ret = msgs.array[n % msgs.arrayMaxLen + 1]
	end
	return ret
end

local function getLatestMessage()
	local ret = message_t()
	if msgs.count > 0 then
		ret = msgs.array[(msgs.count % msgs.arrayMaxLen) + 1]
	end
	return ret
end

----- Getters --------------------------

-- returns {code, text, {flags}} where 
---< code: 0=ok/unknown, 1=warning, 2=error; 
---< text: primary flight mode or error text; 
---< flags: zero or more texts with extra status info (heading-free, RTH, failsafe, etc) from flightFlags{}
local function getStatus()
	local code = 0
	local flags = {}
	local txt = sN[c.ST_NO_CONN]
	local b
	
	-- set the overall mode text
	if (not mavData.hasConnected) then
		code = 1
	elseif (mavData.hasConnected and not mavData.isConnected) then
		code = 2
		txt = sN[c.ST_CONN_LOST]
	else
		txt = sF[c.AQST_INIT]
		for i=0, 31, 1 do
			b = bit32.lshift(1, i)
			if (bit32.band(mavData.statusFlags, b) > 0) then
				if (bit32.band(c.AQ_MSK_STAT, b) > 0 and sF[b] ~= nil) then
					txt = sF[b]
				elseif (bit32.band(c.AQ_MSK_FMOD, b) > 0 and mF[b] ~= nil) then
					txt = mF[b]
				elseif (fF[b] ~= nil) then
					flags[#flags+1] = fF[b]
				else
					flags[#flags+1] = "UNK" .. i
				end
			end
		end
	end

	-- check for warnings
	if (code < 2 and mavData.hasConnected) then
		if (bit32.band(mavData.statusFlags, c.AQ_MSK_CRIT) > 0) then
			code = 2
		---- warn if battery low or ceiling reached
		elseif (bit32.band(mavData.statusFlags, c.AQST_ATCEIL) > 0 or bit32.band(mavData.statusFlags, c.AQST_FLO) > 0) then
			code = 1
		end
	end
	
	return code, txt, flags
end

local function getDop(which)
	if (which == "H") then
		return mavData.gpsHdop
	else
		return mavData.gpsVdop
	end
end

----- Drawing functions for telemetry scripts ---
-- TODO: these don't really belong here...

-- Top and bottom panels. 

local function drawTopPanel(h, timid)
	local ff = 0
	local y = 0
	local x
	local lflags = INVERS
	local scode, stxt, sflags = aq.getStatus()  --{code = 0, txt = "POS Hold", flags={"HF-L", "CEIL"}} -- 
	
	lcd.drawFilledRectangle(0, y, LCD_W, h, 0)

	-- main status text (blink if important)
	if (scode == 2) then
		lflags = lflags + BLINK
	end
	lcd.drawText(1, y, stxt, lflags)
	
	-- flight mode flags, like heading-free mode, ceiling, failsafe
	lflags = lflags + SMLSIZE
	for i, v in ipairs(sflags) do
		if v ~= nil then
			if (ff == 0) then
				lcd.drawText(lcd.getLastPos()+2, y+1, "+", lflags)
				ff = 1
			end
			lcd.drawText(lcd.getLastPos()+2, y + 1, v, lflags)
		end
	end
	
	-- draw timer
	x = LCD_W - 99
	if (x > lcd.getLastPos()) then
		-- if we have the space, draw timer label
		lcd.drawText(x, y+1, "T"..(timid+1), INVERS + SMLSIZE)
		dlib.drawSkinnyColon(lcd.getLastPos(), y);
		x = lcd.getLastPos() + 3
	else
		x = LCD_W - 85
	end
	lcd.drawTimer(x, y, model.getTimer(timid).value, INVERS)
	
	-- Tx voltage
	lcd.drawText(lcd.getLastPos() + 4, y+1, "TX", INVERS + SMLSIZE)
	dlib.drawSkinnyColon(lcd.getLastPos(), y);
	lcd.drawNumber(lcd.getLastPos()+3, y, getValue(g_fld.txV)*10, PREC1+INVERS+LEFT)
	lcd.drawText(lcd.getLastPos(), y+1, "v", INVERS + SMLSIZE)
	
	-- Rx RSSI
	lcd.drawText(LCD_W-25, y+1, "RS", INVERS + SMLSIZE)
	dlib.drawSkinnyColon(lcd.getLastPos(), y);
	lcd.drawNumber(LCD_W, y, getValue(g_fld.rssi), INVERS)
end

-- these 2 are used by drawBottomPanel() to keep track of flashing important messages
local msgFlashTim = false
local msgFlashNum = 0
local function drawBottomPanel(h, msgTO)
	local lflags = INVERS
	local y = LCD_H - h
	
	-- draw background rectangle, possibly alternating between filled and transparent for flash effect
	if (msgFlashTim and getTime() - msgFlashTim < 400 and math.fmod(getTime() - msgFlashTim, 50) < 25) then
		lflags = 0
		lcd.drawRectangle(0, y, LCD_W, h, 0)
	else
		lcd.drawFilledRectangle(0, y, LCD_W, h, 0)
	end

	-- Text may be connection warning or the latest text message received
	if (getValue(g_fld.rssi) < 20) then
		lcd.drawText(LCD_W / 2 - FW * 4, y + 1, "NO DATA", BLINK)
	elseif (aq.mav.hasConnected and not aq.mav.isConnected) then
		lcd.drawText(LCD_W / 2 - FW * 7, y + 1, "NO CONNECTION", BLINK)
	elseif (aq.messages.latestTS > 0 and getTime() < (aq.messages.latestTS + msgTO)) then
		local m = nil
		m = aq.getLatestMessage()
		if (m ~= nil and m.msg ~= nil and m.msg ~= "") then
			if (m.pri < aq.c.SEV_NOTE and msgFlashNum ~= aq.messages.count) then
				msgFlashTim = getTime()
				msgFlashNum = aq.messages.count
			end
			lcd.drawText(0, y + 3,  dlib.round((getTime() - m.ts) * 0.01), lflags + TINSIZE)
			lcd.drawText(10, y + 1, m.msg, lflags)
		end
	end
end


----- Define the "aq" object. ---

aq = {
	-- variables
	mav 		= mavData,
	messages = msgs,
	c			= c,
	-- functions
	getMessageAt 		= getMessageAt,
	getLatestMessage 	= getLatestMessage,
	getStatus			= getStatus,
	getDop				= getDop,
	drawTopPanel      = drawTopPanel,
	drawBottomPanel   = drawBottomPanel,
}

----- Main run() function ---

local brgCalcTimer = 0
local function run()
	local now = getTime()
	
	setMavStatus()
	checkForNewMessage()

	mavData.isConnected = (now - mavData.lastHeard < s.hbTimeout) or SIM

	-- default not connected
	local stat = -FULLSCALE
	local gstat = -FULLSCALE
	local bstat = -FULLSCALE
	-- if has connected then default to no data
	if (mavData.hasConnected) then
		stat = -FULLSCALE * 0.75
		gstat = stat
		bstat = stat
	end

	if (mavData.isConnected) then
		setGpsStatus()
		setT2Values()
		
		if (now - brgCalcTimer >= s.brgUpdtIntvl) then
			setMavBearing()
			brgCalcTimer = now
		end
		
		-- set mav status output
		if (bit32.band(mavData.statusFlags, c.AQ_MSK_CRIT) > 0) then
			-- critical
			stat = -FULLSCALE * 0.5
		elseif (bit32.band(mavData.statusFlags, c.AQST_GDED) > 0) then
			-- guided mode
			stat = FULLSCALE * 0.5
		elseif (bit32.band(mavData.statusFlags, c.AQST_MISN) > 0) then
			-- mission mode
			stat = FULLSCALE * 0.4
		elseif (bit32.band(mavData.statusFlags, c.AQST_PH) > 0) then
			-- pos hold
			stat = FULLSCALE * 0.3
		elseif (bit32.band(mavData.statusFlags, c.AQST_AH) > 0) then
			-- alt hold
			stat = FULLSCALE * 0.2
		elseif (bit32.band(mavData.statusFlags, c.AQST_ACT) > 0) then
			-- flying
			stat = FULLSCALE * 0.1
		elseif (bit32.band(mavData.statusFlags, c.AQST_SB) > 0) then
			-- armed but not flying
			stat = 0
		else
			-- disarmed
			stat = -FULLSCALE * 0.25
		end
		
		-- set gps status output
		if (mavData.gpsFix == 3) then
			if (mavData.gpsVdop ~= nil and mavData.gpsVdop < 1) then
				-- excellent gps
				gstat = FULLSCALE
			elseif (mavData.gpsHdop ~= nil and mavData.gpsHdop < 1) then
				-- better gps
				gstat = FULLSCALE * 0.75
			else
				-- 3D lock (<3.0 HAcc on AQ)
				gstat = FULLSCALE * 0.5
			end
		elseif (mavData.gpsFix == 2) then
			-- 2D
			gstat = FULLSCALE * 0.25
		else
			-- no fix
			gstat = 0
		end
		
		-- set battery percent if reported
		if (mavData.battPercent ~= nil) then
			bstat = FULLSCALE * mavData.battPercent * 0.01
		end
		
	end
	
	return stat, gstat, bstat
	
end

return {init=init, run=run, output=outputs}
