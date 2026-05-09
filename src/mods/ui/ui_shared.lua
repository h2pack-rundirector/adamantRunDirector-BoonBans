local internal = RunDirectorBoonBans_Internal
internal.godInfo = internal.godInfo or {}
local godInfo = internal.godInfo
local uiData = internal.ui
local GOD_AVAILABILITY_INTEGRATION = "run-director.god-availability"

uiData.EMPTY_LIST = {}

uiData.DEFAULT_GOD_COLOR = { 1, 1, 1, 1 }
uiData.DEFAULT_THEME_COLORS = {
    info = { 1, 1, 1, 1 },
    success = { 0.2, 1.0, 0.2, 1.0 },
    warning = { 1.0, 0.8, 0.0, 1.0 },
    error = { 1.0, 0.3, 0.3, 1.0 },
}
uiData.MUTED_TEXT_COLOR = { 0.6, 0.6, 0.6, 1.0 }
uiData.BADGE_COLORS = {
    duo = { 0.82, 1.0, 0.38, 1.0 },
    legendary = { 1.0, 0.56, 0.0, 1.0 },
    infusion = { 1.0, 0.29, 1.0, 1.0 },
}
uiData.RARITY_COLORS = {
    [0] = { 0.7, 0.7, 0.7, 1.0 },
    [1] = { 1.0, 1.0, 1.0, 1.0 },
    [2] = { 0.0, 0.54, 1.0, 1.0 },
    [3] = { 0.62, 0.07, 1.0, 1.0 },
}
uiData.RARITY_LABELS = {
    [0] = "Auto",
    [1] = "Comm",
    [2] = "Rare",
    [3] = "Epic",
}
uiData.NPC_REGION_OPTIONS = {
    { label = "Neither", value = 1 },
    { label = "Underworld", value = 2 },
    { label = "Surface", value = 3 },
    { label = "Both", value = 4 },
}
uiData.BRIDAL_GLOW_VIEW_ID = "__bridal_glow__"
uiData.BAN_FILTER_TEXT_ALIAS = "BanFilterText"
uiData.NPC_VIEW_REGION_ALIAS = "NpcViewRegion"
uiData.DIRECT_BANS_VIEW_ID = "__bans__"
uiData.FORCE_VIEW_ID = "__force__"
uiData.RARITY_VIEW_ID = "__rarity__"
uiData.ROOT_NAV_WIDTH = 220

uiData.bridalGlowEligibleRoots = nil
uiData.rarityRowsByRoot = {}
uiData.bridalGlowBoonsByRoot = {}
uiData.packedBanDisplayValuesByScope = {}
uiData.packedBanValueColorsByScope = {}

function uiData.GetOrdinal(n)
    local s = tostring(n)
    if n % 100 == 11 or n % 100 == 12 or n % 100 == 13 then return s .. "th" end
    local last = n % 10
    if last == 1 then return s .. "st" end
    if last == 2 then return s .. "nd" end
    if last == 3 then return s .. "rd" end
    return s .. "th"
end

function uiData.IsRegionMatch(group, regionValue)
    if regionValue == 4 then return true end
    if group == "Underworld" then
        return regionValue == 2
    end
    if group == "Surface" then
        return regionValue == 3
    end
    return true
end

function uiData.IsRarityEligibleBoon(boon)
    return boon.IsRarityEligible ~= false
end

function uiData.IsBridalGlowEligibleBoon(boon)
    return boon.IsBridalGlowEligible == true
end

function uiData.GetScopeBoons(scopeKey)
    local entry = godInfo[scopeKey]
    if entry and entry.boons then
        return entry.boons
    end
    return uiData.EMPTY_LIST
end

function uiData.FindBoonByKey(scopeKey, boonKey)
    local entry = godInfo[scopeKey]
    if entry and entry.boonByKey then
        return entry.boonByKey[boonKey]
    end

    for _, boon in ipairs(uiData.GetScopeBoons(scopeKey)) do
        if boon.Key == boonKey then
            return boon
        end
    end
end

