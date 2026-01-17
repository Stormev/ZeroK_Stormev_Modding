function widget:GetInfo()
	return {
		name      = "Nuclear Commander",
		desc      = "Draw second radius for anti nuke in which 2 nuclear warheads are shot down, add distance mark while selected nuke",
		author    = "Stormev, help Helwor",
		date      = "2026-01-16",
		license   = "GPL v2 or later",
		layer     = 0,
		enabled   = true,
		handler   = true,
	}
end

-- memory
local detectedAntinukes = {}
local enemyTeams = {}

local selectedNukeLaunchers = {}

-- iternal names
local antiNukeDefID = UnitDefNames["staticantinuke"] and UnitDefNames["staticantinuke"].id
-- internal name пусковой
local LAUNCHER_DEF_ID = UnitDefNames["staticnuke"] and UnitDefNames["staticnuke"].id
-- проверяет: возвращает unitID launcher’а, если такой выбран

-- параметры
local searchRadius = 3000
local scanStepDelay = 0.3
local timeSinceLastScan = 0

local baseRadius = 1000
local PROPORTION = 1.5
local baseSafeRange = 6660
local MAX_R = 2500
local MIN_R = 500
local lastRange = 0

-- data accestion object
local myPlayerID = Spring.GetMyPlayerID()
local myTeamID, myAllyTeamID
local selectionChanged = false

local spGetUnitsInCylinder      = Spring.GetUnitsInCylinder
local spGetUnitDefID            = Spring.GetUnitDefID
local spGetUnitPosition         = Spring.GetUnitPosition
local spGetTeamUnits            = Spring.GetTeamUnits
local spGetMyTeamID             = Spring.GetMyTeamID
local spGetSelectedUnits        = Spring.GetSelectedUnits
local spGetselectedUnitsSorted  = Spring.GetSelectedUnitsSorted
local spIsPosInRadar              = Spring.IsPosInRadar
local spAreTeamsAllied          = Spring.AreTeamsAllied
local Echo                      = Spring.Echo

local glColor        = gl.Color
local glLineWidth    = gl.LineWidth
local glBeginEnd     = gl.BeginEnd
local glVertex       = gl.Vertex
local glDepthTest    = gl.DepthTest
local GL_LINES       = GL.LINES
local spGetGroundHeight = Spring.GetGroundHeight


-- seek most smallest distance between anti and nuke launcher
function findNearestNukeLauncher(pos_x, pos_y, pos_z) -- arguments - anti pos
	if selectedNukeLaunchers and #selectedNukeLaunchers > 0 then
		local ways = {}
		local minUnit, minValue

		for _, unitId in pairs(selectedNukeLaunchers) do
			local x, y, z = select(4, spGetUnitPosition(unitId, true))
			local dx = x - pos_x
			local dz = z - pos_z
			local p = math.sqrt(dx*dx + dz*dz)
			ways[unitId] = p
		end
		
		for unitID, value in pairs(ways) do
			if minValue == nil or value < minValue then
				minValue = value
				minUnit = unitID
			end
		end
		return minUnit
	end
	return nil
end

-- calculate anti-nuke radius
function calcRealRadius(pos_x, pos_y, pos_z) -- arguments - anti pos
	if selectedNukeLaunchers and #selectedNukeLaunchers > 0 then
		local lx, ly, lz = select(7, spGetUnitPosition(findNearestNukeLauncher(pos_x, pos_y, pos_z), true, true))
		
		-- расстояние между пусковой и antinuke
		local dx = lx - pos_x
		local dz = lz - pos_z
		local p = math.sqrt(dx*dx + dz*dz)
		
		if p < MIN_R then
			p = MIN_R
		end

		local r = (baseSafeRange - p) * PROPORTION

		if r > MAX_R then
			r = MAX_R
		end
		
		if r < MIN_R then
			r = MIN_R
		end

		return r
	end
end

function getSelectedNukeLaunchers()
	local selectedNukes = spGetselectedUnitsSorted()[LAUNCHER_DEF_ID]
	if selectedNukes then
		return selectedNukes
	end
	return {}
end

-- draw line
local function DrawGroundLine(x1, z1, x2, z2)
    local y1 = spGetGroundHeight(x1, z1)
    local y2 = spGetGroundHeight(x2, z2)
	
	glColor(1, 0, 0, 0.6)
    glLineWidth(2)
	
    glBeginEnd(GL_LINES, function()
        glVertex(x1, y1 + 5, z1)
        glVertex(x2, y2 + 5, z2)
    end)
	
	glColor(1, 1, 1, 1)
    glLineWidth(1)
end

