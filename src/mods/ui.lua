local internal = RunDirectorBoonBans_Internal

internal.ui = internal.ui or {}
local uiData = internal.ui

import("mods/ui/ui_utilities.lua")
import("mods/ui/ui_shared.lua")
import("mods/ui/ui_olympians.lua")
import("mods/ui/ui_hammers.lua")
import("mods/ui/ui_npcs.lua")
import("mods/ui/ui_other_gods.lua")

function internal.DrawBanSearchControls(ui, session, idSuffix)
    idSuffix = tostring(idSuffix or "")

    ui.AlignTextToFramePadding()
    ui.Text("Filter:")
    ui.SameLine()
    lib.widgets.inputText(ui, session, uiData.BAN_FILTER_TEXT_ALIAS, {
        label = "",
        controlWidth = 180,
    })
    ui.SameLine()
    lib.widgets.button(ui, "Clear", {
        id = "boon_bans_filter_clear_" .. idSuffix,
        onClick = function()
            session.reset(uiData.BAN_FILTER_TEXT_ALIAS)
        end,
    })
end

function internal.DrawFilteredPackedBanList(ui, session, scopeKey, opts)
    opts = opts or {}
    local filterText = tostring(session and session.view and session.view[uiData.BAN_FILTER_TEXT_ALIAS] or "")
    local handle, bindAlias = internal.ResolveBanBinding(scopeKey, session)
    if not handle or not bindAlias then
        return
    end

    lib.widgets.packedCheckboxList(ui, handle, bindAlias, {
        valueColors = opts.valueColors or uiData.BuildPackedBanValueColors(scopeKey),
        slotCount = opts.slotCount or #(uiData.GetScopeBoons(scopeKey) or uiData.EMPTY_LIST),
        filterText = filterText,
    })

    if uiData.GetVisibleBanCount(scopeKey, session) == 0 then
        lib.widgets.text(ui, "No boons match the current filter.", {
            color = uiData.MUTED_TEXT_COLOR,
        })
    end
end

function internal.ResetAllControls(session, host)
    local bansChanged = internal.uiUtilities.ResetAllBans(session, host)
    internal.uiUtilities.ResetAllRarity(session)
    if bansChanged then
        internal.uiUtilities.RecalculateBannedCounts(session, host)
    end
end

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
            local bansChanged = internal.uiUtilities.ResetAllBans(session, host)
            if bansChanged then
                internal.uiUtilities.RecalculateBannedCounts(session, host)
            end
        end,
    })
    lib.widgets.confirmButton(ui, "boon_bans_reset_all_rarity", "RESET ALL RARITY (Global)", {
        confirmLabel = "Confirm RESET ALL RARITY",
        onConfirm = function()
            internal.uiUtilities.ResetAllRarity(session)
        end,
    })
end

function internal.DrawTab(ui, session, host)
    if not ui.BeginTabBar("BoonBansLeanTabs") then
        return false
    end

    if ui.BeginTabItem("Olympians") then
        internal.DrawOlympiansTab(ui, session, host)
        ui.EndTabItem()
    end

    if ui.BeginTabItem("Other Gods") then
        internal.DrawOtherGodsTab(ui, session, host)
        ui.EndTabItem()
    end

    if ui.BeginTabItem("Hammers") then
        internal.DrawHammersTab(ui, session, host)
        ui.EndTabItem()
    end

    if ui.BeginTabItem("NPCs") then
        internal.DrawNpcsTab(ui, session, host)
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
            internal.ResetAllControls(session, host)
        end,
    })
end
