local data = ...

local runStateModule = import("mods/logic/run_state.lua")
local features = data and data.features or {}

local logic = {}

function logic.defineCache(module)
    module.cache.define(runStateModule.buildCacheDeclarations())
end

function logic.attachHooks(module)
    local runState = runStateModule.create()
    local padding = features.privatePadding == true and import("mods/logic/padding.lua") or nil
    local traitInfo = import("mods/logic/trait_info.lua", nil, {
        sourceResolver = data.sourceResolver,
        runState = runState,
    })
    local traitEligibility = import("mods/logic/trait_eligibility.lua", nil, {
        traitInfo = traitInfo,
    })

    module.logIf("[Micro] Boon source data populated.")

    local baseDeps = {
        module = module,
        runState = runState,
        traitInfo = traitInfo,
        traitEligibility = traitEligibility,
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
        traitEligibility = traitEligibility,
        padding = padding,
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
