-- CleanThreatPlates.lua

local addonName = ...
local f = CreateFrame("Frame")

-------------------------------------------------
-- Events
-------------------------------------------------

f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

-------------------------------------------------
-- Active Plate Storage
-------------------------------------------------

local activePlates = {}

-------------------------------------------------
-- Global variables
-------------------------------------------------

local colors = {
    neutral = {1,1,0},
    noThreat = {1,0,0},
    someThreat = {1,1,0},
    fullThreat = {0,1,0},
}

local nameplateRegex = "^nameplate%d+$"


-- Forbidden unit patterns
local regexList = {
    boss = "^boss%d+$",
    arena = "^arena%d+$",
    party = "^party%d+$",
}

-------------------------------------------------
-- Helpers
-------------------------------------------------

local function IsAttackable(unit)

    local reaction = UnitReaction(unit,"player")

    return UnitIsEnemy("player",unit) or reaction <= 4
end

local function GetColor(unit)

    local threat = UnitThreatSituation("player", unit)
    local reaction = UnitReaction(unit,"player")

    if threat == 3 then
        return colors.fullThreat

    elseif threat == 1 or threat == 2 then
        return colors.someThreat

    elseif reaction == 4 then
        return colors.neutral
    end

    return colors.noThreat
end

local function ValidateUnit(unit)

    if not UnitExists(unit) then 
        return false
    end

    if not unit:match(nameplateRegex) then 
        return false
    end

    for _, regex in pairs(regexList) do
        if unit:match(regex) then
            return false
        end
    end
    
    if not IsAttackable(unit) then
        return false
    end

    return true
end

-------------------------------------------------
-- Plate Manipulation
-------------------------------------------------

local function UpdateBarColor(plate, color)

    if not plate or not plate.UnitFrame then
        return
    end

    local bar = plate.UnitFrame.healthBar

    if bar then
        bar:SetStatusBarColor(color[1],color[2],color[3])
    end
end

local function UpdateNameColor(plate, color)

    if not plate or not plate.UnitFrame then
        return
    end

    local name = plate.UnitFrame.name

    if name then
        name:SetTextColor(color[1],color[2],color[3])
    end
end

-------------------------------------------------
-- Core Update
-------------------------------------------------

local function UpdateThreatColor(unit)
    
    if not ValidateUnit(unit) then return end

    local plate = C_NamePlate.GetNamePlateForUnit(unit, true)

    if not plate or plate:IsForbidden() then return end

    local color = GetColor(unit)

    UpdateBarColor(plate, color)
    UpdateNameColor(plate, color)
end

-------------------------------------------------
-- Plate Tracking
-------------------------------------------------

local function PlateAdded(unit)

    if not ValidateUnit(unit) then return end

    activePlates[unit] = true

    UpdateThreatColor(unit)

    -- print("Plate added: " ..  unit .. ", " .. UnitName(unit) .. ". Reaction: " .. UnitReaction(unit,"player"))
end

local function PlateRemoved(unit)

    activePlates[unit] = nil
end

-------------------------------------------------
-- Refresh All Active Plates
-------------------------------------------------

local function RefreshAll()

    for unit in pairs(activePlates) do
        UpdateThreatColor(unit)
    end
end

-------------------------------------------------
-- Throttle System
-------------------------------------------------

local elapsed = 0
local throttle = 0.10

f:SetScript("OnUpdate", function(_, delta)

    elapsed = elapsed + delta

    if elapsed >= throttle then
        elapsed = 0
        RefreshAll()
    end

end)

-------------------------------------------------
-- Event Handler
-------------------------------------------------

f:SetScript("OnEvent", function(_, event, unit)

    if event == "NAME_PLATE_UNIT_ADDED" then
        PlateAdded(unit)

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        PlateRemoved(unit)

    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshAll()

    end

end)

-------------------------------------------------
-- Blizzard Hook Support
-------------------------------------------------

local function Hook(frame)

    if not frame then
        return
    end

    local unit = frame.displayedUnit

    if unit then
        UpdateThreatColor(unit)
    end
end

hooksecurefunc("CompactUnitFrame_UpdateHealthColor", Hook)
hooksecurefunc("CompactUnitFrame_UpdateName", Hook)

-------------------------------------------------
-- Debug Command
-------------------------------------------------

SLASH_CTP1 = "/ctp"

SlashCmdList["CTP"] = function()

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