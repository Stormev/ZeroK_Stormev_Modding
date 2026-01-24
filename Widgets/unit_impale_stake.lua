function widget:GetInfo()
  return {
    name      = "Impale Stake",
    desc      = "Impalers now have predict attack, attack zone, with UI controll. You need take more 0 impalers for unlock it",
    author    = "Stormev",
    date      = "2026-01-25",
    license   = "GPLv2 or later",
    enabled   = true,
    layer     = 0,
  }
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local ARTY_UNIT_NAME      = "vehheavyarty"
local MIN_GROUP           = 1

local BTN_W, BTN_H        = 150, 36
local MARGIN              = 8
local MARGIN_Y            = 200
local PREVIEW_RADIUS      = 100
local WAVE_INTERVAL       = 9          -- seconds between waves
local RANDOM_SPREAD_MIN   = 5
local RANDOM_SPREAD_MAX   = 80

local PREDICT_DT          = 0.20
local AIM_ISSUE_MIN_DIST  = 6          -- world units threshold to issue new attack
local DEFAULT_PROJSPD     = 900
local DEFAULT_PROJ_LIFE   = 10
local MIN_LEAD_TIME       = 0.35       -- minimal lead time to avoid "under-foot" aiming

local LEAD_FACTOR = 0.50     -- 0.5 = сократить упреждение на 50%; подбирай 0.0..1.0
local SMOOTHING_ALPHA = 0.70 -- 0..1: 1 = без сглаживания, 0.7 = сильный откат к новому прицелу

local ignoreEnemyInZone = true

-- visuals
local COLOR_ZONE_PREVIEW  = {1,1,0,0.28}
local COLOR_ZONE_FINAL    = {1,0.85,0,0.45}
local COLOR_PRED_LINE     = {0.0,0.7,1.0,0.95} -- from target -> predicted impact
local COLOR_PRED_MARKER   = {1.0,0.25,0.25,0.95}
local UI_BG               = {0,0,0,0.6}
local UI_TEXT             = {1,1,1,1}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local showButtons     = false
local btnAttackZone   = { x=MARGIN, y=MARGIN+MARGIN_Y, w=BTN_W, h=BTN_H }
local btnPredict      = { x=MARGIN, y=MARGIN+MARGIN_Y + BTN_H + MARGIN, w=BTN_W, h=BTN_H }

-- radius control
local btnRadiusMinus   = { x=MARGIN, y=MARGIN+MARGIN_Y + 2*(BTN_H + MARGIN), w=36, h=36 }
local btnRadiusPlus    = { x=MARGIN + 40, y=MARGIN+MARGIN_Y + 2*(BTN_H + MARGIN), w=36, h=36 }

-- toggle ignore enemies in zone
local btnIgnoreToggle  = { x=MARGIN, y=MARGIN+MARGIN_Y + 3*(BTN_H + MARGIN), w=76, h=36 }

local zoneModeActive  = false
local mouseX, mouseY  = 0, 0
local previewRadius   = PREVIEW_RADIUS

local attackZoneCenter = nil         -- {x,y,z}
local zoneUnits        = nil         -- snapshot of arty units at confirm
local zoneWaveTimer    = 0
local zoneSustained    = false

-- predictive: uid -> { origTarget = unitID or nil, lastAim = {x,z}, lastIssue = secs }
local predictiveUnits  = {}
local predictedData    = {}          -- uid -> { targetX,Y,Z, aimX,Y,Z }

--------------------------------------------------------------------------------
-- Spring locals - cached for speed
--------------------------------------------------------------------------------
local spGetSelectedUnits  = Spring.GetSelectedUnits
local spGetUnitDefID      = Spring.GetUnitDefID
local spGetUnitPosition   = Spring.GetUnitPosition
local spGetUnitVelocity   = Spring.GetUnitVelocity
local spGiveOrderToUnit   = Spring.GiveOrderToUnit
local spGetUnitCommands   = Spring.GetUnitCommands
local spValidUnitID       = Spring.ValidUnitID
local spGetUnitTeam       = Spring.GetUnitTeam
local spGetUnitsInSphere  = Spring.GetUnitsInSphere
local spEcho              = Spring.Echo
local spTraceScreenRay    = Spring.TraceScreenRay
local spGetLocalTeamID    = Spring.GetLocalTeamID
local spGetGameSeconds    = Spring.GetGameSeconds

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function safeRectCheck(px, py, rect)
  if not rect then return false end
  if type(rect.x) ~= "number" then return false end
  return px >= rect.x and px <= (rect.x + rect.w) and py >= rect.y and py <= (rect.y + rect.h)
