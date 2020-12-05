class 'CineCam'

local m_RotationHelper = require "__shared/Util/RotationHelper"
require "__shared/Util/MathExtensions"
require "__shared/Util/StringExtensions"
local points = require "pointrenderer"
local SplineController = require "__shared/Util/catmullrom_spline_controller"

CameraMode = {
	FirstPerson = 1,
	CineCam = 2,
	Orbital = 3,
	Editor = 4
}

function CineCam:__init()
	print("Initializing CineCam module")
	Hooks:Install('UI:CreateChatMessage', 1000, self, self.OnCreateChatMessage) 
	Hooks:Install('Input:PreUpdate', 999, self, self.OnUpdateInputHook)

	Events:Subscribe('Client:UpdateInput', self, self.OnUpdateInput) 
	Events:Subscribe('UpdateManager:Update', self, self.OnUpdate)
	Events:Subscribe('Level:Destroy', self, self.OnLevelDestroyed)

	self:RegisterVars()
end

function CineCam:OnLevelDestroyed()
	self:Destroy()
	self:ResetVars()
end


function CineCam:RegisterVars()
	self:ResetVars()
end

function CineCam:ResetVars()
	self.m_Mode = CameraMode.FirstPerson

	self.m_Camera = nil
	self.m_CameraData = nil
	self.m_Rotation = QuatTransform()
	self.m_LastTransform = nil

	self.m_IsAttached = false
	self.m_AttachedPlayerName = ""
	self.m_AttachedPlayerPos = nil
	self.m_PosIncrease = Vec3(0, 0, 0)

	self.m_CameraYaw = 0.0
	self.m_CameraPitch = 0.0
	self.m_CameraRoll = 0.0

	self.m_MoveX = 0.0
	self.m_MoveY = 0.0
	self.m_MoveZ = 0.0
	self.m_SpeedMultiplier = 1.917
	self.m_RotationSpeedMultiplier = 6
	self.m_Sprint = false

	self.m_LastSpectatedPlayer = 0

	self.m_NewYaw = 0
	self.m_NewPitch = 0

	self.m_Smooth = true
	self.m_Playing = false

	self.m_PlaybackKey = 1
	self.m_FinalSpeed = 1
end


function CineCam:OnCreateChatMessage(p_Hook, p_Message, p_Channel, p_PlayerId, p_RecipientMask, p_SenderIsDead)
	if self.m_Mode ~= CameraMode.CineCam then
		return
	end
	local s_Parts = p_Message:split(' ')
	if(p_PlayerId ~= PlayerManager:GetLocalPlayer().id) then
		return
	end
	if s_Parts[1]:lower() == '!attach' and s_Parts[2] ~= nil then
		local s_Players = self:FindPlayersByString(s_Parts[2])
		if s_Players == nil then
			print('Couldn\'t find alive players with name '.. s_Parts[2])
			return
		end
		local s_Player = s_Players[1]
		if s_Player == nil or s_Player.soldier == nil then
			print('Couldn\'t find alive player with name '.. s_Parts[2])
			return
		end
		print('Attaching to player '.. s_Parts[2])
		self.m_IsAttached = true
		self.m_AttachedPlayerName = s_Player.name
		self.m_AttachedPlayerPos = s_Player.soldier.transform.trans:Clone()
	end

	if s_Parts[1]:lower() == '!detach' then
		self:DetachCameraFromPlayer()
	end
end

function CineCam:FindPlayersByString(p_String)
	local s_Players = PlayerManager:GetPlayers()
	local s_PossiblePlayers = { }

	for _, player in pairs(s_Players) do
		local playerNameUpper = player.name:upper()
		local searchStringUpper = p_String:upper()

		if playerNameUpper:startsWith(searchStringUpper) then
			table.insert(s_PossiblePlayers, player)
		end
	end

	if #s_PossiblePlayers == 0 then
		return nil
	end

	return s_PossiblePlayers
end

function CineCam:SetCameraMode(p_Mode)
    if self.m_Mode == CameraMode.Editor then
        self:UpdateCineCamVars()
    end
	print("Setting CineCam mode to "..p_Mode)
    self.m_Mode = p_Mode
end

function CineCam:GetCameraMode()
    return self.m_Mode
end

function CineCam:SetCameraFOV(p_FOV)
	if p_FOV < 30 then
		p_FOV = 30
	elseif p_FOV > 120 then
		p_FOV = 120
	end

	self.m_CameraData.fov = p_FOV
end

