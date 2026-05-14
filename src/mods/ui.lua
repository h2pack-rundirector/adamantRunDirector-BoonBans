local module = {}
local uiActions = nil
local olympiansUi = nil
local hammersUi = nil
local npcsUi = nil
local otherGodsUi = nil

local function DrawSettingsTab(ui, session, host)
    lib.widgets.dropdown(ui, session, "ImproveFirstNBoonRarity", {
        label = "Force First N Boons to Be Epic",
        values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
        controlWidth = 60,
    })

    ui.Spacing()
    lib.widgets.confirmButton(ui, session, "boon_bans_reset_all_bans", "RESET ALL BANS (Global)", {
        confirmLabel = "Confirm RESET ALL BANS",
        onConfirm = function()
            uiActions.ResetAllBans(session, host)
        end,
    })
    lib.widgets.confirmButton(ui, session, "boon_bans_reset_all_rarity", "RESET ALL RARITY (Global)", {
        confirmLabel = "Confirm RESET ALL RARITY",
        onConfirm = function()
            uiActions.ResetAllRarity(session)
        end,
    })
end

function module.drawTab(ui, session, host)
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

function module.drawQuickContent(ui, session, host)
    lib.widgets.confirmButton(ui, session, "boon_bans_quick_reset_all", "Reset To Default", {
        confirmLabel = "Confirm Reset All",
        onConfirm = function()
            uiActions.ResetAllControls(session, host)
        end,
    })
end

function module.bind(data)
    local uiModel = import("mods/ui/ui_model.lua").create(data)
    uiActions = import("mods/ui/ui_actions.lua").create(data)
    local uiComponentsModule = import("mods/ui/ui_components.lua")
    local uiComponents = uiComponentsModule.bind(data, uiModel, uiActions)
    local uiDeps = {
        data = data,
        model = uiModel,
        actions = uiActions,
        components = uiComponents,
    }
    olympiansUi = import("mods/ui/ui_olympians.lua").bind(uiDeps)
    hammersUi = import("mods/ui/ui_hammers.lua").bind(uiDeps)
    npcsUi = import("mods/ui/ui_npcs.lua").bind(uiDeps)
    otherGodsUi = import("mods/ui/ui_other_gods.lua").bind(uiDeps)
    return module
end

return module
