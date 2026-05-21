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

local function BuildOlympianRoots(data)
    local roots = {}
    for _, godKey in ipairs(OLYMPIAN_ROOT_KEYS) do
        roots[#roots + 1] = uiData.BuildBanPoolRoot(godKey, {
            data = data,
            hasBridalGlow = godKey == "Hera",
        })
    end
    return roots
end

local function IsRootCustomized(root, data)
    for _, banPool in ipairs(root.banPools) do
        if banConfig.IsBanPoolCustomized(banPool.key, data) then
            return true
        end
    end
    return false
end

local function IsGodPoolFilteringActive(services)
    return services.invokeIntegration(GOD_AVAILABILITY_INTEGRATION, "isActive", false) == true
end

local function IsGodVisibleInGodPool(services, godKey)
    local resolvedGodKey = banConfig.ResolveGodKey(godKey)
    return services.invokeIntegration(GOD_AVAILABILITY_INTEGRATION, "isAvailable", true, resolvedGodKey) ~= false
end

local function GetVisibleOlympianRoots(services, data)
    local godPoolFiltering = IsGodPoolFilteringActive(services)
    local roots = {}
    for _, root in ipairs(BuildOlympianRoots(data)) do
        if not godPoolFiltering or IsGodVisibleInGodPool(services, root.id) then
            roots[#roots + 1] = root
        end
    end
    return roots, godPoolFiltering
end

local function GetNavLabel(root, data)
    local label = root.label
    if IsRootCustomized(root, data) then
        label = label .. " *"
    end
    return label
end

local function GetActiveRoot(visibleRoots, data)
    local activeRootId = data.get(ACTIVE_OLYMPIAN_ROOT_ALIAS):read()
    for _, root in ipairs(visibleRoots) do
        if root.id == activeRootId then
            return root
        end
    end
    return visibleRoots[1]
end

local function DrawForcePanel(draw, data, root)
    draw.widgets.text("Setup")
    draw.widgets.separator()
    components.DrawConfiguredBanPoolControl(draw, data, root)
    for _, banPool in ipairs(root.banPools) do
        components.DrawForceBanRow(draw, data, root, banPool)
    end
end

local function GetBridalGlowEligibleRoots(services, data)
    if bridalGlowEligibleRoots then
        return bridalGlowEligibleRoots
    end

    local visibleRoots = GetVisibleOlympianRoots(services, data)
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

local function EnsureBridalGlowRootSelection(roots, selectedBoonKey, data)
    local rootField = data.get(BRIDAL_GLOW_ROOT_ALIAS)
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

local function GetCurrentBridalGlowTargetText(services, data, selectedBoonKey)
    if selectedBoonKey == nil or selectedBoonKey == "" then
        return "Current Target: Random"
    end

    local eligibleRoots = GetBridalGlowEligibleRoots(services, data)
    for _, root in ipairs(eligibleRoots) do
        local boon = FindBoonByKey(root.primaryGodKey, selectedBoonKey)
        if boon and boon.IsBridalGlowEligible == true then
            return "Current Target: " .. (boon.BridalGlowLabel or uiData.GetBoonText(boon))
        end
    end

    return "Current Target: Random"
end

local function DrawBridalGlowPanel(draw, data, services)
    local imgui = draw.imgui
    local targetField = data.get("BridalGlowTargetBoon")
    local rootField = data.get(BRIDAL_GLOW_ROOT_ALIAS)
    local selectedBoonKey = targetField:read() or ""
    local eligibleRoots = GetBridalGlowEligibleRoots(services, data)

    draw.widgets.text("Choose the Olympian god and boon pool Bridal Glow can target.")
    draw.widgets.text(GetCurrentBridalGlowTargetText(services, data, selectedBoonKey))
    draw.widgets.separator()

    if #eligibleRoots == 0 then
        draw.widgets.text("No eligible Olympian gods are currently available.", {
            color = uiData.MUTED_TEXT_COLOR,
        })
        return
    end

    local selectedRoot = EnsureBridalGlowRootSelection(eligibleRoots, selectedBoonKey, data)
    local selectedRootId = selectedRoot and selectedRoot.id or nil
    local eligibleBoons = GetBridalGlowEligibleBoons(selectedRoot)

    imgui.BeginChild("BoonBansBridalGlowGods", 220, 220, true)
    draw.widgets.text("Eligible Gods", {
        color = uiData.MUTED_TEXT_COLOR,
    })
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
    draw.widgets.text("Eligible Boons", {
        color = uiData.MUTED_TEXT_COLOR,
    })
    draw.widgets.separator()
    if imgui.Selectable("Random", selectedBoonKey == "") then
        uiActions.SetBridalGlowTargetBoonKey(nil, data)
        selectedBoonKey = ""
    end
    for _, boon in ipairs(eligibleBoons) do
        if imgui.Selectable(boon.BridalGlowLabel, boon.Key == selectedBoonKey) then
            uiActions.SetBridalGlowTargetBoonKey(boon.Key, data)
            selectedBoonKey = boon.Key
        end
    end
    imgui.EndChild()
end

local function DrawOlympiansTab(draw, data, services)
    local imgui = draw.imgui
    local activeRootField = data.get(ACTIVE_OLYMPIAN_ROOT_ALIAS)
    local visibleRoots, godPoolFiltering = GetVisibleOlympianRoots(services, data)
    if #visibleRoots == 0 then
        draw.widgets.text("No Olympians are currently available.", {
            color = uiData.MUTED_TEXT_COLOR,
        })
        return
    end

    local tabs = {}
    for _, root in ipairs(visibleRoots) do
        tabs[#tabs + 1] = {
            key = root.id,
            label = GetNavLabel(root, data),
            color = uiData.GetGodColor(root.primaryGodKey),
        }
    end

    local activeRootId = draw.nav.verticalTabs({
        id = "BoonBansOlympiansTabs",
        navWidth = uiData.ROOT_NAV_WIDTH,
        tabs = tabs,
        activeKey = activeRootField:read(),
    })
    if activeRootId ~= activeRootField:read() then
        activeRootField:write(activeRootId)
    end

    local root = GetActiveRoot(visibleRoots, data)

    imgui.BeginChild("BoonBansOlympiansDetail", 0, 0, false)
    if godPoolFiltering then
        draw.widgets.text(string.format("Showing %d Olympians enabled in God Pool.", #visibleRoots), {
            color = uiData.MUTED_TEXT_COLOR,
        })
        imgui.Spacing()
    end

    if imgui.BeginTabBar("BoonBansOlympiansViews##" .. root.id) then
        if imgui.BeginTabItem("Setup") then
            DrawForcePanel(draw, data, root)
            imgui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if imgui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(draw, data, services, banPool.key, "olympians")
                imgui.EndTabItem()
            end
        end
        if imgui.BeginTabItem("Rarity") then
            components.DrawRarityPanel(draw, data, root)
            imgui.EndTabItem()
        end
        if root.hasBridalGlow and imgui.BeginTabItem("Bridal Glow Target") then
            DrawBridalGlowPanel(draw, data, services)
            imgui.EndTabItem()
        end
        imgui.EndTabBar()
    end
    imgui.EndChild()
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
