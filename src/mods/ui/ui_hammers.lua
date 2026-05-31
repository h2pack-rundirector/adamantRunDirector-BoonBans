local deps = ...
local uiStyle = deps.style
local uiRoots = deps.roots

local HAMMER_SETUP_OPTS = {
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
local activeHammerRootId = "Staff"

local HAMMER_ROOT_KEYS = {
    "Staff",
    "Dagger",
    "Axe",
    "Torch",
    "Lob",
    "Suit",
}

local function GetHammerRoot(godKey, ui)
    local source = ui.controls.get(godKey)
    local configuredCount = source:tierCount()
    local cached = hammerRootsByKey[godKey]
    if cached and hammerRootCountsByKey[godKey] == configuredCount then
        return cached
    end

    cached = uiRoots.buildTraitSourceRoot(source)
    hammerRootsByKey[godKey] = cached
    hammerRootCountsByKey[godKey] = configuredCount
    return cached
end

local function GetHammerRoots(ui)
    for index = #hammerRoots, 1, -1 do
        hammerRoots[index] = nil
    end

    for _, godKey in ipairs(HAMMER_ROOT_KEYS) do
        hammerRoots[#hammerRoots + 1] = GetHammerRoot(godKey, ui)
    end
    return hammerRoots
end

local function IsHammerEquipped(root)
    local equippedWeapon = GetEquippedWeapon and (GetEquippedWeapon() or "") or ""
    return equippedWeapon ~= "" and equippedWeapon:find(root.id, 1, true) ~= nil
end

local function GetHammerNavLabel(root, ui)
    local label = root.label
    if IsHammerEquipped(root) then
        label = ">> " .. label .. " <<"
    end
    if ui.controls.get(root.controlName):isCustomized() then
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

local function DrawHammerSetupPanel(ui, controlName)
    ui.draw.control(ui.controls.get(controlName), "setup", HAMMER_SETUP_OPTS)
end

local function SetHammerTab(index, root, ui)
    local tab = hammerTabs[index]
    if not tab then
        tab = {}
        hammerTabs[index] = tab
    end

    tab.key = root.id
    tab.label = GetHammerNavLabel(root, ui)
    tab.color = root.color
end

local function TrimHammerTabs(tabCount)
    for index = tabCount + 1, #hammerTabs do
        hammerTabs[index] = nil
    end
end

local function DrawHammersTab(_, ui)
    local draw = ui.draw
    local imgui = draw.imgui
    local roots = GetHammerRoots(ui)
    local tabCount = 0
    for _, root in ipairs(roots) do
        tabCount = tabCount + 1
        SetHammerTab(tabCount, root, ui)
    end
    TrimHammerTabs(tabCount)

    local activeRootValue = GetActiveHammerRoot(roots, activeHammerRootId).id
    activeHammerRootId = activeRootValue
    HAMMER_NAV_OPTS.navWidth = uiStyle.ROOT_NAV_WIDTH
    HAMMER_NAV_OPTS.tabs = hammerTabs
    HAMMER_NAV_OPTS.activeKey = activeRootValue
    local activeRootId = draw.nav.verticalTabs(HAMMER_NAV_OPTS)
    if activeRootId ~= activeRootValue then
        activeHammerRootId = activeRootId
    end

    local root = GetActiveHammerRoot(roots, activeRootId)

    imgui.BeginChild("BoonBansHammersDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansHammersViews##" .. root.id) then
        if imgui.BeginTabItem("Setup") then
            DrawHammerSetupPanel(ui, root.controlName)
            imgui.EndTabItem()
        end
        local source = ui.controls.get(root.controlName)
        for tierIndex, banPool in ipairs(root.banPools) do
            if imgui.BeginTabItem(banPool.label) then
                draw.control(source, "tier", tierIndex)
                imgui.EndTabItem()
            end
        end
        imgui.EndTabBar()
    else
        DrawHammerSetupPanel(ui, root.controlName)
    end
    imgui.EndChild()
end

local module = {}

module.draw = DrawHammersTab

return module
