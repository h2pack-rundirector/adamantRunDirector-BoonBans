local uiData, components = nil, nil
local banConfig = nil
local ACTIVE_HAMMER_ROOT_ALIAS = "ActiveHammerRoot"

local HAMMER_FORCE_ROW_OPTS = {
    controlWidth = 200,
    drawRarity = false,
}

local HAMMER_NAV_OPTS = {
    id = "BoonBansHammersTabs",
}
local hammerTabs = {}

local HAMMER_ROOT_KEYS = {
    "Staff",
    "Dagger",
    "Axe",
    "Torch",
    "Lob",
    "Suit",
}

local function BuildHammerRoots(state)
    local roots = {}
    for _, godKey in ipairs(HAMMER_ROOT_KEYS) do
        roots[#roots + 1] = uiData.BuildBanPoolRoot(godKey, {
            state = state,
            hasRarity = false,
        })
    end
    return roots
end

local function IsHammerCustomized(root, state)
    for _, banPool in ipairs(root.banPools) do
        if banConfig.IsBanPoolCustomized(banPool.key, state) then
            return true
        end
    end
    return false
end

local function IsHammerEquipped(root)
    local equippedWeapon = GetEquippedWeapon and (GetEquippedWeapon() or "") or ""
    return equippedWeapon ~= "" and equippedWeapon:find(root.id, 1, true) ~= nil
end

local function GetHammerNavLabel(root, state)
    local label = root.label
    if IsHammerEquipped(root) then
        label = "» " .. label .. " «"
    end
    if IsHammerCustomized(root, state) then
        label = label .. " *"
    end
    return label
end

local function GetActiveHammerRoot(state)
    local activeRootId = state.get(ACTIVE_HAMMER_ROOT_ALIAS):read()
    for _, root in ipairs(BuildHammerRoots(state)) do
        if root.id == activeRootId then
            return root
        end
    end
    return uiData.BuildBanPoolRoot(HAMMER_ROOT_KEYS[1], { state = state, hasRarity = false })
end

local function DrawHammerForcePanel(draw, state, root)
    draw.widgets.text("Setup")
    draw.widgets.separator()
    components.DrawConfiguredBanPoolControl(draw, state, root)
    for _, banPool in ipairs(root.banPools) do
        components.DrawForceBanRow(draw, state, root, banPool, HAMMER_FORCE_ROW_OPTS)
    end
end

local function SetHammerTab(index, root, state)
    local tab = hammerTabs[index]
    if not tab then
        tab = {}
        hammerTabs[index] = tab
    end

    tab.key = root.id
    tab.label = GetHammerNavLabel(root, state)
    tab.color = uiData.GetGodColor(root.primaryGodKey)
end

local function TrimHammerTabs(tabCount)
    for index = tabCount + 1, #hammerTabs do
        hammerTabs[index] = nil
    end
end

local function DrawHammersTab(draw, state, services)
    local imgui = draw.imgui
    local activeRootField = state.get(ACTIVE_HAMMER_ROOT_ALIAS)
    local tabCount = 0
    for _, root in ipairs(BuildHammerRoots(state)) do
        tabCount = tabCount + 1
        SetHammerTab(tabCount, root, state)
    end
    TrimHammerTabs(tabCount)

    HAMMER_NAV_OPTS.navWidth = uiData.ROOT_NAV_WIDTH
    HAMMER_NAV_OPTS.tabs = hammerTabs
    HAMMER_NAV_OPTS.activeKey = activeRootField:read()
    local activeRootId = draw.nav.verticalTabs(HAMMER_NAV_OPTS)
    if activeRootId ~= activeRootField:read() then
        activeRootField:write(activeRootId)
    end

    local root = GetActiveHammerRoot(state)

    imgui.BeginChild("BoonBansHammersDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansHammersViews##" .. root.id) then
        if imgui.BeginTabItem("Setup") then
            DrawHammerForcePanel(draw, state, root)
            imgui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if imgui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(draw, state, services, banPool.key, "hammer")
                imgui.EndTabItem()
            end
        end
        imgui.EndTabBar()
    else
        DrawHammerForcePanel(draw, state, root)
    end
    imgui.EndChild()
end

local module = {}

function module.bind(deps)
    banConfig = deps.state.banConfig
    uiData = deps.model
    components = deps.components
    hammerTabs = {}
    return module
end

module.draw = DrawHammersTab

return module
