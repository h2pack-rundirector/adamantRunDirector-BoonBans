local godDefs = nil
local banConfig = nil
local banPools = nil

local uiActions = {}

local band = bit32.band

local function Log(services, fmt, ...)
    services.logIf(fmt, ...)
end

function uiActions.SetConfiguredBanPoolCount(godKey, count, session)
    local tableConfig = banConfig.GetBanPoolTableConfig(godKey)
    if not tableConfig then return false end

    local tableHandle = session.table(tableConfig.alias)

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

function uiActions.SetBanMask(banPoolKey, value, session)
    if not godDefs[banPoolKey] then return false end

    local mask = banPools.getBanMask(banPoolKey)
    local nextValue = band(value or 0, mask)
    local fields = banConfig.ResolveBanFields(banPoolKey, session)

    local currentValue = fields.bans:read() or 0
    if currentValue == nextValue then
        return false
    end
    fields.bans:write(nextValue)
    return true
end

function uiActions.ResetAllRarity(session)
    local cleared = {}
    local changed = false
    for _, meta in pairs(godDefs) do
        if meta.rarityVar and not cleared[meta.rarityVar] then
            local current = session.read(meta.rarityVar) or 0
            if current ~= 0 then
                session.write(meta.rarityVar, 0)
                changed = true
            end
            cleared[meta.rarityVar] = true
        end
    end
    return changed
end

function uiActions.SetBridalGlowTargetBoonKey(boonKey, session)
    local nextValue = boonKey or ""
    local currentValue = session.read("BridalGlowTargetBoon") or ""
    if currentValue == nextValue then
        return false
    end
    session.write("BridalGlowTargetBoon", nextValue)
    return true
end

function uiActions.ResetGodBans(banPoolKey, session, services)
    if godDefs[banPoolKey] then
        local changed = uiActions.SetBanMask(banPoolKey, 0, session)
        if not changed then
            return false
        end
        Log(services, "[Micro] Reset bans for %s", banPoolKey)
        return true
    end
    return false
end

function uiActions.BanAllGodBans(banPoolKey, session, services)
    if godDefs[banPoolKey] then
        local mask = banPools.getBanMask(banPoolKey)
        local changed = uiActions.SetBanMask(banPoolKey, mask, session)
        if not changed then
            return false
        end
        Log(services, "[Micro] Banned ALL for %s", banPoolKey)
        return true
    end
    return false
end

function uiActions.ResetAllBans(session, services)
    local changed = false
    for banPoolKey, _ in pairs(godDefs) do
        if uiActions.ResetGodBans(banPoolKey, session, services) then
            changed = true
        end
    end
    if changed then
        Log(services, "[Micro] Global Ban Reset triggered.")
    end
    return changed
end

function uiActions.ResetAllControls(session, services)
    uiActions.ResetAllBans(session, services)
    uiActions.ResetAllRarity(session)
end

return {
    create = function(data)
        godDefs = data.godDefs
        banConfig = data.banConfig
        banPools = data.banPools
        return uiActions
    end,
}
