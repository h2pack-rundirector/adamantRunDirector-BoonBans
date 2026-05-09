local internal = RunDirectorBoonBans_Internal
local uiData = internal.ui
local ACTIVE_NPC_ROOT_ALIAS = "ActiveNpcRoot"

local NPC_ROOTS = {
    { id = "Arachne", label = "Arachne", group = "Underworld", primaryScopeKey = "Arachne", hasRarity = false },
    { id = "Narcissus", label = "Narcissus", group = "Underworld", primaryScopeKey = "Narcissus", hasRarity = false },
    { id = "Echo", label = "Echo", group = "Underworld", primaryScopeKey = "Echo", hasRarity = false },
    { id = "Hades", label = "Hades", group = "Underworld", primaryScopeKey = "Hades", hasRarity = false },
    { id = "Medea", label = "Medea", group = "Surface", primaryScopeKey = "Medea", hasRarity = false },
    { id = "Circe", label = "Circe", group = "Surface", primaryScopeKey = "Circe", hasRarity = false },
    { id = "Icarus", label = "Icarus", group = "Surface", primaryScopeKey = "Icarus", hasRarity = false },
    { id = "Dionysus", label = "Dionysus", group = "Surface", primaryScopeKey = "Dionysus", hasRarity = true },
    { id = "CirceBNB", label = "Black Night Banishment", group = "Surface", primaryScopeKey = "CirceBNB", hasRarity = false },
    { id = "CirceCRD", label = "Red Citrine Divination", group = "Surface", primaryScopeKey = "CirceCRD", hasRarity = false },
    { id = "HadesKeepsake", label = "Jeweled Pom", group = "Keepsakes", primaryScopeKey = "HadesKeepsake", hasRarity = false },
}

for _, root in ipairs(NPC_ROOTS) do
    root.scopes = {
        { key = root.primaryScopeKey, label = "Bans" },
    }
end

local function IsRootCustomized(root, session)
    return uiData.IsScopeCustomized(root.primaryScopeKey, session)
end

local function GetVisibleNpcRoots(session)
    local regionValue = session and session.view and session.view[uiData.NPC_VIEW_REGION_ALIAS] or 4
    local roots = {}
    for _, root in ipairs(NPC_ROOTS) do
        if uiData.IsRegionMatch(root.group, regionValue) then
            roots[#roots + 1] = root
        end
    end
    return roots
end

local function GetNavLabel(root, session)
    local label = root.label
    if IsRootCustomized(root, session) then
        label = label .. " *"
    end
    return label
end

local function GetActiveRoot(visibleRoots, session)
    local activeRootId = session.view[ACTIVE_NPC_ROOT_ALIAS]
    for _, root in ipairs(visibleRoots) do
        if root.id == activeRootId then
            return root
        end
    end
    return visibleRoots[1]
end

local function DrawRegionFilter(ui, session)
    local displayValues = {}
    local values = {}
    for _, option in ipairs(uiData.NPC_REGION_OPTIONS) do
        values[#values + 1] = option.value
        displayValues[option.value] = option.label
    end

    ui.AlignTextToFramePadding()
    ui.Text("Filter NPC Sources:")
    ui.SameLine()
    lib.widgets.radio(ui, session, uiData.NPC_VIEW_REGION_ALIAS, {
        label = "",
        values = values,
        displayValues = displayValues,
        optionGap = 20,
    })
end

function internal.DrawNpcsTab(ui, session)
    DrawRegionFilter(ui, session)
    ui.Spacing()

    local visibleRoots = GetVisibleNpcRoots(session)
    if #visibleRoots == 0 then
        lib.widgets.text(ui, "No NPC sources match the current filter.", {
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
            group = root.group,
        }
    end

    local activeRootId = lib.nav.verticalTabs(ui, {
        id = "BoonBansNpcsTabs",
        navWidth = uiData.ROOT_NAV_WIDTH,
        tabs = tabs,
        activeKey = session.view[ACTIVE_NPC_ROOT_ALIAS],
    })
    if activeRootId ~= session.view[ACTIVE_NPC_ROOT_ALIAS] then
        session.write(ACTIVE_NPC_ROOT_ALIAS, activeRootId)
    end

    local root = GetActiveRoot(visibleRoots, session)

    ui.BeginChild("BoonBansNpcsDetail", 0, 0, false)
    if ui.BeginTabBar("BoonBansNpcsViews##" .. root.id) then
        if ui.BeginTabItem("Bans") then
            internal.DrawBanPanel(ui, session, root.primaryScopeKey, "npcs")
            ui.EndTabItem()
        end
        if root.hasRarity and ui.BeginTabItem("Rarity") then
            internal.DrawRarityPanel(ui, session, root)
            ui.EndTabItem()
        end
        ui.EndTabBar()
    end
    ui.EndChild()
end
