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
local standaloneUi = lib.standaloneUiBridge(PLUGIN_GUID)

local function registerGui()
    rom.gui.add_imgui(standaloneUi.renderWindow)
    rom.gui.add_to_menu_bar(standaloneUi.addMenuBar)
end

local function init()
    import_as_fallback(rom.game)
    local data = import("mods/data.lua")
    local logic = import("mods/logic.lua").bind(data)
    local ui = import("mods/ui.lua").bind(data)

    local host = lib.tryCreateModule({
        pluginGuid = PLUGIN_GUID,
        config = config,
        definition = {
            modpack = PACK_ID,
            id = MODULE_ID,
            name = "Boon Bans",
            tooltip = "Ban boon offerings and force rarity behavior.",
            storage = data.storage,
        },
        registerHooks = logic.registerHooks,
        drawTab = ui.drawTab,
        drawQuickContent = ui.drawQuickContent,
    })
    if not host then
        return
    end

    local ok = host.tryActivate()
    if not ok then
        return
    end

    lib.standaloneHost(PLUGIN_GUID)
end

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(registerGui, init)
end)