local function calcNukeThreatAngle(ax, ay, az)
    -- ищем ближайшего nuke лаунчера
    local nearestLauncher = findNearestNukeLauncher(ax, ay, az)
    if not nearestLauncher then
        return nil
    end

    -- получаем позицию этого лаунчера
    local lx, ly, lz = spGetUnitPosition(nearestLauncher)
    if not lx then
        return nil
    end

    -- горизонтальный вектор от anti→launcher
    local dirX = lx - ax
    local dirZ = lz - az

    -- угол в радианах
    local angleRad = math.atan2(dirZ, dirX)

    -- преобразуем в градусы (если нужны градусы)
    local angleDeg = angleRad * (180 / math.pi)

    return angleRad, angleDeg, nearestLauncher
end

local function DrawThreatDirectionLine(ax, ay, az)
    -- получаем направление
    local angleRad = select(1, calcNukeThreatAngle(ax, ay, az))
    if not angleRad then
        return
    end

    -- длина линии
    local length = 2500

    -- конечная точка в направлении угла
    local endX = ax + math.cos(angleRad) * length
    local endZ = az + math.sin(angleRad) * length

    -- высоты земли
    local startY = Spring.GetGroundHeight(ax, az)
    local endY   = Spring.GetGroundHeight(endX, endZ)

    -- рисуем линию
    gl.Color(1, 0.5, 0, 0.3)
    gl.LineWidth(2)

    gl.BeginEnd(GL.LINES, function()
        gl.Vertex(ax, startY + 5, az)
        gl.Vertex(endX, endY + 5, endZ)
    end)

    gl.LineWidth(1)
    gl.Color(1,1,1,1)
end

local function DrawThreatWall(ax, ay, az, offsetAlongThreat, lenght)

    -- получаем направление угрозы
    local angleRad = select(1, calcNukeThreatAngle(ax, ay, az))
    if not angleRad then
        return
    end

    offsetAlongThreat = offsetAlongThreat or 0

    -- длина стены
    local halfLength = (lenght or 5000) * 0.5

    -- вектор направления угрозы
    local dirX = math.cos(angleRad)
    local dirZ = math.sin(angleRad)

    -- перпендикулярный вектор на 90°
    local perpX = -dirZ
    local perpZ = dirX

    -- центр стены со смещением вдоль направления угрозы
    -- отрицательное offset → против стороны угрозы
    local centerX = ax - dirX * -offsetAlongThreat
    local centerZ = az - dirZ * -offsetAlongThreat

    -- точки начала и конца стены перпендикулярно угрозе
    local startX = centerX + perpX * halfLength
    local startZ = centerZ + perpZ * halfLength

    local endX   = centerX - perpX * halfLength
    local endZ   = centerZ - perpZ * halfLength

    -- высоты по поверхности
    local startY = Spring.GetGroundHeight(startX, startZ)
    local endY   = Spring.GetGroundHeight(endX, endZ)

    -- рисуем линию
    gl.Color(1, 0.7, 0, 0.5)
    gl.LineWidth(2)

    gl.BeginEnd(GL.LINES, function()
        gl.Vertex(startX, startY + 5, startZ)
        gl.Vertex(endX, endY + 5, endZ)
    end)

    gl.LineWidth(1)
    gl.Color(1,1,1,1)
end

local function DrawThreatWallStatic(ax, ay, az, offsetAlongThreat)

    -- получаем направление угрозы
    local angleRad = select(1, calcNukeThreatAngle(ax, ay, az))
    if not angleRad then
        return
    end

    offsetAlongThreat = offsetAlongThreat or 0

    -- длина стены
    local halfLength = 5000 * 0.5

    -- вектор направления угрозы
    local dirX = math.cos(angleRad)
    local dirZ = math.sin(angleRad)

    -- перпендикулярный вектор на 90°
    local perpX = -dirZ
    local perpZ = dirX

    -- центр стены со смещением вдоль направления угрозы
    -- отрицательное offset → против стороны угрозы
    local centerX = ax - dirX * -offsetAlongThreat
    local centerZ = az - dirZ * -offsetAlongThreat

    -- точки начала и конца стены перпендикулярно угрозе
    local startX = centerX + perpX * halfLength
    local startZ = centerZ + perpZ * halfLength

    local endX   = centerX - perpX * halfLength
    local endZ   = centerZ - perpZ * halfLength

    -- высоты по поверхности
    local startY = Spring.GetGroundHeight(startX, startZ)
    local endY   = Spring.GetGroundHeight(endX, endZ)

    -- рисуем линию
    gl.Color(1, 0, 0, 1)
    gl.LineWidth(2)

    gl.BeginEnd(GL.LINES, function()
        gl.Vertex(startX, startY + 5, startZ)
        gl.Vertex(endX, endY + 5, endZ)
    end)

    gl.LineWidth(1)
    gl.Color(1,1,1,1)
