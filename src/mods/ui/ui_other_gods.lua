local uiData, components = nil, nil
local banConfig = nil
local ACTIVE_OTHER_GOD_ROOT_ALIAS = "ActiveOtherGodRoot"
local forceRowOptsByLabel = {}
local OTHER_GODS_NAV_OPTS = {
    id = "BoonBansOtherGodsTabs",
}
local otherGodTabs = {}

local OTHER_GOD_ROOT_SPECS = {
    { id = "Hermes" },
    { id = "Selene" },
    { id = "Artemis" },
    { id = "Athena" },
    { id = "ChaosBuffs" },
    { id = "ChaosCurses" },
    { id = "Judgement1" },
    { id = "Judgement2" },
    { id = "Judgement3" },
}

local function BuildOtherGodRoots(data)
    local roots = {}
    for _, spec in ipairs(OTHER_GOD_ROOT_SPECS) do
        roots[#roots + 1] = uiData.BuildBanPoolRoot(spec.id, { data = data })
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

local function GetNavLabel(root, data)
    local label = root.label
    if IsRootCustomized(root, data) then
        label = label .. " *"
    end
    return label
end

local function GetActiveRoot(data)
    local activeRootId = data.get(ACTIVE_OTHER_GOD_ROOT_ALIAS):read()
    for _, root in ipairs(BuildOtherGodRoots(data)) do
        if root.id == activeRootId then
            return root
        end
    end
    return BuildOtherGodRoots(data)[1]
end

local function GetForceRowOpts(banPool)
    local label = banPool.label == "Bans" and "Force 1" or banPool.label
    local opts = forceRowOptsByLabel[label]
    if not opts then
        opts = {
            label = label,
        }
        forceRowOptsByLabel[label] = opts
    end
    return opts
end

local function DrawForcePanel(draw, data, root)
    draw.widgets.text("Setup")
    draw.widgets.separator()
    components.DrawConfiguredBanPoolControl(draw, data, root)
    for _, banPool in ipairs(root.banPools) do
        components.DrawForceBanRow(draw, data, root, banPool, GetForceRowOpts(banPool))
    end
end

local function SetOtherGodTab(index, root, data)
    local tab = otherGodTabs[index]
    if not tab then
        tab = {}
        otherGodTabs[index] = tab
    end

    tab.key = root.id
    tab.label = GetNavLabel(root, data)
    tab.color = uiData.GetGodColor(root.primaryGodKey)
end

local function TrimOtherGodTabs(tabCount)
    for index = tabCount + 1, #otherGodTabs do
        otherGodTabs[index] = nil
    end
end

local function DrawOtherGodsTab(draw, data, services)
    local imgui = draw.imgui
    local activeRootField = data.get(ACTIVE_OTHER_GOD_ROOT_ALIAS)
    local tabCount = 0
    for _, root in ipairs(BuildOtherGodRoots(data)) do
        tabCount = tabCount + 1
        SetOtherGodTab(tabCount, root, data)
    end
    TrimOtherGodTabs(tabCount)

    OTHER_GODS_NAV_OPTS.navWidth = uiData.ROOT_NAV_WIDTH
    OTHER_GODS_NAV_OPTS.tabs = otherGodTabs
    OTHER_GODS_NAV_OPTS.activeKey = activeRootField:read()
    local activeRootId = draw.nav.verticalTabs(OTHER_GODS_NAV_OPTS)
    if activeRootId ~= activeRootField:read() then
        activeRootField:write(activeRootId)
    end

    local root = GetActiveRoot(data)

    imgui.BeginChild("BoonBansOtherGodsDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansOtherGodsViews##" .. root.id) then
        if #root.banPools > 1 and imgui.BeginTabItem("Setup") then
            DrawForcePanel(draw, data, root)
            imgui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if imgui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(draw, data, services, banPool.key, "other_gods")
                imgui.EndTabItem()
            end
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
    forceRowOptsByLabel = {}
    otherGodTabs = {}
    return module
end

module.draw = DrawOtherGodsTab

return module