end

local function IsVehHeavyArty(defID)
  if not defID then return false end
  local ud = UnitDefs[defID]
  return ud and ud.name == ARTY_UNIT_NAME
end

local function GetArtySelection()
  local sel = spGetSelectedUnits() or {}
  local out = {}
  for i=1,#sel do
    local uid = sel[i]
    if IsVehHeavyArty(spGetUnitDefID(uid)) then
      out[#out+1] = uid
    end
  end
  return out
end

local function UpdateShowButtons()
  showButtons = (#GetArtySelection() >= MIN_GROUP)
end

local function RandomPointInCircle(cx, cz, r)
  local theta = math.random() * 2 * math.pi
  local rad = math.sqrt(math.random()) * r
  return cx + math.cos(theta) * rad, cz + math.sin(theta) * rad
end

local function Distance2D(x1,z1,x2,z2)
  local dx = x1 - x2
  local dz = z1 - z2
  return math.sqrt(dx*dx + dz*dz)
end

-- Solve intercept time (XZ plane) - kept as fallback (not primary)
local function SolveInterceptTime(Sx, Sz, Tx, Tz, Vx, Vz, vp)
  Vx = Vx or 0; Vz = Vz or 0
  if not Sx or not Sz or not Tx or not Tz or not vp then return nil end
  local dx = Tx - Sx
  local dz = Tz - Sz
  local a = (Vx*Vx + Vz*Vz) - vp*vp
  local b = 2*(dx*Vx + dz*Vz)
  local c = dx*dx + dz*dz
  if math.abs(a) < 1e-6 then
    if math.abs(b) < 1e-6 then return nil end
    local t = -c / b
    return (t > 0) and t or nil
  end
  local disc = b*b - 4*a*c
  if disc < 0 then return nil end
  local sqrtD = math.sqrt(disc)
  local t1 = (-b + sqrtD) / (2*a)
  local t2 = (-b - sqrtD) / (2*a)
  local tmin = math.huge
  if t1 > 0 and t1 < tmin then tmin = t1 end
  if t2 > 0 and t2 < tmin then tmin = t2 end
  if tmin == math.huge then return nil end
  return tmin
end

-- Get projectile speed (safe)
local function GetUnitProjectileSpeed(unitID)
  if not unitID or not spValidUnitID(unitID) then return DEFAULT_PROJSPD end
  local defID = spGetUnitDefID(unitID)
  if not defID then return DEFAULT_PROJSPD end
  local ud = UnitDefs[defID]
  if not ud or not ud.weapons then return DEFAULT_PROJSPD end
  for i=1,#ud.weapons do
    local w = ud.weapons[i]
    if w and w.weaponDef then
      local wd = WeaponDefs[w.weaponDef]
      if wd then
        local spd = wd.projectileSpeed or wd.projectilespeed or wd.weaponVelocity or wd.weaponVelocity or wd.weaponVelocity or wd.startvelocity or wd.weaponVelocity or wd.weaponVelocity or wd.weaponVelocity
        -- above duplicated names safe-try; real name varies, we also fallback to projectileSpeed
        if type(spd) == "number" and spd > 0 then return spd end
      end
    end
  end
  return DEFAULT_PROJSPD
end

-- Get flightTime from weapondef - primary source for predictive time
local function GetUnitWeaponFlightTime(unitID)
  if not unitID or not spValidUnitID(unitID) then return DEFAULT_PROJ_LIFE end
  local defID = spGetUnitDefID(unitID)
  if not defID then return DEFAULT_PROJ_LIFE end
  local ud = UnitDefs[defID]
  if not ud or not ud.weapons then return DEFAULT_PROJ_LIFE end
  for i=1,#ud.weapons do
    local w = ud.weapons[i]
    if w and w.weaponDef then
      local wd = WeaponDefs[w.weaponDef]
      if wd then
        -- try flightTime or alternative fields
        local life = wd.flightTime or wd.flighttime or wd.lifeTime or wd.lifetime or wd.duration or wd.weaponTimer
        if type(life) == "number" and life > 0 then return life end
        -- sometimes weaponVelocity is huge (instant) — ignore
      end
    end
  end
  return DEFAULT_PROJ_LIFE
end

--------------------------------------------------------------------------------
-- Issue one randomized wave centered on `center` for units in zoneUnits (snapshot)
--------------------------------------------------------------------------------
local function IssueZoneWave(center)
  if not center or not zoneUnits or #zoneUnits == 0 then return end
  local enemies = {}
  if spGetUnitsInSphere then
    local found = spGetUnitsInSphere(center[1], center[2], center[3], previewRadius) or {}
    for i=1,#found do
      local u = found[i]
      if spValidUnitID(u) and spGetUnitTeam(u) ~= spGetLocalTeamID() then
        enemies[#enemies+1] = u
      end
    end
  end

  for i=1,#zoneUnits do
    local uid = zoneUnits[i]
    if not spValidUnitID(uid) then
      -- skip dead/invalid
    else
      local tx, tz
      if #enemies > 0 and not ignoreEnemyInZone then
        local target = enemies[((i-1) % #enemies) + 1]
        if spValidUnitID(target) then
          local etx, ety, etz = spGetUnitPosition(target)
          local jitterR = math.random(RANDOM_SPREAD_MIN, math.min(RANDOM_SPREAD_MAX, 40))
          local ang = math.random() * 2 * math.pi
          tx = etx + math.cos(ang) * jitterR
          tz = etz + math.sin(ang) * jitterR
        else
          tx, tz = RandomPointInCircle(center[1], center[3], previewRadius)
        end
      else
        tx, tz = RandomPointInCircle(center[1], center[3], previewRadius)
      end
      local ty = center[2]
      spGiveOrderToUnit(uid, CMD.ATTACK, {tx, ty, tz}, 0)
    end
  end
end

--------------------------------------------------------------------------------
-- Input handling: toggle preview; left = confirm, right = cancel
--------------------------------------------------------------------------------
function widget:Initialize()
  math.randomseed((os.time() + (Spring.GetGameSeconds and math.floor(spGetGameSeconds()) or 0)) % 2^31)
  UpdateShowButtons()
  spEcho("vehheavyarty_zone_predict initialized (flightTime)")
end

function widget:MousePress(x, y, button)
  if not showButtons then return false end
  if button ~= 1 and button ~= 3 then return false end

  if safeRectCheck(x, y, btnAttackZone) then
    zoneModeActive = not zoneModeActive
    mouseX, mouseY = x, y
    if zoneModeActive then spEcho("Attack Zone: preview ON - left click to confirm, right click to cancel")
    else spEcho("Attack Zone: preview OFF") end
    return true
  end

  if safeRectCheck(x, y, btnPredict) then
    local sel = GetArtySelection()
    if #sel == 0 then spEcho("Predictive: no artillery selected"); return true end
    local enable = false
    for i=1,#sel do if not predictiveUnits[sel[i]] then enable = true; break end end
    for i=1,#sel do
      local uid = sel[i]
      if enable then predictiveUnits[uid] = predictiveUnits[uid] or { origTarget = nil, lastAim = nil, lastIssue = 0 }
      else predictiveUnits[uid] = nil; predictedData[uid] = nil end
    end
    spEcho("Predictive Aim:", enable and "ON" or "OFF")
    return true
  end

  if zoneModeActive and button == 1 then
    local _, pos = spTraceScreenRay(x, y, true)
    if not pos then spEcho("Attack Zone: click on ground to confirm") else
      attackZoneCenter = { pos[1], pos[2], pos[3] }
      spEcho("Attack Zone confirmed at", string.format("%.1f %.1f %.1f", pos[1], pos[2], pos[3]))
      zoneUnits = GetArtySelection()
      if #zoneUnits < MIN_GROUP then
        spEcho("Attack Zone: not enough artillery selected")
      else
        IssueZoneWave(attackZoneCenter)
        zoneSustained = true
        zoneWaveTimer = WAVE_INTERVAL
      end
      zoneModeActive = false
    end
    return true
  end

  if zoneModeActive and button == 3 then
    zoneModeActive = false
    spEcho("Attack Zone: cancelled (right-click)")
    return true
  end
  
  -- radius minus
if safeRectCheck(x, y, btnRadiusMinus) then
  previewRadius = math.max(10, previewRadius - 10)
  spEcho("Zone radius:", previewRadius)
  return true
end

-- radius plus
if safeRectCheck(x, y, btnRadiusPlus) then
  previewRadius = math.min(500, previewRadius + 10)
  spEcho("Zone radius:", previewRadius)
  return true
end

-- toggle ignore enemies
if safeRectCheck(x, y, btnIgnoreToggle) then
  ignoreEnemyInZone = not ignoreEnemyInZone
  spEcho("Ignore enemies in zone:", ignoreEnemyInZone and "ON" or "OFF")
  return true
end

  return false
end

function widget:MouseMove(x, y, button)
  if zoneModeActive then mouseX, mouseY = x, y; return true end
  return false
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------
function widget:DrawScreen()
  UpdateShowButtons()
  if not showButtons then return end

  gl.PushMatrix()
  gl.Color(UI_BG)
  gl.Rect(btnAttackZone.x, btnAttackZone.y, btnAttackZone.x + btnAttackZone.w, btnAttackZone.y + btnAttackZone.h)
  gl.Rect(btnPredict.x, btnPredict.y, btnPredict.x + btnPredict.w, btnPredict.y + btnPredict.h)
  gl.Color(UI_TEXT)
  gl.Text("Attack Zone", btnAttackZone.x + btnAttackZone.w*0.5, btnAttackZone.y + btnAttackZone.h*0.5, 14, "oc")
  local predText = (next(predictiveUnits) and "Predictive: ON") or "Predictive: OFF"
  gl.Text(predText, btnPredict.x + btnPredict.w*0.5, btnPredict.y + btnPredict.h*0.5, 12, "oc")

  if zoneModeActive then
    local _, pos = spTraceScreenRay(mouseX, mouseY, true)
    if pos then
      local cx, cy, cz = pos[1], pos[2], pos[3]
      gl.PushMatrix()
      gl.DepthTest(true)
      gl.Color(COLOR_ZONE_PREVIEW)
      local segs = 40
      gl.BeginEnd(GL.LINE_STRIP, function()
        for i=0,segs do
          local a = 2*math.pi * (i / segs)
          gl.Vertex(cx + math.cos(a) * previewRadius, cy + 1.5, cz + math.sin(a) * previewRadius)
        end
      end)
      gl.DepthTest(false)
      gl.PopMatrix()
    end
  end
  
	  -- radius buttons
	gl.Color(UI_BG)
	gl.Rect(btnRadiusMinus.x, btnRadiusMinus.y, btnRadiusMinus.x + btnRadiusMinus.w, btnRadiusMinus.y + btnRadiusMinus.h)
	gl.Rect(btnRadiusPlus.x, btnRadiusPlus.y, btnRadiusPlus.x + btnRadiusPlus.w, btnRadiusPlus.y + btnRadiusPlus.h)

	gl.Color(UI_TEXT)
	gl.Text("-", btnRadiusMinus.x + btnRadiusMinus.w*0.5, btnRadiusMinus.y + btnRadiusMinus.h*0.5, 16, "oc")
	gl.Text("+", btnRadiusPlus.x + btnRadiusPlus.w*0.5, btnRadiusPlus.y + btnRadiusPlus.h*0.5, 16, "oc")

	-- ignore enemies toggle
	gl.Color(UI_BG)
	gl.Rect(btnIgnoreToggle.x, btnIgnoreToggle.y, btnIgnoreToggle.x + btnIgnoreToggle.w, btnIgnoreToggle.y + btnIgnoreToggle.h)
	gl.Color(UI_TEXT)
	gl.Text(ignoreEnemyInZone and "Ignore: ON" or "Ignore: OFF",
			btnIgnoreToggle.x + btnIgnoreToggle.w*0.5,
			btnIgnoreToggle.y + btnIgnoreToggle.h*0.5, 12, "oc")

  gl.PopMatrix()
end

function widget:DrawWorld()
  if attackZoneCenter then
    local cx, cy, cz = attackZoneCenter[1], attackZoneCenter[2], attackZoneCenter[3]
    gl.PushMatrix()
    gl.DepthTest(true)
    gl.Color(COLOR_ZONE_FINAL)
    local segs = 48
    gl.BeginEnd(GL.LINE_STRIP, function()
      for i=0,segs do
        local a = 2*math.pi * (i / segs)
        gl.Vertex(cx + math.cos(a) * previewRadius, cy + 1.5, cz + math.sin(a) * previewRadius)
      end
    end)
    gl.DepthTest(false)
    gl.PopMatrix()
  end

  -- predictive visuals: line from target -> predicted impact
  gl.PushMatrix()
  gl.DepthTest(true)
  for uid, d in pairs(predictedData) do
    if spValidUnitID(uid) and d and d.aimX then
      if d.targetX and d.aimX then
        gl.Color(COLOR_PRED_LINE)
        gl.BeginEnd(GL.LINES, function()
          gl.Vertex(d.targetX, d.targetY + 8, d.targetZ)
          gl.Vertex(d.aimX, d.aimY + 8, d.aimZ)
        end)
      end
      gl.Color(COLOR_PRED_MARKER)
      local segs2 = 12
      gl.BeginEnd(GL.LINE_STRIP, function()
        for i=0,segs2 do
          local a = 2*math.pi * (i / segs2)
          gl.Vertex(d.aimX + math.cos(a) * 6, d.aimY + 8, d.aimZ + math.sin(a) * 6)
        end
      end)
    end
  end
  gl.DepthTest(false)
  gl.PopMatrix()
end

--------------------------------------------------------------------------------
-- Update loop: waves and predictive recompute - main place where prediction is calculated
--------------------------------------------------------------------------------
local accum = 0
function widget:Update(dt)
  accum = accum + (dt or 0)
  if accum < 0.05 then return end
  local step = accum
  accum = 0

  -- zone waves
  if zoneSustained and attackZoneCenter and zoneUnits and #zoneUnits>0 then
    zoneWaveTimer = zoneWaveTimer - step
    if zoneWaveTimer <= 0 then
      -- cancel if any unit got MOVE as first active command
      local cancel = false
      for i=1,#zoneUnits do
        local uid = zoneUnits[i]
        if spValidUnitID(uid) then
          local cmds = spGetUnitCommands(uid, 1) or {}
          if cmds and #cmds>0 and cmds[1].id == CMD.MOVE then
            cancel = true
            break
          end
        end
      end
      if cancel then
        zoneSustained = false
        spEcho("Attack Zone: cancelled due to MOVE command")
      else
        IssueZoneWave(attackZoneCenter)
        zoneWaveTimer = WAVE_INTERVAL
      end
    end
  end

  -- predictive part
  widget._predAccum = (widget._predAccum or 0) + step
  if widget._predAccum >= PREDICT_DT then
    widget._predAccum = 0
    predictedData = {}

    for uid, info in pairs(predictiveUnits) do
      if not spValidUnitID(uid) then
        predictiveUnits[uid] = nil
        predictedData[uid] = nil
      else
        local cmds = spGetUnitCommands(uid, -1) or {}
        local lastAttack = nil
        for i = #cmds, 1, -1 do
          if cmds[i] and cmds[i].id == CMD.ATTACK then lastAttack = cmds[i]; break end
        end

        if not lastAttack then
          info.origTarget = nil
          predictedData[uid] = nil
        else
          local p = lastAttack.params or {}
          -- if attack on unit -> override and follow
          if p[1] and spValidUnitID(p[1]) then
            local targetID = p[1]
            if info.origTarget ~= targetID then info.origTarget = targetID end

            if info.origTarget and spValidUnitID(info.origTarget) then
              -- get target pos & vel
              local tx, ty, tz = spGetUnitPosition(info.origTarget)
              local vx, vy, vz = spGetUnitVelocity(info.origTarget)
              vx = vx or 0; vy = vy or 0; vz = vz or 0

              -- shooter pos
              local sx, sy, sz = spGetUnitPosition(uid)
              if tx and sx then
                -- get flightTime firstly
                local flightTime = GetUnitWeaponFlightTime(uid) or DEFAULT_PROJ_LIFE
                -- compute predicted point as where target will be after flightTime seconds
                local t = flightTime
                if not t or t <= 0 then
                  -- fallback to algebraic intercept
                  local vp = GetUnitProjectileSpeed(uid) or DEFAULT_PROJSPD
                  local t_alg = SolveInterceptTime(sx, sz, tx, tz, vx, vz, vp)
                  if not t_alg or t_alg <= 0 then
                    -- fallback to dist/vp
                    local dist = Distance2D(sx, sz, tx, tz)
                    t = (vp > 0) and (dist / vp) or DEFAULT_PROJ_LIFE
                  else
                    t = t_alg
                  end
                end

                -- clamp and ensure not tiny
                if t < MIN_LEAD_TIME then t = MIN_LEAD_TIME end

                local aimX = tx + vx * t * LEAD_FACTOR
                local aimY = ty + vy * t * LEAD_FACTOR
                local aimZ = tz + vz * t * LEAD_FACTOR

                -- decide whether to issue order
                local issue = true
                local lastAim = info.lastAim
                if lastAim and lastAim.x and lastAim.z then
                  local d = Distance2D(lastAim.x, lastAim.z, aimX, aimZ)
                  if d < AIM_ISSUE_MIN_DIST then issue = false end
                end

                if issue then
                  spGiveOrderToUnit(uid, CMD.ATTACK, {aimX, aimY, aimZ}, {})
                  info.lastAim = { x = aimX, z = aimZ }
                  info.lastIssue = spGetGameSeconds() or os.time()
                end

                -- visuals: line from current target pos to aim point (over t seconds)
                predictedData[uid] = {
                  targetX = tx, targetY = ty, targetZ = tz,
                  aimX = aimX, aimY = aimY, aimZ = aimZ,
                  leadTime = t
                }
              else
                info.origTarget = nil
                predictedData[uid] = nil
              end
            else
              predictedData[uid] = nil
            end
          else
            -- lastAttack is coordinate - if we have origTarget, continue to update
            if info.origTarget and spValidUnitID(info.origTarget) then
              local tx, ty, tz = spGetUnitPosition(info.origTarget)
              local vx, vy, vz = spGetUnitVelocity(info.origTarget)
              vx = vx or 0; vy = vy or 0; vz = vz or 0
              local sx, sy, sz = spGetUnitPosition(uid)
              if tx and sx then
                local flightTime = GetUnitWeaponFlightTime(uid) or DEFAULT_PROJ_LIFE
                local t = flightTime
                if not t or t <= 0 then
                  local vp = GetUnitProjectileSpeed(uid) or DEFAULT_PROJSPD
                  local t_alg = SolveInterceptTime(sx, sz, tx, tz, vx, vz, vp)
                  if not t_alg or t_alg <= 0 then
                    local dist = Distance2D(sx, sz, tx, tz)
                    t = (vp > 0) and (dist / vp) or DEFAULT_PROJ_LIFE
                  else
                    t = t_alg
                  end
                end
                if t < MIN_LEAD_TIME then t = MIN_LEAD_TIME end
                local aimX = tx + vx * t * LEAD_FACTOR
                local aimY = ty + vy * t * LEAD_FACTOR
                local aimZ = tz + vz * t * LEAD_FACTOR
                local issue = true
                local lastAim = info.lastAim
                if lastAim and lastAim.x and lastAim.z then
                  local d = Distance2D(lastAim.x, lastAim.z, aimX, aimZ)
                  if d < AIM_ISSUE_MIN_DIST then issue = false end
                end
                if issue then
                  spGiveOrderToUnit(uid, CMD.ATTACK, {aimX, aimY, aimZ}, {})
                  info.lastAim = { x = aimX, z = aimZ }
                  info.lastIssue = spGetGameSeconds() or os.time()
                end
                predictedData[uid] = { targetX = tx, targetY = ty, targetZ = tz, aimX = aimX, aimY = aimY, aimZ = aimZ, leadTime = t }
              else
                info.origTarget = nil
                predictedData[uid] = nil
              end
            else
              predictedData[uid] = nil
              info.origTarget = nil
            end
          end
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- housekeeping
--------------------------------------------------------------------------------
function widget:SelectionChanged(sel)
  UpdateShowButtons()
end

function widget:UnitDestroyed(unitID)
  predictiveUnits[unitID] = nil
  predictedData[unitID] = nil
  if zoneUnits then
    for i = #zoneUnits,1,-1 do
      if zoneUnits[i] == unitID then table.remove(zoneUnits, i) end
    end
  end
end

function widget:Shutdown()
  -- nothing special
end
