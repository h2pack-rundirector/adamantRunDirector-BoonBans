-- luacheck: no unused args

local band = bit32.band

local deps = ...
local data = deps.data
local runtime = deps.runtime

local ui = {}

local RARITY_VALUES = { 0, 1, 2, 3 }
local RARITY_LABELS = {
    [0] = "Auto",
    [1] = "Comm",
    [2] = "Rare",
    [3] = "Epic",
}
local RARITY_COLORS = {
    [0] = { 0.7, 0.7, 0.7, 1.0 },
    [1] = { 1.0, 1.0, 1.0, 1.0 },
    [2] = { 0.0, 0.54, 1.0, 1.0 },
    [3] = { 0.62, 0.07, 1.0, 1.0 },
}
local MUTED_TEXT_OPTS = {
    color = { 0.6, 0.6, 0.6, 1.0 },
}
local FILTER_INPUT_OPTS = {
    label = "",
    controlWidth = 180,
    maxLen = 128,
}
local FORCE_DROPDOWN_BASE = {
    label = "",
    selectionMode = "singleDisabled",
    noneLabel = "None",
    multipleLabel = "Multiple",
}
local RARITY_DROPDOWN_BASE = {
    label = "",
    values = RARITY_VALUES,
    displayValues = RARITY_LABELS,
    valueColors = RARITY_COLORS,
    controlWidth = 120,
}
local RARITY_SHORTCUT_BASE = {
    label = "Rarity",
    values = RARITY_VALUES,
    displayValues = RARITY_LABELS,
    valueColors = RARITY_COLORS,
    controlWidth = 120,
}

local function copyBaseOpts(base)
    local copy = {}
    for key, value in pairs(base or {}) do
        copy[key] = value
    end
    return copy
end

local function ordinal(index)
    local suffix = "th"
    if index % 100 ~= 11 and index % 100 ~= 12 and index % 100 ~= 13 then
        local last = index % 10
        if last == 1 then suffix = "st"
        elseif last == 2 then suffix = "nd"
        elseif last == 3 then suffix = "rd" end
    end
    return tostring(index) .. suffix
end

local function buildValueColorsFromSchema(field)
    local colors = {}
    local schema = field:schema()
    for _, bit in ipairs(schema and schema.bits or {}) do
        if type(bit._valueColor) == "table" then
            colors[bit.alias] = bit._valueColor
        end
    end
    return colors
end

local function createFilterField(instance)
    local value = ""
    local field = {}

    function field:read()
        return value
    end

    function field:write(nextValue)
        nextValue = tostring(nextValue or "")
        if value == nextValue then
            return false
        end
        value = nextValue
        return true
    end

    function field:reset()
        return self:write("")
    end

    function field:alias()
        return "Filter"
    end

    return field
end

local function countVisibleItems(instance, filterText)
    local lowerFilter = tostring(filterText or ""):lower()
    if lowerFilter == "" then
        return #instance.items
    end

    local count = 0
    for _, item in ipairs(instance.items) do
        local text = item.searchText or tostring(item.label or item.key or ""):lower()
        if text:find(lowerFilter, 1, true) ~= nil then
            count = count + 1
        end
    end
    return count
end

local function getForcedItem(control, instance, tierIndex)
    local field = control:banField(tierIndex)
    if field == nil then
        return nil
    end

    local disabledCount = 0
    local forced = nil
    for _, item in ipairs(instance.items) do
        if field:readAlias(item.key) ~= true then
            disabledCount = disabledCount + 1
            forced = item
        end
    end

    if disabledCount == 1 then
        return forced
    end
    return nil
end

local function getRarityItemField(control, instance, item)
    if control._rarityItemFields == nil then
        control._rarityItemFields = {}
    end
    local cached = control._rarityItemFields[item.key]
    if cached ~= nil then
        return cached
    end

    local rarityField = control:rarityField()
    if rarityField == nil then
        return nil
    end

    local field = {
        _kind = rawget(rarityField, "_kind"),
    }
    function field.read()
        return rarityField:readAlias(item.key)
    end
    function field.write(_, value)
        return rarityField:writeAlias(item.key, value)
    end
    function field.alias()
        return item.key
    end
    function field.controlId()
        return tostring(rarityField:controlId()) .. ":" .. tostring(item.key)
    end
    cached = field
    control._rarityItemFields[item.key] = cached
    return cached
end

