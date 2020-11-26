class "EntryComponentHelper"


-- SoldierEntryComponentData: "Open Entry", torso behaves like a regular MP soldier, legs use an AntEnumeration
function EntryComponentHelper:CreateSoldierEntry(p_Index, p_AntEnumerationValue, p_AimingConstraints, p_EntryRadius)

	local s_AimingConstraintsData = AimingConstraintsData()
	s_AimingConstraintsData.minPitch = p_AimingConstraints.DOWN
	s_AimingConstraintsData.maxPitch = p_AimingConstraints.UP
	s_AimingConstraintsData.minYaw = p_AimingConstraints.LEFT
	s_AimingConstraintsData.maxYaw = p_AimingConstraints.RIGHT
	
	local s_SoldierEntryComponentData = SoldierEntryComponentData()
	s_SoldierEntryComponentData.antEntryEnumeration = self:GetAntEnumeration(357045034, p_AntEnumerationValue)
	s_SoldierEntryComponentData.aimingConstraints = s_AimingConstraintsData
	s_SoldierEntryComponentData.inputConceptDefinition = EntryInputActionMapsData(ResourceManager:FindInstanceByGuid(Guid("41EBA837-6162-48EE-8469-A78669F5DB3B"), Guid("D2B06E08-13A0-4E3B-BEE5-C674F06F9D44"))) -- Input/VeniceSoldierInputConcepts
	s_SoldierEntryComponentData.inputMapping = InputActionMappingsData(ResourceManager:FindInstanceByGuid(Guid("18A9880D-FFB4-456A-80B2-56B4EDBE02E0"), Guid("115D78B4-D4CE-46E5-84DC-73F5C092B882"))) -- Input/VeniceSoldierInputMapping
	s_SoldierEntryComponentData.poseConstraints.standPose = false
	s_SoldierEntryComponentData.poseConstraints.crouchPose = true
	s_SoldierEntryComponentData.poseConstraints.pronePose = false
	s_SoldierEntryComponentData.hudData.seatType = EntrySeatType.EST_Passenger
	s_SoldierEntryComponentData.entryRadius = p_EntryRadius
	s_SoldierEntryComponentData.show1pSoldierInEntry = true
	s_SoldierEntryComponentData.showSoldierWeaponInEntry = true
	s_SoldierEntryComponentData.show3pSoldierWeaponInEntry = true
	s_SoldierEntryComponentData.showSoldierGearInEntry = false
	s_SoldierEntryComponentData.entryOrderNumber = p_Index

	return s_SoldierEntryComponentData
end

-- PlayerEntryComponentData: entire body uses an AntEnumeration
function EntryComponentHelper:CreatePlayerEntry(p_Index, p_AntEnumerationValue, p_LinearTransform, p_AimingConstraints)

	local s_StaticCameraData = StaticCameraData()
	s_StaticCameraData.upPitchAngle = p_AimingConstraints.UP
	s_StaticCameraData.downPitchAngle = p_AimingConstraints.DOWN
	s_StaticCameraData.leftYawAngle = p_AimingConstraints.LEFT
	s_StaticCameraData.rightYawAngle = p_AimingConstraints.RIGHT
	s_StaticCameraData.yawInputAction = EntryInputActionEnum.EIACameraYaw
	s_StaticCameraData.pitchInputAction = EntryInputActionEnum.EIACameraPitch
	s_StaticCameraData.pitchSensitivityNonZoomed = 55
	s_StaticCameraData.yawSensitivityNonZoomed = 55
	--s_StaticCameraData.loosePartPhysics:add(CameraLoosePartPhysicsData(ResourceManager:FindInstanceByGuid(Guid("C9F184AE-2BDB-4204-9795-70746B508FD8"), Guid("E6D4A457-2200-4F56-A07E-C463EA9CFE18"))))
	--s_StaticCameraData.loosePartPhysics:add(CameraLoosePartPhysicsData(ResourceManager:FindInstanceByGuid(Guid("257269BC-C239-4530-8EC3-50684E18DDB5"), Guid("86CD4198-3E7F-45F8-9161-6A9E8ABD645E"))))
	s_StaticCameraData.averageFilterFrames = 100

	local s_CameraComponentData = CameraComponentData()
	s_CameraComponentData.camera = s_StaticCameraData
	s_CameraComponentData.forceFieldOfView = 75
	s_CameraComponentData.regularView.flirEnabled = false
	s_CameraComponentData.isFirstPerson = true

	local s_PlayerEntryComponentData = PlayerEntryComponentData()
	s_PlayerEntryComponentData.antEntryEnumeration = self:GetAntEnumeration(357078069, p_AntEnumerationValue)
	s_PlayerEntryComponentData.inputConceptDefinition = EntryInputActionMapsData(ResourceManager:FindInstanceByGuid(Guid("41EBA837-6162-48EE-8469-A78669F5DB3B"), Guid("D2B06E08-13A0-4E3B-BEE5-C674F06F9D44")))
	s_PlayerEntryComponentData.inputMapping = InputActionMappingsData(ResourceManager:FindInstanceByGuid(Guid("18A9880D-FFB4-456A-80B2-56B4EDBE02E0"), Guid("115D78B4-D4CE-46E5-84DC-73F5C092B882")))
	s_PlayerEntryComponentData.poseConstraints.standPose = false
	s_PlayerEntryComponentData.poseConstraints.crouchPose = true
	s_PlayerEntryComponentData.poseConstraints.pronePose = false
	s_PlayerEntryComponentData.hudData.seatType = EntrySeatType.EST_Passenger
	s_PlayerEntryComponentData.entryRadius = 5
	s_PlayerEntryComponentData.show1pSoldierInEntry = true
	s_PlayerEntryComponentData.showSoldierWeaponInEntry = true
	s_PlayerEntryComponentData.show3pSoldierWeaponInEntry = false
	s_PlayerEntryComponentData.showSoldierGearInEntry = false
	s_PlayerEntryComponentData.entryOrderNumber = index
	s_PlayerEntryComponentData.soldierOffset = p_LinearTransform.trans
	s_PlayerEntryComponentData.components:add(s_CameraComponentData)

	return s_PlayerEntryComponentData
end

function EntryComponentHelper:GetAntEnumeration(p_AssetId, p_Value)
	local s_AntEnumeration = AntEnumeration()
	s_AntEnumeration.antAsset.assetId = p_AssetId
	s_AntEnumeration.value = p_Value

	return s_AntEnumeration
end


-- Singleton.
if g_EntryComponentHelper == nil then
	g_EntryComponentHelper = EntryComponentHelper()
end

return g_EntryComponentHelper