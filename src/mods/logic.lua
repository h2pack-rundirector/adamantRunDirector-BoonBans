local data = ...

local runStateModule = import("mods/logic/run_state.lua")

local logic = {}

function logic.defineCache(module)
    module.cache.define(runStateModule.buildCacheDeclarations())
end

function logic.attachHooks(module)
    local runState = runStateModule.create()
    local padding = import("mods/logic/padding.lua")
    local traitInfo = import("mods/logic/trait_info.lua", nil, {
        sourceResolver = data.sourceResolver,
        runState = runState,
    })

    module.logIf("[Micro] Boon source data populated.")

    local baseDeps = {
        module = module,
        runState = runState,
        traitInfo = traitInfo,
        padding = padding,
    }
    local offerContext = {
        scratchKey = "lootOffers",
    }

    import("mods/logic/acquisition.lua", nil, {
        module = module,
        runState = runState,
        traitInfo = traitInfo,
    })
    import("mods/logic/filtering_bnb.lua", nil, baseDeps)
    import("mods/logic/filtering_crd.lua", nil, baseDeps)
    import("mods/logic/filtering_hex.lua", nil, baseDeps)
    import("mods/logic/filtering_jpom.lua", nil, baseDeps)
    import("mods/logic/filtering_judgement.lua", nil, baseDeps)
    import("mods/logic/filtering_npc.lua", nil, baseDeps)
    import("mods/logic/trait_offer_filtering.lua", nil, {
        module = module,
        runState = runState,
        traitInfo = traitInfo,
        offerContext = offerContext,
    })
    import("mods/logic/trait_offer_finalization.lua", nil, {
        module = module,
        runState = runState,
        traitInfo = traitInfo,
        offerContext = offerContext,
    })
    import("mods/logic/rarity_first_n_boons.lua", nil, baseDeps)
    import("mods/logic/bridal_glow.lua", nil, baseDeps)
end

return logic
