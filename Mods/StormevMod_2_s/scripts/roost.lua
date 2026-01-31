include "constants.lua"
include "nanoaim.h.lua"

--pieces
local base = piece "base"
local emit = piece "emit"

--local vars
local smokePiece = { base, emit }
local nanoPieces = { emit }

local nanoTurnSpeedHori = 0.5 * math.pi
local nanoTurnSpeedVert = 0.3 * math.pi

function script.Create()
	StartThread(GG.Script.SmokeUnit, unitID, smokePiece)
	StartThread(GG.NanoAim.UpdateNanoDirectionThread, unitID, nanoPieces, 1000, nanoTurnSpeedHori, nanoTurnSpeedVert)
	Spring.SetUnitNanoPieces(unitID, {emit})
end

function script.StartBuilding()
	GG.NanoAim.UpdateNanoDirection(unitID, nanoPieces, nanoTurnSpeedHori, nanoTurnSpeedVert)
	Spring.SetUnitCOBValue(unitID, COB.INBUILDSTANCE, 1)
end

function script.StopBuilding()
	Spring.SetUnitCOBValue(unitID, COB.INBUILDSTANCE, 0)
end

function script.Killed(recentDamage, maxHealth)
	local severity = recentDamage / maxHealth
	if severity < 0.25 then
		return 1
	elseif severity < 0.50 then
		Explode(emit, SFX.FALL)
		return 1
	elseif severity < 0.75 then
		Explode(emit, SFX.FALL + SFX.SMOKE + SFX.FIRE + SFX.EXPLODE_ON_HIT)
		return 2
	else
		Explode(base, SFX.SHATTER)
		Explode(emit, SFX.FALL + SFX.SMOKE + SFX.FIRE + SFX.EXPLODE_ON_HIT)
		return 2
	end
end

-- Weapon script
function script.AimWeapon() 
	return true 
end

function script.AimFromWeapon() 
	return emit 
end

function script.QueryWeapon() 
	return emit 
end