local function FindAnyBoonByKey(boonKey)
    if type(boonKey) ~= "string" or boonKey == "" then
        return nil
    end

    for _, entry in pairs(godInfo) do
        if type(entry) == "table" and type(entry.boonByKey) == "table" then
            local boon = entry.boonByKey[boonKey]
            if boon then
                return boon
            end
        end
    end
end

local function GetForcedBoonDisplayLabel(boon)
    if not boon then
        return ""
    end
    return boon.SpecialDisplayLabel or uiData.GetBoonText(boon)
end

local function GetBoonMarkerColor(boon)
    return type(boon) == "table" and boon.SpecialBadgeColor or nil
end

function uiData.BuildPackedBanValueColors(scopeKey)
    local cached = uiData.packedBanValueColorsByScope[scopeKey]
    if cached then
        return cached
    end

    local colors = {}
    local rootAlias = internal.GetBanRootAlias(scopeKey)
    if type(rootAlias) ~= "string" or rootAlias == "" then
        return colors
    end
    local rootKey = internal.GetRootKey and internal.GetRootKey(scopeKey) or scopeKey
    local rootMeta = internal.godMeta and internal.godMeta[rootKey] or nil
    if type(rootMeta) == "table" and rootMeta.showPackedValueColors == false then
        uiData.packedBanValueColorsByScope[scopeKey] = colors
        return colors
    end

    for _, boon in ipairs(uiData.GetScopeBoons(scopeKey)) do
        local color = GetBoonMarkerColor(boon)
        local childAlias = internal.MakeBanAlias(rootAlias, boon.Key)
        if type(childAlias) == "string" and childAlias ~= "" and type(color) == "table" then
            colors[childAlias] = color
        end
    end

    uiData.packedBanValueColorsByScope[scopeKey] = colors
    return colors
end

function uiData.BuildPackedBanDisplayValues(scopeKey)
    local cached = uiData.packedBanDisplayValuesByScope[scopeKey]
    if cached then
        return cached
    end

    local displayValues = {}
    local rootAlias = internal.GetBanRootAlias(scopeKey)
    if type(rootAlias) ~= "string" or rootAlias == "" then
        return displayValues
    end

    for _, boon in ipairs(uiData.GetScopeBoons(scopeKey)) do
        local childAlias = internal.MakeBanAlias(rootAlias, boon.Key)
        if type(childAlias) == "string" and childAlias ~= "" then
            displayValues[childAlias] = GetForcedBoonDisplayLabel(boon)
        end
    end

    uiData.packedBanDisplayValuesByScope[scopeKey] = displayValues
    return displayValues
end

function uiData.GetBoonText(boon)
    return boon.Name or boon.Key or ""
end

function uiData.GetScopeSummary(scopeKey, session)
    if session then
        local total = 0
        local banned = 0
        local currentBans = internal.GetBanConfig(scopeKey, session)
        for _, boon in ipairs(uiData.GetScopeBoons(scopeKey)) do
            total = total + 1
            if bit32.band(currentBans, boon.Mask) ~= 0 then
                banned = banned + 1
            end
        end
        return banned, total
    end

    local entry = godInfo[scopeKey]
    if entry and type(entry.banned) == "number" and type(entry.total) == "number" then
        return entry.banned, entry.total
    end

    local total = 0
    local banned = 0
    local currentBans = 0
    for _, boon in ipairs(uiData.GetScopeBoons(scopeKey)) do
        total = total + 1
        if bit32.band(currentBans, boon.Mask) ~= 0 then
            banned = banned + 1
        end
    end
    return banned, total
end

function uiData.IsScopeCustomized(scopeKey, session)
    return internal.GetBanConfig(scopeKey, session) ~= 0
end

function uiData.GetVisibleBanCount(scopeKey, session)
    if type(scopeKey) ~= "string" or scopeKey == "" then
        return 0
    end

    local filterText = tostring(session and session.view and session.view[uiData.BAN_FILTER_TEXT_ALIAS] or ""):lower()
    local visibleCount = 0

    for _, boon in ipairs(uiData.GetScopeBoons(scopeKey)) do
        local boonText = (boon.NameLower or string.lower(uiData.GetBoonText(boon)))
        local matchesText = filterText == "" or boonText:find(filterText, 1, true) ~= nil
        if matchesText then
            visibleCount = visibleCount + 1
        end
    end

    return visibleCount
