local uiData, uiActions, components = nil, nil, nil
local banConfig = nil
local ACTIVE_OLYMPIAN_ROOT_ALIAS = "ActiveOlympianRoot"
local BRIDAL_GLOW_ROOT_ALIAS = "BridalGlowRoot"
local GOD_AVAILABILITY_INTEGRATION = "run-director.god-availability"
local EMPTY_LIST = {}
local bridalGlowEligibleRoots = nil
local bridalGlowBoonsByRoot = {}

local OLYMPIAN_ROOT_KEYS = {
    "Aphrodite",
    "Apollo",
    "Ares",
    "Demeter",
    "Hephaestus",
    "Hera",
    "Hestia",
    "Poseidon",
    "Zeus",
}

local function BuildOlympianRoots(session)
    local roots = {}
    for _, godKey in ipairs(OLYMPIAN_ROOT_KEYS) do
        roots[#roots + 1] = uiData.BuildBanPoolRoot(godKey, {
            session = session,
            hasBridalGlow = godKey == "Hera",
        })
    end
    return roots
end

local function IsRootCustomized(root, session)
    for _, banPool in ipairs(root.banPools) do
        if banConfig.IsBanPoolCustomized(banPool.key, session) then
            return true
        end
    end
    return false
end

local function IsGodPoolFilteringActive()
    return lib.integrations.invoke(GOD_AVAILABILITY_INTEGRATION, "isActive", false) == true
end

local function IsGodVisibleInGodPool(godKey)
    local resolvedGodKey = banConfig.ResolveGodKey(godKey)
    return lib.integrations.invoke(GOD_AVAILABILITY_INTEGRATION, "isAvailable", true, resolvedGodKey) ~= false
end

