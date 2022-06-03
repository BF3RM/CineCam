---@class CineCam
CineCam = class 'CineCam'

require "__shared/Config"
require "__shared/Util/MathExtensions"
require "__shared/Util/StringExtensions"
require "__shared/Util/Logger"

---@type Logger
local m_Logger = Logger("CineCam", true)

---@type RotationHelper
local m_RotationHelper = require "__shared/Util/RotationHelper"

---@type VehicleCameras
local m_VehicleCameras = require "VehicleCameras"

---@type WeaponCameras
local m_WeaponCameras = require "WeaponCameras"

---@type SoldierCameras
local m_SoldierCameras = require "SoldierCameras"

local points = require "pointrenderer"

---@class CameraMode
local CameraMode = {
	FirstPerson = 1,
	CineCam = 2,
	Orbital = 3,
	Editor = 4,
	Soldier = 5,
	Weapon = 6,
	Vehicle = 7,
}

---Returns the current FOV of the local player
---@return number
local function _GetFieldOfView()
	---@type GameRenderSettings|DataContainer|table
	local s_GameRenderSettings = ResourceManager:GetSettings("GameRenderSettings")

	if s_GameRenderSettings ~= nil then
		s_GameRenderSettings = GameRenderSettings(s_GameRenderSettings)
	else
		-- Just in case if we don't get the settings
		s_GameRenderSettings = { fovMultiplier = 1.36 }
	end

	-- calculated by the default base fov (which is 55.0) multiplied with the fovMultiplier
	-- this is the vertical fov (VDEG) btw.

	-- default base fov (55.0):
	-- [https://github.com/EmulatorNexus/Venice-EBX/blob/master/Weapons/Common/ZoomLevels/DefaultBase.txt#L9]

	return 55.0 * s_GameRenderSettings.fovMultiplier
end

function CineCam:__init()
	m_Logger:Write("Initializing CineCam module")

	Hooks:Install('UI:CreateChatMessage', 1000, self, self.OnCreateChatMessage)
	Hooks:Install('Input:PreUpdate', 999, self, self.OnUpdateInputHook)

	Events:Subscribe('Client:UpdateInput', self, self.OnUpdateInput)
	Events:Subscribe('Player:UpdateInput', self, self.OnUpdatePlayerInput)
	Events:Subscribe('UpdateManager:Update', self, self.OnUpdate)
	Events:Subscribe('Level:Destroy', self, self.OnLevelDestroyed)
	Events:Subscribe('Extension:Unloading', self, self.OnExtensionUnloading)
	Events:Subscribe('Soldier:HealthAction', self, self.OnSoldierHealthAction)

	self:RegisterVars()
end

function CineCam:OnLevelDestroyed()
	if self.m_Mode ~= CameraMode.FirstPerson then
		self:Disable()
	end

	self:Destroy()
	self:ResetVars()
	m_VehicleCameras:OnLevelDestroyed()
	m_WeaponCameras:OnLevelDestroyed()
	m_SoldierCameras:OnLevelDestroyed()
end

function CineCam:OnExtensionUnloading()
	if self.m_Mode ~= CameraMode.FirstPerson then
		self:Disable()
	end

	self:Destroy()
	self:ResetVars()
	m_VehicleCameras:OnExtensionUnloading()
	m_WeaponCameras:OnExtensionUnloading()
	m_SoldierCameras:OnExtensionUnloading()
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

	self.m_WeaponLowered = false
end

---@param p_Soldier SoldierEntity
---@param p_Action HealthStateAction|integer
function CineCam:OnSoldierHealthAction(p_Soldier, p_Action)
	if p_Action ~= HealthStateAction.OnManDown and p_Action ~= HealthStateAction.OnDead then
		return
	end

	if self.m_Mode == CameraMode.FirstPerson then
		return
	end

	local s_LocalPlayer = PlayerManager:GetLocalPlayer()

	if s_LocalPlayer == nil then
		return
	end

	if s_LocalPlayer.corpse == p_Soldier then
		m_Logger:Write("You died.")
		self:Disable()
		m_VehicleCameras:Disable()
		m_WeaponCameras:Disable()
		m_SoldierCameras:Disable()
	end
end

---@param p_HookCtx HookContext
---@param p_Message string
---@param p_Channel ChatChannelType|integer
---@param p_PlayerId integer
---@param p_RecipientMask integer
---@param p_SenderIsDead boolean
function CineCam:OnCreateChatMessage(p_HookCtx, p_Message, p_Channel, p_PlayerId, p_RecipientMask, p_SenderIsDead)

	if p_PlayerId ~= PlayerManager:GetLocalPlayer().id then
		return
	end

	-- listen to commands
	local s_Parts = p_Message:split(' ')

	-- switch mounted modes
	if s_Parts[1]:lower() == '!mode' and CameraMode[string:firstToUpper(s_Parts[2])] ~= nil then
		-- disable existing
		m_VehicleCameras:Disable()
		m_WeaponCameras:Disable()
		m_SoldierCameras:Disable()

		-- set new mode
		self:SetCameraMode(CameraMode[string:firstToUpper(s_Parts[2])])
		ChatManager:SendMessage('Set mounted camera mode to: ' .. string:firstToUpper(s_Parts[2]))
	elseif s_Parts[1]:lower() == '!lowerweapon' then
		self:LowerWeapon()
	end

	if self.m_Mode ~= CameraMode.CineCam then
		return
	end

	if s_Parts[1]:lower() == '!attach' and s_Parts[2] ~= nil then
		local s_Players = self:FindPlayersByString(s_Parts[2])

		if s_Players == nil then
			m_Logger:Warning('Couldn\'t find alive players with name '.. s_Parts[2])
			return
		end

		local s_Player = s_Players[1]

		if s_Player == nil or s_Player.soldier == nil then
			m_Logger:Warning('Couldn\'t find alive player with name '.. s_Parts[2])
			return
		end

		m_Logger:Write('Attaching to player '.. s_Parts[2])
		self.m_IsAttached = true
		self.m_AttachedPlayerName = s_Player.name
		self.m_AttachedPlayerPos = s_Player.soldier.transform.trans:Clone()

		if self.m_CameraData == nil then
			m_Logger:Warning("CameraData was nil while attaching player.")
			return
		end

		local s_Position = s_Player.soldier.transform.trans:Clone()
		s_Position = Vec3(s_Position.x + 5.0, s_Position.y + 5.0, s_Position.z + 5.0)

		self.m_CameraData.transform:LookAtTransform(s_Position, s_Player.soldier.transform.trans)
		self.m_CameraData.transform.left = self.m_CameraData.transform.left * -1
		self.m_CameraData.transform.forward = self.m_CameraData.transform.forward * -1
		self.m_CameraData.transform.up = Vec3(self.m_CameraData.transform.up.x * -1, self.m_CameraData.transform.up.y, self.m_CameraData.transform.up.z * -1)
		self:UpdateCineCamVars()
	end
end

---@param p_String string
---@return Player[]
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

---@param p_Mode CameraMode|integer
function CineCam:SetCameraMode(p_Mode)
    if self.m_Mode == CameraMode.Editor then
        self:UpdateCineCamVars()
    end

	m_Logger:Write("Setting CineCam mode to "..p_Mode)
    self.m_Mode = p_Mode
end

function CineCam:GetCameraMode()
    return self.m_Mode
end

---@param p_FOV number
function CineCam:SetCameraFOV(p_FOV)
	if p_FOV < 30 then
		p_FOV = 30
	elseif p_FOV > 120 then
		p_FOV = 120
	end

	self.m_CameraData.fov = p_FOV
end

---@return number|nil
function CineCam:GetCameraFOV()
	if self.m_CameraData then
		return self.m_CameraData.fov
	end
end

function CineCam:UpdateCineCamVars()
    local s_Yaw, s_Pitch, s_Roll = m_RotationHelper:GetYPRFromLUF(
			self.m_CameraData.transform.left,
			self.m_CameraData.transform.up,
			self.m_CameraData.transform.forward)

	-- negative yaw because cam is reversed
	self.m_CameraYaw = -s_Yaw
	self.m_CameraPitch = s_Pitch

    self.m_LastTransform = self.m_CameraData.transform.trans
end

---@param p_HookCtx HookContext
---@param p_Cache ConceptCache
---@param p_DeltaTime number
function CineCam:OnUpdateInputHook(p_HookCtx, p_Cache, p_DeltaTime)
	if self.m_Camera ~= nil and self.m_Mode == CameraMode.CineCam then
		local x = p_Cache:GetLevel(InputConceptIdentifiers.ConceptYaw) * self.m_RotationSpeedMultiplier
		local y = p_Cache:GetLevel(InputConceptIdentifiers.ConceptPitch) * self.m_RotationSpeedMultiplier

		local s_Tickrate = 1.0 / p_DeltaTime
		local s_TickrateMultiplier = s_Tickrate / 30.0

		x = x / s_TickrateMultiplier
		y = y / s_TickrateMultiplier

		if self.m_Smooth then
			x = x * 0.60
			y = y * 0.60
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

	s_Entity:Init(Realm.Realm_Client, true)

	-- local s_Spatial = SpatialEntity(s_Entity)

	self.m_CameraData.fov = _GetFieldOfView()
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
	m_Logger:Write("Camera destroyed")
end

function CineCam:TakeControl()
	if self.m_Camera ~= nil then
		self.m_Camera:FireEvent("TakeControl")
	end
end

function CineCam:ReleaseControl()
	if self.m_Camera ~= nil then
		self.m_Camera:FireEvent("ReleaseControl")
	end
end

function CineCam:Enable()
	self:SetInputRestriction(true)

	if self.m_Camera == nil then
		self:Create()
	end

	if self.m_LastTransform ~= nil then
		self.m_CameraData.transform = self.m_LastTransform
	end

    self:SetCameraMode(CameraMode.CineCam)
	self:TakeControl()
end

function CineCam:Disable()
	self:SetInputRestriction(false)

	self.m_LastTransform = self.m_CameraData.transform
    self:SetCameraMode(CameraMode.FirstPerson)
	self:ReleaseControl()
	m_Logger:Write("Camera disabled")
end

---@param p_EnableRestriction boolean
function CineCam:SetInputRestriction(p_EnableRestriction)
	local s_LocalPlayer = PlayerManager:GetLocalPlayer()

	if s_LocalPlayer == nil then
		return
	end

	for i = 0, 125 do
		s_LocalPlayer:EnableInput(i, not p_EnableRestriction)
	end
end

---@param p_Transform LinearTransform
---@param p_Vector Vec3
---@return Vec3
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
	m_Logger:Write("Playing")
	self.m_Playing = true
end

function CineCam:Stop()
	self.m_Playing = false
end

---@param p_DeltaTime number
function CineCam:OnUpdateInput(p_DeltaTime)
	local s_Step = 1

	if InputManager:WentKeyDown(InputDeviceKeys.IDK_PageDown) then
		if self.m_RotationSpeedMultiplier > 1 then
			m_Logger:Write("Multiplier set to: " .. self.m_RotationSpeedMultiplier)
			self.m_RotationSpeedMultiplier = self.m_RotationSpeedMultiplier - s_Step
		end
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_PageUp) then
		m_Logger:Write("Multiplier set to: " .. self.m_RotationSpeedMultiplier)
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
		m_Logger:Write("FOV set to: " .. self:GetCameraFOV())
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowDown) then
		self:SetCameraFOV(self:GetCameraFOV() - 5)
		m_Logger:Write("FOV set to: " .. self:GetCameraFOV())
	end

	if InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowLeft) then
		if self.m_PlaybackKey > 1 then
			self.m_PlaybackKey = self.m_PlaybackKey - 1
			m_Logger:Write(self.m_PlaybackKey)
		end
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_ArrowRight) then
		self.m_PlaybackKey = self.m_PlaybackKey + 1
		m_Logger:Write(self.m_PlaybackKey)
	end

	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F3) and InputManager:WentKeyDown(InputDeviceKeys.IDK_LeftCtrl) then
		m_Logger:Write("Resetting camera")
		self.m_CameraData.transform.left = Vec3(1,0,0)
		self.m_CameraData.transform.up = Vec3(0,1,0)
		self.m_CameraData.transform.forward = Vec3(0,0,1)
		self.m_CameraData.fov = _GetFieldOfView()
		self.m_CameraYaw = 0.0
		self.m_CameraPitch = 0.0
		self.m_CameraDistance = 1.0
		self.m_ThirdPersonRotX = 0.0
		self.m_ThirdPersonRotY = 0.0
		self:DetachCameraFromPlayer()
	end