function CineCam:GetCameraFOV()
	if self.m_CameraData then
		return self.m_CameraData.fov
	end
end

function CineCam:OnControlStart()
    self:SetCameraMode(CameraMode.Editor)
end

function CineCam:OnControlEnd()
    self:SetCameraMode(CameraMode.CineCam)
end

function CineCam:OnEnableCineCamMovement()
    self:SetCameraMode(CameraMode.CineCam)
end

function CineCam:UpdateCineCamVars()

    local s_Yaw, s_Pitch, s_Roll = m_RotationHelper:GetYPRfromLUF(
			self.m_CameraData.transform.left,
			self.m_CameraData.transform.up,
			self.m_CameraData.transform.forward)

	self.m_CameraYaw = s_Yaw - math.pi
	self.m_CameraPitch = -(s_Pitch - math.pi)

    self.m_LastTransform = self.m_CameraData.transform.trans
end

function CineCam:OnUpdateInputHook(p_Hook, p_Cache, p_DeltaTime)
	if self.m_Camera ~= nil and self.m_Mode == CameraMode.CineCam then
		local x = p_Cache:GetLevel(InputConceptIdentifiers.ConceptYaw) * self.m_RotationSpeedMultiplier
		local y = p_Cache:GetLevel(InputConceptIdentifiers.ConceptPitch) * self.m_RotationSpeedMultiplier
		if(self.smooth) then
			x = x * p_DeltaTime
			y = y * p_DeltaTime
		end
		self.m_CameraYaw   = self.m_CameraYaw - x
		self.m_CameraPitch = self.m_CameraPitch - y
		self.m_CameraRoll = 0
		self.m_Rotation.rotation = Quat(Vec3(self.m_CameraYaw, 0, -self.m_CameraPitch))
	end
end

function CineCam:Create()
	if self.m_CameraData == nil then
		self.m_CameraData = CameraEntityData()
	end
	local s_Entity = EntityManager:CreateEntity(self.m_CameraData, LinearTransform())
	if s_Entity == nil then
		m_Logger:Error("Could not spawn camera")
		return
	end
	s_Entity:Init(Realm.Realm_Client, true);

	-- local s_Spatial = SpatialEntity(s_Entity)

	self.m_CameraData.fov = 90
	self.m_CameraData.transform = ClientUtils:GetCameraTransform()
	self.m_Camera = s_Entity
	self.m_Rotation = self.m_CameraData.transform:ToQuatTransform(false)
end

function CineCam:Destroy()
	if self.m_Camera then
		self.m_Camera:Destroy()
		self.m_Camera = nil
	end
	self.m_CameraData = nil
end

function CineCam:TakeControl()
	if(self.m_Camera ~= nil) then
		self.m_Camera:FireEvent("TakeControl")
	end
end

function CineCam:ReleaseControl()
	if(self.m_Camera ~= nil) then
		self.m_Camera:FireEvent("ReleaseControl")
	end
end

function CineCam:Enable()
	if(self.m_Camera == nil) then
		self:Create()
	end

	if(self.m_lastTransform ~= nil) then
		self.m_CameraData.transform = self.m_LastTransform
	end

    self:SetCameraMode(CameraMode.CineCam)
	self:TakeControl()
end

function CineCam:Disable()
	self.m_LastTransform = self.m_CameraData.transform
    self:SetCameraMode(CameraMode.FirstPerson)
	self:ReleaseControl()
end

function CineCam:RotateX(p_Transform, p_Vector)
	return Vec3(
			p_Transform.left.x * p_Vector.x,
			p_Transform.left.y * p_Vector.x,
			p_Transform.left.z * p_Vector.x
	) + Vec3(
			p_Transform.up.x * p_Vector.y,
			p_Transform.up.y * p_Vector.y,
			p_Transform.up.z * p_Vector.y
	) + Vec3(
			p_Transform.forward.x * p_Vector.z,
			p_Transform.forward.y * p_Vector.z,
			p_Transform.forward.z * p_Vector.z
	)
end

function CineCam:Play()
	print("Playing")
	self.m_Playing = true
end
function CineCam:Stop()
	self.m_Playing = false
end

