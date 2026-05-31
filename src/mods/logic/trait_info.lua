local deps = ...
local sourceResolver = deps.sourceResolver
local runState = deps.runState

local traitInfo = {}
local controlCache = {}

local function resolveInfo(runtime, info)
    if not info then
        return nil, nil
    end

    local controlName = info.controlName
    if not controlName then
        return nil, info
    end
    if controlCache[controlName] ~= nil then
        return controlCache[controlName], info
    end

    local source = runtime.controls.get(controlName)
    if source then
        controlCache[controlName] = source
    end
    return source, info
end

function traitInfo.lookupLoot(lootName)
    return sourceResolver.infoFromLoot(lootName)
end

function traitInfo.lookupTrait(traitName)
    return sourceResolver.infoFromTrait(traitName)
end

function traitInfo.resolveLoot(runtime, lootName)
    return resolveInfo(runtime, traitInfo.lookupLoot(lootName))
end

function traitInfo.primarySourceName(sourceName)
    return sourceResolver.primarySourceName(sourceName)
end

local function lookupTraitInSource(traitName, sourceInfo, tierIndex)
    local controlName = sourceInfo and sourceInfo.controlName or nil
    return sourceResolver.infoFromTrait(traitName, controlName, tierIndex)
end

function traitInfo.currentTierIndex(runtime, sourceInfo)
    local controlName = sourceInfo and sourceInfo.controlName or nil
    return runState.getBanPoolIndex(runtime, controlName)
end

function traitInfo.resolveTrait(runtime, traitName, sourceInfo, tierIndex)
    return resolveInfo(runtime, lookupTraitInSource(traitName, sourceInfo, tierIndex))
end

function traitInfo.resolveCurrentTrait(runtime, traitName)
    local info = traitInfo.lookupTrait(traitName)
    if not info or not runtime then
        return resolveInfo(runtime, info)
    end

    local currentTierIndex = traitInfo.currentTierIndex(runtime, info)
    if not currentTierIndex then
        return resolveInfo(runtime, info)
    end

    local currentInfo = lookupTraitInSource(traitName, info, currentTierIndex) or info
    return resolveInfo(runtime, currentInfo)
end

function traitInfo.isBanned(traitName, runtime, sourceInfo, tierIndex)
    local source, info
    if sourceInfo then
        source, info = traitInfo.resolveTrait(runtime, traitName, sourceInfo, tierIndex)
    else
        source, info = traitInfo.resolveCurrentTrait(runtime, traitName)
    end
    if not info then
        return false, nil
    end

    if not source then
        return false, info
    end

    return source:isBanned(traitName, info.tierIndex or 1) == true, info
end

function traitInfo.blackNightBanishment(runtime)
    return resolveInfo(runtime, sourceResolver.specialSource("blackNightBanishment"))
end

function traitInfo.hadesKeepsake(runtime)
    return resolveInfo(runtime, sourceResolver.specialSource("hadesKeepsake"))
end

function traitInfo.redCitrineDivination(runtime)
    return resolveInfo(runtime, sourceResolver.specialSource("redCitrineDivination"))
end

function traitInfo.judgement(runtime, clearedBiomes)
    return resolveInfo(runtime, sourceResolver.judgementSource(clearedBiomes))
end

return traitInfo
