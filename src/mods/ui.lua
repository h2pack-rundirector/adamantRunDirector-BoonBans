local uiStyle = import("mods/ui/ui_style.lua")
local deps = ...
local controlDeclarations = deps.controlDeclarations
local uiRoots = import("mods/ui/ui_roots.lua", nil, { style = uiStyle })
local uiDeps = {
    style = uiStyle,
    roots = uiRoots,
}
local olympiansUi = import("mods/ui/ui_olympians.lua", nil, uiDeps)
local hammersUi = import("mods/ui/ui_hammers.lua", nil, uiDeps)
local npcsUi = import("mods/ui/ui_npcs.lua", nil, uiDeps)
local otherGodsUi = import("mods/ui/ui_other_gods.lua", nil, uiDeps)

local module = {}

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

local function collectControlNames()
    local controlNames = {}
    for controlName in pairs(controlDeclarations or {}) do
        controlNames[#controlNames + 1] = controlName
    end
    table.sort(controlNames)
    return controlNames
end

local CONTROL_NAMES = collectControlNames()

local function resetAllRarity(controls)
    local changed = false
    for _, controlName in ipairs(CONTROL_NAMES) do
        local source = controls.get(controlName)
        if source:hasRarity() and source:resetRarity() then
            changed = true
        end
    end
    return changed
end

local function resetAllBans(host, controls)
    local changed = false
    for _, controlName in ipairs(CONTROL_NAMES) do
        local source = controls.get(controlName)
        if source:resetAllTiers() then
            changed = true
        end
    end
    if changed then
        host.logIf("[Micro] Global Ban Reset triggered.")
    end
    return changed
end

local function drawSettingsTab(host, ui)
    local draw = ui.draw
    local dataRefs = ui.data
    local imgui = draw.imgui

    draw.widgets.dropdown(dataRefs.get("ImproveFirstNBoonRarity"), FIRST_N_RARITY_DROPDOWN_OPTS)

    imgui.Spacing()
    if draw.widgets.confirmButton("boon_bans_reset_all_bans", "RESET ALL BANS (Global)", RESET_ALL_BANS_CONFIRM_OPTS) then
        resetAllBans(host, ui.controls)
    end

    if draw.widgets.confirmButton("boon_bans_reset_all_rarity", "RESET ALL RARITY (Global)", RESET_ALL_RARITY_CONFIRM_OPTS) then
        resetAllRarity(ui.controls)
    end
end

function module.drawTab(host, ui)
    local draw = ui.draw
    local imgui = draw.imgui

    if not imgui.BeginTabBar("BoonBansLeanTabs") then
        return false
    end

    if imgui.BeginTabItem("Olympians") then
        olympiansUi.draw(host, ui)
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem("Other Gods") then
        otherGodsUi.draw(host, ui)
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem("Hammers") then
        hammersUi.draw(host, ui)
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem("NPCs") then
        npcsUi.draw(host, ui)
        imgui.EndTabItem()
    end

    if imgui.BeginTabItem("Settings") then
        drawSettingsTab(host, ui)
        imgui.EndTabItem()
    end

    imgui.EndTabBar()
    return false
end

function module.drawQuickContent(host, ui)
    local draw = ui.draw
    if draw.widgets.confirmButton("boon_bans_quick_reset_all", "Reset To Default", QUICK_RESET_ALL_CONFIRM_OPTS) then
        local changed = ui.controls.resetAll()
        if changed then
            host.logIf("[Micro] Global Control Reset triggered.")
        end
    end
end

function module.attach(host)
    host.ui.tab(module.drawTab)
    host.ui.quickContent(module.drawQuickContent)
end

return module
