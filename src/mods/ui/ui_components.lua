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

function components.DrawBanSearchControls(ctx, idSuffix)
    local ui = ctx.imgui
    local session = ctx.session
    idSuffix = tostring(idSuffix or "")

    ui.AlignTextToFramePadding()
    ui.Text("Filter:")
    ui.SameLine()
    ctx.widgets.inputText(uiData.BAN_FILTER_TEXT_ALIAS, {
        label = "",
        controlWidth = 180,
    })
    ui.SameLine()
    ctx.widgets.button("Clear", {
        id = "boon_bans_filter_clear_" .. idSuffix,
        onClick = function()
            session.reset(uiData.BAN_FILTER_TEXT_ALIAS)
        end,
    })
end

function components.DrawFilteredPackedBanList(ctx, banPoolKey, opts)
    opts = opts or {}
    local session = ctx.session
    local filterText = tostring(session and session.view and session.view[uiData.BAN_FILTER_TEXT_ALIAS] or "")
    local fields = banConfig.ResolveBanFields(banPoolKey, session)
    if not fields then
        return
    end

    ctx.widgets.packedCheckboxList(fields.bans, {
        valueColors = opts.valueColors or uiData.BuildPackedBanValueColors(banPoolKey),
        slotCount = opts.slotCount or #uiData.GetBanPoolBoons(banPoolKey),
        filterText = filterText,
    })

    if uiData.GetVisibleBanCount(banPoolKey, session) == 0 then
        ctx.widgets.text("No boons match the current filter.", {
            color = uiData.MUTED_TEXT_COLOR,
        })
    end
end

local function GetSingleForcedBoon(ctx, banPoolKey, fields)
    fields = fields or banConfig.ResolveBanFields(banPoolKey, ctx.session)
    if not fields then
        return nil
    end

    local selectedAlias = ctx.widgets.getPackedChoiceAlias(fields.bans, {
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

function components.DrawConfiguredBanPoolControl(ctx, root)
    local ui = ctx.imgui
    local session = ctx.session
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

function components.DrawForcedBoonRarityShortcut(ctx, root, banPool, fields)
    local ui = ctx.imgui
    if not root or not root.hasRarity or not banPool then
        return
    end

    local forcedBoon = GetSingleForcedBoon(ctx, banPool.key, fields)
    if not forcedBoon or forcedBoon.IsRarityEligible == false then
        return
    end

    local rarityAlias = banPools.getRarityAlias(root.primaryGodKey, forcedBoon.Key)
    if not rarityAlias then
        return
    end

    ui.SameLine()
    ui.SetCursorPosX(330)
    ctx.widgets.dropdown(rarityAlias, {
        label = "Rarity",
        values = { 0, 1, 2, 3 },
        displayValues = uiData.RARITY_LABELS,
        valueColors = uiData.RARITY_COLORS,
        controlWidth = 120,
    })
end

function components.DrawForceBanRow(ctx, root, banPool, opts)
    opts = opts or {}
    local ui = ctx.imgui
    local session = ctx.session
    local fields = banConfig.ResolveBanFields(banPool.key, session)
    if not fields then
        return
    end

    ui.AlignTextToFramePadding()
    ui.Text(opts.label or banPool.label)
    ui.SameLine()
    ui.SetCursorPosX(opts.controlX or 80)
    ctx.widgets.packedDropdown(fields.bans, {
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
        components.DrawForcedBoonRarityShortcut(ctx, root, banPool, fields)
    end
end

function components.DrawBanPanel(ctx, banPoolKey, idPrefix)
    local ui = ctx.imgui
    local session = ctx.session
    local host = ctx.host

    components.DrawBanSearchControls(ctx, banPoolKey)
    ui.SameLine()
    ui.SetCursorPosX(ui.GetCursorPosX() + 100)

    ctx.widgets.button("Ban All", {
        id = idPrefix .. "_ban_all_" .. banPoolKey,
        onClick = function()
            uiActions.BanAllGodBans(banPoolKey, session, host)
        end,
    })
    ui.SameLine()
    ctx.widgets.button("Reset", {
        id = idPrefix .. "_reset_" .. banPoolKey,
        onClick = function()
            uiActions.ResetGodBans(banPoolKey, session, host)
        end,
    })

    ctx.widgets.separator()
    components.DrawFilteredPackedBanList(ctx, banPoolKey)
end

function components.DrawRarityPanel(ctx, root)
    local ui = ctx.imgui
    for _, boon in ipairs(uiData.GetBanPoolBoons(root.primaryGodKey)) do
        if boon.IsRarityEligible ~= false then
            local rarityAlias = banPools.getRarityAlias(root.primaryGodKey, boon.Key)
            if rarityAlias then
                ui.AlignTextToFramePadding()
                ui.Text(uiData.GetBoonText(boon))
                ui.SameLine()
                ui.SetCursorPosX(220)
                ctx.widgets.dropdown(rarityAlias, {
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
