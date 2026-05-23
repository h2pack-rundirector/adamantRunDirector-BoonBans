local uiData, uiCommands = nil, nil
local banConfig = nil
local banPools = nil
local components = {}

local EMPTY_OPTS = {}

local BAN_FILTER_INPUT_OPTS = {
    label = "",
    controlWidth = 180,
}

local SINGLE_DISABLED_CHOICE_OPTS = {
    selectionMode = "singleDisabled",
}

local RARITY_VALUES = { 0, 1, 2, 3 }
local rarityDropdownOpts = {
    label = "",
    values = RARITY_VALUES,
    controlWidth = 120,
}
local rarityShortcutDropdownOpts = {
    label = "Rarity",
    values = RARITY_VALUES,
    controlWidth = 120,
}

local mutedTextOpts = nil
local filteredPackedBanOptsByPool = {}
local forcePackedDropdownOptsByPool = {}
local clearFilterButtonOptsById = {}
local banAllButtonOptsById = {}
local resetButtonOptsById = {}

function components.bind(state, model, commands)
    banConfig = state.banConfig
    banPools = state.banPools
    uiData = model
    uiCommands = commands
    mutedTextOpts = {
        color = uiData.MUTED_TEXT_COLOR,
    }
    rarityDropdownOpts.displayValues = uiData.RARITY_LABELS
    rarityDropdownOpts.valueColors = uiData.RARITY_COLORS
    rarityShortcutDropdownOpts.displayValues = uiData.RARITY_LABELS
    rarityShortcutDropdownOpts.valueColors = uiData.RARITY_COLORS
    filteredPackedBanOptsByPool = {}
    forcePackedDropdownOptsByPool = {}
    clearFilterButtonOptsById = {}
    banAllButtonOptsById = {}
    resetButtonOptsById = {}
    return components
end

local function GetFilteredPackedBanOpts(banPoolKey, filterText, opts)
    if opts and (opts.valueColors or opts.slotCount) then
        return {
            valueColors = opts.valueColors or uiData.BuildPackedBanValueColors(banPoolKey),
            slotCount = opts.slotCount or #uiData.GetBanPoolBoons(banPoolKey),
            filterText = filterText,
        }
    end

    local cached = filteredPackedBanOptsByPool[banPoolKey]
    if not cached then
        cached = {
            valueColors = uiData.BuildPackedBanValueColors(banPoolKey),
            slotCount = #uiData.GetBanPoolBoons(banPoolKey),
        }
        filteredPackedBanOptsByPool[banPoolKey] = cached
    end
    cached.filterText = filterText
    return cached
end

local function GetForcePackedDropdownOpts(banPoolKey, controlWidth)
    local widthKey = controlWidth or 220
    local byWidth = forcePackedDropdownOptsByPool[banPoolKey]
    if not byWidth then
        byWidth = {}
        forcePackedDropdownOptsByPool[banPoolKey] = byWidth
    end

    local cached = byWidth[widthKey]
    if not cached then
        cached = {
            id = "force_" .. banPoolKey,
            label = "",
            selectionMode = "singleDisabled",
            noneLabel = "None",
            multipleLabel = "Multiple",
            displayValues = uiData.BuildPackedBanDisplayValues(banPoolKey),
            valueColors = uiData.BuildPackedBanValueColors(banPoolKey),
            controlWidth = widthKey,
        }
        byWidth[widthKey] = cached
    end
    return cached
end

local function GetClearFilterButtonOpts(id, actions)
    local opts = clearFilterButtonOptsById[id]
    if not opts then
        opts = {
            id = id,
        }
        clearFilterButtonOptsById[id] = opts
    end
    opts.action = actions.get("clearFilter")
    return opts
end

local function GetBanAllButtonOpts(id, banPoolKey, actions)
    local opts = banAllButtonOptsById[id]
    if not opts then
        opts = {
            id = id,
        }
        banAllButtonOptsById[id] = opts
    end
    opts.action = actions.get("banAll")
    opts.value = banPoolKey
    return opts
end

local function GetResetButtonOpts(id, banPoolKey, actions)
    local opts = resetButtonOptsById[id]
    if not opts then
        opts = {
            id = id,
        }
        resetButtonOptsById[id] = opts
    end
    opts.action = actions.get("resetBans")
    opts.value = banPoolKey
    return opts
end

function components.DrawBanSearchControls(draw, state, actions, idSuffix)
    local imgui = draw.imgui
    local filterField = state.get(uiData.BAN_FILTER_TEXT_ALIAS)
    idSuffix = tostring(idSuffix or "")
    local clearId = "boon_bans_filter_clear_" .. idSuffix

    imgui.AlignTextToFramePadding()
    imgui.Text("Filter:")
    imgui.SameLine()
    draw.widgets.inputText(filterField, BAN_FILTER_INPUT_OPTS)
    imgui.SameLine()
    draw.widgets.button("Clear", GetClearFilterButtonOpts(clearId, actions))
end