local function getForceDropdownOpts(control, instance, tierIndex, opts)
    local width = opts and opts.controlWidth or 220
    control._forceDropdownOpts = control._forceDropdownOpts or {}
    local cached = control._forceDropdownOpts[width]
    if cached == nil then
        cached = copyBaseOpts(FORCE_DROPDOWN_BASE)
        cached.controlWidth = width
        cached.valueColors = instance.valueColors
        control._forceDropdownOpts[width] = cached
    end
    cached.id = "force_" .. tostring(instance.name) .. "_" .. tostring(tierIndex)
    return cached
end

local function getRarityDropdownOpts(control, shortcut)
    if shortcut then
        if control._rarityShortcutOpts == nil then
            control._rarityShortcutOpts = copyBaseOpts(RARITY_SHORTCUT_BASE)
        end
        return control._rarityShortcutOpts
    end
    if control._rarityDropdownOpts == nil then
        control._rarityDropdownOpts = copyBaseOpts(RARITY_DROPDOWN_BASE)
    end
    return control._rarityDropdownOpts
end

local function drawTierCount(draw, control, instance)
    if instance.maxTiers <= 1 then
        return
    end

    local imgui = draw.imgui
    local currentCount = control:tierCount()
    imgui.AlignTextToFramePadding()
    imgui.Text("Configured pools")
    imgui.SameLine()
    imgui.SetCursorPosX(160)
    if imgui.Button("-##configured_ban_pools_" .. tostring(instance.name)) and currentCount > 1 then
        control:setTierCount(currentCount - 1)
        currentCount = currentCount - 1
    end
    imgui.SameLine()
    imgui.Text(tostring(currentCount))
    imgui.SameLine()
    if imgui.Button("+##configured_ban_pools_" .. tostring(instance.name)) and currentCount < instance.maxTiers then
        control:setTierCount(currentCount + 1)
    end
    imgui.Spacing()
end

local function drawForcedRarityShortcut(draw, control, instance, tierIndex, opts)
    if opts and opts.drawRarity == false then
        return
    end
    if not control:hasRarity() then
        return
    end

    local forcedItem = getForcedItem(control, instance, tierIndex)
    if forcedItem == nil or forcedItem.isRarityEligible == false then
        return
    end

    local field = getRarityItemField(control, instance, forcedItem)
    if field == nil then
        return
    end

    local imgui = draw.imgui
    imgui.SameLine()
    imgui.SetCursorPosX(opts and opts.rarityColumnX or 330)
    draw.widgets.dropdown(field, getRarityDropdownOpts(control, true))
end

local function drawForceRow(draw, control, instance, tierIndex, opts)
    local imgui = draw.imgui
    local label = opts and opts.label or control:tierLabel(tierIndex)
    local field = control:banField(tierIndex)
    if field == nil then
        return
    end

    imgui.AlignTextToFramePadding()
    imgui.Text(label)
    imgui.SameLine()
    imgui.SetCursorPosX(opts and opts.controlX or 80)
    draw.widgets.packedDropdown(field, getForceDropdownOpts(control, instance, tierIndex, opts))
    drawForcedRarityShortcut(draw, control, instance, tierIndex, opts)
end

local function getTierPanelOpts(control, instance, filterText)
    if control._tierPanelOpts == nil then
        control._tierPanelOpts = {
            valueColors = instance.valueColors,
            slotCount = #instance.items,
        }
    end
    control._tierPanelOpts.filterText = filterText
    return control._tierPanelOpts
end

local function getButtonOpts(control, key, id)
    control._buttonOpts = control._buttonOpts or {}
    local opts = control._buttonOpts[key]
    if opts == nil then
        opts = {
            id = id,
        }
        control._buttonOpts[key] = opts
    end
    return opts
end

