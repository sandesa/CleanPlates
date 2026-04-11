CleanPlates = {}
local CP = CleanPlates

local f = CreateFrame("Frame")

-------------------------------------------------
-- Storage
-------------------------------------------------

CP.activeUnits = {}

-------------------------------------------------
-- Config
-------------------------------------------------

CP.throttle = 0.05

-------------------------------------------------
-- Validation
-------------------------------------------------

local nameplateRegex = "^nameplate%d+$"

function CP:ValidateUnit(unit)

    if not UnitExists(unit) then return false end
    if not unit:match(nameplateRegex) then return false end

    return true
end

-------------------------------------------------
-- Unit Lifecycle
-------------------------------------------------

function CP:AddUnit(unit)

    if not self:ValidateUnit(unit) then return end

    self.activeUnits[unit] = {}

    if self.Threat then
        self.Threat:OnUnitAdded(unit)
    end

    if self.Interrupt then
        self.Interrupt:OnUnitAdded(unit)
    end
end

function CP:RemoveUnit(unit)

    self.activeUnits[unit] = nil

    if self.Threat then
        self.Threat:OnUnitRemoved(unit)
    end

    if self.Interrupt then
        self.Interrupt:OnUnitRemoved(unit)
    end
end

-------------------------------------------------
-- Events
-------------------------------------------------

f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("UNIT_SPELLCAST_START")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
f:RegisterEvent("UNIT_SPELLCAST_STOP")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

f:SetScript("OnEvent", function(_, event, unit)

    if event == "NAME_PLATE_UNIT_ADDED" then
        CP:AddUnit(unit)

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        CP:RemoveUnit(unit)

    elseif event:find("UNIT_SPELLCAST") then
        if CP.Interrupt and CP.activeUnits[unit] then
            CP.Interrupt:OnCastEvent(unit)
        end
    end

end)

-------------------------------------------------
-- Throttle Loop
-------------------------------------------------

local elapsed = 0

f:SetScript("OnUpdate", function(_, delta)

    elapsed = elapsed + delta
    if elapsed < CP.throttle then return end
    elapsed = 0

    for unit in pairs(CP.activeUnits) do

        if CP.Threat then
            CP.Threat:Update(unit)
        end

        if CP.Interrupt then
            CP.Interrupt:Update(unit)
        end
    end

end)