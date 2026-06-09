local deps = ...
local moduleRef = deps.module
local traitEligibility = deps.traitEligibility

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
            and not traitEligibility.shouldBlockHadesKeepsakeTrait(runtime, traitName) then
            return true
        end
    end

    return false
end

moduleRef.hooks.wrap("GiveRandomHadesBoonAndBoostBoons", function(host, runtime, base, args, traitData)
    if not host.isEnabled() then
        return base(args, traitData)
    end

    if not shouldFilterHadesKeepsakeTraits(runtime) then
        host.logIf("[Micro] JPom ban filter skipped: no non-banned eligible Hades keepsake traits remain")
        return base(args, traitData)
    end

    return traitEligibility.withJpomFilter(function()
        return base(args, traitData)
    end)
end)
