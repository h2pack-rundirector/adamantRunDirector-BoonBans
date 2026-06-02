local deps = ...
local moduleRef = deps.module
local traitInfo = deps.traitInfo

local function shouldBlockHadesKeepsakeTrait(runtime, traitName)
    local _, info = traitInfo.resolveCurrentTrait(runtime, traitName)
    if not info or info.tierKey ~= "Hades" then
        return false
    end

    local keepsake = traitInfo.hadesKeepsake(runtime)
    return keepsake ~= nil and keepsake:isBanned(traitName, 1) == true
end

moduleRef.hooks.contextWrap("GiveRandomHadesBoonAndBoostBoons", function(host, runtime, context)
    if not host.isEnabled() then
        return
    end

    context.wrap("IsTraitEligible", function(base, traitData, args)
        if shouldBlockHadesKeepsakeTrait(runtime, traitData.Name) then
            host.logIf("[Micro] JPom IsTraitEligible BLOCKED: %s", traitData.Name)
            return false
        end

        return base(traitData, args)
    end)
end)
