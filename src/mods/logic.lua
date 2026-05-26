local logic = {}

function logic.bind(data)
    local runStateModule = import("mods/logic/run_state.lua")
    local banResolverModule = import("mods/logic/ban_resolver.lua")
    local acquisition = import("mods/logic/acquisition.lua").bind(data)
    local npcLogic = import("mods/logic/npc_logic.lua").bind(data)
    local lootLogic = import("mods/logic/loot_logic.lua").bind(data)

    function logic.buildCacheDeclarations()
        return runStateModule.buildCacheDeclarations()
    end

    function logic.registerHooks(host, store)
        local runState = runStateModule.create(store)
        local banResolver = banResolverModule.create(
            data.catalog,
            data.banPools,
            data.banConfig,
            store,
            runState,
            data.godDefs
        )

        host.logIf("[Micro] GodCatalog populated.")
        acquisition.registerHooks(host, runState, banResolver)
        npcLogic.registerHooks(host, store, banResolver)
        lootLogic.registerHooks(host, store, runState, banResolver)
    end

    return logic
end

return logic
