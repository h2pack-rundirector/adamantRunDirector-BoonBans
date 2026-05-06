local internal = RunDirectorBoonBans_Internal
local godMeta = internal.godMeta
internal.godInfo = internal.godInfo or {}
local godInfo = internal.godInfo
local PACK_ID = "run-director"
local MODULE_ID = "BoonBans"

local band, lshift, rshift, bor, bnot = bit32.band, bit32.lshift, bit32.rshift, bit32.bor, bit32.bnot

local function Log(fmt, ...)
    lib.logging.logIf(MODULE_ID, internal.store.read("DebugMode") == true, fmt, ...)
end

local function ReadValue(key, session)
    if session then
        return session.read(key)
    end
    return internal.store.read(key)
end

local function WriteValue(key, value, session)
    if not session then
        error("Boon Bans state writes require session", 0)
    end
    session.write(key, value)
end

local function GetRootKey(key)
    local meta = godMeta[key]
    if not meta then return key end
    if meta.duplicateOf then return GetRootKey(meta.duplicateOf) end
    return key
end

local function GetTierStateConfig(rootKey)
    local root = GetRootKey(rootKey)
    local meta = godMeta[root]
    return meta and meta.tierStateConfig or nil
end

local function GetDisabledTierMask(enabledCount, maxTiers)
    local mask = 0
    for tier = enabledCount + 1, maxTiers do
        mask = bor(mask, lshift(1, tier - 1))
    end
    return mask
end

function internal.GetMaxConfigurableTiers(rootKey)
    local tierState = GetTierStateConfig(rootKey)
    return tierState and math.floor(tonumber(tierState.maxTiers) or 1) or 1
end

function internal.GetConfiguredTierCount(rootKey, session)
    local tierState = GetTierStateConfig(rootKey)
    if not tierState then
        return 1
    end

    local maxTiers = internal.GetMaxConfigurableTiers(rootKey)
    local mask = ReadValue(tierState.var, session) or 0
    local count = 0
    for tier = 1, maxTiers do
        if band(mask, lshift(1, tier - 1)) ~= 0 then
            break
        end
        count = tier
    end
    return count
end

function internal.SetConfiguredTierCount(rootKey, count, session)
    local tierState = GetTierStateConfig(rootKey)
    if not tierState then return false end

    local maxTiers = internal.GetMaxConfigurableTiers(rootKey)
    local nextCount = math.floor(tonumber(count) or 1)
    if nextCount < 1 then nextCount = 1 end
    if nextCount > maxTiers then nextCount = maxTiers end

    local nextValue = GetDisabledTierMask(nextCount, maxTiers)
    local currentValue = ReadValue(tierState.var, session) or 0
    if currentValue == nextValue then
        return false
    end
    WriteValue(tierState.var, nextValue, session)
    return true
end

function internal.IsTierConfigured(rootKey, tier, session)
    local tierState = GetTierStateConfig(rootKey)
    if not tierState then
        return true
    end

    local tierIndex = math.floor(tonumber(tier) or 1)
    if tierIndex < 1 or tierIndex > internal.GetMaxConfigurableTiers(rootKey) then
        return false
    end
    local mask = ReadValue(tierState.var, session) or 0
    return band(mask, lshift(1, tierIndex - 1)) == 0
end

function internal.SetBanConfig(godKey, value, session)
    local meta = godMeta[godKey]
    if not meta or not meta.packedConfig then return false end

    local mask = lshift(1, meta.packedConfig.bits) - 1
    local nextValue = band(value or 0, mask)
    local currentValue = ReadValue(meta.packedConfig.var, session) or 0
    if currentValue == nextValue then
        return false
    end
    WriteValue(meta.packedConfig.var, nextValue, session)
    return true
end

function internal.GetBanConfig(godKey, session)
    local meta = godMeta[godKey]
    if not meta or not meta.packedConfig then return 0 end

    local val = ReadValue(meta.packedConfig.var, session) or 0
    local mask = lshift(1, meta.packedConfig.bits) - 1
    return band(val, mask)