end

function CineCam:OnUpdatePlayerInput(p_Player, p_DeltaTime)
	if self.m_Mode == CameraMode.Vehicle then
		m_VehicleCameras:OnUpdatePlayerInput(p_Player, p_DeltaTime)
	elseif self.m_Mode == CameraMode.Weapon then
		m_WeaponCameras:OnUpdatePlayerInput(p_Player, p_DeltaTime)
	elseif self.m_Mode == CameraMode.Soldier then
		m_SoldierCameras:OnUpdatePlayerInput(p_Player, p_DeltaTime)
	end
end

---@param p_DeltaTime number
---@param p_UpdatePass UpdatePass|integer
function CineCam:OnUpdate(p_DeltaTime, p_UpdatePass)
	-- Only update in post-frame
	if p_UpdatePass ~= UpdatePass.UpdatePass_PreFrame then
		return
	end

	-- route
	m_VehicleCameras:OnUpdate(p_DeltaTime)
	m_WeaponCameras:OnUpdate(p_DeltaTime)
	m_SoldierCameras:OnUpdate(p_DeltaTime)

	if self.m_Mode ~= CameraMode.CineCam then
		return
	end

	self:UpdateCameraControls(p_DeltaTime)
	self:UpdateAttachmentMovement(p_DeltaTime)
	self:UpdateCineCamera(p_DeltaTime)
	-- After the camera has moved reset movement.
	self.m_MoveX = 0.0
	self.m_MoveY = 0.0
	self.m_MoveZ = 0.0
