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

local function BuildOtherGodRoots(state)
    local roots = {}
    for _, spec in ipairs(OTHER_GOD_ROOT_SPECS) do
        roots[#roots + 1] = uiData.BuildBanPoolRoot(spec.id, { state = state })
    end
    return roots
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

local function GetActiveRoot(state)
    local activeRootId = state.get(ACTIVE_OTHER_GOD_ROOT_ALIAS):read()
    for _, root in ipairs(BuildOtherGodRoots(state)) do
        if root.id == activeRootId then
            return root
        end
    end
    return BuildOtherGodRoots(state)[1]
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

local function DrawOtherGodsTab(draw, state, services)
    local imgui = draw.imgui
    local activeRootField = state.get(ACTIVE_OTHER_GOD_ROOT_ALIAS)
    local tabCount = 0
    for _, root in ipairs(BuildOtherGodRoots(state)) do
        tabCount = tabCount + 1
        SetOtherGodTab(tabCount, root, state)
    end
    TrimOtherGodTabs(tabCount)

    OTHER_GODS_NAV_OPTS.navWidth = uiData.ROOT_NAV_WIDTH
    OTHER_GODS_NAV_OPTS.tabs = otherGodTabs
    OTHER_GODS_NAV_OPTS.activeKey = activeRootField:read()
    local activeRootId = draw.nav.verticalTabs(OTHER_GODS_NAV_OPTS)
    if activeRootId ~= activeRootField:read() then
        activeRootField:write(activeRootId)
    end

    local root = GetActiveRoot(state)

    imgui.BeginChild("BoonBansOtherGodsDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansOtherGodsViews##" .. root.id) then
        if #root.banPools > 1 and imgui.BeginTabItem("Setup") then
            DrawForcePanel(draw, state, root)
            imgui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if imgui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(draw, state, services, banPool.key, "other_gods")
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
    return module
end

module.draw = DrawOtherGodsTab

return module
