---@class WeaponCameras
WeaponCameras = class 'WeaponCameras'

---@type Logger
local m_Logger = Logger('WeaponCameras', true)

function WeaponCameras:__init()
    self:RegisterVars()
end

function WeaponCameras:RegisterVars()
    self:ResetVars()
end

function WeaponCameras:ResetVars()
    self.m_Enabled = false
    self.m_CameraData = nil
    self.m_ActiveCamera = nil
    self.m_MoveSteps = 0.05
    self.m_CurrentOffset = Vec3(0, 0, 0)
    self.m_Player = nil
    self.m_Inversed = false
end

function WeaponCameras:CreateCameraAndTakeControl(p_Transform)
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

function WeaponCameras:OnUpdatePlayerInput(p_Player, p_DeltaTime)
    if self.m_Player == nil then
        self.m_Player = p_Player
    end

    if InputManager:WentKeyDown(InputDeviceKeys.IDK_C) then
        if not self.m_Player.inVehicle and self.m_Player.soldier ~= nil and not self.m_Enabled then
            self.m_Enabled = true
            local s_Transform = self.m_Player.soldier.weaponsComponent.weaponTransform
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

function WeaponCameras:OnUpdate(p_DeltaTime)
    if self.m_Player == nil or self.m_Player.controlledControllable == nil then
        self.m_Enabled = false
    end

    if self.m_Enabled then
        local s_WeaponTransform = self.m_Player.soldier.weaponsComponent.weaponTransform

        local s_OffsetLT = LinearTransform()
        local s_OffsetTrans = Vec3()
        local s_OffsetTransLR = Vec3()
        local s_OffsetTransFB = Vec3()
        local s_OffsetTransUD = Vec3()

        --LR
        if InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowLeft) then
            if self.m_Inversed then
                s_OffsetTransLR = Vec3(-self.m_MoveSteps, 0, 0)
            else
                s_OffsetTransLR = Vec3(self.m_MoveSteps, 0, 0)
            end
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowRight) then
            if self.m_Inversed then
                s_OffsetTransLR = Vec3(self.m_MoveSteps, 0, 0)
            else
                s_OffsetTransLR = Vec3(-self.m_MoveSteps, 0, 0)
            end
        end

        --FB
        if InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowUp) then
            if self.m_Inversed then
                s_OffsetTransFB = Vec3(0, 0, -self.m_MoveSteps)
            else
                s_OffsetTransFB = Vec3(0, 0, self.m_MoveSteps)
            end
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowDown) then
            if self.m_Inversed then
                s_OffsetTransFB = Vec3(0, 0, self.m_MoveSteps)
            else
                s_OffsetTransFB = Vec3(0, 0, -self.m_MoveSteps)
            end
        end

        --UD
        if InputManager:IsKeyDown(InputDeviceKeys.IDK_Space) then
            s_OffsetTransUD = Vec3(0, self.m_MoveSteps, 0)
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_LeftCtrl) then
            s_OffsetTransUD = Vec3(0, -self.m_MoveSteps, 0)
        end

        s_OffsetTrans = s_OffsetTransLR + s_OffsetTransFB + s_OffsetTransUD

        if self.m_Inversed then
            s_WeaponTransform.forward = s_WeaponTransform.forward * (-1)
            s_WeaponTransform.left = s_WeaponTransform.left * (-1)
        end


        local yaw, pitch, roll = RotationHelper:GetYPRFromLT(s_WeaponTransform)
        -- yaw = yaw - math.pi / 2
        -- pitch = pitch - math.pi / 2
        -- roll = roll - math.pi / 2
        local left, up, forward = RotationHelper:GetLUFFromYPR(yaw, pitch, roll)
        s_WeaponTransform.forward = forward
        s_WeaponTransform.up = up
        s_WeaponTransform.left = left

        self.m_CurrentOffset = self.m_CurrentOffset + s_OffsetTrans
        s_OffsetLT.trans = self.m_CurrentOffset
        self.m_CameraData.transform = s_OffsetLT * s_WeaponTransform
    end
end

return WeaponCameras()
