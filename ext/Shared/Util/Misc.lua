function GetNormalizedId(playerId) -- DONT USE THIS SHIT
	return playerId + 1 -- returns the playerId + 1 because lua is 1 indexed and playerIds are not
end

function h()
	local vars = {"A","B","C","D","E","F","0","1","2","3","4","5","6","7","8","9"}
	return vars[math.floor(MathUtils:GetRandomInt(1,16))]..vars[math.floor(MathUtils:GetRandomInt(1,16))]
end

function IsTableEmpty(t)
    for _,_ in pairs(t) do
        return false
    end
    return true
end

-- Generates a random guid.
function GenerateGuid()
	return Guid(h()..h()..h()..h().."-"..h()..h().."-"..h()..h().."-"..h()..h().."-"..h()..h()..h()..h()..h()..h(), "D")
end

--- vvvv Unused, can't delete bc pow might kill me vvvv

-- Never ever fucking modify this, holy shit.
-- I spent 9 hours trying to figure out why my camera rotation wasn't working.
-- I swear to god, I will personally hunt you down.
function multiply(in1, in2)
	local Q1 = in1
	local Q2 = in2
	return Quat( (Q2.w * Q1.x) + (Q2.x * Q1.w) + (Q2.y * Q1.z) - (Q2.z * Q1.y),
		(Q2.w * Q1.y) - (Q2.x * Q1.z) + (Q2.y * Q1.w) + (Q2.z * Q1.x),
		(Q2.w * Q1.z) + (Q2.x * Q1.y) - (Q2.y * Q1.x) + (Q2.z * Q1.w),
		(Q2.w * Q1.w) - (Q2.x * Q1.x) - (Q2.y * Q1.y) - (Q2.z * Q1.z) )
end

-- Regular normalizing function for quats.
function Normalize(quat)
	local n = quat.x * quat.x + quat.y * quat.y + quat.z * quat.z + quat.w * quat.w

	if n ~= 1 and n > 0 then
		n = 1 / math.sqrt(n)
		quat.x = quat.x * n
		quat.y = quat.y * n
		quat.z = quat.z * n
		quat.w = quat.w * n
	end
	return quat
end
