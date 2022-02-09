local points = {
}

---@type Logger
local m_Logger = Logger("PointRenderer", false)

local activeIndex = nil
local selectedIndex = nil
local savedPosition = nil

local closeLoop = false

local center = ClientUtils:GetWindowSize()/2

local function getVertexForPoint(vec3)

	local vertex = DebugVertex()
	vertex.pos = vec3
	vertex.color = Vec4(1, 1, 1, 0.5)

	return vertex
end

local function appendVerticesForSegment(vertices, from, to)
	local i = #vertices
	from = from:ToLinearTransform()
	to = to:ToLinearTransform()

	-- Every segment is 2 triangles, each triangle is 3 points
	vertices[i+1] = getVertexForPoint(from.trans)	-- ◩
	vertices[i+2] = getVertexForPoint(from.trans + (from.forward * -1))
	if not to then
		return
	end
	vertices[i+3] = getVertexForPoint(to.trans + (to.forward * -1))
	vertices[i+4] = getVertexForPoint(from.trans) -- ◪
	vertices[i+5] = getVertexForPoint(to.trans)
	vertices[i+6] = getVertexForPoint(to.trans + (to.forward * -1))
end

local function printPointsAsVec3s()
	m_Logger:Write("printing "..tostring(#points).." points")

	local result = "points = { "

	for index, point in pairs(points) do

		result = result.."Vec3"..tostring(point)..", "
	end

	m_Logger:Write(result.."}")
end

local function printPointsAsVec2s()
	m_Logger:Write("printing "..tostring(#points).." points")

	local result = "points = { "

	for index, point in pairs(points) do

		result = result.. tostring(point)..", "
	end

	m_Logger:Write(result.."}")
end

Events:Subscribe('UI:DrawHud', function()
	local vertices = {}

	for i, point in pairs(points) do
		point = point:ToLinearTransform()

		-- Draw green spheres for the first point
		if i == 1 then
			DebugRenderer:DrawSphere(point.trans, 0.1, Vec4(0, 1, 0, 0.5), true, false)
			DebugRenderer:DrawLine(point.trans, point.trans + (point.forward * -1), Vec4(0, 1, 0, 0.5), Vec4(0, 1, 0, 0.5))
		else
			-- Draw segment between saved points
			-- appendVerticesForSegment(vertices, points[i-1], points[i])

			-- Draw 2 green spheres at every point that isn't the active one
			if i ~= activeIndex then
				DebugRenderer:DrawSphere(point.trans, 0.1, Vec4(1, 1, 1, 0.5), true, false)
				DebugRenderer:DrawLine(point.trans, point.trans + (point.forward * -1), Vec4(1, 1, 1, 0.5), Vec4(0, 1, 0, 0.5))
			end
		end
	end

	-- Draw the segment between the last and the first point
	if #points > 0 and closeLoop then
		-- appendVerticesForSegment(vertices, points[#points], points[1])
	end

	-- Draw 2 red spheres on the active point
	if activeIndex then
		DebugRenderer:DrawSphere(points[activeIndex]:ToLinearTransform().trans, 0.1, Vec4(1, 0, 0, 0.5), true, false)
	-- Draw 2 blue spheres on the selected point
	elseif selectedIndex then
		DebugRenderer:DrawSphere(points[selectedIndex]:ToLinearTransform().trans, 0.1, Vec4(0, 0, 1, 0.5), true, false)
	end

	DebugRenderer:DrawVertices(0, vertices)
end)

Events:Subscribe('Player:UpdateInput', function()
	local s_CamTrans = ClientUtils:GetCameraTransform()

	-- Press F5 to start or stop moving points
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F5) then
		-- If the active point is the last, and unconfirmed, remove it
		if activeIndex == #points and not savedPosition then
			points[activeIndex] = nil
			activeIndex = nil
		-- If a previous point was being moved, revert it back to the saved position
		elseif savedPosition then
			points[activeIndex] = savedPosition
			activeIndex = nil
			savedPosition = nil
		-- If a point is being moved, stop moving it
		elseif activeIndex then
			activeIndex = nil
		-- Start or continue adding points
		else
			activeIndex = #points + 1
			points[activeIndex] = QuatTransform()
		end
	end

	-- Press F6 to insert point after current point
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F6) then
		local index = activeIndex or selectedIndex

		if index == nil then
			return
		end

		table.insert(points, index + 1, QuatTransform(Quat(), Vec4(s_CamTrans.trans.x,s_CamTrans.trans.y,s_CamTrans.trans.z, 1)))
		activeIndex = index + 1
		selectedIndex = nil
		savedPosition = nil
	end

	-- Press F7 to toggle close loop
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F7) then
		closeLoop = not closeLoop and true or false
	end


	-- Press F4 to clear point(s)
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F4) then
		-- If theres a point being moved, clear only it
		if activeIndex then
			points[activeIndex] = nil
		-- If theres a point selected, clear only it
		elseif selectedIndex then
			points[selectedIndex] = nil
		-- Otherwise, clear all points
		else
			points = {}
			m_Logger:Write(points[1])
		end

		activeIndex = nil
		selectedIndex = nil
		savedPosition = nil
	end

	-- Press E to select point or confirm point placement
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F) then
		if activeIndex then
			-- If a point was being moved and it has now been confirmed
			if savedPosition then
				activeIndex = nil
				savedPosition = nil
			-- If the point that will be confirmed is the last, start drawing the next one
			elseif activeIndex == #points then
				activeIndex = activeIndex + 1
				savedPosition = nil
			-- If theres no saved position and the point being moved is not the last, an inserted point was being placed and it has now been confirmed
			else
				activeIndex = nil
			end
		-- If E is pressed while a previous point is selected, that point becomes the active point
		elseif selectedIndex then
			savedPosition = points[selectedIndex]
			activeIndex = selectedIndex
			selectedIndex = nil
		end
	end

	-- Press F3 to print points as Vec3s
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F3) then
		printPointsAsVec3s()
	end

	-- Press F2 to print points as Vec2s
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F2) then
		printPointsAsVec2s()
	end
