local mods = rom.mods
mods["SGG_Modding-ENVY"].auto()

---@diagnostic disable: lowercase-global
rom = rom
_PLUGIN = _PLUGIN
game = rom.game
modutil = mods["SGG_Modding-ModUtil"]
local chalk = mods["SGG_Modding-Chalk"]
local reload = mods["SGG_Modding-ReLoad"]
---@module "adamant-ModpackLib"
---@type AdamantModpackLib
lib = mods["adamant-ModpackLib"]

local config = chalk.auto("config.lua")

local PACK_ID = "run-director"
local MODULE_ID = "BoonBans"
local PLUGIN_GUID = _PLUGIN.guid

local function init()
    import_as_fallback(rom.game)
    local data = import("mods/data.lua")
    local godAvailability = import("mods/cache/god_availability.lua").create()
    data.godAvailability = godAvailability
    local logic = import("mods/logic.lua").bind(data)
    local uiCommands = import("mods/ui/ui_commands.lua").create(data)
    local ui = import("mods/ui.lua").bind(data, uiCommands)

    local host, store = lib.createModule({
        pluginGuid = PLUGIN_GUID,
        config = config,
        modpack = PACK_ID,
        id = MODULE_ID,
        name = "Boon Bans",
        tooltip = "Ban boon offerings and force rarity behavior.",
        storage = data.storage,
        actions = {
            clearFilter = function(state)
                uiCommands.ClearFilter(state)
            end,
            banAll = function(state, services, banPoolKey)
                uiCommands.BanAllGodBans(banPoolKey, state, services)
            end,
            resetBans = function(state, services, banPoolKey)
                uiCommands.ResetGodBans(banPoolKey, state, services)
            end,
            resetAllBans = function(state, services)
                uiCommands.ResetAllBans(state, services)
            end,
            resetAllRarity = function(state)
                uiCommands.ResetAllRarity(state)
            end,
            resetAllControls = function(state, services)
                uiCommands.ResetAllControls(state, services)
            end,
        },
        drawTab = ui.drawTab,
        drawQuickContent = ui.drawQuickContent,
    })
    if not host then
        return
    end

    host.fallbackUi.attachGuiOnce(function(fallbackUi)
        rom.gui.add_imgui(fallbackUi.renderWindow)
        rom.gui.add_to_menu_bar(fallbackUi.addMenuBar)
    end)
    logic.registerHooks(host, store)
    local ok = host.activate()
    if not ok then
        return
    end
end

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(nil, init)
end)
