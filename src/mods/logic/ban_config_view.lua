local internal = RunDirectorBoonBans_Internal
local godMeta = internal.godMeta
internal.godInfo = internal.godInfo or {}
local godInfo = internal.godInfo

internal.banConfigView = internal.banConfigView or {}
local banConfigView = internal.banConfigView

local band, lshift, rshift = bit32.band, bit32.lshift, bit32.rshift

local function ReadValue(key, handle)
    return handle.read(key)
end

local function GetRootKey(key)
    local meta = godMeta[key]
    if not meta then return key end
    if meta.duplicateOf then return GetRootKey(meta.duplicateOf) end
    return key
end

local function GetTierTableConfig(rootKey)
    local root = GetRootKey(rootKey)
    local meta = godMeta[root]
    return meta and meta.tierTableConfig or nil
end
banConfigView.GetTierTableConfig = GetTierTableConfig

local function GetTableHandle(tableAlias, handle)
    local tableHandle = handle and handle.table and handle.table(tableAlias) or nil
    if not tableHandle then
        error("Boon Bans missing table storage handle for " .. tostring(tableAlias), 0)
    end
    return tableHandle
end
banConfigView.GetTableHandle = GetTableHandle

function banConfigView.GetRootKey(key)
    return GetRootKey(key)
end

function banConfigView.GetMaxConfigurableTiers(rootKey)
    local tableConfig = GetTierTableConfig(rootKey)
    return tableConfig and math.floor(tonumber(tableConfig.maxRows) or 1) or 1
end

function banConfigView.GetConfiguredTierCount(rootKey, handle)
    local tableConfig = GetTierTableConfig(rootKey)
    if not tableConfig then
        return 1
    end

    return GetTableHandle(tableConfig.alias, handle):count()
end

function banConfigView.IsTierConfigured(rootKey, tier, handle)
    local tableConfig = GetTierTableConfig(rootKey)
    if not tableConfig then
        return true
    end

    local tierIndex = math.floor(tonumber(tier) or 1)
    if tierIndex < 1 or tierIndex > banConfigView.GetMaxConfigurableTiers(rootKey) then
        return false
    end
    return tierIndex <= banConfigView.GetConfiguredTierCount(rootKey, handle)
end

function banConfigView.GetBanConfig(godKey, handle)
    local meta = godMeta[godKey]
    if not meta or not meta.packedConfig then return 0 end

    local boundHandle, bindAlias = internal.ResolveBanBinding(godKey, handle)
    if not boundHandle or not bindAlias then return 0 end
    local val = boundHandle.read(bindAlias) or 0
    local mask = lshift(1, meta.packedConfig.bits) - 1
    return band(val, mask)
end

function banConfigView.GetRarityValue(godKey, bitIndex, handle)
    local meta = godMeta[godKey]
    if not meta or not meta.rarityVar then return 0 end

    local packedVal = ReadValue(meta.rarityVar, handle) or 0
    local shift = bitIndex * 2
    return band(rshift(packedVal, shift), 3)
end

function banConfigView.UpdateGodStats(godKey, handle)
    local entry = godInfo[godKey]
    if not entry or not entry.boons then return false end

    local godConfig = banConfigView.GetBanConfig(godKey, handle)
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

function banConfigView.GetTotalBansConfigured()
    local totalBans = 0
    for _, info in pairs(godInfo) do
        if type(info) == "table" and type(info.banned) == "number" then
            totalBans = totalBans + info.banned
        end
    end
    return totalBans
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

function banConfigView.ListContainsEquivalent(list, template)
    if type(list) ~= "table" then return false end
    for _, entry in ipairs(list) do
        if DeepCompare(entry, template) then
            return true
        end
    end
    return false
end
