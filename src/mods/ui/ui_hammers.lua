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
local hammerRoots = {}
local hammerRootsByKey = {}
local hammerRootCountsByKey = {}

local HAMMER_ROOT_KEYS = {
    "Staff",
    "Dagger",
    "Axe",
    "Torch",
    "Lob",
    "Suit",
}

local function GetHammerRoot(godKey, state)
    local configuredCount = banConfig.GetConfiguredBanPoolCount(godKey, state)
    local cached = hammerRootsByKey[godKey]
    if cached and hammerRootCountsByKey[godKey] == configuredCount then
        return cached
    end

    cached = uiData.BuildBanPoolRoot(godKey, {
        state = state,
        hasRarity = false,
    })
    hammerRootsByKey[godKey] = cached
    hammerRootCountsByKey[godKey] = configuredCount
    return cached
end

local function GetHammerRoots(state)
    for index = #hammerRoots, 1, -1 do
        hammerRoots[index] = nil
    end

    for _, godKey in ipairs(HAMMER_ROOT_KEYS) do
        hammerRoots[#hammerRoots + 1] = GetHammerRoot(godKey, state)
    end
    return hammerRoots
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
        label = ">> " .. label .. " <<"
    end
    if IsHammerCustomized(root, state) then
        label = label .. " *"
    end
    return label
end

local function GetActiveHammerRoot(roots, activeRootId)
    for _, root in ipairs(roots) do
        if root.id == activeRootId then
            return root
        end
    end
    return roots[1]
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

local function DrawHammersTab(draw, state, actions)
    local imgui = draw.imgui
    local activeRootField = state.get(ACTIVE_HAMMER_ROOT_ALIAS)
    local roots = GetHammerRoots(state)
    local tabCount = 0
    for _, root in ipairs(roots) do
        tabCount = tabCount + 1
        SetHammerTab(tabCount, root, state)
    end
    TrimHammerTabs(tabCount)

    local activeRootValue = activeRootField:read()
    HAMMER_NAV_OPTS.navWidth = uiData.ROOT_NAV_WIDTH
    HAMMER_NAV_OPTS.tabs = hammerTabs
    HAMMER_NAV_OPTS.activeKey = activeRootValue
    local activeRootId = draw.nav.verticalTabs(HAMMER_NAV_OPTS)
    if activeRootId ~= activeRootValue then
        activeRootField:write(activeRootId)
    end

    local root = GetActiveHammerRoot(roots, activeRootId)

    imgui.BeginChild("BoonBansHammersDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansHammersViews##" .. root.id) then
        if imgui.BeginTabItem("Setup") then
            DrawHammerForcePanel(draw, state, root)
            imgui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if imgui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(draw, state, actions, banPool.key, "hammer")
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
    hammerRoots = {}
    hammerRootsByKey = {}
    hammerRootCountsByKey = {}
    return module
end

module.draw = DrawHammersTab

return module