local function GetVisibleOlympianRoots(session)
    local godPoolFiltering = IsGodPoolFilteringActive()
    local roots = {}
    for _, root in ipairs(BuildOlympianRoots(session)) do
        if not godPoolFiltering or IsGodVisibleInGodPool(root.id) then
            roots[#roots + 1] = root
        end
    end
    return roots, godPoolFiltering
end

local function GetNavLabel(root, session)
    local label = root.label
    if IsRootCustomized(root, session) then
        label = label .. " *"
    end
    return label
end

local function GetActiveRoot(visibleRoots, session)
    local activeRootId = session.view[ACTIVE_OLYMPIAN_ROOT_ALIAS]
    for _, root in ipairs(visibleRoots) do
        if root.id == activeRootId then
            return root
        end
    end
    return visibleRoots[1]
end

local function DrawForcePanel(ctx, root)
    ctx.widgets.text("Setup")
    ctx.widgets.separator()
    components.DrawConfiguredBanPoolControl(ctx, root)
    for _, banPool in ipairs(root.banPools) do
        components.DrawForceBanRow(ctx, root, banPool)
    end
end

local function GetBridalGlowEligibleRoots(session)
    if bridalGlowEligibleRoots then
        return bridalGlowEligibleRoots
    end

    local visibleRoots = GetVisibleOlympianRoots(session)
    local cached = {}
    for _, root in ipairs(visibleRoots) do
        cached[#cached + 1] = root
    end
    bridalGlowEligibleRoots = cached
    return cached
end

local function GetBridalGlowEligibleBoons(root)
    if not root then
        return EMPTY_LIST
    end

    local cached = bridalGlowBoonsByRoot[root.id]
    if cached then
        return cached
    end

    local boons = {}
    for _, boon in ipairs(uiData.GetBanPoolBoons(root.primaryGodKey)) do
        if boon.IsBridalGlowEligible == true then
            boon.BridalGlowLabel = boon.BridalGlowLabel or uiData.GetBoonText(boon)
            boons[#boons + 1] = boon
        end
    end
    bridalGlowBoonsByRoot[root.id] = boons
    return boons
end

local function FindBoonByKey(banPoolKey, boonKey)
    for _, boon in ipairs(uiData.GetBanPoolBoons(banPoolKey)) do
        if boon.Key == boonKey then
            return boon
        end
    end
end

local function FindBridalGlowRootForTarget(roots, selectedBoonKey)
    if not selectedBoonKey or selectedBoonKey == "" then
        return nil
    end

    for _, root in ipairs(roots) do
        local boon = FindBoonByKey(root.primaryGodKey, selectedBoonKey)
        if boon and boon.IsBridalGlowEligible == true then
            return root
        end
    end
    return nil
end

local function EnsureBridalGlowRootSelection(roots, selectedBoonKey, session)
    local transientRootKey = session.view[BRIDAL_GLOW_ROOT_ALIAS]
    if transientRootKey then
        for _, root in ipairs(roots) do
            if root.id == transientRootKey then
                return root
            end
        end
    end

    local matchedRoot = FindBridalGlowRootForTarget(roots, selectedBoonKey)
    if matchedRoot then
        session.write(BRIDAL_GLOW_ROOT_ALIAS, matchedRoot.id)
        return matchedRoot
    end

    local fallback = roots[1]
    session.write(BRIDAL_GLOW_ROOT_ALIAS, fallback and fallback.id or "")
    return fallback
end

local function GetCurrentBridalGlowTargetText(selectedBoonKey)
    if selectedBoonKey == nil or selectedBoonKey == "" then
        return "Current Target: Random"
    end

    local eligibleRoots = GetBridalGlowEligibleRoots()
    for _, root in ipairs(eligibleRoots) do
        local boon = FindBoonByKey(root.primaryGodKey, selectedBoonKey)
        if boon and boon.IsBridalGlowEligible == true then
            return "Current Target: " .. (boon.BridalGlowLabel or uiData.GetBoonText(boon))
        end
    end

    return "Current Target: Random"
end

local function DrawBridalGlowPanel(ctx)
    local ui = ctx.imgui
    local session = ctx.session
    local selectedBoonKey = session.view.BridalGlowTargetBoon or ""
    local eligibleRoots = GetBridalGlowEligibleRoots(session)

    ctx.widgets.text("Choose the Olympian god and boon pool Bridal Glow can target.")
    ctx.widgets.text(GetCurrentBridalGlowTargetText(selectedBoonKey))
    ctx.widgets.separator()

    if #eligibleRoots == 0 then
        ctx.widgets.text("No eligible Olympian gods are currently available.", {
            color = uiData.MUTED_TEXT_COLOR,
        })
        return
    end

    local selectedRoot = EnsureBridalGlowRootSelection(eligibleRoots, selectedBoonKey, session)
    local selectedRootId = selectedRoot and selectedRoot.id or nil
    local eligibleBoons = GetBridalGlowEligibleBoons(selectedRoot)

    ui.BeginChild("BoonBansBridalGlowGods", 220, 220, true)
    ctx.widgets.text("Eligible Gods", {
        color = uiData.MUTED_TEXT_COLOR,
    })
    ctx.widgets.separator()
    for _, root in ipairs(eligibleRoots) do
        if ui.Selectable(root.label, root.id == selectedRootId) then
            session.write(BRIDAL_GLOW_ROOT_ALIAS, root.id)
            selectedRoot = root
            selectedRootId = root.id
            eligibleBoons = GetBridalGlowEligibleBoons(selectedRoot)
        end
    end
    ui.EndChild()

    ui.SameLine()

    ui.BeginChild("BoonBansBridalGlowBoons", 0, 220, true)
    ctx.widgets.text("Eligible Boons", {
        color = uiData.MUTED_TEXT_COLOR,
    })
    ctx.widgets.separator()
    if ui.Selectable("Random", selectedBoonKey == "") then
        uiActions.SetBridalGlowTargetBoonKey(nil, session)
        selectedBoonKey = ""
    end
    for _, boon in ipairs(eligibleBoons) do
        if ui.Selectable(boon.BridalGlowLabel, boon.Key == selectedBoonKey) then
            uiActions.SetBridalGlowTargetBoonKey(boon.Key, session)
            selectedBoonKey = boon.Key
        end
    end
    ui.EndChild()
end

local function DrawOlympiansTab(ctx)
    local ui = ctx.imgui
    local session = ctx.session
    local visibleRoots, godPoolFiltering = GetVisibleOlympianRoots(session)
    if #visibleRoots == 0 then
        ctx.widgets.text("No Olympians are currently available.", {
            color = uiData.MUTED_TEXT_COLOR,
        })
        return
    end

    local tabs = {}
    for _, root in ipairs(visibleRoots) do
        tabs[#tabs + 1] = {
            key = root.id,
            label = GetNavLabel(root, session),
            color = uiData.GetGodColor(root.primaryGodKey),
        }
    end

    local activeRootId = lib.nav.verticalTabs(ui, {
        id = "BoonBansOlympiansTabs",
        navWidth = uiData.ROOT_NAV_WIDTH,
        tabs = tabs,
        activeKey = session.view[ACTIVE_OLYMPIAN_ROOT_ALIAS],
    })
    if activeRootId ~= session.view[ACTIVE_OLYMPIAN_ROOT_ALIAS] then
        session.write(ACTIVE_OLYMPIAN_ROOT_ALIAS, activeRootId)
    end

    local root = GetActiveRoot(visibleRoots, session)

    ui.BeginChild("BoonBansOlympiansDetail", 0, 0, false)
    if godPoolFiltering then
        ctx.widgets.text(string.format("Showing %d Olympians enabled in God Pool.", #visibleRoots), {
            color = uiData.MUTED_TEXT_COLOR,
        })
        ui.Spacing()
    end

    if ui.BeginTabBar("BoonBansOlympiansViews##" .. root.id) then
        if ui.BeginTabItem("Setup") then
            DrawForcePanel(ctx, root)
            ui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if ui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(ctx, banPool.key, "olympians")
                ui.EndTabItem()
            end
        end
        if ui.BeginTabItem("Rarity") then
            components.DrawRarityPanel(ctx, root)
            ui.EndTabItem()
        end
        if root.hasBridalGlow and ui.BeginTabItem("Bridal Glow Target") then
            DrawBridalGlowPanel(ctx)
            ui.EndTabItem()
        end
        ui.EndTabBar()
    end
    ui.EndChild()
end

local module = {}

function module.bind(deps)
    banConfig = deps.data.banConfig
    uiData = deps.model
    uiActions = deps.actions
    components = deps.components
    return module
end

module.draw = DrawOlympiansTab

return module
