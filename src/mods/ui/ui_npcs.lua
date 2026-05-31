local deps = ...
local uiStyle = deps.style
local uiRoots = deps.roots
local NPC_NAV_OPTS = {
    id = "BoonBansNpcsTabs",
}
local npcTabs = {}
local npcRoots = {}
local activeNpcRootId = "Arachne"

local NPC_ROOTS = {
    "Arachne",
    "Narcissus",
    "Echo",
    "Hades",
    "Medea",
    "Circe",
    "Icarus",
    "Dionysus",
    "CirceBNB",
    "CirceCRD",
    "HadesKeepsake",
}

local function GetNpcRoots(ui)
    for index = #npcRoots, 1, -1 do
        npcRoots[index] = nil
    end

    for _, controlName in ipairs(NPC_ROOTS) do
        npcRoots[#npcRoots + 1] = uiRoots.buildTraitSourceRoot(ui.controls.get(controlName))
    end
    return npcRoots
end

local function GetNavLabel(root, ui)
    local label = root.label
    if ui.controls.get(root.controlName):isCustomized() then
        label = label .. " *"
    end
    return label
end

local function FindRootById(roots, rootId)
    for _, root in ipairs(roots) do
        if root.id == rootId then
            return root
        end
    end
end

local function NormalizeActiveRoot(roots, activeRootId)
    local root = FindRootById(roots, activeRootId)
    if root then
        return root, activeRootId
    end

    root = roots[1]
    activeRootId = root.id
    return root, activeRootId
end

local function GetActiveRoot(roots, activeRootId)
    local root = FindRootById(roots, activeRootId)
    if root then
        return root
    end
    return roots[1]
end

local function SetNpcTab(index, root, ui)
    local tab = npcTabs[index]
    if not tab then
        tab = {}
        npcTabs[index] = tab
    end

    tab.key = root.id
    tab.label = GetNavLabel(root, ui)
    tab.color = root.color
    tab.group = root.group
end

local function TrimNpcTabs(tabCount)
    for index = tabCount + 1, #npcTabs do
        npcTabs[index] = nil
    end
end

local function DrawNpcsTab(_, ui)
    local draw = ui.draw
    local imgui = draw.imgui

    local roots = GetNpcRoots(ui)

    local tabCount = 0
    for _, root in ipairs(roots) do
        tabCount = tabCount + 1
        SetNpcTab(tabCount, root, ui)
    end
    TrimNpcTabs(tabCount)

    local root, activeRootId = NormalizeActiveRoot(roots, activeNpcRootId)
    activeNpcRootId = activeRootId

    NPC_NAV_OPTS.navWidth = uiStyle.ROOT_NAV_WIDTH
    NPC_NAV_OPTS.tabs = npcTabs
    NPC_NAV_OPTS.activeKey = activeRootId
    local selectedRootId = draw.nav.verticalTabs(NPC_NAV_OPTS)
    if selectedRootId ~= activeRootId then
        activeNpcRootId = selectedRootId
        root = GetActiveRoot(roots, selectedRootId)
    end

    imgui.BeginChild("BoonBansNpcsDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansNpcsViews##" .. root.id) then
        if imgui.BeginTabItem("Bans") then
            draw.control(ui.controls.get(root.controlName), "tier", 1)
            imgui.EndTabItem()
        end
        if root.hasRarity and imgui.BeginTabItem("Rarity") then
            draw.control(ui.controls.get(root.controlName), "rarity")
            imgui.EndTabItem()
        end
        imgui.EndTabBar()
    end
    imgui.EndChild()
end

local module = {}

module.draw = DrawNpcsTab

return module
