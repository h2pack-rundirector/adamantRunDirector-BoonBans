local internal = RunDirectorBoonBans_Internal

function internal.RegisterHooks(host, store)
    _G.bit32 = require("bit32")

    import("mods/logic/ban_config_view.lua")
    import("mods/logic/runtime_utilities.lua")

    import("mods/logic/runtime_state.lua")
    import("mods/logic/acquisition.lua")
    import("mods/logic/npc_logic.lua")
    import("mods/logic/loot_logic.lua")

    internal.RegisterRuntimeState(host, store)
    internal.RegisterAcquisitionHooks(host)
    internal.RegisterNpcHooks(host, store)
    internal.RegisterLootHooks(host, store)
end

return internal
