function widget:GetInfo()
  return {
    name      = "Silo Ballistic Trajectory",
    desc      = "Draws a ballistic trajectory for silo`s rockets",
    author    = "Stormev",
    date      = "01.16.2026",
    license   = "GPL v2 or later",
    layer     = 0,
    enabled   = true,
  }
end

-- valid units for widget
local validRocketUnits = {
  ["empmissile"] = true,
  ["napalmmissile"] = true,
  ["subtacmissile"] = true,
  ["tacnuke"] = true,
  ["staticmissilesilo"] = true,
  ["missileslow"] = true,
  ["seismic"] = true,
}

-- Spring API shortcuts
local spGetActiveCommand  = Spring.GetActiveCommand
local spGetMouseState     = Spring.GetMouseState
local spTraceScreenRay    = Spring.TraceScreenRay
local spGetSelectedUnits  = Spring.GetSelectedUnits
local spGetUnitPosition   = Spring.GetUnitPosition
local spGetGroundHeight   = Spring.GetGroundHeight

-- GL shortcuts
local glBeginEnd     = gl.BeginEnd
local glLineStipple  = gl.LineStipple
local GL_LINE_STRIP  = GL.LINE_STRIP
local glColor        = gl.Color
local glVertex       = gl.Vertex

-- Physics
local gravity = Game.gravity or 100
local arcFactor = 0.5      --  gravity modifier ": <1 = "меньше g", >1 = "больше g" размер дуги
local useHighArc = true    -- true = высокая арка
local rocket_velocity = 500 -- rocket speed
local startPoseHeight = 3000 -- postion when rocket go to arc status

-- Calculate ballistic direction to hit `targetPos` from `startPos` with speed v
local function CalcDirToHit(startPos, targetPos, velocity, arcFactor, highArc)
    arcFactor = arcFactor or 1.0
    local gEffective = gravity * arcFactor

    local dx = targetPos[1] - startPos[1]
    local dz = targetPos[3] - startPos[3]
    local dy = targetPos[2] - startPos[2]

    local dist = math.sqrt(dx*dx + dz*dz)
    if dist < 1e-4 then return nil end

    local hx = dx / dist
    local hz = dz / dist

    local vxh = velocity * hx
    local vzh = velocity * hz
    local vh = math.sqrt(vxh*vxh + vzh*vzh)
    if vh < 1e-6 then return nil end

    local tHit = dist / vh

    -- вертикальная скорость для точного попадания
    local vy = (dy + 0.5 * gEffective * tHit * tHit) / tHit
    if highArc then
        vy = vy + math.sqrt(gEffective) * 0.1 * tHit -- немного выше для высокой дуги
    end

    -- нормализуем dir
    return {hx, vy / velocity, hz}
end

-- draw vertical line to arc (visual)
local function DrawLowPos(lowPos, startPos)
  glLineStipple("")
  glColor(0.2, 1, 0.2, 1)

  glBeginEnd(GL_LINE_STRIP, function()
    glVertex(lowPos[1], lowPos[2], lowPos[3])
    glVertex(startPos[1], startPos[2], startPos[3])
  end)

  glColor(1, 1, 1, 1)
end

-- Draw a ballistic trajectory
local function DrawTrajectory(startPos, dir, velocity, arcFactor)
    arcFactor = arcFactor or 1.0
    local gFactor = 0.5 * gravity * arcFactor

    glLineStipple("")
    glColor(0.2, 1, 0.2, 1)

    local vx = dir[1] * velocity
    local vy = dir[2] * velocity
    local vz = dir[3] * velocity


    local t = 0 -- time (step)
    local firstStep = true

    glBeginEnd(GL_LINE_STRIP, function()
        while t <= 10 do
            local x = startPos[1] + vx * t
            local y = startPos[2] + vy * t - gFactor * t*t
            local z = startPos[3] + vz * t

            -- ground block
            if y <= spGetGroundHeight(x, z) and not firstStep then
                break
            end

            glVertex(x, y, z)
            firstStep = false
            t = t + 0.02
        end
    end)

    glColor(1, 1, 1, 1)
end

function widget:DrawWorld()
	
  -- while attacking
  local _, activeCmd = spGetActiveCommand()
  if activeCmd ~= CMD.ATTACK then
    return
  end

  local mx, my = spGetMouseState()
  local desc, worldPos = spTraceScreenRay(mx, my, true)
  if not worldPos then
    return
  end

  local units = spGetSelectedUnits() or {}
  for _, unitID in ipairs(units) do
  
    local ud = UnitDefs[Spring.GetUnitDefID(unitID)]
    local ux, uy, uz = spGetUnitPosition(unitID)
	if ud and validRocketUnits[ud.name] then
		if ux then
			local lowPos = {ux, uy, uz}
			local startPos = {ux, uy + startPoseHeight, uz}
			  
			local dir = CalcDirToHit(startPos, worldPos, rocket_velocity, arcFactor, useHighArc)
			if dir then
			  DrawLowPos(lowPos, startPos)               
			  DrawTrajectory(startPos, dir, rocket_velocity, arcFactor, worldPos)
			end
		end
	end
  end
end
