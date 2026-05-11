local internal = RunDirectorBoonBans_Internal

function internal.RegisterHooks(host, store)
    local runStateModule = import("mods/logic/run_state.lua")
    local banResolverModule = import("mods/logic/ban_resolver.lua")
    import("mods/logic/acquisition.lua")
    import("mods/logic/npc_logic.lua")
    import("mods/logic/loot_logic.lua")

    local runState = runStateModule.create(store)
    local banResolver = banResolverModule.create(
        internal.catalog,
        internal.banPools,
        internal.banConfig,
        store,
        runState,
        internal.godDefs
    )

    host.logIf("[Micro] GodCatalog populated.")
    internal.RegisterAcquisitionHooks(host, runState, banResolver)
    internal.RegisterNpcHooks(host, store, banResolver)
    internal.RegisterLootHooks(host, store, runState, banResolver)
end

return internal
