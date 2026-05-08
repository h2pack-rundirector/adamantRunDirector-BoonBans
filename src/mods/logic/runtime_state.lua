---@meta _
---@diagnostic disable: lowercase-global

local internal = RunDirectorBoonBans_Internal
local godMeta = internal.godMeta
local MODULE_ID = "BoonBans"

internal.godInfo = internal.godInfo or {}
local godInfo = internal.godInfo

local t_insert = table.insert

local function GetRunState()
    return internal.GetRunState()
end

local function IsBoonBansActive()
    return internal.host.isEnabled()
end

local function Log(fmt, ...)
    lib.logging.logIf(MODULE_ID, internal.store.read("DebugMode") == true, fmt, ...)
end

local function GetRootKey(key)
    local meta = godMeta[key]
    if not meta then return key end
    if meta.duplicateOf then return GetRootKey(meta.duplicateOf) end
    return key
end

local function GetSourceColor(name)
    local meta = godMeta[name]
    local colorKey = meta and meta.colorKey
    local inGameColor = colorKey and game.Color[colorKey] or game.Color.Black
    return { inGameColor[1] / 255, inGameColor[2] / 255, inGameColor[3] / 255, inGameColor[4] / 255 }
end

local function PopulateGodInfo()
    for key in pairs(godInfo) do
        godInfo[key] = nil
    end
    godInfo.traitLookup = {}

    for key, _ in pairs(godMeta) do
        godInfo[key] = { color = GetSourceColor(key), boons = {}, boonByKey = {} }
    end

    local function addBoonToRuntime(godKey, sourceBoon)
        local boon = {}
        for key, value in pairs(sourceBoon) do
            boon[key] = value
        end
        boon.God = godKey
        godInfo[godKey].boons = godInfo[godKey].boons or {}
        t_insert(godInfo[godKey].boons, boon)
        godInfo[godKey].boonByKey[boon.Key] = boon

        local entry = { god = godKey, bit = boon.Bit, mask = boon.Mask }
        if not godInfo.traitLookup[boon.Key] then
            godInfo.traitLookup[boon.Key] = { entry }
        else
            t_insert(godInfo.traitLookup[boon.Key], entry)
        end
    end

    local baseCatalog = internal.GetOrBuildBaseBoonCatalog()
    for key, meta in pairs(godMeta) do
        if not meta.duplicateOf and meta.lootSource then
            local entry = baseCatalog[key]
            if entry and entry.boons then
                for _, boon in ipairs(entry.boons) do
                    addBoonToRuntime(key, boon)
                end
            end
            internal.UpdateGodStats(key)
        end
    end

    for key, meta in pairs(godMeta) do
        if meta.duplicateOf then
            local parentKey = meta.duplicateOf
            local parentEntry = godInfo[parentKey]
            if parentEntry then
                for _, parentBoon in ipairs(parentEntry.boons) do
                    addBoonToRuntime(key, parentBoon)
                end
                internal.UpdateGodStats(key)
            end
        end
    end

    Log("[Micro] GodInfo Populated.")
end

function internal.GetOrRecalcBoonCounts()
    local state = GetRunState()
    if not state then
        return {}
    end
    if not state.BoonPickCounts then
        state.BoonPickCounts = {}
    end
    return state.BoonPickCounts
end

function internal.FindTraitInfo(traitName, filterGodKey, knownTier)
    local list = godInfo.traitLookup[traitName]
    if not list then return nil end

    local targetEntry = nil
    if filterGodKey then
        for _, entry in ipairs(list) do
            local entryRoot = GetRootKey(entry.god)
            if entryRoot == filterGodKey then
                targetEntry = entry
                break
            end
        end
    end
    if not targetEntry then
        targetEntry = list[1]
    end

    local targetTier = knownTier
    if not targetTier then
        local rootKey = GetRootKey(targetEntry.god)
        local currentPicks = (internal.GetOrRecalcBoonCounts()[rootKey] or 0)
        targetTier = currentPicks + 1
    end

    for i = 1, #list do
        local entry = list[i]
        local meta = godMeta[entry.god]
        local entryTier = meta.tier or 1
        if entryTier == targetTier then
            if not filterGodKey or GetRootKey(entry.god) == filterGodKey then
                return entry
            end
        end
    end
    return nil
end

function internal.GetGodFromLootsource(lootKey)
    for godKey, meta in pairs(godMeta) do
        if meta.lootSource and meta.lootSource.key == lootKey then
            if lootKey == "WeaponUpgrade" then
                local currentWeapon = GetEquippedWeapon()
                if string.find(currentWeapon, godKey, 1, true) then
                    return GetRootKey(godKey)
                end
            else
                return GetRootKey(godKey)
            end
        end
    end
    return nil
end

internal.GetRootKey = GetRootKey
internal.IsBoonBansActive = IsBoonBansActive

PopulateGodInfo()