end

function uiData.GetSourceColor(scopeKey)
    local entry = godInfo[scopeKey]
    if entry and type(entry.color) == "table" then
        return entry.color
    end
    return uiData.DEFAULT_GOD_COLOR
end

function uiData.IsGodPoolFilteringActive()
    return lib.integrations.invoke(GOD_AVAILABILITY_INTEGRATION, "isActive", false) == true
end

function uiData.IsGodVisibleInGodPool(godKey)
    local root = internal.GetRootKey and internal.GetRootKey(godKey) or godKey
    return lib.integrations.invoke(GOD_AVAILABILITY_INTEGRATION, "isAvailable", true, root) ~= false
end

function uiData.GetCurrentBridalGlowTargetText(session)
    local selectedBoonKey = session and session.view and session.view.BridalGlowTargetBoon or ""
    if selectedBoonKey == nil or selectedBoonKey == "" then
        return "Current Target: Random"
    end

    local boon = FindAnyBoonByKey(selectedBoonKey)
    if boon and uiData.IsBridalGlowEligibleBoon(boon) then
        return "Current Target: " .. (boon.BridalGlowLabel or uiData.GetBoonText(boon))
    end

    return "Current Target: Random"
end

function uiData.GetRootDisplayLabel(rootKey, meta)
    meta = meta or {}
    local display = meta.displayTextKey or rootKey
    if meta.maxTiers then
        display = display:gsub("^1st%s+", "")
    end
    return display
end

function uiData.GetRootMeta(rootKey)
    return internal.godMeta and internal.godMeta[rootKey] or nil
end

function uiData.IsRarityRoot(rootKey)
    local meta = uiData.GetRootMeta(rootKey)
    return type(meta) == "table" and meta.rarityVar ~= nil
end

function uiData.GetTierScopeKey(rootKey, tier)
    if tier <= 1 then
        return rootKey
    end
    return rootKey .. tostring(tier)
end

function uiData.BuildTierScopes(rootKey, session)
    local rootMeta = uiData.GetRootMeta(rootKey) or {}
    local maxTiers = math.max(math.floor(tonumber(rootMeta.maxTiers) or 1), 1)
    local configuredTiers = internal.GetConfiguredTierCount and internal.GetConfiguredTierCount(rootKey, session) or maxTiers
    if configuredTiers < 1 then configuredTiers = 1 end
    if configuredTiers > maxTiers then configuredTiers = maxTiers end
    local scopes = {}

    for tier = 1, configuredTiers do
        local scopeKey = uiData.GetTierScopeKey(rootKey, tier)
        if uiData.GetRootMeta(scopeKey) then
            scopes[#scopes + 1] = {
                key = scopeKey,
                label = uiData.GetOrdinal(tier),
            }
        end
    end

    if #scopes == 0 then
        scopes[1] = { key = rootKey, label = "Bans" }
    end
    return scopes
end

function uiData.BuildTierRoot(rootKey, opts)
    opts = opts or {}
    local rootMeta = uiData.GetRootMeta(rootKey) or {}
    local maxTiers = math.max(math.floor(tonumber(rootMeta.maxTiers) or 1), 1)
    return {
        id = rootKey,
        label = opts.label or uiData.GetRootDisplayLabel(rootKey, rootMeta),
        primaryScopeKey = rootKey,
        maxTiers = maxTiers,
        hasRarity = opts.hasRarity ~= nil and opts.hasRarity or uiData.IsRarityRoot(rootKey),
        hasBridalGlow = opts.hasBridalGlow == true,
        scopes = uiData.BuildTierScopes(rootKey, opts.session),
    }
end

