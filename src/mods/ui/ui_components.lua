local uiData, uiActions = nil, nil
local banConfig = nil
local banPools = nil
local components = {}

function components.bind(data, model, actions)
    banConfig = data.banConfig
    banPools = data.banPools
    uiData = model
    uiActions = actions
    return components
end

function components.DrawBanSearchControls(draw, idSuffix)
    local imgui = draw.imgui
    local session = draw.session
    idSuffix = tostring(idSuffix or "")

    imgui.AlignTextToFramePadding()
    imgui.Text("Filter:")
    imgui.SameLine()
    draw.widgets.inputText(uiData.BAN_FILTER_TEXT_ALIAS, {
        label = "",
        controlWidth = 180,
    })
    imgui.SameLine()
    draw.widgets.button("Clear", {
        id = "boon_bans_filter_clear_" .. idSuffix,
        onClick = function()
            session.reset(uiData.BAN_FILTER_TEXT_ALIAS)
        end,
    })
end

function components.DrawFilteredPackedBanList(draw, banPoolKey, opts)
    opts = opts or {}
    local session = draw.session
    local filterText = tostring(session and session.view and session.view[uiData.BAN_FILTER_TEXT_ALIAS] or "")
    local fields = banConfig.ResolveBanFields(banPoolKey, session)
    if not fields then
        return
    end

    draw.widgets.packedCheckboxList(fields.bans, {
        valueColors = opts.valueColors or uiData.BuildPackedBanValueColors(banPoolKey),
        slotCount = opts.slotCount or #uiData.GetBanPoolBoons(banPoolKey),
        filterText = filterText,
    })

    if uiData.GetVisibleBanCount(banPoolKey, session) == 0 then
        draw.widgets.text("No boons match the current filter.", {
            color = uiData.MUTED_TEXT_COLOR,
        })
    end
end

local function GetSingleForcedBoon(draw, banPoolKey, fields)
    fields = fields or banConfig.ResolveBanFields(banPoolKey, draw.session)
    if not fields then
        return nil
    end

    local selectedAlias = draw.widgets.getPackedChoiceAlias(fields.bans, {
        selectionMode = "singleDisabled",
    })
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

function components.DrawConfiguredBanPoolControl(draw, root)
    local imgui = draw.imgui
    local session = draw.session
    if not root or not root.primaryGodKey or (root.maxBanPools or 1) <= 1 then
        return
    end

    local godKey = root.primaryGodKey
    local maxBanPools = banConfig.GetMaxConfigurableBanPools(godKey)
    if maxBanPools <= 1 then
        return
    end

    local currentCount = banConfig.GetConfiguredBanPoolCount(godKey, session)
    imgui.AlignTextToFramePadding()
    imgui.Text("Configured pools")
    imgui.SameLine()
    imgui.SetCursorPosX(160)
    if imgui.Button("-##configured_ban_pools_" .. godKey) and currentCount > 1 then
        uiActions.SetConfiguredBanPoolCount(godKey, currentCount - 1, session)
        currentCount = currentCount - 1
    end
    imgui.SameLine()
    imgui.Text(tostring(currentCount))
    imgui.SameLine()
    if imgui.Button("+##configured_ban_pools_" .. godKey) and currentCount < maxBanPools then
        uiActions.SetConfiguredBanPoolCount(godKey, currentCount + 1, session)
    end
    imgui.Spacing()
end

function components.DrawForcedBoonRarityShortcut(draw, root, banPool, fields)
    local imgui = draw.imgui
    if not root or not root.hasRarity or not banPool then
        return
    end

    local forcedBoon = GetSingleForcedBoon(draw, banPool.key, fields)
    if not forcedBoon or forcedBoon.IsRarityEligible == false then
        return
    end

    local rarityAlias = banPools.getRarityAlias(root.primaryGodKey, forcedBoon.Key)
    if not rarityAlias then
        return
    end

    imgui.SameLine()
    imgui.SetCursorPosX(330)
    draw.widgets.dropdown(rarityAlias, {
        label = "Rarity",
        values = { 0, 1, 2, 3 },
        displayValues = uiData.RARITY_LABELS,
        valueColors = uiData.RARITY_COLORS,
        controlWidth = 120,
    })
end

function components.DrawForceBanRow(draw, root, banPool, opts)
    opts = opts or {}
    local imgui = draw.imgui
    local session = draw.session
    local fields = banConfig.ResolveBanFields(banPool.key, session)
    if not fields then
        return
    end

    imgui.AlignTextToFramePadding()
    imgui.Text(opts.label or banPool.label)
    imgui.SameLine()
    imgui.SetCursorPosX(opts.controlX or 80)
    draw.widgets.packedDropdown(fields.bans, {
        id = "force_" .. banPool.key,
        label = "",
        selectionMode = "singleDisabled",
        noneLabel = "None",
        multipleLabel = "Multiple",
        displayValues = uiData.BuildPackedBanDisplayValues(banPool.key),
        valueColors = uiData.BuildPackedBanValueColors(banPool.key),
        controlWidth = opts.controlWidth or 220,
    })

    if opts.drawRarity ~= false then
        components.DrawForcedBoonRarityShortcut(draw, root, banPool, fields)
    end
end

function components.DrawBanPanel(draw, banPoolKey, idPrefix)
    local imgui = draw.imgui
    local session = draw.session
    local host = draw.host

    components.DrawBanSearchControls(draw, banPoolKey)
    imgui.SameLine()
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 100)

    draw.widgets.button("Ban All", {
        id = idPrefix .. "_ban_all_" .. banPoolKey,
        onClick = function()
            uiActions.BanAllGodBans(banPoolKey, session, host)
        end,
    })
    imgui.SameLine()
    draw.widgets.button("Reset", {
        id = idPrefix .. "_reset_" .. banPoolKey,
        onClick = function()
            uiActions.ResetGodBans(banPoolKey, session, host)
        end,
    })

    draw.widgets.separator()
    components.DrawFilteredPackedBanList(draw, banPoolKey)
end

function components.DrawRarityPanel(draw, root)
    local imgui = draw.imgui
    for _, boon in ipairs(uiData.GetBanPoolBoons(root.primaryGodKey)) do
        if boon.IsRarityEligible ~= false then
            local rarityAlias = banPools.getRarityAlias(root.primaryGodKey, boon.Key)
            if rarityAlias then
                imgui.AlignTextToFramePadding()
                imgui.Text(uiData.GetBoonText(boon))
                imgui.SameLine()
                imgui.SetCursorPosX(220)
                draw.widgets.dropdown(rarityAlias, {
                    label = "",
                    values = { 0, 1, 2, 3 },
                    displayValues = uiData.RARITY_LABELS,
                    valueColors = uiData.RARITY_COLORS,
                    controlWidth = 120,
                })
            end
        end
    end
end

return components
