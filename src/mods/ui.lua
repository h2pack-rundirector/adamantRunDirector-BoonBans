local module = {}
local uiActions = nil
local olympiansUi = nil
local hammersUi = nil
local npcsUi = nil
local otherGodsUi = nil

local FIRST_N_RARITY_DROPDOWN_OPTS = {
    label = "Force First N Boons to Be Epic",
    values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
    controlWidth = 60,
}

local function DrawSettingsTab(draw, data, services)
    local imgui = draw.imgui

    draw.widgets.dropdown(data.get("ImproveFirstNBoonRarity"), FIRST_N_RARITY_DROPDOWN_OPTS)

    imgui.Spacing()
    draw.widgets.confirmButton("boon_bans_reset_all_bans", "RESET ALL BANS (Global)", {
        confirmLabel = "Confirm RESET ALL BANS",
        onConfirm = function()
            uiActions.ResetAllBans(data, services)
        end,
    })
    draw.widgets.confirmButton("boon_bans_reset_all_rarity", "RESET ALL RARITY (Global)", {
        confirmLabel = "Confirm RESET ALL RARITY",
        onConfirm = function()
            uiActions.ResetAllRarity(data)
        end,
    })
end

function module.drawTab(draw, data, _, services)
    local imgui = draw.imgui

    if not imgui.BeginTabBar("BoonBansLeanTabs") then
        return false
    end

    if imgui.BeginTabItem("Olympians") then
        olympiansUi.draw(draw, data, services)
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem("Other Gods") then
        otherGodsUi.draw(draw, data, services)
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem("Hammers") then
        hammersUi.draw(draw, data, services)
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem("NPCs") then
        npcsUi.draw(draw, data, services)
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem("Settings") then
        DrawSettingsTab(draw, data, services)
        imgui.EndTabItem()
    end

    imgui.EndTabBar()
    return false
end

function module.drawQuickContent(draw, data, _, services)
    draw.widgets.confirmButton("boon_bans_quick_reset_all", "Reset To Default", {
        confirmLabel = "Confirm Reset All",
        onConfirm = function()
            uiActions.ResetAllControls(data, services)
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
