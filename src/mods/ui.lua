local module = {}
local uiCommands = nil
local olympiansUi = nil
local hammersUi = nil
local npcsUi = nil
local otherGodsUi = nil

local FIRST_N_RARITY_DROPDOWN_OPTS = {
    label = "Force First N Boons to Be Epic",
    values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
    controlWidth = 60,
}
local RESET_ALL_BANS_CONFIRM_OPTS = {
    confirmLabel = "Confirm RESET ALL BANS",
}
local RESET_ALL_RARITY_CONFIRM_OPTS = {
    confirmLabel = "Confirm RESET ALL RARITY",
}
local QUICK_RESET_ALL_CONFIRM_OPTS = {
    confirmLabel = "Confirm Reset All",
}

local function DrawSettingsTab(draw, state, actions)
    local imgui = draw.imgui

    draw.widgets.dropdown(state.get("ImproveFirstNBoonRarity"), FIRST_N_RARITY_DROPDOWN_OPTS)

    imgui.Spacing()
    RESET_ALL_BANS_CONFIRM_OPTS.action = actions.get("resetAllBans")
    draw.widgets.confirmButton("boon_bans_reset_all_bans", "RESET ALL BANS (Global)", RESET_ALL_BANS_CONFIRM_OPTS)

    RESET_ALL_RARITY_CONFIRM_OPTS.action = actions.get("resetAllRarity")
    draw.widgets.confirmButton("boon_bans_reset_all_rarity", "RESET ALL RARITY (Global)", RESET_ALL_RARITY_CONFIRM_OPTS)
end

function module.drawTab(_, ui)
    local draw = ui.draw
    local state = ui.data
    local actions = ui.actions
    local imgui = draw.imgui

    if not imgui.BeginTabBar("BoonBansLeanTabs") then
        return false
    end

    if imgui.BeginTabItem("Olympians") then
        olympiansUi.draw(draw, state, actions)
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem("Other Gods") then
        otherGodsUi.draw(draw, state, actions)
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem("Hammers") then
        hammersUi.draw(draw, state, actions)
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem("NPCs") then
        npcsUi.draw(draw, state, actions)
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem("Settings") then
        DrawSettingsTab(draw, state, actions)
        imgui.EndTabItem()
    end

    imgui.EndTabBar()
    return false
end

function module.drawQuickContent(_, ui)
    local draw = ui.draw
    local actions = ui.actions
    QUICK_RESET_ALL_CONFIRM_OPTS.action = actions.get("resetAllControls")
    draw.widgets.confirmButton("boon_bans_quick_reset_all", "Reset To Default", QUICK_RESET_ALL_CONFIRM_OPTS)
end

function module.bind(state, commands)
    local uiModel = import("mods/ui/ui_model.lua").create(state)
    uiCommands = commands or import("mods/ui/ui_commands.lua").create(state)
    local uiComponentsModule = import("mods/ui/ui_components.lua")
    local uiComponents = uiComponentsModule.bind(state, uiModel, uiCommands)
    local uiDeps = {
        state = state,
        model = uiModel,
        commands = uiCommands,
        components = uiComponents,
        godAvailability = state.godAvailability,
    }
    olympiansUi = import("mods/ui/ui_olympians.lua").bind(uiDeps)
    hammersUi = import("mods/ui/ui_hammers.lua").bind(uiDeps)
    npcsUi = import("mods/ui/ui_npcs.lua").bind(uiDeps)
    otherGodsUi = import("mods/ui/ui_other_gods.lua").bind(uiDeps)
    return module
end

return module