end)

-- stolen't https://github.com/EmulatorNexus/VEXT-Samples/blob/80cddf7864a2cdcaccb9efa810e65fae1baeac78/no-headglitch-raycast/ext/Client/__init__.lua
local function raycast()
	local localPlayer = PlayerManager:GetLocalPlayer()

	if localPlayer == nil then
		return
	end

	-- We get the camera transform, from which we will start the raycast. We get the direction from the forward vector. Camera transform
	-- is inverted, so we have to invert this vector.
	local transform = ClientUtils:GetCameraTransform()
	local direction = Vec3(-transform.forward.x, -transform.forward.y, -transform.forward.z)

	if transform.trans == Vec3(0,0,0) then
		return
	end

	local castStart = transform.trans

	-- We get the raycast end transform with the calculated direction and the max distance.
	local castEnd = Vec3(
		transform.trans.x + (direction.x * 100),
		transform.trans.y + (direction.y * 100),
		transform.trans.z + (direction.z * 100))

	-- Perform raycast, returns a RayCastHit object.
	local raycastHit = RaycastManager:Raycast(castStart, castEnd, RayCastFlags.DontCheckWater | RayCastFlags.DontCheckCharacter | RayCastFlags.DontCheckRagdoll | RayCastFlags.CheckDetailMesh)

	return raycastHit
end

Events:Subscribe('UpdateManager:Update', function(delta, pass)
	-- Only do raycast on presimulation UpdatePass
	if pass ~= UpdatePass.UpdatePass_PreSim then
		return
	end

	local raycastHit = raycast()

	if raycastHit == nil then
		return
	end

	local hitPosition = raycastHit.position

	selectedIndex = nil

	-- Move the active point to the "point of aim"
	if activeIndex then
		local newTransform = ClientUtils:GetCameraTransform()
		points[activeIndex] = newTransform:ToQuatTransform(true)
	-- If theres no active point, check to see if the POA is near a point
	else
		for index, point in pairs(points) do
			local pointScreenPos = ClientUtils:WorldToScreen(point:ToLinearTransform().trans)

			-- Skip to the next point if this one isn't in view
			if pointScreenPos == nil then
				goto continue
			end

			-- Select point if its close to the hitPosition
			if center:Distance(pointScreenPos) < 20 then
				selectedIndex = index
			end

			::continue::
		end
	end
end)

Console:Register('load', '<Guid> load points from existing VolumeVectorShapeData', function(args)
	if #args == 0 then
		return
	end

	local guid = Guid(args[1])

	if guid == nil then
		return
	end

	local instance = ResourceManager:SearchForInstanceByGuid(guid)

	if instance == nil or not instance:Is("VolumeVectorShapeData") then
		print("could not load VolumeVectorShapeData")
		return
	end

	points = {}
	savedPosition = nil
	activeIndex = nil
	closeLoop = true

	local vectorData = VolumeVectorShapeData(instance)

	for i, point in pairs(vectorData.points) do
		points[i] = Vec3(point:Clone())
	end
end)

Console:Register('help', 'show usage info', function(args)
	print("\nPress F5 to start/stop placing\n"..
		"Press E to confirm position or select a previous point\n"..
		"Press F4 to delete a point/all points if none are selected\n"..
		"Press F6 to insert a point after the selected point\n"..
		"Press F7 to toggle close loop\n"..
		"Press F2/F3 to print as Vec2s/Vec3s\n")
end)

return points
