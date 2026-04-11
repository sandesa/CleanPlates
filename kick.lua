local CP = CleanPlates
CP.Interrupt = {}

local Interrupt = CP.Interrupt

-------------------------------------------------
-- STORAGE
-------------------------------------------------

-------------------------------------------------
-- UI
-------------------------------------------------

local container = CreateFrame("Frame", nil, UIParent)
container:SetSize(220, 300)
container:SetPoint("CENTER")

container.buttons = {}

-------------------------------------------------
-- BUTTON
-------------------------------------------------

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

-------------------------------------------------
-- CAST DETECTION
-------------------------------------------------

function Interrupt:GetCast(unit)

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
end

function Interrupt:OnCastEvent(unit)

    local data = CP.activeUnits[unit]
    if not data then return end

    data.cast = self:GetCast(unit)
end

-------------------------------------------------
-- CLEANUP
-------------------------------------------------

function Interrupt:OnUnitAdded(unit)
    local data = CP.activeUnits[unit]
    if data then data.cast = nil end
end

function Interrupt:OnUnitRemoved(unit)
    local data = CP.activeUnits[unit]
    if data then data.cast = nil end
end

-------------------------------------------------
-- UI BUILD
-------------------------------------------------

function Interrupt:UpdateUI()

    local sorted = {}

    for unit, data in pairs(CP.activeUnits) do
        if data.cast then
            table.insert(sorted, {unit = unit, cast = data.cast})
        end
    end

    table.sort(sorted, function(a, b)
        return a.cast.endTime < b.cast.endTime
    end)

    local index = 1
    local now = GetTime() * 1000

    for _, entry in ipairs(sorted) do

        local unit = entry.unit
        local cast = entry.cast

        local btn = container.buttons[index]

        if not btn then
            btn = CreateButton(index)
            container.buttons[index] = btn
        end

        btn.unit = unit
        btn.text:SetText(cast.spell)
        btn.icon:SetTexture(cast.icon)

        local duration = cast.endTime - cast.startTime
        local progress = now - cast.startTime

        btn.castbar:SetMinMaxValues(0, duration)
        btn.castbar:SetValue(progress)

        btn:Show()
        index = index + 1
    end

    for i = index, #container.buttons do
        container.buttons[i]:Hide()
    end
end