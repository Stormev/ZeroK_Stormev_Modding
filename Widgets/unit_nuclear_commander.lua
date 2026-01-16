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

local detectedAntinukes = {}
local enemyTeams = {}
local launcherID = false
local antiNukeDefID = UnitDefNames["staticantinuke"] and UnitDefNames["staticantinuke"].id

-- параметры
local searchRadius = 3000
local scanStepDelay = 0.3
local timeSinceLastScan = 0

local baseRadius = 1000
local PROPORTION = 1.5
local baseSafeRange = 6660
local MAX_R = 2500
local MIN_R = 800
local lastRange = 0

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

-- internal name пусковой
local LAUNCHER_DEF_ID = UnitDefNames["staticnuke"] and UnitDefNames["staticnuke"].id
-- проверяет: возвращает unitID launcher’а, если такой выбран


function calcRealRadius(pos_x, pos_y, pos_z)
	local lx, ly, lz = select(7, spGetUnitPosition(launcherID, true, true))
	
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

function widget:DrawWorld()
	if not launcherID then
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
			end
		end
		gl.DrawGroundCircle(pos.x, pos.y, pos.z, calcRealRadius(pos.x, pos.y, pos.z), 60)
	end
	gl.Color(1,1,1,1)
end

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

function widget:DrawScreen()
	if not launcherID then
		return
	end

	local lx, ly, lz = select(7, spGetUnitPosition(launcherID, true, true)) -- get aim position
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

function widget:UnitDestroyed(unitID)
	detectedAntinukes[unitID] = nil
end

function widget:UnitGiven(unitID, deFID, toTeam, fromTeam)
	if detectedAntinukes[unitID] and spAreTeamsAllied(toTeam, myTeamID) then
		Echo("Enemy AntiNuke captured! " .. unitID)
		detectedAntinukes[unitID] = nil
	end
end

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

function widget:SelectionChanged()
	selectionChanged = true
end
function widget:CommandsChanged()
	if selectionChanged then
		selectionChanged = false
		local selectedNukes = spGetselectedUnitsSorted()[LAUNCHER_DEF_ID]
		launcherID = selectedNukes and selectedNukes[1]
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