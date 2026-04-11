local CP = CleanPlates
CP.Threat = {}

local Threat = CP.Threat

local colors = {
    neutral = {1,1,0},
    noThreat = {1,0,0},
    someThreat = {1,1,0},
    fullThreat = {0,1,0},
}

function Threat:GetColor(unit)

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

function Threat:Update(unit)

    local plate = C_NamePlate.GetNamePlateForUnit(unit, true)
    if not plate or plate:IsForbidden() then return end

    local color = self:GetColor(unit)

    local bar = plate.UnitFrame.healthBar
    if bar then
        bar:SetStatusBarColor(color[1], color[2], color[3])
    end

    local name = plate.UnitFrame.name
    if name then
        name:SetTextColor(color[1], color[2], color[3])
    end
end

function Threat:OnUnitAdded(unit)
    self:Update(unit)
end

function Threat:OnUnitRemoved(unit) end