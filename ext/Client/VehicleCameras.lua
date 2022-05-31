---@class VehicleCameras
VehicleCameras = class 'VehicleCameras'

---@type Logger
local m_Logger = Logger('VehicleCameras', true)

function VehicleCameras:__init()
    self:RegisterVars()
end

function VehicleCameras:RegisterVars()
    self.m_Enabled = false
    self.m_CameraData = nil
    self.m_ActiveCamera = nil
    self.m_MoveSteps = 0.5
    self.m_CurrentOffset = Vec3(0, 0, 0)
end

function VehicleCameras:CreateCameraAndTakeControl(p_Transform)
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
	self.m_CameraData.fov = 90
	self.m_CameraData.transform = p_Transform
    self.m_ActiveCamera = s_Entity
    self.m_ActiveCamera:FireEvent('TakeControl')
end

function VehicleCameras:UpdateCameras(p_Player, p_DeltaTime)
    if InputManager:WentKeyDown(InputDeviceKeys.IDK_C) then
        if p_Player.inVehicle and not self.m_Enabled then
            self.m_Enabled = true
            local s_Vehicle = p_Player.controlledControllable
            local s_Transform = SpatialEntity(s_Vehicle).transform
            self:CreateCameraAndTakeControl(s_Transform)
        elseif self.m_Enabled then
            self.m_Enabled = false
            self.m_ActiveCamera:FireEvent('ReleaseControl')
            self.m_ActiveCamera:Destroy()
        end
    end

    if self.m_Enabled then
        local s_PlayerCameraTransform = ClientUtils:GetCameraTransform()
        local s_Vehicle = p_Player.controlledControllable
        local s_VehicleTransform = SpatialEntity(s_Vehicle).transform

        local s_Offset = Vec3()
        if InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowLeft) then
            s_Offset = Vec3(self.m_MoveSteps, 0, 0)
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowRight) then
            s_Offset = Vec3(-self.m_MoveSteps, 0, 0)
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowUp) then
            s_Offset = Vec3(0, 0, self.m_MoveSteps)
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowDown) then
            s_Offset = Vec3(0, 0, -self.m_MoveSteps)
        end

        self.m_CurrentOffset = self.m_CurrentOffset + s_Offset

        if s_PlayerCameraTransform ~= nil then
            local s_CameraPosition = s_VehicleTransform
            s_CameraPosition.trans = s_VehicleTransform.trans + self.m_CurrentOffset
            local s_CamWorldTrans = s_CameraPosition * s_VehicleTransform
            self.m_CameraData.transform = s_CamWorldTrans
        end
    end
end



return VehicleCameras()