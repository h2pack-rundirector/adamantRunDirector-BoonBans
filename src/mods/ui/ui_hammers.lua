local uiData, components = nil, nil
local banConfig = nil
local ACTIVE_HAMMER_ROOT_ALIAS = "ActiveHammerRoot"

local HAMMER_ROOT_KEYS = {
    "Staff",
    "Dagger",
    "Axe",
    "Torch",
    "Lob",
    "Suit",
}

local function BuildHammerRoots(session)
    local roots = {}
    for _, godKey in ipairs(HAMMER_ROOT_KEYS) do
        roots[#roots + 1] = uiData.BuildBanPoolRoot(godKey, {
            session = session,
            hasRarity = false,
        })
    end
    return roots
end

local function IsHammerCustomized(root, session)
    for _, banPool in ipairs(root.banPools) do
        if banConfig.IsBanPoolCustomized(banPool.key, session) then
            return true
        end
    end
    return false
end

local function IsHammerEquipped(root)
    local equippedWeapon = GetEquippedWeapon and (GetEquippedWeapon() or "") or ""
    return equippedWeapon ~= "" and equippedWeapon:find(root.id, 1, true) ~= nil
end

local function GetHammerNavLabel(root, session)
    local label = root.label
    if IsHammerEquipped(root) then
        label = "» " .. label .. " «"
    end
    if IsHammerCustomized(root, session) then
        label = label .. " *"
    end
    return label
end

local function GetActiveHammerRoot(session)
    local activeRootId = session.view[ACTIVE_HAMMER_ROOT_ALIAS]
    for _, root in ipairs(BuildHammerRoots(session)) do
        if root.id == activeRootId then
            return root
        end
    end
    return uiData.BuildBanPoolRoot(HAMMER_ROOT_KEYS[1], { session = session, hasRarity = false })
end

local function DrawHammerForcePanel(draw, root)
    draw.widgets.text("Setup")
    draw.widgets.separator()
    components.DrawConfiguredBanPoolControl(draw, root)
    for _, banPool in ipairs(root.banPools) do
        components.DrawForceBanRow(draw, root, banPool, {
            controlWidth = 200,
            drawRarity = false,
        })
    end
end

local function DrawHammersTab(draw)
    local imgui = draw.imgui
    local session = draw.session
    local tabs = {}
    for _, root in ipairs(BuildHammerRoots(session)) do
        tabs[#tabs + 1] = {
            key = root.id,
            label = GetHammerNavLabel(root, session),
            color = uiData.GetGodColor(root.primaryGodKey),
        }
    end

    local activeRootId = draw.nav.verticalTabs({
        id = "BoonBansHammersTabs",
        navWidth = uiData.ROOT_NAV_WIDTH,
        tabs = tabs,
        activeKey = session.view[ACTIVE_HAMMER_ROOT_ALIAS],
    })
    if activeRootId ~= session.view[ACTIVE_HAMMER_ROOT_ALIAS] then
        session.write(ACTIVE_HAMMER_ROOT_ALIAS, activeRootId)
    end

    local root = GetActiveHammerRoot(session)

    imgui.BeginChild("BoonBansHammersDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansHammersViews##" .. root.id) then
        if imgui.BeginTabItem("Setup") then
            DrawHammerForcePanel(draw, root)
            imgui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if imgui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(draw, banPool.key, "hammer")
                imgui.EndTabItem()
            end
        end
        imgui.EndTabBar()
    else
        DrawHammerForcePanel(draw, root)
    end
    imgui.EndChild()
end

local module = {}

function module.bind(deps)
    banConfig = deps.data.banConfig
    uiData = deps.model
    components = deps.components
    return module
end

module.draw = DrawHammersTab

return module
