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
        if uiData.IsScopeCustomized(scope.key, session) then
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

local function DrawForcePanel(ui, session, root)
    lib.widgets.text(ui, "Setup")
    lib.widgets.separator(ui)
    internal.DrawConfiguredTierControl(ui, session, root)
    for _, scope in ipairs(root.scopes) do
        internal.DrawForceBanRow(ui, session, root, scope, {
            label = scope.label == "Bans" and "Force 1" or scope.label,
        })
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
                internal.DrawBanPanel(ui, session, scope.key, "other_gods")
                ui.EndTabItem()
            end
        end
        if root.hasRarity and ui.BeginTabItem("Rarity") then
            internal.DrawRarityPanel(ui, session, root)
            ui.EndTabItem()
        end
        ui.EndTabBar()
    end
    ui.EndChild()
end
