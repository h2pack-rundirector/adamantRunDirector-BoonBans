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

function components.DrawBanSearchControls(ui, session, idSuffix)
    idSuffix = tostring(idSuffix or "")

    ui.AlignTextToFramePadding()
    ui.Text("Filter:")
    ui.SameLine()
    lib.widgets.inputText(ui, session, uiData.BAN_FILTER_TEXT_ALIAS, {
        label = "",
        controlWidth = 180,
    })
    ui.SameLine()
    lib.widgets.button(ui, "Clear", {
        id = "boon_bans_filter_clear_" .. idSuffix,
        onClick = function()
            session.reset(uiData.BAN_FILTER_TEXT_ALIAS)
        end,
    })
end

function components.DrawFilteredPackedBanList(ui, session, banPoolKey, opts)
    opts = opts or {}
    local filterText = tostring(session and session.view and session.view[uiData.BAN_FILTER_TEXT_ALIAS] or "")
    local handle, bindAlias = banConfig.ResolveBanBinding(banPoolKey, session)
    if not handle or not bindAlias then
        return
    end

    lib.widgets.packedCheckboxList(ui, handle, bindAlias, {
        valueColors = opts.valueColors or uiData.BuildPackedBanValueColors(banPoolKey),
        slotCount = opts.slotCount or #uiData.GetBanPoolBoons(banPoolKey),
        filterText = filterText,
    })

    if uiData.GetVisibleBanCount(banPoolKey, session) == 0 then
        lib.widgets.text(ui, "No boons match the current filter.", {
            color = uiData.MUTED_TEXT_COLOR,
        })
    end
end

local function GetSingleForcedBoon(banPoolKey, session, handle, bindAlias)
    if not handle or not bindAlias then
        handle, bindAlias = banConfig.ResolveBanBinding(banPoolKey, session)
    end
    if not handle or not bindAlias then
        return nil
    end

    local selectedAlias = lib.widgets.getPackedChoiceAlias(handle, bindAlias, {
        selectionMode = "singleDisabled",
    })
    if not selectedAlias then
        return nil
    end

    for _, boon in ipairs(uiData.GetBanPoolBoons(banPoolKey)) do
        local childAlias = banPools.makeBanAlias(bindAlias, boon.Key)
        if childAlias == selectedAlias then
            return boon
        end
    end
end

function components.DrawConfiguredBanPoolControl(ui, session, root)
    if not root or not root.primaryGodKey or (root.maxBanPools or 1) <= 1 then
        return
    end

    local godKey = root.primaryGodKey
    local maxBanPools = banConfig.GetMaxConfigurableBanPools(godKey)
    if maxBanPools <= 1 then
        return
    end

    local currentCount = banConfig.GetConfiguredBanPoolCount(godKey, session)
    ui.AlignTextToFramePadding()
    ui.Text("Configured pools")
    ui.SameLine()
    ui.SetCursorPosX(160)
    if ui.Button("-##configured_ban_pools_" .. godKey) and currentCount > 1 then
        uiActions.SetConfiguredBanPoolCount(godKey, currentCount - 1, session)
        currentCount = currentCount - 1
    end
    ui.SameLine()
    ui.Text(tostring(currentCount))
    ui.SameLine()
    if ui.Button("+##configured_ban_pools_" .. godKey) and currentCount < maxBanPools then
        uiActions.SetConfiguredBanPoolCount(godKey, currentCount + 1, session)
    end
    ui.Spacing()
end

function components.DrawForcedBoonRarityShortcut(ui, session, root, banPool, handle, bindAlias)
    if not root or not root.hasRarity or not banPool then
        return
    end

    local forcedBoon = GetSingleForcedBoon(banPool.key, session, handle, bindAlias)
    if not forcedBoon or forcedBoon.IsRarityEligible == false then
        return
    end

    local rarityAlias = banPools.getRarityAlias(root.primaryGodKey, forcedBoon.Key)
    if not rarityAlias then
        return
    end

    ui.SameLine()
    ui.SetCursorPosX(330)
    lib.widgets.dropdown(ui, session, rarityAlias, {
        label = "Rarity",
        values = { 0, 1, 2, 3 },
        displayValues = uiData.RARITY_LABELS,
        valueColors = uiData.RARITY_COLORS,
        controlWidth = 120,
    })
end

function components.DrawForceBanRow(ui, session, root, banPool, opts)
    opts = opts or {}
    local handle, bindAlias = banConfig.ResolveBanBinding(banPool.key, session)
    if not handle or not bindAlias then
        return
    end

    ui.AlignTextToFramePadding()
    ui.Text(opts.label or banPool.label)
    ui.SameLine()
    ui.SetCursorPosX(opts.controlX or 80)
    lib.widgets.packedDropdown(ui, handle, bindAlias, {
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
        components.DrawForcedBoonRarityShortcut(ui, session, root, banPool, handle, bindAlias)
    end
end

function components.DrawBanPanel(ui, session, host, banPoolKey, idPrefix)
    components.DrawBanSearchControls(ui, session, banPoolKey)
    ui.SameLine()
    ui.SetCursorPosX(ui.GetCursorPosX() + 100)

    lib.widgets.button(ui, "Ban All", {
        id = idPrefix .. "_ban_all_" .. banPoolKey,
        onClick = function()
            uiActions.BanAllGodBans(banPoolKey, session, host)
        end,
    })
    ui.SameLine()
    lib.widgets.button(ui, "Reset", {
        id = idPrefix .. "_reset_" .. banPoolKey,
        onClick = function()
            uiActions.ResetGodBans(banPoolKey, session, host)
        end,
    })

    lib.widgets.separator(ui)
    components.DrawFilteredPackedBanList(ui, session, banPoolKey)
end

function components.DrawRarityPanel(ui, session, root)
    for _, boon in ipairs(uiData.GetBanPoolBoons(root.primaryGodKey)) do
        if boon.IsRarityEligible ~= false then
            local rarityAlias = banPools.getRarityAlias(root.primaryGodKey, boon.Key)
            if rarityAlias then
                ui.AlignTextToFramePadding()
                ui.Text(uiData.GetBoonText(boon))
                ui.SameLine()
                ui.SetCursorPosX(220)
                lib.widgets.dropdown(ui, session, rarityAlias, {
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