function CineCam:OnUpdateInput(p_Delta)
	local s_Step = 1
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_PageDown) then
		if self.m_RotationSpeedMultiplier > 1 then
			print("Multiplier set to: " .. self.m_RotationSpeedMultiplier)
			self.m_RotationSpeedMultiplier = self.m_RotationSpeedMultiplier - s_Step
		end
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_PageUp) then
		print("Multiplier set to: " .. self.m_RotationSpeedMultiplier)
		self.m_RotationSpeedMultiplier = self.m_RotationSpeedMultiplier + s_Step
	end
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F3) then
		self:Play()
	end

	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F2) then
		if self.m_Mode == CameraMode.FirstPerson then
			--if not RM_DEV.IS_DEBUG_MODE then
			--	return
			--end
			local s_LocalPlayer = PlayerManager:GetLocalPlayer()
			-- Don't change to CineCam if the player isn't alive, maybe add message saying so?
			if s_LocalPlayer == nil or s_LocalPlayer.soldier == nil then
				return
			end
			self:Enable()
			Events:Dispatch('UIManager:RequestDisableMouse')
		elseif self.m_Mode == CameraMode.CineCam then
			self:Disable()
		end
	end

	if self.m_Mode ~= CameraMode.CineCam then
		return
	end

	if not points[self.m_PlaybackKey] then
		self:Stop()
	end

	if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowUp) then
		self:SetCameraFOV(self:GetCameraFOV() + 5)
		print("FOV set to: " .. self:GetCameraFOV())

	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowDown) then
		self:SetCameraFOV(self:GetCameraFOV() - 5)
		print("FOV set to: " .. self:GetCameraFOV())
	end
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowLeft) then
		if(self.m_PlaybackKey > 1) then
			self.m_PlaybackKey = self.m_PlaybackKey - 1
			print(self.m_PlaybackKey)
		end
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowRight) then
		self.m_PlaybackKey = self.m_PlaybackKey + 1
		print(self.m_PlaybackKey)
	end

	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F3) and InputManager:WentKeyDown(InputDeviceKeys.IDK_LeftCtrl) then
		print("Resetting camera")
		self.m_CameraData.transform.left = Vec3(1,0,0)
		self.m_CameraData.transform.up = Vec3(0,1,0)
		self.m_CameraData.transform.forward = Vec3(0,0,1)
		self.m_CameraData.fov = 90
		self.m_CameraYaw = 0.0
		self.m_CameraPitch = 0.0
		self.m_CameraDistance = 1.0
		self.m_ThirdPersonRotX = 0.0
		self.m_ThirdPersonRotY = 0.0
		self:DetachCameraFromPlayer()
	end
end
function CineCam:OnUpdate(p_Delta, p_Pass)
	-- Only update in pre-frame

	if p_Pass ~= UpdatePass.UpdatePass_PreFrame then
		return
	end

	if self.m_Mode ~= CameraMode.CineCam then
		return
	end

	self:UpdateCameraControls(p_Delta)
	self:UpdateAttachmentMovement(p_Delta)
	self:UpdateCineCamera(p_Delta)
	-- After the camera has moved reset movement.
	self.m_RotateX = 0.0
	self.m_RotateY = 0.0
	self.m_MoveX = 0.0
	self.m_MoveY = 0.0
	self.m_MoveZ = 0.0

end

function CineCam:UpdateAttachmentMovement(p_Delta)
	if not self.m_IsAttached then
		return
	end

	local s_Player = PlayerManager:GetPlayerByName(self.m_AttachedPlayerName)

	if s_Player == nil or s_Player.soldier == nil then
		self:DetachCameraFromPlayer()
		return
	end

	self.m_PosIncrease = s_Player.soldier.transform.trans - self.m_AttachedPlayerPos
	self.m_AttachedPlayerPos = s_Player.soldier.transform.trans:Clone()
end

function CineCam:DetachCameraFromPlayer()
	self.m_IsAttached = false
	self.m_AttachedPlayerName = ""
	self.m_AttachedPlayerPos = nil
	self.m_PosIncrease = Vec3(0, 0, 0)
end

function CineCam:UpdateCameraControls(p_Delta)
	local s_MoveX = InputManager:GetLevel(InputConceptIdentifiers.ConceptMoveLR)
	local s_MoveY = 0.0
	local s_MoveZ = -InputManager:GetLevel(InputConceptIdentifiers.ConceptMoveFB)

	if InputManager:IsKeyDown(InputDeviceKeys.IDK_E) then
		s_MoveY = 1.0
	elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_Q) then
		s_MoveY = -1.0
	end

	--- When moving diagonally lower axis direction speeds.
	if s_MoveX ~= 0.0 and s_MoveZ ~= 0.0  then
		s_MoveX = s_MoveX * 0.7071 -- cos(45º)
		s_MoveZ = s_MoveZ * 0.7071 -- cos(45º)
	end

	self.m_MoveX = self.m_MoveX + s_MoveX
	self.m_MoveY = self.m_MoveY + s_MoveY
	self.m_MoveZ = self.m_MoveZ + s_MoveZ

	-- Camera speed and distance controls.
	self.m_Sprint = InputManager:IsKeyDown(InputDeviceKeys.IDK_LeftShift)

	local s_MouseWheel = InputManager:GetLevel(InputConceptIdentifiers.ConceptFreeCameraSwitchSpeed)

	self.m_SpeedMultiplier = self.m_SpeedMultiplier + (s_MouseWheel * 0.01)

	if self.m_SpeedMultiplier < 0.000005 then
		self.m_SpeedMultiplier = 0.00005
	end
