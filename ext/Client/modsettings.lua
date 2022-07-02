---@type Logger
local m_Logger = Logger("ModSettings", false)

local m_ModSettings_Keybinds = {
	["RSMD"] = {
		displayName = "Decrease Rotation Speed Multiplier",
		default = InputDeviceKeys.IDK_PageDown
	},
	["RSMI"] = {
		displayName = "Increase Rotation Speed Multiplier",
		default = InputDeviceKeys.IDK_PageUp
	},
	["Toggle_CineCam"] = {
		displayName = "Toggle CineCam",
		default = InputDeviceKeys.IDK_F2
	},
	["FOVD"] = {
		displayName = "Decrease CineCam FOV",
		default = InputDeviceKeys.IDK_ArrowDown
	},
	["FOVI"] = {
		displayName = "Increase CineCam FOV",
		default = InputDeviceKeys.IDK_ArrowUp
	},
	["MoveUp"] = {
		displayName = "Move Camera up",
		default = InputDeviceKeys.IDK_E
	},
	["MoveDown"] = {
		displayName = "Move Camera down",
		default = InputDeviceKeys.IDK_Q
	},
}

for l_Name, l_Preference in pairs(m_ModSettings_Keybinds) do
	local s_Setting = SettingsManager:GetSetting(l_Name)

	if s_Setting == nil then
		s_Setting = SettingsManager:DeclareKeybind(l_Name, l_Preference.default,
			{ displayName = l_Preference.displayName, showInUi = true })
		s_Setting.value = l_Preference.default

		m_Logger:Write("Created setting for " .. l_Name)
	end
end