local function drawTierPanel(draw, control, instance, tierIndex)
    local imgui = draw.imgui
    local filterField = control:filterField()
    local filterText = tostring(filterField:read() or "")
    local banField = control:banField(tierIndex)
    if banField == nil then
        return
    end

    imgui.AlignTextToFramePadding()
    imgui.Text("Filter:")
    imgui.SameLine()
    imgui.PushItemWidth(FILTER_INPUT_OPTS.controlWidth)
    local nextFilterText, filterChanged = imgui.InputText(
        "##" .. tostring(filterField:alias()) .. "_" .. tostring(instance.name),
        filterText,
        FILTER_INPUT_OPTS.maxLen
    )
    imgui.PopItemWidth()
    if filterChanged then
        filterField:write(nextFilterText)
        filterText = tostring(filterField:read() or "")
    end
    imgui.SameLine()
    if draw.widgets.button("Clear", getButtonOpts(control, "clearFilter", "clear_filter_" .. tostring(instance.name))) then
        filterField:reset()
        filterText = ""
    end

    imgui.SameLine()
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 100)
    if draw.widgets.button("Ban All", getButtonOpts(
        control,
        "banAll:" .. tostring(tierIndex),
        "ban_all_" .. tostring(instance.name) .. "_" .. tostring(tierIndex)
    )) then
        control:banAllTier(tierIndex)
    end
    imgui.SameLine()
    if draw.widgets.button("Reset", getButtonOpts(
        control,
        "reset:" .. tostring(tierIndex),
        "reset_" .. tostring(instance.name) .. "_" .. tostring(tierIndex)
    )) then
        control:resetTier(tierIndex)
    end

    draw.widgets.separator()
    draw.widgets.packedCheckboxList(banField, getTierPanelOpts(control, instance, filterText))
    if countVisibleItems(instance, filterText) == 0 then
        draw.widgets.text("No boons match the current filter.", MUTED_TEXT_OPTS)
    end
end

function ui.create(fields, instance)
    local control = runtime.create(fields, instance)
    local filterField = createFilterField(instance)

    function control:banField(tierIndex)
        if not self:isTierConfigured(tierIndex) then
            return nil
        end
        return fields.Tiers:get(tierIndex, "Bans")
    end

    function control:filterField()
        return filterField
    end

    function control:tierLabel(tierIndex)
        tierIndex = math.floor(tonumber(tierIndex) or 1)
        if instance.maxTiers <= 1 then
            return "Bans"
        end
        return ordinal(tierIndex)
    end

    function control:rarityField()
        return fields.Rarity
    end

    function control:setTierCount(count)
        local nextCount = data.normalizeTierCount(instance, count)
        local currentCount = self:tierCount()
        if currentCount == nextCount then
            return false
        end
        while currentCount < nextCount do
            fields.Tiers:append()
            currentCount = currentCount + 1
        end
        while currentCount > nextCount do
            fields.Tiers:remove(currentCount)
            currentCount = currentCount - 1
        end
        return true
    end

    function control:writeBanMask(tierIndex, value)
        if not self:isTierConfigured(tierIndex) then
            return false
        end
        return fields.Tiers:write(tierIndex, "Bans", band(value or 0, instance.fullMask))
    end

    function control:banAllTier(tierIndex)
        return self:writeBanMask(tierIndex, instance.fullMask)
    end

    function control:resetTier(tierIndex)
        if not self:isTierConfigured(tierIndex) then
            return false
        end
        return fields.Tiers:reset(tierIndex, "Bans")
    end

    function control:resetAllTiers()
        local changed = false
        for tierIndex = 1, self:tierCount() do
            changed = self:resetTier(tierIndex) or changed
        end
        return changed
    end

    function control:resetTierCount()
        return self:setTierCount(self:defaultTiers())
    end

    function control:resetRarity()
        if fields.Rarity == nil then
            return false
        end
        return fields.Rarity:reset()
    end

    function control:resetAll()
        local tiersChanged = self:resetAllTiers()
        local tierCountChanged = self:resetTierCount()
        local rarityChanged = self:resetRarity()
        return tiersChanged or tierCountChanged or rarityChanged
    end

    instance.valueColors = buildValueColorsFromSchema(fields.Tiers:get(1, "Bans"))
    return control
end

ui.views = {}

function ui.views.default(draw, control, instance, opts)
    opts = opts or {}
    draw.widgets.text("Setup")
    draw.widgets.separator()
    drawTierCount(draw, control, instance)
    for tierIndex = 1, control:tierCount() do
        drawForceRow(draw, control, instance, tierIndex, opts)
    end
end

ui.views.setup = ui.views.default

function ui.views.tier(draw, control, instance, tierIndex)
    drawTierPanel(draw, control, instance, tierIndex or 1)
end

function ui.views.rarity(draw, control, instance)
    if not control:hasRarity() then
        return
    end

    local imgui = draw.imgui
    for _, item in ipairs(instance.items) do
        if item.isRarityEligible ~= false then
            local field = getRarityItemField(control, instance, item)
            if field ~= nil then
                imgui.AlignTextToFramePadding()
                imgui.Text(item.label)
                imgui.SameLine()
                imgui.SetCursorPosX(220)
                draw.widgets.dropdown(field, getRarityDropdownOpts(control, false))
            end
        end
    end
end

return ui