end

function CineCam:ToVec3(inp)
	return Vec3(inp.x, inp.y, inp.z)
end
function CineCam:UpdateCineCamera(p_Delta)
	local s_Transform = self.m_CameraData.transform
	local distance = 1
	if not self.m_Smooth then
		s_Transform.forward = Vec3( math.sin(self.m_CameraYaw)*math.cos(self.m_CameraPitch),
				math.sin(self.m_CameraPitch),
				math.cos(self.m_CameraYaw)*math.cos(self.m_CameraPitch))

		s_Transform.up = Vec3( -(math.sin(self.m_CameraYaw)*math.sin(self.m_CameraPitch)),
				math.cos(self.m_CameraPitch),
				-(math.cos(self.m_CameraYaw)*math.sin(self.m_CameraPitch)) )


		s_Transform.left = s_Transform.forward:Cross(Vec3(s_Transform.up.x * -1, s_Transform.up.y * -1, s_Transform.up.z * -1))

	else
		s_Transform = self.m_CameraData.transform:ToQuatTransform(false)
		local s_NewRotation = s_Transform.rotation:Slerp(self.m_Rotation.rotation, (p_Delta / self.m_FinalSpeed) * self.m_RotationSpeedMultiplier)
		if (self.m_Playing) then
			s_NewRotation = s_Transform.rotation:Slerp(points[self.m_PlaybackKey].rotation, p_Delta / self.m_FinalSpeed)
		end
		s_Transform.rotation = s_NewRotation
		s_Transform = s_Transform:ToLinearTransform(false)
		self.m_CameraData.transform = s_Transform
	end
	if self.m_Playing then
		local destinationTransform = points[self.m_PlaybackKey].transAndScale
		self.m_CameraData.transform.trans:Lerp(Vec3(destinationTransform.x, destinationTransform.y, destinationTransform.z), p_Delta / self.m_FinalSpeed)
	end
	if self.m_IsAttached then
		self.m_CameraData.transform.trans:Lerp(s_Transform.trans + self.m_PosIncrease, 1)
	end
	if self.m_MoveX ~= 0.0 then
		local s_MoveX = 20.0 * self.m_MoveX * self.m_SpeedMultiplier;

		if self.m_Sprint then
			s_MoveX = s_MoveX * 2.0
		end

		local s_MoveVector = Vec3(s_Transform.left.x * s_MoveX, s_Transform.left.y * s_MoveX, s_Transform.left.z * s_MoveX)
		self.m_CameraData.transform.trans:Lerp(s_Transform.trans + s_MoveVector, p_Delta / self.m_FinalSpeed)
	end

	if self.m_MoveY ~= 0.0 then
		local s_MoveY = 10.0 * self.m_MoveY * self.m_SpeedMultiplier;

		if self.m_Sprint then
			s_MoveY = s_MoveY * 2.0
		end

		local s_MoveVector = Vec3(s_Transform.up.x * s_MoveY, s_Transform.up.y * s_MoveY, s_Transform.up.z * s_MoveY)
		self.m_CameraData.transform.trans:Lerp(s_Transform.trans + s_MoveVector, p_Delta / self.m_FinalSpeed)
	end

	if self.m_MoveZ ~= 0.0 then
		local s_MoveZ = 10.0 * self.m_MoveZ * self.m_SpeedMultiplier;

		if self.m_Sprint then
			s_MoveZ = s_MoveZ * 2.0
		end

		local s_MoveVector = Vec3(s_Transform.forward.x * s_MoveZ, s_Transform.forward.y * s_MoveZ, s_Transform.forward.z * s_MoveZ)
		self.m_CameraData.transform.trans:Lerp(s_Transform.trans + s_MoveVector, p_Delta / self.m_FinalSpeed)
	end	
end


return CineCam()