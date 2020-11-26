class 'RaycastHelper'

local m_Logger = Logger("RaycastHelper", false)

-- Get the player that `p_LocalSoldier` is looking at. Argument `p_AllowCorpses` is optional, default is false.
function RaycastHelper:GetPlayerWithRaycast(p_LocalSoldier, p_AllowCorpses)
	if p_AllowCorpses == nil then
		p_AllowCorpses = false
	end

	local s_Transform = ClientUtils:GetCameraTransform()

	if s_Transform.trans == Vec3(0, 0, 0) then -- Camera is below the ground. Creating an entity here would be useless.
		return
	end

	-- The freecam transform is inverted. Invert it back
	local s_CameraForward = Vec3(s_Transform.forward.x * -1, s_Transform.forward.y * -1, s_Transform.forward.z * -1)

	local s_CastPosition = Vec3(s_Transform.trans.x + (s_CameraForward.x * RM_CONFIG.NAMETAG_RAYCAST_DISTANCE),
								s_Transform.trans.y + (s_CameraForward.y * RM_CONFIG.NAMETAG_RAYCAST_DISTANCE),
								s_Transform.trans.z + (s_CameraForward.z * RM_CONFIG.NAMETAG_RAYCAST_DISTANCE))

	local s_Raycast = RaycastManager:Raycast(s_Transform.trans, s_CastPosition, 2)

	if s_Raycast == nil or s_Raycast.rigidBody == nil or s_Raycast.rigidBody:Is("PhysicsEntityBase") == false then
		return
	end

	local physicsEntityBase = PhysicsEntityBase(s_Raycast.rigidBody)
	if physicsEntityBase.userData ~= nil and physicsEntityBase.userData:Is("ClientSoldierEntity") then
		local s_Soldier = SoldierEntity(physicsEntityBase.userData)
		if p_LocalSoldier == s_Soldier then
			return
		end
		-- Player is alive
		if s_Soldier.player ~= nil then
			m_Logger:Write('Found player '..s_Soldier.player.name..' with raycast.')
			return s_Soldier.player
		end
		-- It is a wounded soldier, so look for a corpse
		if p_AllowCorpses and not s_Soldier.isAlive and not s_Soldier.isDead then
			local s_friendlyPlayers = PlayerManager:GetPlayersByTeam(p_LocalSoldier.player.teamId)
			for _, s_Player in pairs(s_friendlyPlayers) do
				if s_Player.corpse == s_Soldier then
					m_Logger:Write('Found corpse of '..s_Player.name..' with raycast.')
					return s_Player
				end
			end
		end
	end
end

function RaycastHelper:GetPlayerAndDistanceWithRaycast(p_LocalSoldier)
	local raycastPlayer = self:GetPlayerWithRaycast(p_LocalSoldier)
	if raycastPlayer == nil or raycastPlayer.soldier == nil then
		return nil
	end
	local distance = p_LocalSoldier.transform.trans:Distance(raycastPlayer.soldier.transform.trans)
	return raycastPlayer, distance
end

return RaycastHelper
