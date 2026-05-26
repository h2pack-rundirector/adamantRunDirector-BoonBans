local uiData, components = nil, nil
local banConfig = nil
local ACTIVE_OTHER_GOD_ROOT_ALIAS = "ActiveOtherGodRoot"
local forceRowOptsByLabel = {}
local OTHER_GODS_NAV_OPTS = {
    id = "BoonBansOtherGodsTabs",
}
local otherGodTabs = {}
local otherGodRoots = {}
local otherGodRootsByKey = {}
local otherGodRootCountsByKey = {}

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

local function GetOtherGodRoot(godKey, state)
    local configuredCount = banConfig.GetConfiguredBanPoolCount(godKey, state)
    local cached = otherGodRootsByKey[godKey]
    if cached and otherGodRootCountsByKey[godKey] == configuredCount then
        return cached
    end

    cached = uiData.BuildBanPoolRoot(godKey, { state = state })
    otherGodRootsByKey[godKey] = cached
    otherGodRootCountsByKey[godKey] = configuredCount
    return cached
end

local function GetOtherGodRoots(state)
    for index = #otherGodRoots, 1, -1 do
        otherGodRoots[index] = nil
    end

    for _, spec in ipairs(OTHER_GOD_ROOT_SPECS) do
        otherGodRoots[#otherGodRoots + 1] = GetOtherGodRoot(spec.id, state)
    end
    return otherGodRoots
end

local function IsRootCustomized(root, state)
    for _, banPool in ipairs(root.banPools) do
        if banConfig.IsBanPoolCustomized(banPool.key, state) then
            return true
        end
    end
    return false
end

local function GetNavLabel(root, state)
    local label = root.label
    if IsRootCustomized(root, state) then
        label = label .. " *"
    end
    return label
end

local function GetActiveRoot(roots, activeRootId)
    for _, root in ipairs(roots) do
        if root.id == activeRootId then
            return root
        end
    end
    return roots[1]
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

local function DrawForcePanel(draw, state, root)
    draw.widgets.text("Setup")
    draw.widgets.separator()
    components.DrawConfiguredBanPoolControl(draw, state, root)
    for _, banPool in ipairs(root.banPools) do
        components.DrawForceBanRow(draw, state, root, banPool, GetForceRowOpts(banPool))
    end
end

local function SetOtherGodTab(index, root, state)
    local tab = otherGodTabs[index]
    if not tab then
        tab = {}
        otherGodTabs[index] = tab
    end

    tab.key = root.id
    tab.label = GetNavLabel(root, state)
    tab.color = uiData.GetGodColor(root.primaryGodKey)
end

local function TrimOtherGodTabs(tabCount)
    for index = tabCount + 1, #otherGodTabs do
        otherGodTabs[index] = nil
    end
end

local function DrawOtherGodsTab(draw, state, actions)
    local imgui = draw.imgui
    local activeRootField = state.get(ACTIVE_OTHER_GOD_ROOT_ALIAS)
    local roots = GetOtherGodRoots(state)
    local tabCount = 0
    for _, root in ipairs(roots) do
        tabCount = tabCount + 1
        SetOtherGodTab(tabCount, root, state)
    end
    TrimOtherGodTabs(tabCount)

    local activeRootValue = activeRootField:read()
    OTHER_GODS_NAV_OPTS.navWidth = uiData.ROOT_NAV_WIDTH
    OTHER_GODS_NAV_OPTS.tabs = otherGodTabs
    OTHER_GODS_NAV_OPTS.activeKey = activeRootValue
    local activeRootId = draw.nav.verticalTabs(OTHER_GODS_NAV_OPTS)
    if activeRootId ~= activeRootValue then
        activeRootField:write(activeRootId)
    end

    local root = GetActiveRoot(roots, activeRootId)

    imgui.BeginChild("BoonBansOtherGodsDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansOtherGodsViews##" .. root.id) then
        if (root.maxBanPools or 1) > 1 and imgui.BeginTabItem("Setup") then
            DrawForcePanel(draw, state, root)
            imgui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if imgui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(draw, state, actions, banPool.key, "other_gods")
                imgui.EndTabItem()
            end
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
    forceRowOptsByLabel = {}
    otherGodTabs = {}
    otherGodRoots = {}
    otherGodRootsByKey = {}
    otherGodRootCountsByKey = {}
    return module
end

module.draw = DrawOtherGodsTab

return module
