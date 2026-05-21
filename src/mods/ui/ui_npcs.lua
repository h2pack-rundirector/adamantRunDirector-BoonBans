local uiData, components = nil, nil
local banConfig = nil
local ACTIVE_NPC_ROOT_ALIAS = "ActiveNpcRoot"

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

local function IsRootCustomized(root, data)
    return banConfig.IsBanPoolCustomized(root.primaryGodKey, data)
end

local function GetVisibleNpcRoots(data)
    local regionValue = data and data.get(uiData.NPC_VIEW_REGION_ALIAS):read() or 4
    local roots = {}
    for _, spec in ipairs(NPC_ROOTS) do
        if IsRegionMatch(spec.group, regionValue) then
            roots[#roots + 1] = uiData.BuildBanPoolRoot(spec.id, {
                data = data,
                label = spec.label,
                group = spec.group,
                hasRarity = spec.hasRarity,
            })
        end
    end
    return roots
end

local function GetNavLabel(root, data)
    local label = root.label
    if IsRootCustomized(root, data) then
        label = label .. " *"
    end
    return label
end

local function GetActiveRoot(visibleRoots, data)
    local activeRootId = data.get(ACTIVE_NPC_ROOT_ALIAS):read()
    for _, root in ipairs(visibleRoots) do
        if root.id == activeRootId then
            return root
        end
    end
    return visibleRoots[1]
end

local function DrawRegionFilter(draw, data)
    local imgui = draw.imgui
    local displayValues = {}
    local values = {}
    for _, option in ipairs(uiData.NPC_REGION_OPTIONS) do
        values[#values + 1] = option.value
        displayValues[option.value] = option.label
    end

    imgui.AlignTextToFramePadding()
    imgui.Text("Filter NPC Sources:")
    imgui.SameLine()
    draw.widgets.radio(data.get(uiData.NPC_VIEW_REGION_ALIAS), {
        label = "",
        values = values,
        displayValues = displayValues,
        optionGap = 20,
    })
end

local function DrawNpcsTab(draw, data, services)
    local imgui = draw.imgui
    local activeRootField = data.get(ACTIVE_NPC_ROOT_ALIAS)

    DrawRegionFilter(draw, data)
    imgui.Spacing()

    local visibleRoots = GetVisibleNpcRoots(data)
    if #visibleRoots == 0 then
        draw.widgets.text("No NPC sources match the current filter.", {
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
            group = root.group,
        }
    end

    local activeRootId = draw.nav.verticalTabs({
        id = "BoonBansNpcsTabs",
        navWidth = uiData.ROOT_NAV_WIDTH,
        tabs = tabs,
        activeKey = activeRootField:read(),
    })
    if activeRootId ~= activeRootField:read() then
        activeRootField:write(activeRootId)
    end

    local root = GetActiveRoot(visibleRoots, data)

    imgui.BeginChild("BoonBansNpcsDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansNpcsViews##" .. root.id) then
        if imgui.BeginTabItem("Bans") then
            components.DrawBanPanel(draw, data, services, root.primaryGodKey, "npcs")
            imgui.EndTabItem()
        end
        if root.hasRarity and imgui.BeginTabItem("Rarity") then
            components.DrawRarityPanel(draw, data, root)
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
    components = deps.components
    return module
end

module.draw = DrawNpcsTab

return module
