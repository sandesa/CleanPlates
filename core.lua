CleanPlates = {}
local CP = CleanPlates

local f = CreateFrame("Frame")

-------------------------------------------------
-- STATE
-------------------------------------------------

CP.activeUnits = {}

CP.uiDirty = false

-------------------------------------------------
-- CONFIG
-------------------------------------------------

local nameplateRegex = "^nameplate%d+$"

local regexList = {
    boss = "^boss%d+$",
    arena = "^arena%d+$",
    party = "^party%d+$",
}

-------------------------------------------------
-- UTIL
-------------------------------------------------

function CP:ValidateUnit(unit)
    if not UnitExists(unit) then return false end

    if not unit or not unit:match(nameplateRegex) then return false end

    for _, regex in pairs(regexList) do
        if unit:match(regex) then
            return false
        end
    end

    local reaction = UnitReaction(unit,"player")

    return UnitIsEnemy("player",unit) or reaction <= 4
end

function CP:MarkUIDirty()
    self.uiDirty = true
end

-------------------------------------------------
-- UNIT LIFECYCLE
-------------------------------------------------

function CP:AddUnit(unit)

    if not self:ValidateUnit(unit) then return end

    self.activeUnits[unit] = {
        cast = nil,
        threatColor = nil,
    }

    if self.Threat then
        self.Threat:OnUnitAdded(unit)
    end

    if self.Interrupt then
        self.Interrupt:OnUnitAdded(unit)
    end

    self:MarkUIDirty()
end

function CP:RemoveUnit(unit)

    self.activeUnits[unit] = nil

    if self.Threat then
        self.Threat:OnUnitRemoved(unit)
    end

    if self.Interrupt then
        self.Interrupt:OnUnitRemoved(unit)
    end

    self:MarkUIDirty()
end

-------------------------------------------------
-- EVENT DISPATCH
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
        if CP.Interrupt and unit and CP.activeUnits[unit] then
            CP.Interrupt:OnCastEvent(unit)
            CP:MarkUIDirty()
        end
    end
end)

-------------------------------------------------
-- LIGHT RENDER LOOP
-------------------------------------------------

local render = CreateFrame("Frame")

render:SetScript("OnUpdate", function()

    if not CP.uiDirty then return end
    CP.uiDirty = false

    if CP.Threat then
        CP.Threat:UpdateAll()
    end

    if CP.Interrupt then
        CP.Interrupt:UpdateUI()
    end
end)