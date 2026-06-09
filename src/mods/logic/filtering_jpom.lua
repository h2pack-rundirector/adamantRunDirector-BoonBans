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

local function getHadesKeepsakeTraitNames()
    local hadesData = UnitSetData
        and UnitSetData.NPC_Hades
        and UnitSetData.NPC_Hades.NPC_Hades_Field_01

    return hadesData and hadesData.Traits or nil
end

local function isVanillaEligible(traitName)
    local traitData = TraitData and TraitData[traitName] or nil
    return traitData ~= nil and IsTraitEligible(traitData) == true
end

local function shouldFilterHadesKeepsakeTraits(runtime)
    local traits = getHadesKeepsakeTraitNames()
    if traits == nil then
        return false
    end

    for _, traitName in pairs(traits) do
        if not HeroHasTrait(traitName)
            and isVanillaEligible(traitName)
            and not shouldBlockHadesKeepsakeTrait(runtime, traitName) then
            return true
        end
    end

    return false
end

moduleRef.hooks.contextWrap("GiveRandomHadesBoonAndBoostBoons", function(host, runtime, context)
    if not host.isEnabled() then
        return
    end

    if not shouldFilterHadesKeepsakeTraits(runtime) then
        host.logIf("[Micro] JPom ban filter skipped: no non-banned eligible Hades keepsake traits remain")
        return
    end

    context.wrap("IsTraitEligible", function(base, traitData, args)
        if not traitData or not traitData.Name then
            return base(traitData, args)
        end

        if shouldBlockHadesKeepsakeTrait(runtime, traitData.Name) then
            host.logIf("[Micro] JPom IsTraitEligible BLOCKED: %s", traitData.Name)
            return false
        end

        return base(traitData, args)
    end)
end)
