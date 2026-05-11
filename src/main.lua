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
---@class RunDirectorBoonBansInternal
---@field standaloneUi StandaloneRuntime|nil
---@field RegisterHooks fun(host: AuthorHost, store: ManagedStore)|nil
---@field DrawTab fun(imgui: table, session: AuthorSession, host: AuthorHost)|nil
---@field DrawQuickContent fun(imgui: table, session: AuthorSession, host: AuthorHost)|nil
RunDirectorBoonBans_Internal = RunDirectorBoonBans_Internal or {}
---@type RunDirectorBoonBansInternal
local internal = RunDirectorBoonBans_Internal

internal.standaloneUi = nil

local function registerGui()
    rom.gui.add_imgui(function()
        if internal.standaloneUi and internal.standaloneUi.renderWindow then
            internal.standaloneUi.renderWindow()
        end
    end)

    rom.gui.add_to_menu_bar(function()
        if internal.standaloneUi and internal.standaloneUi.addMenuBar then
            internal.standaloneUi.addMenuBar()
        end
    end)
end

local function init()
    import_as_fallback(rom.game)
    import("mods/data.lua")
    import("mods/logic.lua")
    import("mods/ui.lua")

    local host = lib.createModule({
        owner = internal,
        pluginGuid = PLUGIN_GUID,
        config = config,
        definition = {
            modpack = PACK_ID,
            id = MODULE_ID,
            name = "Boon Bans",
            tooltip = "Ban boon offerings and force rarity behavior.",
            storage = internal.storage,
        },
        registerHooks = internal.RegisterHooks,
        drawTab = internal.DrawTab,
        drawQuickContent = internal.DrawQuickContent,
    })
    host.activate()
    if not lib.isModuleCoordinated(PACK_ID) then
        internal.standaloneUi = lib.standaloneHost(PLUGIN_GUID)
    else
        internal.standaloneUi = nil
    end
end

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(registerGui, init)
end)
