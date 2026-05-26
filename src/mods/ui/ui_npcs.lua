local uiData, components = nil, nil
local banConfig = nil
local ACTIVE_NPC_ROOT_ALIAS = "ActiveNpcRoot"
local mutedTextOpts = nil
local npcRegionRadioOpts = nil
local NPC_NAV_OPTS = {
    id = "BoonBansNpcsTabs",
}
local npcTabs = {}

local NPC_ROOTS = {
    { id = "Arachne", label = "Arachne", group = "Underworld", hasRarity = false },
    { id = "Narcissus", label = "Narcissus", group = "Underworld", hasRarity = false },
    { id = "Echo", label = "Echo", group = "Underworld", hasRarity = false },
    { id = "Hades", label = "Hades", group = "Underworld", hasRarity = false },
    { id = "Medea", label = "Medea", group = "Surface", hasRarity = false },
    { id = "Circe", label = "Circe", group = "Surface", hasRarity = false },
    { id = "Icarus", label = "Icarus", group = "Surface", hasRarity = false },
    { id = "Dionysus", label = "Dionysus", group = "Surface", hasRarity = true },
    { id = "CirceBNB", label = "Black Night Banishment", group = "Surface", hasRarity = false },
    { id = "CirceCRD", label = "Red Citrine Divination", group = "Surface", hasRarity = false },
    { id = "HadesKeepsake", label = "Jeweled Pom", group = "Keepsakes", hasRarity = false },
}

local function IsRegionMatch(group, regionValue)
    if regionValue == 4 then return true end
    if group == "Underworld" then
        return regionValue == 2
    end
    if group == "Surface" then
        return regionValue == 3
    end
    return true
end

local function IsRootCustomized(root, state)
    return banConfig.IsBanPoolCustomized(root.primaryGodKey, state)
end

local function GetVisibleNpcRoots(state)
    local regionValue = state and state.get(uiData.NPC_VIEW_REGION_ALIAS):read() or 4
    local roots = {}
    for _, spec in ipairs(NPC_ROOTS) do
        if IsRegionMatch(spec.group, regionValue) then
            roots[#roots + 1] = uiData.BuildBanPoolRoot(spec.id, {
                state = state,
                label = spec.label,
                group = spec.group,
                hasRarity = spec.hasRarity,
            })
        end
    end
    return roots
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

local function DrawRegionFilter(draw, state)
    local imgui = draw.imgui

    imgui.AlignTextToFramePadding()
    imgui.Text("Filter NPC Sources:")
    imgui.SameLine()
    draw.widgets.radio(state.get(uiData.NPC_VIEW_REGION_ALIAS), npcRegionRadioOpts)
end

local function SetNpcTab(index, root, state)
    local tab = npcTabs[index]
    if not tab then
        tab = {}
        npcTabs[index] = tab
    end

    tab.key = root.id
    tab.label = GetNavLabel(root, state)
    tab.color = uiData.GetGodColor(root.primaryGodKey)
    tab.group = root.group
end

local function TrimNpcTabs(tabCount)
    for index = tabCount + 1, #npcTabs do
        npcTabs[index] = nil
    end
end

local function DrawNpcsTab(draw, state, actions)
    local imgui = draw.imgui
    local activeRootField = state.get(ACTIVE_NPC_ROOT_ALIAS)

    DrawRegionFilter(draw, state)
    imgui.Spacing()

    local visibleRoots = GetVisibleNpcRoots(state)
    if #visibleRoots == 0 then
        draw.widgets.text("No NPC sources match the current filter.", mutedTextOpts)
        return
    end

    local tabCount = 0
    for _, root in ipairs(visibleRoots) do
        tabCount = tabCount + 1
        SetNpcTab(tabCount, root, state)
    end
    TrimNpcTabs(tabCount)

    local root, activeRootId = NormalizeActiveRoot(visibleRoots, activeRootField)

    NPC_NAV_OPTS.navWidth = uiData.ROOT_NAV_WIDTH
    NPC_NAV_OPTS.tabs = npcTabs
    NPC_NAV_OPTS.activeKey = activeRootId
    local selectedRootId = draw.nav.verticalTabs(NPC_NAV_OPTS)
    if selectedRootId ~= activeRootId then
        activeRootField:write(selectedRootId)
        root = GetActiveRoot(visibleRoots, selectedRootId)
    end

    imgui.BeginChild("BoonBansNpcsDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansNpcsViews##" .. root.id) then
        if imgui.BeginTabItem("Bans") then
            components.DrawBanPanel(draw, state, actions, root.primaryGodKey, "npcs")
            imgui.EndTabItem()
        end
        if root.hasRarity and imgui.BeginTabItem("Rarity") then
            components.DrawRarityPanel(draw, state, root)
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
    components = deps.components
    npcTabs = {}
    mutedTextOpts = {
        color = uiData.MUTED_TEXT_COLOR,
    }
    local displayValues = {}
    local values = {}
    for _, option in ipairs(uiData.NPC_REGION_OPTIONS) do
        values[#values + 1] = option.value
        displayValues[option.value] = option.label
    end
    npcRegionRadioOpts = {
        label = "",
        values = values,
        displayValues = displayValues,
        optionGap = 20,
    }
    return module
end

module.draw = DrawNpcsTab

return module
