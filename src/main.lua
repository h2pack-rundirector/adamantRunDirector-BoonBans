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

    local module = lib.createModule({
        pluginGuid = PLUGIN_GUID,
        config = config,
        modpack = PACK_ID,
        id = MODULE_ID,
        name = "Boon Bans",
        tooltip = "Ban boon offerings and force rarity behavior.",
    })
    if not module then
        return
    end

    module.data.define(data.storage)
    module.cache.define(logic.buildCacheDeclarations())
    module.actions.define({
        clearFilter = function(host, uiData)
            uiCommands.ClearFilter(uiData)
        end,
        banAll = function(host, uiData, _, banPoolKey)
            uiCommands.BanAllGodBans(banPoolKey, uiData, host)
        end,
        resetBans = function(host, uiData, _, banPoolKey)
            uiCommands.ResetGodBans(banPoolKey, uiData, host)
        end,
        resetAllBans = function(host, uiData)
            uiCommands.ResetAllBans(uiData, host)
        end,
        resetAllRarity = function(host, uiData)
            uiCommands.ResetAllRarity(uiData)
        end,
        resetAllControls = function(host, uiData)
            uiCommands.ResetAllControls(uiData, host)
        end,
    })
    module.ui.tab(ui.drawTab)
    module.ui.quickContent(ui.drawQuickContent)

    module.fallbackUi.attachGuiOnce(function(fallbackUi)
        rom.gui.add_imgui(fallbackUi.renderWindow)
        rom.gui.add_to_menu_bar(fallbackUi.addMenuBar)
    end)
    godAvailability.registerShared(module)
    logic.registerHooks(module)
    local ok = module.activate()
    if not ok then
        return
    end
end

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(nil, init)
end)
