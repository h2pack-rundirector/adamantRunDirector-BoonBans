-- luacheck: globals GetEquippedWeapon

local sourceResolverModule = {}

local function getSourceName(godDefs, sourceKey)
    local def = godDefs and godDefs[sourceKey] or nil
    return def and def.banPoolGroupKey or sourceKey
end

local function getTierIndex(godDefs, sourceKey)
    local def = godDefs and godDefs[sourceKey] or nil
    return def and def.banPoolIndex or 1
end

local function getSortedGodKeys(godDefs)
    local keys = {}
    for godKey in pairs(godDefs or {}) do
        keys[#keys + 1] = godKey
    end
    table.sort(keys, function(a, b)
        local aDef = godDefs[a] or {}
        local bDef = godDefs[b] or {}
        local aSort = aDef.sortIndex or 0
        local bSort = bDef.sortIndex or 0
        if aSort == bSort then
            return a < b
        end
        return aSort < bSort
    end)
    return keys
end

local function buildLootSourceIndex(godDefs)
    local lootSources = {}
    local weaponSources = {}
    local seenWeaponSources = {}

    for _, godKey in ipairs(getSortedGodKeys(godDefs)) do
        local def = godDefs[godKey]
        local lootSource = def and def.lootSource or nil
        local lootKey = lootSource and lootSource.key or nil
        if lootKey then
            local sourceName = getSourceName(godDefs, godKey)
            if lootSource.type == "WeaponUpgrade" or lootKey == "WeaponUpgrade" then
                if not seenWeaponSources[sourceName] then
                    weaponSources[#weaponSources + 1] = sourceName
                    seenWeaponSources[sourceName] = true
                end
            elseif lootSources[lootKey] == nil then
                lootSources[lootKey] = sourceName
            end
        end
    end

    return lootSources, weaponSources
end

local function buildTraitIndex(godDefs, catalog)
    local traitIndex = {}
    for traitName, entries in pairs(catalog.traitLookup or {}) do
        local infos = {}
        for _, entry in ipairs(entries) do
            local controlName = getSourceName(godDefs, entry.god)
            local tierIndex = getTierIndex(godDefs, entry.god)
            infos[#infos + 1] = {
                controlName = controlName,
                sourceName = controlName,
                tierKey = entry.god,
                tierIndex = tierIndex,
                traitName = traitName,
            }
        end
        traitIndex[traitName] = infos
    end
    return traitIndex
end

local function equippedWeaponName()
    if type(GetEquippedWeapon) == "function" then
        return tostring(GetEquippedWeapon() or "")
    end
    return ""
end

function sourceResolverModule.create(godDefs, catalog)
    local sourceResolver = {}
    local lootSources, weaponSources = buildLootSourceIndex(godDefs)
    local traitIndex = buildTraitIndex(godDefs, catalog)

    local function primarySourceName(sourceName)
        local def = godDefs and godDefs[sourceName] or nil
        if def and def.duplicateOf then
            return primarySourceName(def.duplicateOf)
        end
        return sourceName
    end

    function sourceResolver.primarySourceName(sourceName)
        return primarySourceName(sourceName)
    end

    function sourceResolver.fromLootName(lootName)
        if type(lootName) ~= "string" or lootName == "" then
            return nil
        end

        if lootName == "WeaponUpgrade" then
            local currentWeapon = equippedWeaponName()
            for _, sourceName in ipairs(weaponSources) do
                if currentWeapon:find(sourceName, 1, true) then
                    return sourceName
                end
            end
            return nil
        end

        return lootSources[lootName]
    end

    function sourceResolver.fromTraitName(traitName, opts)
        opts = opts or {}
        local list = traitIndex[traitName]
        if not list then
            return nil
        end

        local controlName = opts.controlName or opts.sourceName or opts.filterGodKey
        local requestedTierIndex = opts.tierIndex or opts.banPoolIndex
        if requestedTierIndex ~= nil then
            requestedTierIndex = math.floor(tonumber(requestedTierIndex) or 1)
        end

        for _, entry in ipairs(list) do
            if (not controlName or entry.controlName == controlName)
                and (not requestedTierIndex or entry.tierIndex == requestedTierIndex) then
                return entry
            end
        end

        return nil
    end

    return sourceResolver
end

return sourceResolverModule
