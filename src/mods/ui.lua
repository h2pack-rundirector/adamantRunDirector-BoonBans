local internal = RunDirectorBoonBans_Internal

local uiModel = import("mods/ui/ui_model.lua")
local uiActions = import("mods/ui/ui_actions.lua")
local uiComponents = import("mods/ui/ui_components.lua", nil, uiModel, uiActions)
local uiDeps = {
    model = uiModel,
    actions = uiActions,
    components = uiComponents,
}
local olympiansUi = import("mods/ui/ui_olympians.lua", nil, uiDeps)
local hammersUi = import("mods/ui/ui_hammers.lua", nil, uiDeps)
local npcsUi = import("mods/ui/ui_npcs.lua", nil, uiDeps)
local otherGodsUi = import("mods/ui/ui_other_gods.lua", nil, uiDeps)

local function DrawSettingsTab(ui, session, host)
    lib.widgets.dropdown(ui, session, "ImproveFirstNBoonRarity", {
        label = "Force First N Boons to Be Epic",
        values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
        controlWidth = 60,
    })

    ui.Spacing()
    lib.widgets.confirmButton(ui, "boon_bans_reset_all_bans", "RESET ALL BANS (Global)", {
        confirmLabel = "Confirm RESET ALL BANS",
        onConfirm = function()
            uiActions.ResetAllBans(session, host)
        end,
    })
    lib.widgets.confirmButton(ui, "boon_bans_reset_all_rarity", "RESET ALL RARITY (Global)", {
        confirmLabel = "Confirm RESET ALL RARITY",
        onConfirm = function()
            uiActions.ResetAllRarity(session)
        end,
    })
end

function internal.DrawTab(ui, session, host)
    if not ui.BeginTabBar("BoonBansLeanTabs") then
        return false
    end

    if ui.BeginTabItem("Olympians") then
        olympiansUi.draw(ui, session, host)
        ui.EndTabItem()
    end

    if ui.BeginTabItem("Other Gods") then
        otherGodsUi.draw(ui, session, host)
        ui.EndTabItem()
    end

    if ui.BeginTabItem("Hammers") then
        hammersUi.draw(ui, session, host)
        ui.EndTabItem()
    end

    if ui.BeginTabItem("NPCs") then
        npcsUi.draw(ui, session, host)
        ui.EndTabItem()
    end

    if ui.BeginTabItem("Settings") then
        DrawSettingsTab(ui, session, host)
        ui.EndTabItem()
    end

    ui.EndTabBar()
    return false
end

function internal.DrawQuickContent(ui, session, host)
    lib.widgets.confirmButton(ui, "boon_bans_quick_reset_all", "Reset To Default", {
        confirmLabel = "Confirm Reset All",
        onConfirm = function()
            uiActions.ResetAllControls(session, host)
        end,
    })
end
