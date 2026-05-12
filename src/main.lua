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

MODULE_ANCHOR = MODULE_ANCHOR or {}
local moduleAnchor = MODULE_ANCHOR

moduleAnchor.standaloneUi = nil

local function registerGui()
    rom.gui.add_imgui(function()
        if moduleAnchor.standaloneUi and moduleAnchor.standaloneUi.renderWindow then
            moduleAnchor.standaloneUi.renderWindow()
        end
    end)

    rom.gui.add_to_menu_bar(function()
        if moduleAnchor.standaloneUi and moduleAnchor.standaloneUi.addMenuBar then
            moduleAnchor.standaloneUi.addMenuBar()
        end
    end)
end

local function init()
    import_as_fallback(rom.game)
    local data = import("mods/data.lua")
    local logic = import("mods/logic.lua").bind(data)
    local ui = import("mods/ui.lua").bind(data)

    local host = lib.createModule({
        owner = moduleAnchor,
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
    host.activate()
    if not lib.isModuleCoordinated(PACK_ID) then
        moduleAnchor.standaloneUi = lib.standaloneHost(PLUGIN_GUID)
    else
        moduleAnchor.standaloneUi = nil
    end
end

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(registerGui, init)
end)
