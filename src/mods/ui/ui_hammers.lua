local internal = RunDirectorBoonBans_Internal
local uiData, components = nil, nil
local banConfig = internal.banConfig
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

local function DrawHammerForcePanel(ui, session, root)
    lib.widgets.text(ui, "Setup")
    lib.widgets.separator(ui)
    components.DrawConfiguredBanPoolControl(ui, session, root)
    for _, banPool in ipairs(root.banPools) do
        components.DrawForceBanRow(ui, session, root, banPool, {
            controlWidth = 200,
            drawRarity = false,
        })
    end
end

local function DrawHammersTab(ui, session, host)
    local tabs = {}
    for _, root in ipairs(BuildHammerRoots(session)) do
        tabs[#tabs + 1] = {
            key = root.id,
            label = GetHammerNavLabel(root, session),
            color = uiData.GetGodColor(root.primaryGodKey),
        }
    end

    local activeRootId = lib.nav.verticalTabs(ui, {
        id = "BoonBansHammersTabs",
        navWidth = uiData.ROOT_NAV_WIDTH,
        tabs = tabs,
        activeKey = session.view[ACTIVE_HAMMER_ROOT_ALIAS],
    })
    if activeRootId ~= session.view[ACTIVE_HAMMER_ROOT_ALIAS] then
        session.write(ACTIVE_HAMMER_ROOT_ALIAS, activeRootId)
    end

    local root = GetActiveHammerRoot(session)

    ui.BeginChild("BoonBansHammersDetail", 0, 0, false)
    if ui.BeginTabBar("BoonBansHammersViews##" .. root.id) then
        if ui.BeginTabItem("Setup") then
            DrawHammerForcePanel(ui, session, root)
            ui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if ui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(ui, session, host, banPool.key, "hammer")
                ui.EndTabItem()
            end
        end
        ui.EndTabBar()
    else
        DrawHammerForcePanel(ui, session, root)
    end
    ui.EndChild()
end

local module = {}

function module.bind(deps)
    uiData = deps.model
    components = deps.components
    return module
end

module.draw = DrawHammersTab

return module
