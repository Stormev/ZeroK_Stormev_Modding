function widget:GetInfo()
	return {
		name      = "Nuclear Commander",
		desc      = "Draw second radius for anti nuke in which 2 nuclear warheads are shot down, add distance mark while selected nuke",
		author    = "Stormev",
		date      = "2026-01-16",
		license   = "GPL v2 or later",
		layer     = 0,
		enabled   = true
	}
end

local detectedAntinukes = {}
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

local spGetUnitsInCylinder  = Spring.GetUnitsInCylinder
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitPosition     = Spring.GetUnitPosition
local spGetTeamUnits        = Spring.GetTeamUnits
local spGetMyTeamID         = Spring.GetMyTeamID
local spGetSelectedUnits    = Spring.GetSelectedUnits
local Echo                  = Spring.Echo

-- internal name пусковой
local LAUNCHER_DEF_ID = UnitDefNames["staticnuke"] and UnitDefNames["staticnuke"].id

-- проверяет: возвращает unitID launcher’а, если такой выбран
local function GetSelectedLauncherID()
	local sel = spGetSelectedUnits()
	if not sel then
		return nil
	end
	for _, uid in ipairs(sel) do
		if spGetUnitDefID(uid) == LAUNCHER_DEF_ID then
			return uid
		end
	end
	return nil
end

function widget:Update(dt)
	timeSinceLastScan = timeSinceLastScan + dt
	if timeSinceLastScan < scanStepDelay then
		return
	end
	timeSinceLastScan = 0

	local myTeam = spGetMyTeamID()
	if not myTeam then
		return
	end

	local allies = spGetTeamUnits(myTeam)
	if not allies then
		return
	end

	for _, allyID in ipairs(allies) do
		local ax, ay, az = spGetUnitPosition(allyID)
		if ax then
			local enemies = spGetUnitsInCylinder(ax, az, searchRadius, Spring.ENEMY_UNITS)
			if enemies then
				for _, enemyID in ipairs(enemies) do
					local defID = spGetUnitDefID(enemyID)
					if defID == antiNukeDefID then
						local x,y,z = spGetUnitPosition(enemyID)
						if x then
							if not detectedAntinukes[enemyID] then
								Echo("Enemy AntiNuke Detected:", enemyID, defID)
							end
							detectedAntinukes[enemyID] = {x = x, y = y, z = z}
						end
					end
				end
			end
		end
	end
end

function calcRealRadius(pos_x, pos_y, pos_z)
	local launcherID = GetSelectedLauncherID()
	if not launcherID then
		return
	end
	
	local lx, ly, lz = spGetUnitPosition(launcherID)
	
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
	local launcherID = GetSelectedLauncherID()
	if not launcherID then
		return
	end

	gl.Color(1, 0, 0, 0.4)
	for unitID, pos in pairs(detectedAntinukes) do
		local x,y,z = spGetUnitPosition(unitID)
		if x then
			pos.x, pos.y, pos.z = x,y,z
		end
		gl.DrawGroundCircle(pos.x, pos.y, pos.z, calcRealRadius(pos.x, pos.y, pos.z), 60)
	end
	gl.Color(1,1,1,1)
end


function widget:DrawScreen()
	local launcherID = GetSelectedLauncherID()
	if not launcherID then
		return
	end

	local lx, ly, lz = spGetUnitPosition(launcherID)
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
	local text = string.format("Пидаляметр: %.1f", dist)
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
