
-- this "script" can set environment variables while running in the simulator which other scripts might look for.

SIM = true

local _sim={}

_sim.getValue = function(v)
--	if (val == "altitude") then
		return math.random(500)
--	else
--		return getValue(v)
--	end
end

function simObj() 
	return _sim
end

local function run()
end

return {run=run}
