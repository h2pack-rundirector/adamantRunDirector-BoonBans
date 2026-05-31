local deps = ...
local sourceResolver = deps.sourceResolver
local runState = deps.runState

local traitInfo = {}

local function getSourceControl(runtime, controlName, cache)
    if not controlName then
        return nil
    end
    if cache and cache[controlName] ~= nil then
        return cache[controlName]
    end

    local source = runtime.controls.get(controlName)
    if cache then
        cache[controlName] = source
    end
    return source
end

function traitInfo.controlFromLoot(lootName)
    return sourceResolver.fromLootName(lootName)
end

function traitInfo.primarySourceName(sourceName)
    return sourceResolver.primarySourceName(sourceName)
end

function traitInfo.controlFromTrait(traitName, opts)
    opts = opts or {}
    return sourceResolver.fromTraitName(traitName, {
        controlName = opts.controlName or opts.sourceName or opts.filterGodKey,
        tierIndex = opts.tierIndex or opts.banPoolIndex,
    })
end

function traitInfo.currentControlFromTrait(traitName, runtime, opts)
    opts = opts or {}
    local info = traitInfo.controlFromTrait(traitName, {
        controlName = opts.controlName or opts.filterGodKey,
        tierIndex = opts.tierIndex or opts.banPoolIndex,
    })
    if not info or opts.banPoolIndex or opts.tierIndex or not runtime then
        return info
    end

    local currentTierIndex = runState.getBanPoolIndex(runtime, info.controlName)
    if not currentTierIndex then
        return info
    end

    return traitInfo.controlFromTrait(traitName, {
        controlName = info.controlName,
        tierIndex = currentTierIndex,
    }) or info
end

function traitInfo.isBanned(traitName, runtime, opts)
    opts = opts or {}
    local info = traitInfo.currentControlFromTrait(traitName, runtime, {
        controlName = opts.controlName or opts.filterGodKey,
        tierIndex = opts.tierIndex or opts.banPoolIndex,
    })
    if not info then
        return false, nil
    end

    local source = getSourceControl(runtime, info.controlName, opts.cache)
    if not source then
        return false, info
    end

    return source:isBanned(traitName, info.tierIndex or 1) == true, info
end

return traitInfo