end

---@param p_DeltaTime number
function CineCam:UpdateAttachmentMovement(p_DeltaTime)
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
	m_Logger:Write("Detached player")
end

---@param p_DeltaTime number
function CineCam:UpdateCameraControls(p_DeltaTime)
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

---@param p_DeltaTime number
function CineCam:UpdateCineCamera(p_DeltaTime)
	---@type LinearTransform|QuatTransform
	local s_Transform = self.m_CameraData.transform

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
		local s_NewRotation = s_Transform.rotation:Slerp(self.m_Rotation.rotation, (p_DeltaTime / self.m_FinalSpeed) * self.m_RotationSpeedMultiplier)

		if self.m_Playing then
			s_NewRotation = s_Transform.rotation:Slerp(points[self.m_PlaybackKey].rotation, p_DeltaTime / self.m_FinalSpeed)
		end

		s_Transform.rotation = s_NewRotation
		s_Transform = s_Transform:ToLinearTransform()
		self.m_CameraData.transform = s_Transform
	end

	if self.m_Playing then
		local destinationTransform = points[self.m_PlaybackKey].transAndScale
		self.m_CameraData.transform.trans:Lerp(Vec3(destinationTransform.x, destinationTransform.y, destinationTransform.z), p_DeltaTime / self.m_FinalSpeed)
	end

	if self.m_IsAttached then
		self.m_CameraData.transform.trans:Lerp(s_Transform.trans + self.m_PosIncrease, 1)
	end

	if self.m_MoveX ~= 0.0 then
		local s_MoveX = 20.0 * self.m_MoveX * self.m_SpeedMultiplier

		if self.m_Sprint then
			s_MoveX = s_MoveX * 2.0
		end

		local s_MoveVector = Vec3(s_Transform.left.x * s_MoveX, s_Transform.left.y * s_MoveX, s_Transform.left.z * s_MoveX)
		self.m_CameraData.transform.trans:Lerp(s_Transform.trans + s_MoveVector, p_DeltaTime / self.m_FinalSpeed)
	end

	if self.m_MoveY ~= 0.0 then
		local s_MoveY = 10.0 * self.m_MoveY * self.m_SpeedMultiplier

		if self.m_Sprint then
			s_MoveY = s_MoveY * 2.0
		end

		local s_MoveVector = Vec3(s_Transform.up.x * s_MoveY, s_Transform.up.y * s_MoveY, s_Transform.up.z * s_MoveY)
		self.m_CameraData.transform.trans:Lerp(s_Transform.trans + s_MoveVector, p_DeltaTime / self.m_FinalSpeed)
	end

	if self.m_MoveZ ~= 0.0 then
		local s_MoveZ = 10.0 * self.m_MoveZ * self.m_SpeedMultiplier

		if self.m_Sprint then
			s_MoveZ = s_MoveZ * 2.0
		end

		local s_MoveVector = Vec3(s_Transform.forward.x * s_MoveZ, s_Transform.forward.y * s_MoveZ, s_Transform.forward.z * s_MoveZ)
		self.m_CameraData.transform.trans:Lerp(s_Transform.trans + s_MoveVector, p_DeltaTime / self.m_FinalSpeed)
	end
end

function CineCam:LowerWeapon()
	local s_Player = PlayerManager:GetLocalPlayer()
	self.m_WeaponLowered = not self.m_WeaponLowered

	if s_Player ~= nil then
    	s_Player:EnableInput(EntryInputActionEnum.EIAFire, not self.m_WeaponLowered)
		m_Logger:Write("Weapon lowered set to: " .. tostring(self.m_WeaponLowered))
	end
end

return CineCam()
