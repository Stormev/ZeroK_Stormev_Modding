if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name      = "PW Metal Random Income",
		desc      = "Sets random metal income for Ancient Fabricators",
		author    = "YourName",
		date      = "2026",
		license   = "CC-0",
		layer     = 0,
		enabled   = true
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local pwMetalDefID = UnitDefNames['pw_metal'] and UnitDefNames['pw_metal'].id

local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spEcho = Spring.Echo

local inlosTrueTable = {inlos = true}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitDefID == pwMetalDefID then
		local randomMetal = math.random(0, 16)

        Spring.SetUnitRulesParam(unitID, "metalMake", randomMetal)
		Spring.AddUnitResource(unitID, "metal", metal)
		Spring.SendMessageToTeam(unitTeam, "Ancient Fabricator produces +" .. randomMetal .. " metal")
	end
end

function gadget:GameFrame(frame)
    for _, unitID in ipairs(Spring.GetAllUnits()) do
        local metal = Spring.GetUnitRulesParam(unitID, "metalMake")
        if metal then
            Spring.AddUnitResource(unitID, "metal", metal / 30)
        end
    end
end

function gadget:Initialize()
	return
end