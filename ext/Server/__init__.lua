class 'CineCamServer'


function CineCamServer:__init()
	NetEvents:Subscribe('SetInputRestriction', self, self.SetInputRestriction)
end

function CineCamServer:SetInputRestriction(p_Player, p_EnableRestriction)
	for i = 0, 125 do
		p_Player:EnableInput(i, not p_EnableRestriction)
	end
end
return CineCamServer()