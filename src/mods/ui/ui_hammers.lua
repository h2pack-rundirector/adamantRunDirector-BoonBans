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

local function BuildHammerRoots(data)
    local roots = {}
    for _, godKey in ipairs(HAMMER_ROOT_KEYS) do
        roots[#roots + 1] = uiData.BuildBanPoolRoot(godKey, {
            data = data,
            hasRarity = false,
        })
    end
    return roots
end

local function IsHammerCustomized(root, data)
    for _, banPool in ipairs(root.banPools) do
        if banConfig.IsBanPoolCustomized(banPool.key, data) then
            return true
        end
    end
    return false
end

local function IsHammerEquipped(root)
    local equippedWeapon = GetEquippedWeapon and (GetEquippedWeapon() or "") or ""
    return equippedWeapon ~= "" and equippedWeapon:find(root.id, 1, true) ~= nil
end

local function GetHammerNavLabel(root, data)
    local label = root.label
    if IsHammerEquipped(root) then
        label = "» " .. label .. " «"
    end
    if IsHammerCustomized(root, data) then
        label = label .. " *"
    end
    return label
end

local function GetActiveHammerRoot(data)
    local activeRootId = data.get(ACTIVE_HAMMER_ROOT_ALIAS):read()
    for _, root in ipairs(BuildHammerRoots(data)) do
        if root.id == activeRootId then
            return root
        end
    end
    return uiData.BuildBanPoolRoot(HAMMER_ROOT_KEYS[1], { data = data, hasRarity = false })
end

local function DrawHammerForcePanel(draw, data, root)
    draw.widgets.text("Setup")
    draw.widgets.separator()
    components.DrawConfiguredBanPoolControl(draw, data, root)
    for _, banPool in ipairs(root.banPools) do
        components.DrawForceBanRow(draw, data, root, banPool, HAMMER_FORCE_ROW_OPTS)
    end
end

local function SetHammerTab(index, root, data)
    local tab = hammerTabs[index]
    if not tab then
        tab = {}
        hammerTabs[index] = tab
    end

    tab.key = root.id
    tab.label = GetHammerNavLabel(root, data)
    tab.color = uiData.GetGodColor(root.primaryGodKey)
end

local function TrimHammerTabs(tabCount)
    for index = tabCount + 1, #hammerTabs do
        hammerTabs[index] = nil
    end
end

local function DrawHammersTab(draw, data, services)
    local imgui = draw.imgui
    local activeRootField = data.get(ACTIVE_HAMMER_ROOT_ALIAS)
    local tabCount = 0
    for _, root in ipairs(BuildHammerRoots(data)) do
        tabCount = tabCount + 1
        SetHammerTab(tabCount, root, data)
    end
    TrimHammerTabs(tabCount)

    HAMMER_NAV_OPTS.navWidth = uiData.ROOT_NAV_WIDTH
    HAMMER_NAV_OPTS.tabs = hammerTabs
    HAMMER_NAV_OPTS.activeKey = activeRootField:read()
    local activeRootId = draw.nav.verticalTabs(HAMMER_NAV_OPTS)
    if activeRootId ~= activeRootField:read() then
        activeRootField:write(activeRootId)
    end

    local root = GetActiveHammerRoot(data)

    imgui.BeginChild("BoonBansHammersDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansHammersViews##" .. root.id) then
        if imgui.BeginTabItem("Setup") then
            DrawHammerForcePanel(draw, data, root)
            imgui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if imgui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(draw, data, services, banPool.key, "hammer")
                imgui.EndTabItem()
            end
        end
        imgui.EndTabBar()
    else
        DrawHammerForcePanel(draw, data, root)
    end
    imgui.EndChild()
end

local module = {}

function module.bind(deps)
    banConfig = deps.data.banConfig
    uiData = deps.model
    components = deps.components
    hammerTabs = {}
    return module
end

module.draw = DrawHammersTab

return module
