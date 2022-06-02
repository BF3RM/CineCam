---@class WeaponCameras
WeaponCameras = class 'WeaponCameras'

---@type Logger
local m_Logger = Logger('WeaponCameras', false)

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
    self.m_CurrentOffset = Vec3(0, 0, 0)
    self.m_Player = nil
    self.m_Inversed = false
end

function WeaponCameras:OnLevelDestroyed()
    self:Disable()
    self:ResetVars()
end

function WeaponCameras:OnExtensionUnloading()
    self:Disable()
    self:ResetVars()
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

	-- higher fov because gopro style mby?
	self.m_CameraData.fov = 80
	self.m_CameraData.transform = p_Transform
    self.m_ActiveCamera = s_Entity
    self.m_ActiveCamera:FireEvent('TakeControl')
end

function WeaponCameras:Disable()
    self.m_Enabled = false
    if self.m_ActiveCamera ~= nil then
        self.m_ActiveCamera:FireEvent('ReleaseControl')
        self.m_ActiveCamera:Destroy()
        self.m_ActiveCamera = nil
    end
end

function WeaponCameras:OnUpdatePlayerInput(p_Player, p_DeltaTime)
    if self.m_Player == nil then
        self.m_Player = p_Player
    end

    if InputManager:WentKeyDown(InputDeviceKeys.IDK_C) then
        if not self.m_Player.inVehicle and self.m_Player.soldier ~= nil and not self.m_Enabled then
            self.m_Enabled = true
            self.m_Detached = false
            local s_Transform = self.m_Player.soldier.worldTransform
            self:CreateCameraAndTakeControl(s_Transform)
        elseif self.m_Enabled then
            self:Disable()
        end
    end

    if InputManager:WentKeyDown(InputDeviceKeys.IDK_V) then
        -- inverse
        self.m_Inversed = not self.m_Inversed
    end

    if InputManager:WentKeyDown(InputDeviceKeys.IDK_B) then
        -- inverse
        self.m_Detached = not self.m_Detached
    end
end

function WeaponCameras:OnUpdate(p_DeltaTime)
    if self.m_Player == nil then
        self.m_Enabled = false
    end

    if self.m_Detached then
        return
    end

    if self.m_Enabled then
        local s_OffsetLT = LinearTransform()
        local s_OffsetTrans = Vec3()
        local s_OffsetTransLR = Vec3()
        local s_OffsetTransFB = Vec3()
        local s_OffsetTransUD = Vec3()

        local s_MoveSteps = Config.MOUNTED_CAMERA_MOVE_SPEED

        if InputManager:IsKeyDown(InputDeviceKeys.IDK_LeftShift) then
            s_MoveSteps = s_MoveSteps * Config.MOUNTED_CAMERA_BOOST_MULTIPLIER
        end

        --LR
        if InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowLeft) then
            s_OffsetTransLR = Vec3(-s_MoveSteps, 0, 0)
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowRight) then
            s_OffsetTransLR = Vec3(s_MoveSteps, 0, 0)
        end

        --FB
        if InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowUp) then
            s_OffsetTransFB = Vec3(0, s_MoveSteps, 0)
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_ArrowDown) then
            s_OffsetTransFB = Vec3(0, -s_MoveSteps, 0)
        end

        --UD
        if InputManager:IsKeyDown(InputDeviceKeys.IDK_Space) then
            s_OffsetTransUD = Vec3(0, 0, s_MoveSteps)
        elseif InputManager:IsKeyDown(InputDeviceKeys.IDK_LeftCtrl) then
            s_OffsetTransUD = Vec3(0, 0, -s_MoveSteps)
        end

        s_OffsetTrans = s_OffsetTransLR + s_OffsetTransFB + s_OffsetTransUD

        local s_WeaponTransform = self.m_Player.soldier.weaponsComponent.weaponTransform

        self.m_CurrentOffset = self.m_CurrentOffset + s_OffsetTrans
        -- correct weapon transform leveling
        s_OffsetLT.left = Vec3(1, 0, 0)
        s_OffsetLT.up = Vec3(0, 0, 1)
        s_OffsetLT.forward = Vec3(0, -1, 0)
        s_OffsetLT.trans = self.m_CurrentOffset
        -- correct ypr
        local s_CorrectionTransform = MathUtils:GetTransformFromYPR(math.pi, math.pi/0.91, math.pi/2)

        if self.m_Inversed then
            s_WeaponTransform.forward = s_WeaponTransform.forward * (-1)
            s_WeaponTransform.left = s_WeaponTransform.left * (-1)
            s_CorrectionTransform = MathUtils:GetTransformFromYPR(math.pi, math.pi/0.53, math.pi/2)
        end

        self.m_CameraData.transform = s_OffsetLT * s_CorrectionTransform * s_WeaponTransform
    end
end

return WeaponCameras()
