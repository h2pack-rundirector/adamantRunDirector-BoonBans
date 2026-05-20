local uiData, components = nil, nil
local banConfig = nil
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

local function DrawForcePanel(draw, root)
    draw.widgets.text("Setup")
    draw.widgets.separator()
    components.DrawConfiguredBanPoolControl(draw, root)
    for _, banPool in ipairs(root.banPools) do
        components.DrawForceBanRow(draw, root, banPool, {
            label = banPool.label == "Bans" and "Force 1" or banPool.label,
        })
    end
end

local function DrawOtherGodsTab(draw)
    local imgui = draw.imgui
    local session = draw.session
    local tabs = {}
    for _, root in ipairs(BuildOtherGodRoots(session)) do
        tabs[#tabs + 1] = {
            key = root.id,
            label = GetNavLabel(root, session),
            color = uiData.GetGodColor(root.primaryGodKey),
        }
    end

    local activeRootId = draw.nav.verticalTabs({
        id = "BoonBansOtherGodsTabs",
        navWidth = uiData.ROOT_NAV_WIDTH,
        tabs = tabs,
        activeKey = session.view[ACTIVE_OTHER_GOD_ROOT_ALIAS],
    })
    if activeRootId ~= session.view[ACTIVE_OTHER_GOD_ROOT_ALIAS] then
        session.write(ACTIVE_OTHER_GOD_ROOT_ALIAS, activeRootId)
    end

    local root = GetActiveRoot(session)

    imgui.BeginChild("BoonBansOtherGodsDetail", 0, 0, false)
    if imgui.BeginTabBar("BoonBansOtherGodsViews##" .. root.id) then
        if #root.banPools > 1 and imgui.BeginTabItem("Setup") then
            DrawForcePanel(draw, root)
            imgui.EndTabItem()
        end
        for _, banPool in ipairs(root.banPools) do
            if imgui.BeginTabItem(banPool.label) then
                components.DrawBanPanel(draw, banPool.key, "other_gods")
                imgui.EndTabItem()
            end
        end
        if root.hasRarity and imgui.BeginTabItem("Rarity") then
            components.DrawRarityPanel(draw, root)
            imgui.EndTabItem()
        end
        imgui.EndTabBar()
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

module.draw = DrawOtherGodsTab

return module