function components.DrawFilteredPackedBanList(draw, state, banPoolKey, opts)
    opts = opts or EMPTY_OPTS
    local filterText = tostring(state.get(uiData.BAN_FILTER_TEXT_ALIAS):read() or "")
    local fields = banConfig.ResolveBanFields(banPoolKey, state)
    if not fields then
        return
    end

    draw.widgets.packedCheckboxList(fields.bans, GetFilteredPackedBanOpts(banPoolKey, filterText, opts))

    if uiData.GetVisibleBanCount(banPoolKey, state) == 0 then
        draw.widgets.text("No boons match the current filter.", mutedTextOpts)
    end
end

local function GetSingleForcedBoon(draw, state, banPoolKey, fields)
    fields = fields or banConfig.ResolveBanFields(banPoolKey, state)
    if not fields then
        return nil
    end

    local selectedAlias = draw.widgets.getPackedChoiceAlias(fields.bans, SINGLE_DISABLED_CHOICE_OPTS)
    if not selectedAlias then
        return nil
    end

    for _, boon in ipairs(uiData.GetBanPoolBoons(banPoolKey)) do
        local childAlias = banPools.makeBanAlias(fields.bans:alias(), boon.Key)
        if childAlias == selectedAlias then
            return boon
        end
    end
end

function components.DrawConfiguredBanPoolControl(draw, state, root)
    local imgui = draw.imgui
    if not root or not root.primaryGodKey or (root.maxBanPools or 1) <= 1 then
        return
    end

    local godKey = root.primaryGodKey
    local maxBanPools = banConfig.GetMaxConfigurableBanPools(godKey)
    if maxBanPools <= 1 then
        return
    end

    local currentCount = banConfig.GetConfiguredBanPoolCount(godKey, state)
    imgui.AlignTextToFramePadding()
    imgui.Text("Configured pools")
    imgui.SameLine()
    imgui.SetCursorPosX(160)
    if imgui.Button("-##configured_ban_pools_" .. godKey) and currentCount > 1 then
        uiCommands.SetConfiguredBanPoolCount(godKey, currentCount - 1, state)
        currentCount = currentCount - 1
    end
    imgui.SameLine()
    imgui.Text(tostring(currentCount))
    imgui.SameLine()
    if imgui.Button("+##configured_ban_pools_" .. godKey) and currentCount < maxBanPools then
        uiCommands.SetConfiguredBanPoolCount(godKey, currentCount + 1, state)
    end
    imgui.Spacing()
end

function components.DrawForcedBoonRarityShortcut(draw, state, root, banPool, fields)
    local imgui = draw.imgui
    if not root or not root.hasRarity or not banPool then
        return
    end

    local forcedBoon = GetSingleForcedBoon(draw, state, banPool.key, fields)
    if not forcedBoon or forcedBoon.IsRarityEligible == false then
        return
    end

    local rarityAlias = banPools.getRarityAlias(root.primaryGodKey, forcedBoon.Key)
    if not rarityAlias then
        return
    end

    imgui.SameLine()
    imgui.SetCursorPosX(330)
    draw.widgets.dropdown(state.get(rarityAlias), rarityShortcutDropdownOpts)
end

function components.DrawForceBanRow(draw, state, root, banPool, opts)
    opts = opts or EMPTY_OPTS
    local imgui = draw.imgui
    local fields = banConfig.ResolveBanFields(banPool.key, state)
    if not fields then
        return
    end

    imgui.AlignTextToFramePadding()
    imgui.Text(opts.label or banPool.label)
    imgui.SameLine()
    imgui.SetCursorPosX(opts.controlX or 80)
    draw.widgets.packedDropdown(fields.bans, GetForcePackedDropdownOpts(banPool.key, opts.controlWidth))

    if opts.drawRarity ~= false then
        components.DrawForcedBoonRarityShortcut(draw, state, root, banPool, fields)
    end
end

function components.DrawBanPanel(draw, state, actions, banPoolKey, idPrefix)
    local imgui = draw.imgui
    local banAllId = idPrefix .. "_ban_all_" .. banPoolKey
    local resetId = idPrefix .. "_reset_" .. banPoolKey

    components.DrawBanSearchControls(draw, state, actions, banPoolKey)
    imgui.SameLine()
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 100)

    draw.widgets.button("Ban All", GetBanAllButtonOpts(banAllId, banPoolKey, actions))
    imgui.SameLine()
    draw.widgets.button("Reset", GetResetButtonOpts(resetId, banPoolKey, actions))

    draw.widgets.separator()
    components.DrawFilteredPackedBanList(draw, state, banPoolKey)
end

function components.DrawRarityPanel(draw, state, root)
    local imgui = draw.imgui
    for _, boon in ipairs(uiData.GetBanPoolBoons(root.primaryGodKey)) do
        if boon.IsRarityEligible ~= false then
            local rarityAlias = banPools.getRarityAlias(root.primaryGodKey, boon.Key)
            if rarityAlias then
                imgui.AlignTextToFramePadding()
                imgui.Text(uiData.GetBoonText(boon))
                imgui.SameLine()
                imgui.SetCursorPosX(220)
                draw.widgets.dropdown(state.get(rarityAlias), rarityDropdownOpts)
            end
        end
    end
end

return components
