function widget:GetInfo()
  return {
    name      = "Silo Ballistic Trajectory",
    desc      = "Draws a ballistic trajectory for silo`s rockets",
    author    = "Stormev",
    date      = "16.01.2026",
    license   = "GPL v2 or later",
    layer     = 0,
    enabled   = true,
  }
end

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
local gravity = Game.gravity or 130

-- Calculate ballistic direction to hit `targetPos` from `startPos` with speed v
local function CalcDirToHit(startPos, targetPos, v)
  local dx = targetPos[1] - startPos[1]
  local dz = targetPos[3] - startPos[3]
  local dy = targetPos[2] - startPos[2]

  local dist = math.sqrt(dx*dx + dz*dz)
  if dist <= 0.001 then
    return nil -- no meaningful direction
  end

  -- discriminant
  local v2 = v * v
  local g  = gravity
  local term = v2*v2 - g * (g * dist*dist + 2 * dy * v2)

  if term < 0 then
    return nil -- unreachable with this speed
  end

  local sqrtTerm = math.sqrt(term)

  -- choose lower trajectory (use + for higher arc)
  local angle = math.atan((v2 - sqrtTerm) / (g * dist))

  -- horizontal dir
  local hx = dx / dist
  local hz = dz / dist

  -- construct direction vector
  return {
    hx * math.cos(angle),
    math.sin(angle),
    hz * math.cos(angle)
  }
end

local function CalcLowPos(lowPos, startPos)
  glLineStipple("")
  glColor(0.2, 1, 0.2, 1) -- желтоватая вспомогательная линия

  glBeginEnd(GL_LINE_STRIP, function()
    glVertex(lowPos[1], lowPos[2], lowPos[3])
    glVertex(startPos[1], startPos[2], startPos[3])
  end)

  glColor(1, 1, 1, 1)
end

-- Draw a ballistic trajectory
local function DrawTrajectory(startPos, dir, velocity)
  glLineStipple("")
  glColor(0.2, 1, 0.2, 1) -- green
  glBeginEnd(GL_LINE_STRIP, function()
    local vx = dir[1] * velocity
    local vy = dir[2] * velocity
    local vz = dir[3] * velocity
    local t  = 0
    while true do
      local x = startPos[1] + vx * t
      local y = startPos[2] + vy * t - (0.5) * gravity * (t*t) -- base - (0.5)
      local z = startPos[3] + vz * t

      if y <= spGetGroundHeight(x, z) then
        break
      end

      glVertex(x, y, z)
      t = t + 0.02
      if t > 10 then
        break
      end
    end
  end)
  glColor(1, 1, 1, 1)
end

function widget:DrawWorld()
	
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
    local ux, uy, uz = spGetUnitPosition(unitID)
    if ux then
	
	  local lowPos = {ux, uy, uz}
      local startPos = {ux, uy + 3000, uz}
      local dir = CalcDirToHit(startPos, worldPos, 500)
      if dir then
	    CalcLowPos(lowPos, startPos)
        DrawTrajectory(startPos, dir, 500) -- * магическое число которое делает дзен :)
      end
    end
  end
end
