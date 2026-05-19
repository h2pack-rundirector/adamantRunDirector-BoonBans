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

local function IsRootCustomized(root, session)
    return banConfig.IsBanPoolCustomized(root.primaryGodKey, session)
end

local function GetVisibleNpcRoots(session)
    local regionValue = session and session.view and session.view[uiData.NPC_VIEW_REGION_ALIAS] or 4
    local roots = {}
    for _, spec in ipairs(NPC_ROOTS) do
        if IsRegionMatch(spec.group, regionValue) then
            roots[#roots + 1] = uiData.BuildBanPoolRoot(spec.id, {
                session = session,
                label = spec.label,
                group = spec.group,
                hasRarity = spec.hasRarity,
            })
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

local function DrawRegionFilter(ctx)
    local ui = ctx.imgui
    local displayValues = {}
    local values = {}
    for _, option in ipairs(uiData.NPC_REGION_OPTIONS) do
        values[#values + 1] = option.value
        displayValues[option.value] = option.label
    end

    ui.AlignTextToFramePadding()
    ui.Text("Filter NPC Sources:")
    ui.SameLine()
    ctx.widgets.radio(uiData.NPC_VIEW_REGION_ALIAS, {
        label = "",
        values = values,
        displayValues = displayValues,
        optionGap = 20,
    })
end

local function DrawNpcsTab(ctx)
    local ui = ctx.imgui
    local session = ctx.session

    DrawRegionFilter(ctx)
    ui.Spacing()

    local visibleRoots = GetVisibleNpcRoots(session)
    if #visibleRoots == 0 then
        ctx.widgets.text("No NPC sources match the current filter.", {
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
            components.DrawBanPanel(ctx, root.primaryGodKey, "npcs")
            ui.EndTabItem()
        end
        if root.hasRarity and ui.BeginTabItem("Rarity") then
            components.DrawRarityPanel(ctx, root)
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
    components = deps.components
    return module
end

module.draw = DrawNpcsTab

return module
