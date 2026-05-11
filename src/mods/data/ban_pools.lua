local lshift = bit32.lshift

local function CreateBanPools(godDefs, baseCatalog)
    local banPools = {}

    banPools.BAN_POOL_ALIAS = "Bans"

    local function GetDef(key)
        return godDefs and godDefs[key] or nil
    end

    function banPools.getCatalogKey(banPoolKey)
        local def = GetDef(banPoolKey)
        if not def then
            return banPoolKey
        end
        return def.duplicateOf or banPoolKey
    end

    function banPools.getGroupKey(banPoolKey)
        local def = GetDef(banPoolKey)
        return def and def.banPoolGroupKey or banPoolKey
    end

    function banPools.getTableAlias(banPoolKey)
        local groupKey = banPools.getGroupKey(banPoolKey)
        return groupKey .. "BanPools"
    end

    function banPools.getBanPoolIndex(banPoolKey)
        local def = GetDef(banPoolKey)
        return def and def.banPoolIndex or 1
    end

    function banPools.getBanPoolKey(groupKey, banPoolIndex)
        if banPoolIndex <= 1 then
            return groupKey
        end
        return groupKey .. tostring(banPoolIndex)
    end

    function banPools.getMaxBanPools(banPoolKey)
        local def = GetDef(banPools.getGroupKey(banPoolKey))
        return def and def.maxBanPools or 1
    end

    function banPools.getDefaultBanPools(banPoolKey)
        local def = GetDef(banPools.getGroupKey(banPoolKey))
        return def and def.defaultBanPools or 1
    end

    function banPools.isTableOwner(banPoolKey)
        return banPools.getGroupKey(banPoolKey) == banPoolKey
            and banPools.getBanPoolIndex(banPoolKey) == 1
    end

    function banPools.getTableConfig(banPoolKey)
        local def = GetDef(banPoolKey)
        if not def then
            return nil
        end
        return {
            alias = banPools.getTableAlias(banPoolKey),
            maxRows = banPools.getMaxBanPools(banPoolKey),
            defaultRows = banPools.getDefaultBanPools(banPoolKey),
        }
    end

    function banPools.makeRarityAlias(rarityVar, boonKey)
        return rarityVar .. "__" .. boonKey
    end

    function banPools.getRarityAlias(godKey, boonKey)
        local def = GetDef(godKey)
        local rarityVar = def and def.rarityVar or nil
        if not rarityVar then
            return nil
        end
        return banPools.makeRarityAlias(rarityVar, boonKey)
    end

    function banPools.makeBanAlias(packedAlias, boonKey)
        return packedAlias .. "__" .. boonKey
    end

    function banPools.getBanPackedAlias(banPoolKey)
        if not GetDef(banPoolKey) then
            return nil
        end
        return banPools.BAN_POOL_ALIAS
    end

    function banPools.getBitCount(banPoolKey)
        local catalogKey = banPools.getCatalogKey(banPoolKey)
        local entry = baseCatalog[catalogKey]
        return entry and entry.boons and #entry.boons or 0
    end

    function banPools.getBanMask(banPoolKey)
        local bitCount = banPools.getBitCount(banPoolKey)
        if bitCount <= 0 then
            return 0
        end
        return lshift(1, bitCount) - 1
    end

    return banPools
end

return {
    create = CreateBanPools,
}
