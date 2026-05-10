---@meta _
---@diagnostic disable: lowercase-global

local internal = RunDirectorBoonBans_Internal
local godMeta = internal.godMeta
local banConfigView = internal.banConfigView

internal.godInfo = internal.godInfo or {}
local godInfo = internal.godInfo

local t_insert = table.insert

local function GetSourceColor(name)
    local meta = godMeta[name]
    local colorKey = meta and meta.colorKey
    local inGameColor = colorKey and game.Color[colorKey] or game.Color.Black
    return { inGameColor[1] / 255, inGameColor[2] / 255, inGameColor[3] / 255, inGameColor[4] / 255 }
end

local function PopulateGodInfo(host, store)
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
            banConfigView.UpdateGodStats(key, store)
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
                banConfigView.UpdateGodStats(key, store)
            end
        end
    end

    host.logIf("[Micro] GodInfo Populated.")
end

function internal.RegisterRuntimeState(host, store)
    function internal.GetOrRecalcBoonCounts()
        local state = internal.runtimeUtilities.GetRunState(store)
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
                local entryRoot = banConfigView.GetRootKey(entry.god)
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
            local rootKey = banConfigView.GetRootKey(targetEntry.god)
            local currentPicks = (internal.GetOrRecalcBoonCounts()[rootKey] or 0)
            targetTier = currentPicks + 1
        end

        for i = 1, #list do
            local entry = list[i]
            local meta = godMeta[entry.god]
            local entryTier = meta.tier or 1
            if entryTier == targetTier then
                if not filterGodKey or banConfigView.GetRootKey(entry.god) == filterGodKey then
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
                        return banConfigView.GetRootKey(godKey)
                    end
                else
                    return banConfigView.GetRootKey(godKey)
                end
            end
        end
        return nil
    end

    PopulateGodInfo(host, store)
end
