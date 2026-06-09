local deps = ...
local traitInfo = deps.traitInfo

local policy = {
    bypassDepth = 0,
    jpomDepth = 0,
}

function policy.withBypass(callback)
    policy.bypassDepth = policy.bypassDepth + 1
    local result = callback()
    policy.bypassDepth = policy.bypassDepth - 1
    return result
end

function policy.withJpomFilter(callback)
    policy.jpomDepth = policy.jpomDepth + 1
    local result = callback()
    policy.jpomDepth = policy.jpomDepth - 1
    return result
end

function policy.isBypassing()
    return policy.bypassDepth > 0
end

function policy.isJpomFiltering()
    return policy.jpomDepth > 0
end

function policy.shouldBlockConfiguredTrait(runtime, traitName)
    local source, info = traitInfo.resolveCurrentTrait(runtime, traitName)
    if not info then
        return false
    end

    local tierIndex = info.tierIndex or 1
    if not source or not source:isTierConfigured(tierIndex) then
        return false
    end

    return source:isBanned(traitName, tierIndex) == true
end

function policy.shouldBlockHadesKeepsakeTrait(runtime, traitName)
    local _, info = traitInfo.resolveCurrentTrait(runtime, traitName)
    if not info or info.tierKey ~= "Hades" then
        return false
    end

    local keepsake = traitInfo.hadesKeepsake(runtime)
    return keepsake ~= nil and keepsake:isBanned(traitName, 1) == true
end

function policy.shouldBlock(runtime, traitData)
    if not traitData or not traitData.Name then
        return false
    end

    if policy.isJpomFiltering() and policy.shouldBlockHadesKeepsakeTrait(runtime, traitData.Name) then
        return true, "jpom"
    end

    if policy.shouldBlockConfiguredTrait(runtime, traitData.Name) then
        return true, "ban"
    end

    return false
end

return policy
