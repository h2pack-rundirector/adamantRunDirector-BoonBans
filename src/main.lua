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
    local godAvailability = import("mods/shared/god_availability.lua")
    local logic = import("mods/logic.lua", nil, data)
    local ui = import("mods/ui.lua", nil, {
        controlDeclarations = data.controls,
        features = data.features,
    })

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
    module.controls.defineTemplates(data.controlTemplates)
    module.controls.define(data.controls)

    
    godAvailability.attach(module)
    logic.defineCache(module)
    logic.attachHooks(module)
    ui.attach(module)

    module.fallbackUi.attachGuiOnce(function(fallbackUi)
        rom.gui.add_imgui(fallbackUi.renderWindow)
        rom.gui.add_to_menu_bar(fallbackUi.addMenuBar)
    end)
    local ok = module.activate()
    if not ok then
        return
    end
end

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(nil, init)
end)
