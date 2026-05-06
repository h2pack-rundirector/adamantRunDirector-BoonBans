local internal = RunDirectorBoonBans_Internal
local uiData = internal.ui
local ACTIVE_OTHER_GOD_ROOT_ALIAS = "ActiveOtherGodRoot"

local OTHER_GOD_ROOT_SPECS = {
    { id = "Hermes", tiered = true },
    { id = "Selene" },
    { id = "Artemis" },
    { id = "Athena" },
    { id = "ChaosBuffs" },
    { id = "ChaosCurses" },
    { id = "Judgement1" },
    { id = "Judgement2" },
    { id = "Judgement3" },
}

local function BuildOtherGodRoots(session)
    local roots = {}
    for _, spec in ipairs(OTHER_GOD_ROOT_SPECS) do
        if spec.tiered then
            roots[#roots + 1] = uiData.BuildTierRoot(spec.id, { session = session })
        else
            roots[#roots + 1] = uiData.BuildSingleScopeRoot(spec.id)
        end
    end
    return roots
end

local function IsRootCustomized(root, session)
    for _, scope in ipairs(root.scopes) do
        local banned = uiData.GetScopeSummary(scope.key, session)
        if banned > 0 then
            return true
        end
    end
    return false
end

local function GetNavLabel(root, session)
    local label = root.label
    if IsRootCustomized(root, session) then
        label = label .. " *"
    end
    return label
end

local function GetActiveRoot(session)
    local activeRootId = session.view[ACTIVE_OTHER_GOD_ROOT_ALIAS]
    for _, root in ipairs(BuildOtherGodRoots(session)) do
        if root.id == activeRootId then
            return root
        end
    end
    return BuildOtherGodRoots(session)[1]
end

local function DrawForceRow(ui, session, root, scope)
    local bindAlias = internal.GetBanRootAlias(scope.key)
    if not bindAlias then
        return
    end

    ui.AlignTextToFramePadding()
    ui.Text(scope.label == "Bans" and "Force 1" or scope.label)
    ui.SameLine()
    ui.SetCursorPosX(80)
    lib.widgets.packedDropdown(ui, session, bindAlias, internal.store, {
        label = "",
        selectionMode = "singleDisabled",
        noneLabel = "None",
        multipleLabel = "Multiple",
        displayValues = uiData.BuildPackedBanDisplayValues(scope.key),
        valueColors = uiData.BuildPackedBanValueColors(scope.key),
        controlWidth = 220,
    })
    internal.DrawForcedBoonRarityShortcut(ui, session, root, scope)
end

local function DrawForcePanel(ui, session, root)
    lib.widgets.text(ui, "Setup")
    lib.widgets.separator(ui)
    internal.DrawConfiguredTierControl(ui, session, root)
    for _, scope in ipairs(root.scopes) do
        DrawForceRow(ui, session, root, scope)
    end
end

local function DrawBanPanel(ui, session, _, scope)
    internal.DrawBanSearchControls(ui, session, scope.key)
    ui.SameLine()
    ui.SetCursorPosX(ui.GetCursorPosX() + 100)

    lib.widgets.button(ui, "Ban All", {
        id = "other_gods_ban_all_" .. scope.key,
        onClick = function()
            internal.BanAllGodBans(scope.key, session)
        end,
    })
    ui.SameLine()
    lib.widgets.button(ui, "Reset", {
        id = "other_gods_reset_" .. scope.key,
        onClick = function()
            internal.ResetGodBans(scope.key, session)
        end,
    })

    lib.widgets.separator(ui)
    internal.DrawFilteredPackedBanList(ui, session, scope.key)
end

local function DrawRarityPanel(ui, session, root)
    for _, boon in ipairs(uiData.GetScopeBoons(root.primaryScopeKey)) do
        if uiData.IsRarityEligibleBoon(boon) then
            local rarityAlias = internal.GetRarityAlias(root.primaryScopeKey, boon.Key)
            if rarityAlias then
                ui.AlignTextToFramePadding()
                ui.Text(uiData.GetBoonText(boon))
                ui.SameLine()
                ui.SetCursorPosX(220)
                lib.widgets.dropdown(ui, session, rarityAlias, {
                    label = "",
                    values = { 0, 1, 2, 3 },
                    displayValues = uiData.RARITY_LABELS,
                    valueColors = uiData.RARITY_COLORS,
                    controlWidth = 120,
                })
            end
        end
    end
end

function internal.DrawOtherGodsTab(ui, session)
    local tabs = {}
    for _, root in ipairs(BuildOtherGodRoots(session)) do
        tabs[#tabs + 1] = {
            key = root.id,
            label = GetNavLabel(root, session),
            color = uiData.GetSourceColor(root.primaryScopeKey),
        }
    end

    local activeRootId = lib.nav.verticalTabs(ui, {
        id = "BoonBansOtherGodsTabs",
        navWidth = uiData.ROOT_NAV_WIDTH,
        tabs = tabs,
        activeKey = session.view[ACTIVE_OTHER_GOD_ROOT_ALIAS],
    })
    if activeRootId ~= session.view[ACTIVE_OTHER_GOD_ROOT_ALIAS] then
        session.write(ACTIVE_OTHER_GOD_ROOT_ALIAS, activeRootId)
    end

    local root = GetActiveRoot(session)

    ui.BeginChild("BoonBansOtherGodsDetail", 0, 0, false)
    if ui.BeginTabBar("BoonBansOtherGodsViews##" .. root.id) then
        if #root.scopes > 1 and ui.BeginTabItem("Setup") then
            DrawForcePanel(ui, session, root)
            ui.EndTabItem()
        end
        for _, scope in ipairs(root.scopes) do
            if ui.BeginTabItem(scope.label) then
                DrawBanPanel(ui, session, root, scope)
                ui.EndTabItem()
            end
        end
        if root.hasRarity and ui.BeginTabItem("Rarity") then
            DrawRarityPanel(ui, session, root)
            ui.EndTabItem()
        end
        ui.EndTabBar()
    end
    ui.EndChild()
end
