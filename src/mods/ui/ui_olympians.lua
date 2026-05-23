local uiData, uiActions, components = nil, nil, nil
local banConfig = nil
local godAvailability = nil
local ACTIVE_OLYMPIAN_ROOT_ALIAS = "ActiveOlympianRoot"
local BRIDAL_GLOW_ROOT_ALIAS = "BridalGlowRoot"
local EMPTY_LIST = {}
local bridalGlowBoonsByRoot = {}
local mutedTextOpts = nil
local OLYMPIAN_NAV_OPTS = {
    id = "BoonBansOlympiansTabs",
}
local olympianTabs = {}

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

local function BuildOlympianRoots(state)
    local roots = {}
    for _, godKey in ipairs(OLYMPIAN_ROOT_KEYS) do
        roots[#roots + 1] = uiData.BuildBanPoolRoot(godKey, {
            state = state,
            hasBridalGlow = godKey == "Hera",
        })
    end
    return roots
end

local function IsRootCustomized(root, state)
    for _, banPool in ipairs(root.banPools) do
        if banConfig.IsBanPoolCustomized(banPool.key, state) then
            return true
        end
    end
    return false
end

local function IsGodPoolFilteringActive(services)
    return godAvailability and godAvailability.isActive(services) == true
end

local function IsGodVisibleInGodPool(services, godKey)
    local resolvedGodKey = banConfig.ResolveGodKey(godKey)
    return not godAvailability or godAvailability.isAvailable(services, resolvedGodKey) ~= false
end

