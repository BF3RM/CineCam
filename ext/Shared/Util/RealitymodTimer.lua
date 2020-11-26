class "RealitymodTimer"

local m_Logger = Logger("RealitymodTimer", false)

local currentTime = 0
local lastDelta = 0
local debugDelta = 0
local timers = {}

function RealitymodTimer:__init()
	m_Logger:Write("RealitymodTimer init.")
end

function RealitymodTimer:ResetData()
	currentTime = 0
	lastDelta = 0
	debugDelta = 0
	timers = {}
end

-- this local function has to be above in the code of where its getting called. Don't move it down.
local function xpcall_callback(err)
	return m_Logger:Write(tostring(err))
end

function RealitymodTimer:GetTimers()
	return timerstimers
end

function RealitymodTimer:GetTimer(timerName)
	if not timerName then
		m_Logger:Error('RealitymodTimer:GetTimer() - argument timerName was nil')
		return
	end

	return timers[timerName]
end

function RealitymodTimer:OnEngineUpdate(p_Delta, p_SimDelta)
	lastDelta = lastDelta + p_Delta
	debugDelta = debugDelta + p_Delta

	if lastDelta < 0.1 then -- add check: or round hasnt started yet
		return
	end

	currentTime = currentTime + lastDelta

	if debugDelta >= 5.0 then
		-- m_Logger:Write(currentTime) -- debug only
		-- m_Logger:Write('checking timers:')
		-- m_Logger:Write(timers)
		debugDelta = 0
	end

	lastDelta = 0

	RealitymodTimer:Check()
end

local isRandomseedSet = false

function RealitymodTimer:GetTimeLeft(timerName)
	local timer = timers[timerName]
	return timer.lastExec + timer.delay - currentTime
end

function RealitymodTimer:GetNewRandomString()
	if currentTime == 0 then
		m_Logger:Error('CurrentTime was 0, that means the OnEngineUpdate didnt start yet. No way you should be spawning stuff already.')
		return
	end

	local pseudorandom = nil

	while(true) do
		pseudorandom = MathUtils:GetRandomInt(10000000, 99999999)

		if timers[pseudorandom] == nil then
			break
		end
	end

	m_Logger:Write("RealitymodTimer:GetNewRandomString() - got a new random timer name: " .. tostring(pseudorandom))
	return tostring(pseudorandom)
end

function RealitymodTimer:Simple(delay, func)
	RealitymodTimer:CreateInternal(RealitymodTimer:GetNewRandomString(), delay, 1, func, false)
end

function RealitymodTimer:Create(name, delay, reps, func)
	RealitymodTimer:CreateInternal(name, delay, reps, func, false)
end

function RealitymodTimer:CreateRepetitive(name, delay, func)
	RealitymodTimer:CreateInternal(name, delay, 0, func, true)
end

function RealitymodTimer:CreateInternal(name, delay, reps, func, isRepetitive) -- call one of the above not this one
	if name ~= nil and type(name) ~= "string" then
		m_Logger:Error("Invalid timer name: "..tostring(name))
		return
	end

	if type(delay) ~= "number" or delay < 0 then
		m_Logger:Error("Invalid timer delay: "..tostring(delay))
		return
	end

	if type(reps) ~= "number" or reps < 0 or math.floor(reps) ~= reps then
		m_Logger:Error("Invalid timer reps: "..tostring(reps))
		return
	end

	if func ~= nil and type(func) ~= "function" and not (getmetatable(func) and getmetatable(func).__call) then
		m_Logger:Error("Invalid timer function: "..tostring(func))
		return
	end

	name = name or RealitymodTimer:GetNewRandomString()

	timers[name] = {
		name = name,
		delay = delay,
		reps = reps == 0 and -1 or reps,
		func = func,
		on = false,
		lastExec = 0,
		isRepetitive = false or isRepetitive,
	}

	m_Logger:Write("RealitymodTimer:CreateInternal() - timer name: " .. name .. ' delay: ' .. delay)
	RealitymodTimer:Start(name)
end

function RealitymodTimer:Check()
	local t = currentTime
	for name,tmr in pairs(timers) do
		if tmr.lastExec + tmr.delay <= t and tmr.on then
			if tmr.func ~= nil then
				tmr.func()
			end

			tmr.lastExec = t

			if not tmr.isRepetitive then
				tmr.reps = tmr.reps - 1
				if tmr.reps == 0 then
					timers[name] = nil
				end
			end
		end
	end
end

function RealitymodTimer:Start(name)
	m_Logger:Write('RealitymodTimer:Start() - Starting timer: ' .. name)
	local t = timers[name]
	if not t then
		m_Logger:Error("Tried to start nonexistant timer: "..tostring(name))
		return
	end
	t.on = true
	t.timeDiff = nil
	t.lastExec = currentTime
	return true
end

function RealitymodTimer:Stop(name)
	m_Logger:Write('RealitymodTimer:Stop() - Stopping timer: ' .. name)
	local t = timers[name]
	if not t then
		m_Logger:Error("Tried to stop nonexistant timer: "..tostring(name))
		return
	end
	t.on = false
	t.timeDiff = nil
	--timers[name] = nil
	return true
end

function RealitymodTimer:Pause(name)
	m_Logger:Write('RealitymodTimer:Pause() - Pausing timer: ' .. name)
	local t = timers[name]
	if not t then
		m_Logger:Error("Tried to pause nonexistant timer: "..tostring(name))
		return
	end
	t.on = false
	t.timeDiff = currentTime - t.lastExec
	return true
end

function RealitymodTimer:UnPause(name)
	m_Logger:Write('RealitymodTimer:UnPause() - Unpausing timer: ' .. name)
	local t = timers[name]
	if not t or not t.timeDiff then
		m_Logger:Error("Tried to unpause nonexistant timer: "..tostring(name))
		return
	end
	if not t.timeDiff then
		m_Logger:Error("Tried to unpause nonpaused timer: "..tostring(name))
		return
	end

	t.on = true
	t.lastExec = currentTime - t.timeDiff
	t.timeDiff = nil
	return true
end

function RealitymodTimer:Adjust(name, delay, reps, func, isRepetitive)
	m_Logger:Write('RealitymodTimer:Adjust() - Adjusting timer: ' .. name)
	local t = timers[name]
	-- if not t or not t.timeDiff then
	if not t then
		m_Logger:Error("Tried to adjust nonexistant timer: "..tostring(name))
		return
	end
	if type(delay) ~= "number" or delay < 0 then
		m_Logger:Error("Invalid timer delay: "..tostring(delay))
		return
	end
	if type(reps) ~= "number" or reps < 0 or math.floor(reps) ~= reps then
		m_Logger:Error("Invalid timer reps: "..tostring(reps))
		return
	end

	t.delay = delay
	-- t.reps = reps
	t.reps = reps + 1 -- for some reason this has to be + 1 to work as you'd expect it to
	t.isRepetitive = isRepetitive

	if func ~= nil and type(func) ~= "function" and not (getmetatable(func) and getmetatable(func).__call) then
		m_Logger:Error("Invalid timer function: "..tostring(func))
		return
	end
	t.func = func
	return true
end

function RealitymodTimer:Delete(name)
	if name == nil or type(name) ~= "string" then
		return
	end

	m_Logger:Write('RealitymodTimer:Delete() - Delete timer: ' .. name)

	if timers[name] ~= nil then
		timers[name] = nil
	end

end
-- RealitymodTimer.Remove = RealitymodTimer.Delete -- whats this for?

-- Singleton.
if g_RealitymodTimer == nil then
    g_RealitymodTimer = RealitymodTimer()
end

return g_RealitymodTimer