end


-- draw frontline summary others radius antis
function drawAntiNukeFrontLine()
	for unitID, pos in pairs(detectedAntinukes) do
        -- проверка существования юнита
        if not Spring.ValidUnitID(unitID) then
            if Spring.IsPosInRadar(pos.x, pos.y, pos.z, myAllyTeamID) then
                Spring.Echo("Antinuke "..unitID.." doesn't exist anymore!")
                detectedAntinukes[unitID] = nil
            end
            return
        end

        -- обновление позиции
        local x,y,z = Spring.GetUnitPosition(unitID)
        pos.x, pos.y, pos.z = x,y,z

        -- x y z -- anti pos
        DrawThreatDirectionLine(x, y, z)
		DrawThreatWall(x, y, z, calcRealRadius(x, y, z) * 0.95)
		DrawThreatWallStatic(x, y, z, 20)
    end
end

-- draw
function widget:DrawWorld()
	if #selectedNukeLaunchers <= 1 then
		return
	end
	
	gl.Color(1, 0, 0, 0.4)
	for unitID, pos in pairs(detectedAntinukes) do
		local x,y,z = select(4, spGetUnitPosition(unitID, true))
		if x then
			pos.x, pos.y, pos.z = x,y,z
		else
			if spIsPosInRadar(pos.x, pos.y, pos.z, myAllyTeamID) then
				Echo('Antinuke ' .. unitID .. ' doesn\'t exist anymore !')
				detectedAntinukes[unitID] = nil
				return
			end
		end
		glLineWidth(2)
		gl.DrawGroundCircle(pos.x, pos.y, pos.z, calcRealRadius(pos.x, pos.y, pos.z), 60)
	end
	
	drawAntiNukeFrontLine()
	
	gl.Color(1,1,1,1)
	glLineWidth(1)
end


-- seek anti's
function widget:Update(dt)
	timeSinceLastScan = timeSinceLastScan + dt
	if timeSinceLastScan > scanStepDelay then
		timeSinceLastScan = 0
		for unitID, pos in pairs(detectedAntinukes) do
			if not spGetUnitPosition(unitID) and spIsPosInRadar(pos.x, pos.y, pos.z, allyTeamID) then
				Echo('Antinuke ' .. unitID .. ' doesn\'t exist anymore (update)!')
				detectedAntinukes[unitID] = nil
			end
		end
	end
end


-- draw distance
function widget:DrawScreen()
	local selectedNukeLaunchers = getSelectedNukeLaunchers()
	
	if selectedNukeLaunchers and #selectedNukeLaunchers <= 1 then
		return
	end
	
	local lx, ly, lz = select(7, spGetUnitPosition(selectedNukeLaunchers[1], true, true)) -- get aim position

	if not lx then
		return
	end

	local mx, my = Spring.GetMouseState()
	local desc, data = Spring.TraceScreenRay(mx, my, true)
	local tx, ty, tz

	if desc == "ground" and data then
		tx, ty, tz = data[1], data[2], data[3]
	else
		return
	end

	local dx = tx - lx
	local dz = tz - lz
	local dist = math.sqrt(dx*dx + dz*dz)
	lastRange = dist
	local text = string.format("Nuke Distance: %.1f", dist)
	local fontSize = 20

	local vsx, vsy = Spring.GetViewGeometry()
	local screenX, screenY = mx * 1.014, my * 1.014

	gl.Color(1, 1, 0, 1)
	gl.Text(text, screenX, screenY, fontSize, "o")
	gl.Color(1,1,1,1)
end

-- if destroyed
function widget:UnitDestroyed(unitID)
	detectedAntinukes[unitID] = nil
end

-- if given
function widget:UnitGiven(unitID, deFID, toTeam, fromTeam)
	if detectedAntinukes[unitID] and spAreTeamsAllied(toTeam, myTeamID) then
		Echo("Enemy AntiNuke captured! " .. unitID)
		detectedAntinukes[unitID] = nil
	end
end

-- if captured
function widget:UnitTaken(unitID, defID, fromTeam, toTeam)
	if defID == antiNukeDefID and spAreTeamsAllied(fromTeam, myTeamID) and not spAreTeamsAllied(toTeam, myTeamID) then
		local x, y, z = select(4, spGetUnitPosition(unitID, true))
		if x then
			Echo("Our AntiNuke got captured! " .. unitID)
			detectedAntinukes[unitID] = {x = x, y = y, z = z}
		else
			Echo('Error, Antinuke ' .. unitID .. ' doesn\'t have position after getting taken from allied team')
		end
	end