local function GetVisibleOlympianRoots(services, state)
    local godPoolFiltering = IsGodPoolFilteringActive(services)
    local roots = {}
    for _, root in ipairs(BuildOlympianRoots(state)) do
        if not godPoolFiltering or IsGodVisibleInGodPool(services, root.id) then
            roots[#roots + 1] = root
        end
    end
    return roots, godPoolFiltering
end

local function GetNavLabel(root, state)
    local label = root.label
    if IsRootCustomized(root, state) then
        label = label .. " *"
    end
    return label
end

local function FindRootById(visibleRoots, rootId)
    for _, root in ipairs(visibleRoots) do
        if root.id == rootId then
            return root
        end
    end
end

local function NormalizeActiveRoot(visibleRoots, activeRootField)
    local activeRootId = activeRootField:read()
    local root = FindRootById(visibleRoots, activeRootId)
    if root then
        return root, activeRootId
    end

    root = visibleRoots[1]
    activeRootId = root.id
    activeRootField:write(activeRootId)
    return root, activeRootId
end

local function GetActiveRoot(visibleRoots, activeRootId)
    local root = FindRootById(visibleRoots, activeRootId)
    if root then
        return root
    end
    return visibleRoots[1]
end

local function DrawForcePanel(draw, state, root)
    draw.widgets.text("Setup")
    draw.widgets.separator()
    components.DrawConfiguredBanPoolControl(draw, state, root)
    for _, banPool in ipairs(root.banPools) do
        components.DrawForceBanRow(draw, state, root, banPool)
    end
end

local function GetBridalGlowEligibleRoots(services, state)
    return GetVisibleOlympianRoots(services, state)
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

local function EnsureBridalGlowRootSelection(roots, selectedBoonKey, state)
    local rootField = state.get(BRIDAL_GLOW_ROOT_ALIAS)
    local transientRootKey = rootField:read()
    if transientRootKey then
        for _, root in ipairs(roots) do
            if root.id == transientRootKey then
                return root
            end
        end
    end

    local matchedRoot = FindBridalGlowRootForTarget(roots, selectedBoonKey)
    if matchedRoot then
        rootField:write(matchedRoot.id)
        return matchedRoot
    end

    local fallback = roots[1]
    rootField:write(fallback and fallback.id or "")
    return fallback
end

local function GetCurrentBridalGlowTargetText(eligibleRoots, selectedBoonKey)
    if selectedBoonKey == nil or selectedBoonKey == "" then
        return "Current Target: Random"
    end

    for _, root in ipairs(eligibleRoots) do
        local boon = FindBoonByKey(root.primaryGodKey, selectedBoonKey)
        if boon and boon.IsBridalGlowEligible == true then
            return "Current Target: " .. (boon.BridalGlowLabel or uiData.GetBoonText(boon))
        end
    end

    return "Current Target: Random"
end

local function DrawBridalGlowPanel(draw, state, services)
    local imgui = draw.imgui
    local targetField = state.get("BridalGlowTargetBoon")
    local rootField = state.get(BRIDAL_GLOW_ROOT_ALIAS)
    local selectedBoonKey = targetField:read() or ""
    local eligibleRoots = GetBridalGlowEligibleRoots(services, state)

    draw.widgets.text("Choose the Olympian god and boon pool Bridal Glow can target.")
    draw.widgets.text(GetCurrentBridalGlowTargetText(eligibleRoots, selectedBoonKey))
    draw.widgets.separator()

    if #eligibleRoots == 0 then
        draw.widgets.text("No eligible Olympian gods are currently available.", mutedTextOpts)
        return
    end

    local selectedRoot = EnsureBridalGlowRootSelection(eligibleRoots, selectedBoonKey, state)
    local selectedRootId = selectedRoot and selectedRoot.id or nil
    local eligibleBoons = GetBridalGlowEligibleBoons(selectedRoot)

    imgui.BeginChild("BoonBansBridalGlowGods", 220, 220, true)
    draw.widgets.text("Eligible Gods", mutedTextOpts)
    draw.widgets.separator()
    for _, root in ipairs(eligibleRoots) do
        if imgui.Selectable(root.label, root.id == selectedRootId) then
            rootField:write(root.id)
            selectedRoot = root
            selectedRootId = root.id
            eligibleBoons = GetBridalGlowEligibleBoons(selectedRoot)
        end
    end
    imgui.EndChild()

    imgui.SameLine()

    imgui.BeginChild("BoonBansBridalGlowBoons", 0, 220, true)
    draw.widgets.text("Eligible Boons", mutedTextOpts)
    draw.widgets.separator()
    if imgui.Selectable("Random", selectedBoonKey == "") then
        uiActions.SetBridalGlowTargetBoonKey(nil, state)
        selectedBoonKey = ""
    end
    for _, boon in ipairs(eligibleBoons) do
        if imgui.Selectable(boon.BridalGlowLabel, boon.Key == selectedBoonKey) then
            uiActions.SetBridalGlowTargetBoonKey(boon.Key, state)
            selectedBoonKey = boon.Key
        end
    end
    imgui.EndChild()
end

local function SetOlympianTab(index, root, state)
    local tab = olympianTabs[index]
    if not tab then
        tab = {}
        olympianTabs[index] = tab
    end

    tab.key = root.id
    tab.label = GetNavLabel(root, state)
    tab.color = uiData.GetGodColor(root.primaryGodKey)
end

local function TrimOlympianTabs(tabCount)
    for index = tabCount + 1, #olympianTabs do
        olympianTabs[index] = nil
    end
end

local function DrawOlympiansTab(draw, state, services)
    local imgui = draw.imgui
    local activeRootField = state.get(ACTIVE_OLYMPIAN_ROOT_ALIAS)
    local visibleRoots, godPoolFiltering = GetVisibleOlympianRoots(services, state)
    if #visibleRoots == 0 then
        draw.widgets.text("No Olympians are currently available.", mutedTextOpts)
        return
    end

    local tabCount = 0
    for _, root in ipairs(visibleRoots) do
        tabCount = tabCount + 1
        SetOlympianTab(tabCount, root, state)
    end
    TrimOlympianTabs(tabCount)

    local root, activeRootId = NormalizeActiveRoot(visibleRoots, activeRootField)

    OLYMPIAN_NAV_OPTS.navWidth = uiData.ROOT_NAV_WIDTH
    OLYMPIAN_NAV_OPTS.tabs = olympianTabs
    OLYMPIAN_NAV_OPTS.activeKey = activeRootId
    local selectedRootId = draw.nav.verticalTabs(OLYMPIAN_NAV_OPTS)
    if selectedRootId ~= activeRootId then
        activeRootField:write(selectedRootId)
        root = GetActiveRoot(visibleRoots, selectedRootId)
    end

    imgui.BeginChild("BoonBansOlympiansDetail", 0, 0, false)
    if godPoolFiltering then
        draw.widgets.text(string.format("Showing %d Olympians enabled in God Pool.", #visibleRoots), mutedTextOpts)
        imgui.Spacing()
    end

    if imgui.BeginTabBar("BoonBansOlympiansViews##" .. root.id) then
        if imgui.BeginTabItem("Setup") then
            DrawForcePanel(draw, state, root)
            imgui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if imgui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(draw, state, services, banPool.key, "olympians")
                imgui.EndTabItem()
            end
        end
        if imgui.BeginTabItem("Rarity") then
            components.DrawRarityPanel(draw, state, root)
            imgui.EndTabItem()
        end
        if root.hasBridalGlow and imgui.BeginTabItem("Bridal Glow Target") then
            DrawBridalGlowPanel(draw, state, services)
            imgui.EndTabItem()
        end
        imgui.EndTabBar()
    end
    imgui.EndChild()
end

local module = {}

function module.bind(deps)
    banConfig = deps.state.banConfig
    uiData = deps.model
    uiActions = deps.actions
    components = deps.components
    godAvailability = deps.godAvailability
    mutedTextOpts = {
        color = uiData.MUTED_TEXT_COLOR,
    }
    olympianTabs = {}
    bridalGlowBoonsByRoot = {}
    return module
end

module.draw = DrawOlympiansTab

return module
