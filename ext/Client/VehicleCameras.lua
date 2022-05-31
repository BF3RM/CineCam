---@class VehicleCameras
VehicleCameras = class 'VehicleCameras'

---@type Logger
local m_Logger = Logger('VehicleCameras', true)

function VehicleCameras:__init()
    self:RegisterVars()
end

function VehicleCameras:RegisterVars()
    self:ResetVars()
end

function VehicleCameras:ResetVars()
    self.m_Enabled = false
    self.m_CameraData = nil
    self.m_ActiveCamera = nil
    self.m_MoveSteps = 0.05
    self.m_CurrentOffset = Vec3(0, 0, 0)
    self.m_Player = nil
    self.m_Inversed = false
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
	self.m_CameraData.fov = 60
	self.m_CameraData.transform = p_Transform
    self.m_ActiveCamera = s_Entity
    self.m_ActiveCamera:FireEvent('TakeControl')
end

function VehicleCameras:OnUpdatePlayerInput(p_Player, p_DeltaTime)
    if self.m_Player == nil then
        self.m_Player = p_Player
    end

    if InputManager:WentKeyDown(InputDeviceKeys.IDK_C) then
        if self.m_Player.inVehicle and not self.m_Enabled then
            self.m_Enabled = true
            local s_Vehicle = self.m_Player.controlledControllable
            local s_Transform = SpatialEntity(s_Vehicle).transform
            self:CreateCameraAndTakeControl(s_Transform)
        elseif self.m_Enabled then
            self.m_Enabled = false
            self.m_ActiveCamera:FireEvent('ReleaseControl')
            self.m_ActiveCamera:Destroy()
        end
    end

    if InputManager:WentKeyDown(InputDeviceKeys.IDK_V) then
        -- inverse
        self.m_Inversed = not self.m_Inversed
    end
end

function VehicleCameras:OnUpdate(p_DeltaTime)
    if self.m_Player == nil or self.m_Player.controlledControllable == nil then
        self.m_Enabled = false
    end

    if self.m_Enabled then
        local s_Vehicle = self.m_Player.controlledControllable
        local s_VehicleTransform = SpatialEntity(s_Vehicle).transform

        local s_OffsetLT = LinearTransform()
        local s_OffsetTrans = Vec3()

        if InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowLeft) then
            s_OffsetTrans = Vec3(self.m_MoveSteps, 0, 0)
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowRight) then
            s_OffsetTrans = Vec3(-self.m_MoveSteps, 0, 0)
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowUp) then
            s_OffsetTrans = Vec3(0, 0, self.m_MoveSteps)
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowDown) then
            s_OffsetTrans = Vec3(0, 0, -self.m_MoveSteps)
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_Space) then
            s_OffsetTrans = Vec3(0, self.m_MoveSteps, 0)
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_LeftCtrl) then
            s_OffsetTrans = Vec3(0, -self.m_MoveSteps, 0)
        end

        if self.m_Inversed then
            s_VehicleTransform.forward = s_VehicleTransform.forward * (-1)
            s_VehicleTransform.left = s_VehicleTransform.left * (-1)
        end

        self.m_CurrentOffset = self.m_CurrentOffset + s_OffsetTrans
        s_OffsetLT.trans = self.m_CurrentOffset
        self.m_CameraData.transform = s_OffsetLT * s_VehicleTransform
    end
end

return VehicleCameras()