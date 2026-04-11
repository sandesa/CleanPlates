local addonName = ...
local f = CreateFrame("Frame")

-------------------------------------------------
-- Events
-------------------------------------------------

f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("UNIT_SPELLCAST_START")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
f:RegisterEvent("UNIT_SPELLCAST_STOP")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

-------------------------------------------------
-- Active Unit Storage (MERGED)
-------------------------------------------------

local activeUnits = {}

-------------------------------------------------
-- Config
-------------------------------------------------

local throttle = 0.05

local colors = {
    neutral = {1,1,0},
    noThreat = {1,0,0},
    someThreat = {1,1,0},
    fullThreat = {0,1,0},
}

-------------------------------------------------
-- Regex / Validation
-------------------------------------------------

local nameplateRegex = "^nameplate%d+$"

local regexList = {
    "^boss%d+$",
    "^arena%d+$",
    "^party%d+$",
}

local function ValidateUnit(unit)

    if not UnitExists(unit) then return false end
    if not unit:match(nameplateRegex) then return false end

    for _, regex in pairs(regexList) do
        if unit:match(regex) then
            return false
        end
    end

    return true
end

-------------------------------------------------
-- Threat Module
-------------------------------------------------

local function GetThreatColor(unit)

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

local function UpdateThreat(unit)

    local data = activeUnits[unit]
    if not data then return end

    data.threatColor = GetThreatColor(unit)
end

-------------------------------------------------
-- Interrupt Module
-------------------------------------------------

local function GetCastInfo(unit)

    local name, _, icon, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(unit)

    if not name then
        name, _, icon, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
    end

    if name and not notInterruptible then
        return {
            spell = name,
            icon = icon,
            startTime = startTime,
            endTime = endTime
        }
    end

    return nil
end

local function UpdateCast(unit)

    local data = activeUnits[unit]
    if not data then return end

    data.cast = GetCastInfo(unit)
end

-------------------------------------------------
-- Nameplate Updates
-------------------------------------------------

local function UpdateNameplate(unit)

    local plate = C_NamePlate.GetNamePlateForUnit(unit, true)
    if not plate or plate:IsForbidden() then return end

    local data = activeUnits[unit]
    if not data then return end

    local color = data.threatColor
    if not color then return end

    local bar = plate.UnitFrame.healthBar
    if bar then
        bar:SetStatusBarColor(color[1], color[2], color[3])
    end

    local name = plate.UnitFrame.name
    if name then
        name:SetTextColor(color[1], color[2], color[3])
    end
end

-------------------------------------------------
-- Interrupt UI
-------------------------------------------------

local container = CreateFrame("Frame", "CleanPlatesInterruptFrame", UIParent)
container:SetSize(220, 300)
container:SetPoint("CENTER")
container.buttons = {}

local function CreateButton(index)

    local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
    btn:SetSize(200, 40)
    btn:SetPoint("TOP", 0, -(index - 1) * 45)

    btn:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    btn:SetBackdropColor(0,0,0,0.7)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(30,30)
    btn.icon:SetPoint("LEFT",5,0)

    btn.text = btn:CreateFontString(nil,"OVERLAY","GameFontNormal")
    btn.text:SetPoint("TOPLEFT", btn.icon, "TOPRIGHT", 5, 0)

    btn.castbar = CreateFrame("StatusBar", nil, btn)
    btn.castbar:SetSize(150,10)
    btn.castbar:SetPoint("BOTTOMLEFT", btn.icon, "BOTTOMRIGHT", 5, 2)
    btn.castbar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")

    btn:SetScript("OnClick", function(self)
        if self.unit then
            TargetUnit(self.unit)
        end
    end)

    return btn
end

local function UpdateInterruptUI()

    local index = 1

    for unit, data in pairs(activeUnits) do

        if data.cast then

            local btn = container.buttons[index]

            if not btn then
                btn = CreateButton(index)
                container.buttons[index] = btn
            end

            btn.unit = unit
            btn.text:SetText(data.cast.spell)
            btn.icon:SetTexture(data.cast.icon)

            local now = GetTime() * 1000
            local duration = data.cast.endTime - data.cast.startTime
            local progress = now - data.cast.startTime

            btn.castbar:SetMinMaxValues(0, duration)
            btn.castbar:SetValue(progress)

            btn.startTime = data.cast.startTime
            btn.endTime = data.cast.endTime

            btn:Show()
            index = index + 1
        end
    end

    for i = index, #container.buttons do
        container.buttons[i]:Hide()
    end
end

-------------------------------------------------
-- Core Update Loop
-------------------------------------------------

local elapsed = 0

container:SetScript("OnUpdate", function(_, delta)

    elapsed = elapsed + delta
    if elapsed < throttle then return end
    elapsed = 0

    local now = GetTime() * 1000

    for unit, data in pairs(activeUnits) do

        -- Update threat
        UpdateThreat(unit)
        UpdateNameplate(unit)

        -- Update castbars
        if data.cast then
            -- expire finished casts
            if now >= data.cast.endTime then
                data.cast = nil
            end
        end
    end

    UpdateInterruptUI()
end)

-------------------------------------------------
-- Unit Lifecycle
-------------------------------------------------

local function AddUnit(unit)

    if not ValidateUnit(unit) then return end

    activeUnits[unit] = {
        threatColor = nil,
        cast = nil
    }

    UpdateThreat(unit)
    UpdateCast(unit)
end

local function RemoveUnit(unit)
    activeUnits[unit] = nil
end

-------------------------------------------------
-- Event Handler
-------------------------------------------------

f:SetScript("OnEvent", function(_, event, unit)

    if event == "NAME_PLATE_UNIT_ADDED" then
        AddUnit(unit)

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        RemoveUnit(unit)

    elseif event == "PLAYER_ENTERING_WORLD" then
        for unit in pairs(activeUnits) do
            UpdateThreat(unit)
            UpdateCast(unit)
        end

    elseif event:find("UNIT_SPELLCAST") then
        if unit and activeUnits[unit] then
            UpdateCast(unit)
        end
    end

end)