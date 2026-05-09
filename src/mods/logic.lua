local internal = RunDirectorBoonBans_Internal

function internal.RegisterHooks(store, host)
    _G.bit32 = require("bit32")

    import("mods/logic/utilities.lua")
    local access = internal.MakeStorageAccess(store)
    local isEnabled = host.isEnabled

    import("mods/logic/runtime_state.lua")
    import("mods/logic/acquisition.lua")
    import("mods/logic/npc_logic.lua")
    import("mods/logic/loot_logic.lua")

    internal.RegisterRuntimeState(access)
    internal.RegisterAcquisitionHooks(isEnabled)
    internal.RegisterNpcHooks(access, isEnabled)
    internal.RegisterLootHooks(access, isEnabled)
end

return internal
