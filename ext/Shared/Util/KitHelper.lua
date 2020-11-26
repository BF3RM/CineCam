class "KitHelper"

local m_Logger = Logger("KitHelper", false)

--- WeaponSlot_2 is inaccessible, so we dont assign anything to it.
local m_WeaponSlotsMap = {
	[1] = WeaponSlot.WeaponSlot_0,
	[2] = WeaponSlot.WeaponSlot_1,
	[3] = WeaponSlot.WeaponSlot_3,
	[4] = WeaponSlot.WeaponSlot_4,
	[5] = WeaponSlot.WeaponSlot_5,
	[6] = WeaponSlot.WeaponSlot_6,
	[7] = WeaponSlot.WeaponSlot_7,
	[8] = WeaponSlot.WeaponSlot_8
}

function KitHelper:GetKeyFromWeaponSlot(p_WeaponSlot)
	for l_Key, l_WeaponSlot in pairs(m_WeaponSlotsMap) do
		if l_WeaponSlot == p_WeaponSlot then
			return l_Key
		end
	end
end

function KitHelper:GetWeaponSlotFromKey(p_Key)
	return m_WeaponSlotsMap[p_Key]
end

function KitHelper:GetWeaponSlotsMap()
	return m_WeaponSlotsMap
end

function KitHelper:GetKitFromSoldier(p_Soldier)
    if p_Soldier == nil then
        return ''
    end

    local s_WeaponNamesArray = { }

	for s_SlotIndex, s_Weapon in pairs(p_Soldier.weaponsComponent.weapons) do
		if s_Weapon == nil then
			goto continue
		end
		-- -1 cause lua array is one indexed
		local s_WeaponSlot = s_SlotIndex - 1

		if s_WeaponSlot == WeaponSlot.WeaponSlot_2 then -- Slot 2 is never used, ignore.
			goto continue
		end

		local s_WeaponName = s_Weapon.name

		if s_WeaponName == nil or s_WeaponName == "" then
			goto continue
		end

		-- Smoke Grenade exception
		if s_WeaponName == g_Weapons.Grenade.weaponName and s_WeaponSlot == WeaponSlot.WeaponSlot_6 then
			s_WeaponName = g_Weapons.SmokeGrenade.weaponName
		end

		-- Grenade launcher exceptions
		if s_WeaponName == g_Weapons.M16A4.weaponName and s_WeaponSlot ~= WeaponSlot.WeaponSlot_0 then
			s_WeaponName = g_Weapons.M16A4_M320_Launcher.weaponName
		elseif s_WeaponName == g_Weapons.AK74M.weaponName and s_WeaponSlot ~= WeaponSlot.WeaponSlot_0 then
			s_WeaponName = g_Weapons.AK74M_GP30_Launcher.weaponName
		end

		local slotKey = self:GetKeyFromWeaponSlot(s_WeaponSlot)
		if slotKey then
			s_WeaponNamesArray[slotKey] = s_WeaponName
		end

		::continue::
	end

    return self:GetKitFromWeaponNames(s_WeaponNamesArray)
end

function KitHelper:GetKitNameFromSoldier(p_Soldier)

    local s_Kit = self:GetKitFromSoldier(p_Soldier)

    if s_Kit ~= nil then
        return s_Kit.name
    end
end

function KitHelper:GetKitIdFromSoldier(p_Soldier)
    local s_Kit = self:GetKitFromSoldier(p_Soldier)

    if s_Kit ~= nil then
        return s_Kit.orderId
    end
end

function KitHelper:FindWeaponByName(p_Name)
	for _, l_Weapon in pairs(g_Weapons) do
		if l_Weapon.weaponName:lower() == p_Name:lower() then
			return l_Weapon
		end
	end

	return nil
end

function KitHelper:GetKitFromWeaponNames(p_WeaponNamesArray)
	local s_KitsFound = {}

	for _, v in pairs(g_RUKits) do
		table.insert(s_KitsFound, { kit = v, team = TeamId.Team2 })
	end
	for _, v in pairs(g_USKits) do
		table.insert(s_KitsFound, { kit = v, team = TeamId.Team1 })
	end

	m_Logger:WriteTable(p_WeaponNamesArray)
	for l_Key, l_WeaponName in pairs(p_WeaponNamesArray) do
		s_KitsFound = self:FindWeaponInKits(l_WeaponName, s_KitsFound, l_Key)

		if #s_KitsFound == 0 then
			m_Logger:Error('No kits found with the weapon '.. l_WeaponName)
			return
		elseif #s_KitsFound == 1 then
			return s_KitsFound[1].kit, s_KitsFound[1].team
		end
	end
end

function KitHelper:FindWeaponInKits(p_WeaponName, p_Kits, p_Key)
	m_Logger:Write('Looking at key '..p_Key..', weapon name: '..p_WeaponName ..', n of kis: '..#p_Kits)
	local s_KitsFound = {}
	for _, l_Kit in pairs(p_Kits) do
		local s_WeaponData = l_Kit.kit.weapons[p_Key]

		if s_WeaponData then
			if s_WeaponData.type.weaponName:lower() == p_WeaponName:lower() then
				table.insert(s_KitsFound, l_Kit)
			end
		end
	end
	m_Logger:Write('N of matching kits: ' .. #s_KitsFound)
	return s_KitsFound
end

-- Singleton.
if g_KitHelper == nil then
    g_KitHelper = KitHelper()
end

return g_KitHelper