function internal.DrawConfiguredTierControl(ui, session, root)
    if not root or not root.primaryScopeKey or (root.maxTiers or 1) <= 1 then
        return
    end

    local rootKey = root.primaryScopeKey
    local maxTiers = internal.GetMaxConfigurableTiers(rootKey)
    if maxTiers <= 1 then
        return
    end

    local currentCount = internal.GetConfiguredTierCount(rootKey, session)
    ui.AlignTextToFramePadding()
    ui.Text("Configured tiers")
    ui.SameLine()
    ui.SetCursorPosX(160)
    if ui.Button("-##configured_tiers_" .. rootKey) and currentCount > 1 then
        internal.SetConfiguredTierCount(rootKey, currentCount - 1, session)
        currentCount = currentCount - 1
    end
    ui.SameLine()
    ui.Text(tostring(currentCount))
    ui.SameLine()
    if ui.Button("+##configured_tiers_" .. rootKey) and currentCount < maxTiers then
        internal.SetConfiguredTierCount(rootKey, currentCount + 1, session)
    end
    ui.Spacing()
end

local function GetSingleForcedBoon(scopeKey, session, handle, bindAlias)
    if not handle or not bindAlias then
        handle, bindAlias = internal.ResolveBanBinding(scopeKey, session)
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

    for _, boon in ipairs(uiData.GetScopeBoons(scopeKey)) do
        local childAlias = internal.MakeBanAlias(bindAlias, boon.Key)
        if childAlias == selectedAlias then
            return boon
        end
    end
end

function internal.DrawForcedBoonRarityShortcut(ui, session, root, scope, handle, bindAlias)
    if not root or not root.hasRarity or not scope then
        return
    end

    local forcedBoon = GetSingleForcedBoon(scope.key, session, handle, bindAlias)
    if not forcedBoon or not uiData.IsRarityEligibleBoon(forcedBoon) then
        return
    end

    local rarityAlias = internal.GetRarityAlias(root.primaryScopeKey, forcedBoon.Key)
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

function internal.DrawForceBanRow(ui, session, root, scope, opts)
    opts = opts or {}
    local handle, bindAlias = internal.ResolveBanBinding(scope.key, session)
    if not handle or not bindAlias then
        return
    end

    ui.AlignTextToFramePadding()
    ui.Text(opts.label or scope.label)
    ui.SameLine()
    ui.SetCursorPosX(opts.controlX or 80)
    lib.widgets.packedDropdown(ui, handle, bindAlias, {
        id = "force_" .. scope.key,
        label = "",
        selectionMode = "singleDisabled",
        noneLabel = "None",
        multipleLabel = "Multiple",
        displayValues = uiData.BuildPackedBanDisplayValues(scope.key),
        valueColors = uiData.BuildPackedBanValueColors(scope.key),
        controlWidth = opts.controlWidth or 220,
    })

    if opts.drawRarity ~= false then
        internal.DrawForcedBoonRarityShortcut(ui, session, root, scope, handle, bindAlias)
    end
end

function internal.DrawBanPanel(ui, session, scopeKey, idPrefix)
    internal.DrawBanSearchControls(ui, session, scopeKey)
    ui.SameLine()
    ui.SetCursorPosX(ui.GetCursorPosX() + 100)

    lib.widgets.button(ui, "Ban All", {
        id = idPrefix .. "_ban_all_" .. scopeKey,
        onClick = function()
            internal.BanAllGodBans(scopeKey, session)
        end,
    })
    ui.SameLine()
    lib.widgets.button(ui, "Reset", {
        id = idPrefix .. "_reset_" .. scopeKey,
        onClick = function()
            internal.ResetGodBans(scopeKey, session)
        end,
    })

    lib.widgets.separator(ui)
    internal.DrawFilteredPackedBanList(ui, session, scopeKey)
end

function internal.DrawRarityPanel(ui, session, root)
    for _, boon in ipairs(uiData.GetScopeBoons(root.primaryScopeKey)) do
        if uiData.IsRarityEligibleBoon(boon) then
            local rarityAlias = internal.GetRarityAlias(root.primaryScopeKey, boon.Key)
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

function uiData.BuildSingleScopeRoot(rootKey, opts)
    opts = opts or {}
    local rootMeta = uiData.GetRootMeta(rootKey) or {}
    return {
        id = rootKey,
        label = opts.label or uiData.GetRootDisplayLabel(rootKey, rootMeta),
        group = opts.group,
        primaryScopeKey = rootKey,
        hasRarity = opts.hasRarity ~= nil and opts.hasRarity or uiData.IsRarityRoot(rootKey),
        scopes = {
            { key = rootKey, label = opts.scopeLabel or "Bans" },
        },
    }
end
