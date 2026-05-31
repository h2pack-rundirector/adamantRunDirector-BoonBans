local deps = ...
local uiStyle = deps.style
local uiRoots = deps.roots
local OTHER_GODS_NAV_OPTS = {
    id = "BoonBansOtherGodsTabs",
}
local otherGodTabs = {}
local otherGodRoots = {}
local otherGodRootsByKey = {}
local otherGodRootCountsByKey = {}
local activeOtherGodRootId = "Hermes"

local OTHER_GOD_ROOT_KEYS = {
    "Hermes",
    "Selene",
    "Artemis",
    "Athena",
    "ChaosBuffs",
    "ChaosCurses",
    "Judgement1",
    "Judgement2",
    "Judgement3",
}

local function GetOtherGodRoot(godKey, ui)
    local source = ui.controls.get(godKey)
    local configuredCount = source:tierCount()
    local cached = otherGodRootsByKey[godKey]
    if cached and otherGodRootCountsByKey[godKey] == configuredCount then
        return cached
    end

    cached = uiRoots.buildTraitSourceRoot(source)
    otherGodRootsByKey[godKey] = cached
    otherGodRootCountsByKey[godKey] = configuredCount
    return cached
end

local function GetOtherGodRoots(ui)
    for index = #otherGodRoots, 1, -1 do
        otherGodRoots[index] = nil
    end

    for _, godKey in ipairs(OTHER_GOD_ROOT_KEYS) do
        otherGodRoots[#otherGodRoots + 1] = GetOtherGodRoot(godKey, ui)
    end
    return otherGodRoots
end

local function GetNavLabel(root, ui)
    local label = root.label
    if ui.controls.get(root.controlName):isCustomized() then
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

local function SetOtherGodTab(index, root, ui)
    local tab = otherGodTabs[index]
    if not tab then
        tab = {}
        otherGodTabs[index] = tab
    end

    tab.key = root.id
    tab.label = GetNavLabel(root, ui)
    tab.color = root.color
end

local function TrimOtherGodTabs(tabCount)
    for index = tabCount + 1, #otherGodTabs do
        otherGodTabs[index] = nil
    end
end

local function DrawOtherGodsTab(_, ui)
    local draw = ui.draw
    local imgui = draw.imgui
    local roots = GetOtherGodRoots(ui)
    local tabCount = 0
    for _, root in ipairs(roots) do
        tabCount = tabCount + 1
        SetOtherGodTab(tabCount, root, ui)
    end
    TrimOtherGodTabs(tabCount)

    local activeRootValue = GetActiveRoot(roots, activeOtherGodRootId).id
    activeOtherGodRootId = activeRootValue
    OTHER_GODS_NAV_OPTS.navWidth = uiStyle.ROOT_NAV_WIDTH
    OTHER_GODS_NAV_OPTS.tabs = otherGodTabs
    OTHER_GODS_NAV_OPTS.activeKey = activeRootValue
    local activeRootId = draw.nav.verticalTabs(OTHER_GODS_NAV_OPTS)
    if activeRootId ~= activeRootValue then
        activeOtherGodRootId = activeRootId
    end

    local root = GetActiveRoot(roots, activeRootId)

    imgui.BeginChild("BoonBansOtherGodsDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansOtherGodsViews##" .. root.id) then
        if (root.maxBanPools or 1) > 1 and imgui.BeginTabItem("Setup") then
            draw.control(ui.controls.get(root.controlName), "setup")
            imgui.EndTabItem()
        end
        local source = ui.controls.get(root.controlName)
        for tierIndex, banPool in ipairs(root.banPools) do
            if imgui.BeginTabItem(banPool.label) then
                draw.control(source, "tier", tierIndex)
                imgui.EndTabItem()
            end
        end
        if root.hasRarity and imgui.BeginTabItem("Rarity") then
            draw.control(source, "rarity")
            imgui.EndTabItem()
        end
        imgui.EndTabBar()
    end
    imgui.EndChild()
end

local module = {}

module.draw = DrawOtherGodsTab

return module