end

function internal.GetRunState()
    if not CurrentRun then return nil end
    local state = lib.gameObject.get(CurrentRun, PACK_ID, MODULE_ID, "run", function()
        return {
            BoonPickCounts = {},
            ImproveFirstNBoonRarity = internal.store.read("ImproveFirstNBoonRarity") or 0,
        }
    end)
    if not state.BoonPickCounts then
        state.BoonPickCounts = {}
    end
    if state.ImproveFirstNBoonRarity == nil then
        state.ImproveFirstNBoonRarity = internal.store.read("ImproveFirstNBoonRarity") or 0
    end
    return state
end

function internal.GetRarityValue(godKey, bitIndex, session)
    local meta = godMeta[godKey]
    if not meta or not meta.rarityVar then return 0 end

    local packedVal = ReadValue(meta.rarityVar, session) or 0
    local shift = bitIndex * 2
    return band(rshift(packedVal, shift), 3)
end

function internal.SetRarityValue(godKey, bitIndex, newVal, session)
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

function internal.ResetAllRarity(session)
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

function internal.UpdateGodStats(godKey, session)
    local entry = godInfo[godKey]
    if not entry or not entry.boons then return false end

    local godConfig = internal.GetBanConfig(godKey, session)
    local count = 0
    for _, boon in ipairs(entry.boons) do
        if band(godConfig, boon.Mask) ~= 0 then
            count = count + 1
        end
    end

    entry.banned = count
    entry.total = #entry.boons
    entry.banLabel = string.format("(%d/%d Banned)", count, #entry.boons)
    return true
end

function internal.GetTotalBansConfigured()
    local totalBans = 0
    for _, info in pairs(godInfo) do
        if type(info) == "table" and type(info.banned) == "number" then
            totalBans = totalBans + info.banned
        end
    end
    return totalBans
end

function internal.SetBridalGlowTargetBoonKey(boonKey, session)
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

function internal.ResetGodBans(god, session)
    if godMeta[god] and godInfo[god] then
        local changed = internal.SetBanConfig(god, 0, session)
        if not changed then
            return false
        end
        godInfo[god].banned = 0
        godInfo[god].banLabel = string.format("(%d/%d Banned)", 0, godInfo[god].total or 0)
        Log("[Micro] Reset bans for %s", god)
        return true
    end
    return false
end

function internal.BanAllGodBans(god, session)
    local meta = godMeta[god]
    if meta and meta.packedConfig and godInfo[god] then
        local mask = lshift(1, meta.packedConfig.bits) - 1
        local changed = internal.SetBanConfig(god, mask, session)
        if not changed then
            return false
        end
        godInfo[god].banned = godInfo[god].total
        godInfo[god].banLabel = string.format("(%d/%d Banned)", godInfo[god].banned or 0, godInfo[god].total or 0)
        Log("[Micro] Banned ALL for %s", god)
        return true
    end
    return false
end

function internal.ResetAllBans(session)
    local changed = false
    for god, _ in pairs(godInfo) do
        if internal.ResetGodBans(god, session) then
            changed = true
        end
    end
    if changed then
        Log("[Micro] Global Ban Reset triggered.")
    end
    return changed
end

function internal.RecalculateBannedCounts(session)
    local changed = false
    for godKey, _ in pairs(godInfo) do
        if internal.UpdateGodStats(godKey, session) then
            changed = true
        end
    end
    if changed then
        Log("[Micro] Recalculated all ban counts.")
    end
    return changed
end

local function DeepCompare(a, b)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return false end

    for key, value in pairs(a) do
        if not DeepCompare(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

function internal.ListContainsEquivalent(list, template)
    if type(list) ~= "table" then return false end
    for _, entry in ipairs(list) do
        if DeepCompare(entry, template) then
            return true
        end
    end
    return false
end