end

-- ENGINE LIMITATION: if an anti has been already discovered and the widget is reloaded:
-- if the unit just appear in radar and not been previously seen by LoS (not LOS_PREVLOS and not LOS_CONTRADAR) spGetUnitDefID(unitID) gives nothings, even though the user can see what it is
-- so the next function is useless
-- function widget:UnitEnteredRadar(unitID, teamID, forAllyTeam, defID)
-- 	if not detectedAntinukes[unitID] and enemyTeams[teamID] then
-- 		if (defID or spGetUnitDefID(unitID)) == antiNukeDefID then
-- 			local x, y, z = select(4, spGetUnitPosition(unitID, true))
-- 			if x then
-- 				Echo("Enemy AntiNuke Detected: " .. unitID)
-- 				detectedAntinukes[unitID] = {x = x, y = y, z = z}
-- 			else
-- 				Echo('Error, Antinuke ' .. unitID .. ' doesn\'t have position when entering Radar')
-- 			end
-- 		end
-- 	end
-- end

-- if we see enemy anti nuke
function widget:UnitEnteredLos(unitID, teamID, forAllyTeam, defID)
	if not detectedAntinukes[unitID] then
		if enemyTeams[teamID] then
			if (defID or spGetUnitDefID(unitID)) == antiNukeDefID then
				local x, y, z = select(4, spGetUnitPosition(unitID, true))
				if x then
					Echo("Enemy AntiNuke Detected: " .. unitID)
					detectedAntinukes[unitID] = {x = x, y = y, z = z}
				else
					Echo('Error, Antinuke ' .. unitID .. ' doesn\'t have position when entering Los')
				end
			end
		end
	else -- update pos in case of terraform missile used on anti
		local x, y, z = select(4, spGetUnitPosition(unitID, true))
		if x then
			local obj = detectedAntinukes[unitID]
			obj.x, obj.y, obj.z = x, y, z
		end
	end
end

function widget:SelectionChanged(selectedUnits, deselectedUnits)
	selectionChanged = true
	selectedNukeLaunchers = getSelectedNukeLaunchers()
end

function widget:CommandsChanged()
	if selectionChanged then
		selectionChanged = false
		local selectedNukes = spGetselectedUnitsSorted()[LAUNCHER_DEF_ID]
		selectedNukeLaunchers = selectedNukes or {}
	end
end

function widget:PlayerChanged(playerID)
	if playerID ~= myPlayerID then
		return
	end
	local newTeamID = Spring.GetMyTeamID()

	if newTeamID ~= myTeamID then
		if not spAreTeamsAllied(newTeamID, myTeamID) then
			widget:Initialize()
			return
		end
		myTeamID = newTeamID
	end
end
function widget:Initialize()
	if not (LAUNCHER_DEF_ID and antiNukeDefID) then
		Spring.Echo('['..widget:GetInfo().name..']: ' .. 'Game doesn\'t have Nuke/Anti Nuke, shutting down')
		widgetHandler:RemoveWidget(widget)
		return
	end
	detectedAntinukes = {}
	enemyTeams = {}
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if not spAreTeamsAllied(teamID, myTeamID) then
			enemyTeams[teamID] = true
			for _, unitID in ipairs(Spring.GetTeamUnitsByDefs(teamID, {antiNukeDefID})) do
				widget:UnitEnteredLos(unitID, teamID, myTeamID, antiNukeDefID)
			end
		end
	end
	-- Helwor's workaround to get discovered buildings mid game (may not work 100%)
	if WG.structDiscoveredByAllyTeams then
		local discovered = WG.structDiscoveredByAllyTeams and WG.structDiscoveredByAllyTeams[myAllyTeamID]
		if discovered then
			for unitID, struct in pairs(discovered) do
				if struct.defID == antiNukeDefID and struct.teamID and not spAreTeamsAllied(struct.teamID, myTeamID) then
					if not detectedAntinukes[unitID] then
						local x, y, z = select(4, spGetUnitPosition(unitID))
						if not x then
							Echo('Antinuke added via Structure Discovered, with memorized pos '.. unitID)
							detectedAntinukes[unitID] = {x = struct[4], y = struct[5], z = struct[6]}
						else
							Echo('Antinuke added via Structure Discovered '.. unitID)
							detectedAntinukes[unitID] = {x = x, y = y, z = z}
						end
					end
				end
			end
		end
	end
	selectionChanged = true
	widget:CommandsChanged()
end