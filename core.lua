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

function CP:IsAttackable(unit)
    local reaction = UnitReaction(unit,"player")

    return UnitIsEnemy("player",unit) or (reaction and reaction <= 4)
end

function CP:ValidateUnit(unit)
    if not UnitExists(unit) then return false end

    if not unit or not unit:match(nameplateRegex) then return false end

    for _, regex in pairs(regexList) do
        if unit:match(regex) then
            return false
        end
    end

    return self:IsAttackable(unit)
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

    -- if self.Interrupt then
    --     self.Interrupt:OnUnitAdded(unit)
    -- end

    self:MarkUIDirty()
end

function CP:RemoveUnit(unit)

    self.activeUnits[unit] = nil

    if self.Threat then
        self.Threat:OnUnitRemoved(unit)
    end

    -- if self.Interrupt then
    --     self.Interrupt:OnUnitRemoved(unit)
    -- end

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

    -- elseif event:find("UNIT_SPELLCAST") then
    --     if CP.Interrupt and unit and CP.activeUnits[unit] then
    --         CP.Interrupt:OnCastEvent(event, unit)
    --         CP:MarkUIDirty()
    --     end
    -- end
    end
end)

-------------------------------------------------
-- Blizzard Hooks
-------------------------------------------------

function CP:Hook(frame)

    if not frame then return end

    local unit = frame.displayedUnit

    if unit then 
        if self.Threat then
            self.Threat:UpdateUnit(unit)
        end

        -- if self.Interrupt then
        --     self.Interrupt:UpdateUnit(unit)
        -- end
    end
end

hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
    CP:Hook(frame)
end)
hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
    CP:Hook(frame)
end)

-------------------------------------------------
-- Render Loop with throttling
-------------------------------------------------

local elapsed = 0
local throttle = 0.1

f:SetScript("OnUpdate", function(_, delta)

    elapsed = elapsed + delta

    -- if CP.Interrupt then
    --         CP.Interrupt:UpdateUI()
    -- end

    if elapsed >= throttle then
        elapsed = 0

         if CP.uiDirty then
            CP.uiDirty = false

            if CP.Threat then
                CP.Threat:UpdateAll()
            end
        end
    end
end)

-------------------------------------------------
-- Debug Command
-------------------------------------------------

SLASH_CTP1 = "/cp"

SlashCmdList["CP"] = function()

    if not UnitExists("target") then
        print("|cff00ff00[CleanThreatPlates]|r No target selected.")
        return
    end

    local name = UnitName("target") or "Unknown"
    local guid = UnitGUID("target") or "nil"
    local token = UnitTokenFromGUID(UnitGUID("target") or "")
    local classification = UnitClassification("target") or "Unknown"
    local creatureType = UnitCreatureType("target") or "Unknown"
    local level = UnitLevel("target") or "??"
    local threat = UnitThreatSituation("player","target")
    local reaction = UnitReaction("target","player")
    local inCombat = UnitAffectingCombat("target") and "Yes" or "No"
    local targetingPlayer = UnitIsUnit("targettarget","player") and "Yes" or "No"
    local isEnemy = UnitIsEnemy("player","target") and "Yes" or "No"
    local isNeutral = reaction == 4 and "Yes" or "No"

    local buildInfo = GetBuildInfo()

    print("|cff00ff00[CleanThreatPlates Debug]|r")
    print("Name:", name)
    print("GUID:", guid)
    print("Token:", token)
    print("Classification", classification)
    print("Creature type", creatureType)
    print("Level", level)
    print("ThreatSituation:", threat)
    print("Reaction:", reaction)
    print("In Combat:", inCombat)
    print("Targeting You:", targetingPlayer)
    print("Unit is Enemy:", isEnemy)
    print("Unit is Neutral:", isNeutral)
    print("WoW Version:", buildInfo)

end