local internal = RunDirectorBoonBans_Internal
local uiData, components = nil, nil
local banConfig = internal.banConfig
local ACTIVE_OTHER_GOD_ROOT_ALIAS = "ActiveOtherGodRoot"

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

local function BuildOtherGodRoots(session)
    local roots = {}
    for _, spec in ipairs(OTHER_GOD_ROOT_SPECS) do
        roots[#roots + 1] = uiData.BuildBanPoolRoot(spec.id, { session = session })
    end
    return roots
end

local function IsRootCustomized(root, session)
    for _, banPool in ipairs(root.banPools) do
        if banConfig.IsBanPoolCustomized(banPool.key, session) then
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
    components.DrawConfiguredBanPoolControl(ui, session, root)
    for _, banPool in ipairs(root.banPools) do
        components.DrawForceBanRow(ui, session, root, banPool, {
            label = banPool.label == "Bans" and "Force 1" or banPool.label,
        })
    end
end

local function DrawOtherGodsTab(ui, session, host)
    local tabs = {}
    for _, root in ipairs(BuildOtherGodRoots(session)) do
        tabs[#tabs + 1] = {
            key = root.id,
            label = GetNavLabel(root, session),
            color = uiData.GetGodColor(root.primaryGodKey),
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
        if #root.banPools > 1 and ui.BeginTabItem("Setup") then
            DrawForcePanel(ui, session, root)
            ui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if ui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(ui, session, host, banPool.key, "other_gods")
                ui.EndTabItem()
            end
        end
        if root.hasRarity and ui.BeginTabItem("Rarity") then
            components.DrawRarityPanel(ui, session, root)
            ui.EndTabItem()
        end
        ui.EndTabBar()
    end
    ui.EndChild()
end

local module = {}

function module.bind(deps)
    uiData = deps.model
    components = deps.components
    return module
end

module.draw = DrawOtherGodsTab

return module
