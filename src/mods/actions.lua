local function collectControlNames(state)
    local controlNames = {}
    for controlName in pairs(state.controls or {}) do
        controlNames[#controlNames + 1] = controlName
    end
    table.sort(controlNames)
    return controlNames
end

local function resetAllRarity(controlNames, controls)
    local changed = false
    for _, controlName in ipairs(controlNames) do
        local source = controls.get(controlName)
        if source:hasRarity() and source:resetRarity() then
            changed = true
        end
    end
    return changed
end

local function resetAllBans(controlNames, controls, host)
    local changed = false
    for _, controlName in ipairs(controlNames) do
        local source = controls.get(controlName)
        if source:resetAllTiers() then
            changed = true
        end
    end
    if changed then
        host.logIf("[Micro] Global Ban Reset triggered.")
    end
    return changed
end

local function resetAllControls(controlNames, controls, host)
    local changed = false
    for _, controlName in ipairs(controlNames) do
        local source = controls.get(controlName)
        if source:resetAll() then
            changed = true
        end
    end
    if changed then
        host.logIf("[Micro] Global Control Reset triggered.")
    end
    return changed
end

local function setBridalGlowTargetBoonKey(state, boonKey)
    local nextValue = boonKey or ""
    local targetField = state.get("BridalGlowTargetBoon")
    local currentValue = targetField:read() or ""
    if currentValue == nextValue then
        return false
    end
    targetField:write(nextValue)
    return true
end

return {
    create = function(state)
        local controlNames = collectControlNames(state)

        return {
            resetAllRarity = function(_, _, _, _, actionContext)
                return resetAllRarity(controlNames, actionContext.controls)
            end,
            resetAllBans = function(host, _, _, _, actionContext)
                return resetAllBans(controlNames, actionContext.controls, host)
            end,
            resetAllControls = function(host, _, _, _, actionContext)
                return resetAllControls(controlNames, actionContext.controls, host)
            end,
            setBridalGlowTarget = function(_, uiState, _, boonKey)
                return setBridalGlowTargetBoonKey(uiState, boonKey)
            end,
        }
    end,
}
