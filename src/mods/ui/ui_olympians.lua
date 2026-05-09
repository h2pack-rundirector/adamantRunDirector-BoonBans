local internal = RunDirectorBoonBans_Internal
local uiData = internal.ui
local ACTIVE_OLYMPIAN_ROOT_ALIAS = "ActiveOlympianRoot"
local BRIDAL_GLOW_ROOT_ALIAS = "BridalGlowRoot"

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
    for _, rootKey in ipairs(OLYMPIAN_ROOT_KEYS) do
        roots[#roots + 1] = uiData.BuildTierRoot(rootKey, {
            session = session,
            hasBridalGlow = rootKey == "Hera",
        })
    end
    return roots
end

local function IsRootCustomized(root, session)
    for _, scope in ipairs(root.scopes) do
        if uiData.IsScopeCustomized(scope.key, session) then
            return true
        end
    end
    return false
end

local function GetVisibleOlympianRoots(session)
    local godPoolFiltering = uiData.IsGodPoolFilteringActive()
    local roots = {}
    for _, root in ipairs(BuildOlympianRoots(session)) do
        if not godPoolFiltering or uiData.IsGodVisibleInGodPool(root.id) then
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

local function DrawForcePanel(ui, session, root)
    lib.widgets.text(ui, "Setup")
    lib.widgets.separator(ui)
    internal.DrawConfiguredTierControl(ui, session, root)
    for _, scope in ipairs(root.scopes) do
        internal.DrawForceBanRow(ui, session, root, scope)
    end
end

local function GetBridalGlowEligibleRoots()
    if uiData.bridalGlowEligibleRoots then
        return uiData.bridalGlowEligibleRoots
    end

    local visibleRoots = GetVisibleOlympianRoots()
    local cached = {}
    for _, root in ipairs(visibleRoots) do
        cached[#cached + 1] = root
    end
    uiData.bridalGlowEligibleRoots = cached
    return cached
end

local function GetBridalGlowEligibleBoons(root)
    if not root then
        return uiData.EMPTY_LIST
    end

    local cached = uiData.bridalGlowBoonsByRoot[root.id]
    if cached then
        return cached
    end

    local boons = {}
    for _, boon in ipairs(uiData.GetScopeBoons(root.primaryScopeKey)) do
        if uiData.IsBridalGlowEligibleBoon(boon) then
            boon.BridalGlowLabel = boon.BridalGlowLabel or uiData.GetBoonText(boon)
            boons[#boons + 1] = boon
        end
    end
    uiData.bridalGlowBoonsByRoot[root.id] = boons
    return boons
end

local function FindBridalGlowRootForTarget(roots, selectedBoonKey)
    if not selectedBoonKey or selectedBoonKey == "" then
        return nil
    end

    for _, root in ipairs(roots) do
        local boon = uiData.FindBoonByKey(root.primaryScopeKey, selectedBoonKey)
        if boon and uiData.IsBridalGlowEligibleBoon(boon) then
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

local function DrawBridalGlowPanel(ui, session)
    local selectedBoonKey = session.view.BridalGlowTargetBoon or ""
    local eligibleRoots = GetBridalGlowEligibleRoots()

    lib.widgets.text(ui, "Choose the Olympian god and boon pool Bridal Glow can target.")
    lib.widgets.text(ui, uiData.GetCurrentBridalGlowTargetText(session))
    lib.widgets.separator(ui)

    if #eligibleRoots == 0 then
        lib.widgets.text(ui, "No eligible Olympian gods are currently available.", {
            color = uiData.MUTED_TEXT_COLOR,
        })
        return
    end

    local selectedRoot = EnsureBridalGlowRootSelection(eligibleRoots, selectedBoonKey, session)
    local selectedRootId = selectedRoot and selectedRoot.id or nil
    local eligibleBoons = GetBridalGlowEligibleBoons(selectedRoot)

    ui.BeginChild("BoonBansBridalGlowGods", 220, 220, true)
    lib.widgets.text(ui, "Eligible Gods", {
        color = uiData.MUTED_TEXT_COLOR,
    })
    lib.widgets.separator(ui)
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
    lib.widgets.text(ui, "Eligible Boons", {
        color = uiData.MUTED_TEXT_COLOR,
    })
    lib.widgets.separator(ui)
    if ui.Selectable("Random", selectedBoonKey == "") then
        internal.SetBridalGlowTargetBoonKey(nil, session)
        selectedBoonKey = ""
    end
    for _, boon in ipairs(eligibleBoons) do
        if ui.Selectable(boon.BridalGlowLabel, boon.Key == selectedBoonKey) then
            internal.SetBridalGlowTargetBoonKey(boon.Key, session)
            selectedBoonKey = boon.Key
        end
    end
    ui.EndChild()
end

function internal.DrawOlympiansTab(ui, session)
    local visibleRoots, godPoolFiltering = GetVisibleOlympianRoots(session)
    if #visibleRoots == 0 then
        lib.widgets.text(ui, "No Olympians are currently available.", {
            color = uiData.MUTED_TEXT_COLOR,
        })
        return
    end

    local tabs = {}
    for _, root in ipairs(visibleRoots) do
        tabs[#tabs + 1] = {
            key = root.id,
            label = GetNavLabel(root, session),
            color = uiData.GetSourceColor(root.primaryScopeKey),
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
        lib.widgets.text(ui, string.format("Showing %d Olympians enabled in God Pool.", #visibleRoots), {
            color = uiData.MUTED_TEXT_COLOR,
        })
        ui.Spacing()
    end

    if ui.BeginTabBar("BoonBansOlympiansViews##" .. root.id) then
        if ui.BeginTabItem("Setup") then
            DrawForcePanel(ui, session, root)
            ui.EndTabItem()
        end
        for _, scope in ipairs(root.scopes) do
            if ui.BeginTabItem(scope.label) then
                internal.DrawBanPanel(ui, session, scope.key, "olympians")
                ui.EndTabItem()
            end
        end
        if ui.BeginTabItem("Rarity") then
            internal.DrawRarityPanel(ui, session, root)
            ui.EndTabItem()
        end
        if root.hasBridalGlow and ui.BeginTabItem("Bridal Glow Target") then
            DrawBridalGlowPanel(ui, session)
            ui.EndTabItem()
        end
        ui.EndTabBar()
    end
    ui.EndChild()
end
