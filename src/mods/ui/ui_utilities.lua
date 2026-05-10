local internal = RunDirectorBoonBans_Internal
local godMeta = internal.godMeta
local godInfo = internal.godInfo
local banConfigView = internal.banConfigView

internal.uiUtilities = internal.uiUtilities or {}
local uiUtilities = internal.uiUtilities

local band, lshift, bor, bnot = bit32.band, bit32.lshift, bit32.bor, bit32.bnot

local function Log(host, fmt, ...)
    host.logIf(fmt, ...)
end

local function ReadValue(key, session)
    return session.read(key)
end

local function WriteValue(key, value, session)
    if not session then
        error("Boon Bans state writes require session", 0)
    end
    session.write(key, value)
end

function uiUtilities.SetConfiguredTierCount(rootKey, count, session)
    local tableConfig = banConfigView.GetTierTableConfig(rootKey)
    if not tableConfig then return false end
    if not session then
        error("Boon Bans tier writes require session", 0)
    end

    local tableHandle = banConfigView.GetTableHandle(tableConfig.alias, session)

    local maxTiers = banConfigView.GetMaxConfigurableTiers(rootKey)
    local nextCount = math.floor(tonumber(count) or 1)
    if nextCount < 1 then nextCount = 1 end
    if nextCount > maxTiers then nextCount = maxTiers end

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

function uiUtilities.SetBanConfig(godKey, value, session)
    local meta = godMeta[godKey]
    if not meta or not meta.packedConfig then return false end

    local mask = lshift(1, meta.packedConfig.bits) - 1
    local nextValue = band(value or 0, mask)
    local handle, bindAlias = internal.ResolveBanBinding(godKey, session)
    if not handle or not bindAlias then return false end
    if not handle.write then
        error("Boon Bans state writes require session", 0)
    end

    local currentValue = handle.read(bindAlias) or 0
    if currentValue == nextValue then
        return false
    end
    handle.write(bindAlias, nextValue)
    return true
end

function uiUtilities.SetRarityValue(godKey, bitIndex, newVal, session)
    local meta = godMeta[godKey]
    if not meta or not meta.rarityVar then return false end

    local current = ReadValue(meta.rarityVar, session) or 0
    local shift = bitIndex * 2
    local clearMask = bnot(lshift(3, shift))
    local cleared = band(current, clearMask)
    local nextValue = bor(cleared, lshift(newVal, shift))
    if nextValue == current then
        return false
    end
    WriteValue(meta.rarityVar, nextValue, session)
    return true
end

function uiUtilities.ResetAllRarity(session)
    local cleared = {}
    local changed = false
    for _, meta in pairs(godMeta) do
        if meta.rarityVar and not cleared[meta.rarityVar] then
            local current = ReadValue(meta.rarityVar, session) or 0
            if current ~= 0 then
                WriteValue(meta.rarityVar, 0, session)
                changed = true
            end
            cleared[meta.rarityVar] = true
        end
    end
    return changed
end

function uiUtilities.SetBridalGlowTargetBoonKey(boonKey, session)
    if not session then
        error("Bridal Glow target writes require session", 0)
    end

    local nextValue = boonKey or ""
    local currentValue = ReadValue("BridalGlowTargetBoon", session) or ""
    if currentValue == nextValue then
        return false
    end
    session.write("BridalGlowTargetBoon", nextValue)
    return true
end

function uiUtilities.ResetGodBans(god, session, host)
    if godMeta[god] and godInfo[god] then
        local changed = uiUtilities.SetBanConfig(god, 0, session)
        if not changed then
            return false
        end
        godInfo[god].banned = 0
        godInfo[god].banLabel = string.format("(%d/%d Banned)", 0, godInfo[god].total or 0)
        Log(host, "[Micro] Reset bans for %s", god)
        return true
    end
    return false
end

function uiUtilities.BanAllGodBans(god, session, host)
    local meta = godMeta[god]
    if meta and meta.packedConfig and godInfo[god] then
        local mask = lshift(1, meta.packedConfig.bits) - 1
        local changed = uiUtilities.SetBanConfig(god, mask, session)
        if not changed then
            return false
        end
        godInfo[god].banned = godInfo[god].total
        godInfo[god].banLabel = string.format("(%d/%d Banned)", godInfo[god].banned or 0, godInfo[god].total or 0)
        Log(host, "[Micro] Banned ALL for %s", god)
        return true
    end
    return false
end

function uiUtilities.ResetAllBans(session, host)
    local changed = false
    for god, _ in pairs(godInfo) do
        if uiUtilities.ResetGodBans(god, session, host) then
            changed = true
        end
    end
    if changed then
        Log(host, "[Micro] Global Ban Reset triggered.")
    end
    return changed
end

function uiUtilities.RecalculateBannedCounts(session, host)
    local changed = false
    for godKey, _ in pairs(godInfo) do
        if banConfigView.UpdateGodStats(godKey, session) then
            changed = true
        end
    end
    if changed then
        Log(host, "[Micro] Recalculated all ban counts.")
    end
    return changed
end
