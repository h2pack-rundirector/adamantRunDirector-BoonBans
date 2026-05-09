local internal = RunDirectorBoonBans_Internal
local uiData = internal.ui
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
    for _, rootKey in ipairs(HAMMER_ROOT_KEYS) do
        roots[#roots + 1] = uiData.BuildTierRoot(rootKey, {
            session = session,
            hasRarity = false,
        })
    end
    return roots
end

local function IsHammerCustomized(root, session)
    for _, scope in ipairs(root.scopes) do
        local banned = uiData.GetScopeSummary(scope.key, session)
        if banned > 0 then
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
    return uiData.BuildTierRoot(HAMMER_ROOT_KEYS[1], { session = session, hasRarity = false })
end

local function DrawHammerForceRow(ui, session, scope)
    local bindAlias = internal.GetBanRootAlias(scope.key)
    if not bindAlias then
        return
    end

    ui.AlignTextToFramePadding()
    ui.Text(scope.label)
    ui.SameLine()
    ui.SetCursorPosX(80)
    lib.widgets.packedDropdown(ui, session, bindAlias, {
        label = "",
        selectionMode = "singleDisabled",
        noneLabel = "None",
        multipleLabel = "Multiple",
        displayValues = uiData.BuildPackedBanDisplayValues(scope.key),
        valueColors = uiData.BuildPackedBanValueColors(scope.key),
        controlWidth = 200,
    })
end

local function DrawHammerForcePanel(ui, session, root)
    lib.widgets.text(ui, "Setup")
    lib.widgets.separator(ui)
    internal.DrawConfiguredTierControl(ui, session, root)
    for _, scope in ipairs(root.scopes) do
        DrawHammerForceRow(ui, session, scope)
    end
end

local function DrawHammerBanPanel(ui, session, scope)
    internal.DrawBanSearchControls(ui, session, scope.key)
    ui.SameLine()
    ui.SetCursorPosX(ui.GetCursorPosX() + 100)

    lib.widgets.button(ui, "Ban All", {
        id = "hammer_ban_all_" .. scope.key,
        onClick = function()
            internal.BanAllGodBans(scope.key, session)
        end,
    })
    ui.SameLine()
    lib.widgets.button(ui, "Reset", {
        id = "hammer_reset_" .. scope.key,
        onClick = function()
            internal.ResetGodBans(scope.key, session)
        end,
    })

    lib.widgets.separator(ui)
    internal.DrawFilteredPackedBanList(ui, session, scope.key)
end

function internal.DrawHammersTab(ui, session)
    local tabs = {}
    for _, root in ipairs(BuildHammerRoots(session)) do
        tabs[#tabs + 1] = {
            key = root.id,
            label = GetHammerNavLabel(root, session),
            color = uiData.GetSourceColor(root.primaryScopeKey),
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
        for _, scope in ipairs(root.scopes) do
            if ui.BeginTabItem(scope.label) then
                DrawHammerBanPanel(ui, session, scope)
                ui.EndTabItem()
            end
        end
        ui.EndTabBar()
    else
        DrawHammerForcePanel(ui, session, root)
    end
    ui.EndChild()
end
