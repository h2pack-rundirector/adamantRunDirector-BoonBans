local godDefs = nil
local banConfig = nil
local banPools = nil

local uiCommands = {}

local band = bit32.band

local function Log(services, fmt, ...)
    services.logIf(fmt, ...)
end

function uiCommands.SetConfiguredBanPoolCount(godKey, count, state)
    local tableConfig = banConfig.GetBanPoolTableConfig(godKey)
    if not tableConfig then return false end

    local tableHandle = state.get(tableConfig.alias)

    local maxBanPools = banConfig.GetMaxConfigurableBanPools(godKey)
    local nextCount = math.floor(tonumber(count) or 1)
    if nextCount < 1 then nextCount = 1 end
    if nextCount > maxBanPools then nextCount = maxBanPools end

    local currentCount = tableHandle:count()
    if currentCount == nextCount then
        return false
    end
    while currentCount < nextCount do
        tableHandle:append()
        currentCount = currentCount + 1
    end
    while currentCount > nextCount do
        tableHandle:remove(currentCount)
        currentCount = currentCount - 1
    end
    return true
end

function uiCommands.SetBanMask(banPoolKey, value, state)
    if not godDefs[banPoolKey] then return false end

    local mask = banPools.getBanMask(banPoolKey)
    local nextValue = band(value or 0, mask)
    local fields = banConfig.ResolveBanFields(banPoolKey, state)

    local currentValue = fields.bans:read() or 0
    if currentValue == nextValue then
        return false
    end
    fields.bans:write(nextValue)
    return true
end

function uiCommands.ResetAllRarity(state)
    local cleared = {}
    local changed = false
    for _, meta in pairs(godDefs) do
        if meta.rarityVar and not cleared[meta.rarityVar] then
            local rarityField = state.get(meta.rarityVar)
            local current = rarityField:read() or 0
            if current ~= 0 then
                rarityField:write(0)
                changed = true
            end
            cleared[meta.rarityVar] = true
        end
    end
    return changed
end

function uiCommands.SetBridalGlowTargetBoonKey(boonKey, state)
    local nextValue = boonKey or ""
    local targetField = state.get("BridalGlowTargetBoon")
    local currentValue = targetField:read() or ""
    if currentValue == nextValue then
        return false
    end
    targetField:write(nextValue)
    return true
end

function uiCommands.ClearFilter(state)
    state.get("BanFilterText"):reset()
end

function uiCommands.ResetGodBans(banPoolKey, state, services)
    if godDefs[banPoolKey] then
        local changed = uiCommands.SetBanMask(banPoolKey, 0, state)
        if not changed then
            return false
        end
        Log(services, "[Micro] Reset bans for %s", banPoolKey)
        return true
    end
    return false
end

function uiCommands.BanAllGodBans(banPoolKey, state, services)
    if godDefs[banPoolKey] then
        local mask = banPools.getBanMask(banPoolKey)
        local changed = uiCommands.SetBanMask(banPoolKey, mask, state)
        if not changed then
            return false
        end
        Log(services, "[Micro] Banned ALL for %s", banPoolKey)
        return true
    end
    return false
end

function uiCommands.ResetAllBans(state, services)
    local changed = false
    for banPoolKey, _ in pairs(godDefs) do
        if uiCommands.ResetGodBans(banPoolKey, state, services) then
            changed = true
        end
    end
    if changed then
        Log(services, "[Micro] Global Ban Reset triggered.")
    end
    return changed
end

function uiCommands.ResetAllControls(state, services)
    uiCommands.ResetAllBans(state, services)
    uiCommands.ResetAllRarity(state)
end

return {
    create = function(state)
        godDefs = state.godDefs
        banConfig = state.banConfig
        banPools = state.banPools
        return uiCommands
    end,
}
