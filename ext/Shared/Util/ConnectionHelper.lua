class "ConnectionHelper"


function ConnectionHelper:CreateEventConnection(p_Source, p_Target, p_SourceEvent, p_TargetEvent, p_Type)
    local s_SourceEventSpec = EventSpec()
    s_SourceEventSpec.id = tonumber(p_SourceEvent) or MathUtils:FNVHash(p_SourceEvent)

    local s_TargetEventSpec = EventSpec()
    s_TargetEventSpec.id = tonumber(p_TargetEvent) or MathUtils:FNVHash(p_TargetEvent)

    local s_EventConnection = EventConnection()
    s_EventConnection.source = p_Source
    s_EventConnection.target = p_Target
    s_EventConnection.sourceEvent = s_SourceEventSpec
    s_EventConnection.targetEvent = s_TargetEventSpec
    s_EventConnection.targetType = p_Type

    return s_EventConnection
end

function ConnectionHelper:CreatePropertyConnection(p_Source, p_Target, p_SourceFieldId, p_TargetFieldId)  
    local s_PropertyConnection = PropertyConnection()
    s_PropertyConnection.source = p_Source
    s_PropertyConnection.target = p_Target
    s_PropertyConnection.sourceFieldId = tonumber(p_SourceFieldId) or MathUtils:FNVHash(p_SourceFieldId)
    s_PropertyConnection.targetFieldId = tonumber(p_TargetFieldId) or MathUtils:FNVHash(p_TargetFieldId)

	return s_PropertyConnection
end

function ConnectionHelper:CreateLinkConnection(p_Source, p_Target, p_SourceEvent, p_TargetEvent)
	local s_LinkConnection = LinkConnection()
    s_LinkConnection.source = p_Source
    s_LinkConnection.target = p_Target
    s_LinkConnection.sourceFieldId = tonumber(p_SourceFieldId) or MathUtils:FNVHash(p_SourceFieldId)
    s_LinkConnection.targetFieldId = tonumber(p_TargetFieldId) or MathUtils:FNVHash(p_TargetFieldId)

	return s_LinkConnection
end

-- Singleton.
if g_ConnectionHelper == nil then
	g_ConnectionHelper = ConnectionHelper()
end

return g_ConnectionHelper