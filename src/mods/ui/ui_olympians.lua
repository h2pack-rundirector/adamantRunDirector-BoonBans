local deps = ...
local uiStyle = deps.style
local uiRoots = deps.roots
local godAvailability = import("mods/cache/god_availability.lua")
local bridalGlowUi = import("mods/ui/ui_bridal_glow.lua", nil, deps)
local mutedTextOpts = {
    color = uiStyle.MUTED_TEXT_COLOR,
}
local OLYMPIAN_NAV_OPTS = {
    id = "BoonBansOlympiansTabs",
}
local olympianTabs = {}
local olympianRoots = {}
local olympianRootsByKey = {}
local olympianRootCountsByKey = {}
local visibleOlympianRoots = {}
local activeOlympianRootId = "Aphrodite"

local OLYMPIAN_ROOT_KEYS = {
    "Aphrodite",
    "Apollo",
    "Ares",
    "Demeter",
    "Hephaestus",
    "Hera",
    "Hestia",
    "Poseidon",
    "Zeus",
}

local function GetOlympianRoot(godKey, ui)
    local source = ui.controls.get(godKey)
    local configuredCount = source:tierCount()
    local cached = olympianRootsByKey[godKey]
    if cached and olympianRootCountsByKey[godKey] == configuredCount then
        return cached
    end

    cached = uiRoots.buildTraitSourceRoot(source, {
        hasBridalGlow = godKey == "Hera",
    })
    olympianRootsByKey[godKey] = cached
    olympianRootCountsByKey[godKey] = configuredCount
    return cached
end

local function GetOlympianRoots(ui)
    for index = #olympianRoots, 1, -1 do
        olympianRoots[index] = nil
    end

    for _, godKey in ipairs(OLYMPIAN_ROOT_KEYS) do
        olympianRoots[#olympianRoots + 1] = GetOlympianRoot(godKey, ui)
    end
    return olympianRoots
end

local function GetVisibleOlympianRoots(ui)
    local state = ui.data
    local availability = godAvailability.read(state)
    local godPoolFiltering = godAvailability.isSnapshotActive(availability)
    for index = #visibleOlympianRoots, 1, -1 do
        visibleOlympianRoots[index] = nil
    end

    for _, root in ipairs(GetOlympianRoots(ui)) do
        if not godPoolFiltering or godAvailability.isSnapshotAvailable(availability, root.id) then
            visibleOlympianRoots[#visibleOlympianRoots + 1] = root
        end
    end
    return visibleOlympianRoots, godPoolFiltering
end

local function GetNavLabel(root, ui)
    local label = root.label
    if ui.controls.get(root.controlName):isCustomized() then
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

local function NormalizeActiveRoot(visibleRoots, activeRootId)
    local root = FindRootById(visibleRoots, activeRootId)
    if root then
        return root, activeRootId
    end

    root = visibleRoots[1]
    activeRootId = root.id
    return root, activeRootId
end

local function GetActiveRoot(visibleRoots, activeRootId)
    local root = FindRootById(visibleRoots, activeRootId)
    if root then
        return root
    end
    return visibleRoots[1]
end

local function SetOlympianTab(index, root, ui)
    local tab = olympianTabs[index]
    if not tab then
        tab = {}
        olympianTabs[index] = tab
    end

    tab.key = root.id
    tab.label = GetNavLabel(root, ui)
    tab.color = root.color
end

local function TrimOlympianTabs(tabCount)
    for index = tabCount + 1, #olympianTabs do
        olympianTabs[index] = nil
    end
end

local function DrawOlympiansTab(_, ui)
    local draw = ui.draw
    local imgui = draw.imgui
    local visibleRoots, godPoolFiltering = GetVisibleOlympianRoots(ui)
    if #visibleRoots == 0 then
        draw.widgets.text("No Olympians are currently available.", mutedTextOpts)
        return
    end

    local tabCount = 0
    for _, root in ipairs(visibleRoots) do
        tabCount = tabCount + 1
        SetOlympianTab(tabCount, root, ui)
    end
    TrimOlympianTabs(tabCount)

    local root, activeRootId = NormalizeActiveRoot(visibleRoots, activeOlympianRootId)
    activeOlympianRootId = activeRootId

    OLYMPIAN_NAV_OPTS.navWidth = uiStyle.ROOT_NAV_WIDTH
    OLYMPIAN_NAV_OPTS.tabs = olympianTabs
    OLYMPIAN_NAV_OPTS.activeKey = activeRootId
    local selectedRootId = draw.nav.verticalTabs(OLYMPIAN_NAV_OPTS)
    if selectedRootId ~= activeRootId then
        activeOlympianRootId = selectedRootId
        root = GetActiveRoot(visibleRoots, selectedRootId)
    end

    imgui.BeginChild("BoonBansOlympiansDetail", 0, 0, false)
    if godPoolFiltering then
        draw.widgets.text(string.format("Showing %d Olympians enabled in God Pool.", #visibleRoots), mutedTextOpts)
        imgui.Spacing()
    end

    if imgui.BeginTabBar("BoonBansOlympiansViews##" .. root.id) then
        if imgui.BeginTabItem("Setup") then
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
        if imgui.BeginTabItem("Rarity") then
            draw.control(source, "rarity")
            imgui.EndTabItem()
        end
        if root.hasBridalGlow and imgui.BeginTabItem("Bridal Glow Target") then
            bridalGlowUi.draw(ui, visibleRoots)
            imgui.EndTabItem()
        end
        imgui.EndTabBar()
    end
    imgui.EndChild()
end

local module = {}

module.draw = DrawOlympiansTab

return module
