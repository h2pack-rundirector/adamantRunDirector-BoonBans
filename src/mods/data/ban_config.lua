local function CreateBanConfig(godDefs, banPools)
    local banConfig = {}

    -- Read-only projection over player choices. Runtime callers pass
    -- store; UI callers pass session. Writes belong in ui_actions.

    local band, rshift = bit32.band, bit32.rshift

    local function ResolveGodKey(key)
        local meta = godDefs[key]
        if not meta then return key end
        if meta.duplicateOf then return ResolveGodKey(meta.duplicateOf) end
        return key
    end

    function banConfig.ResolveGodKey(key)
        return ResolveGodKey(key)
    end

    function banConfig.GetBanPoolTableConfig(godKey)
        local resolvedGodKey = ResolveGodKey(godKey)
        return banPools.getTableConfig(resolvedGodKey)
    end

    function banConfig.GetMaxConfigurableBanPools(godKey)
        return banPools.getMaxBanPools(godKey)
    end

    function banConfig.GetConfiguredBanPoolCount(godKey, handle)
        local tableConfig = banConfig.GetBanPoolTableConfig(godKey)
        if not tableConfig then
            return 1
        end

        return handle.table(tableConfig.alias):count()
    end

    function banConfig.IsBanPoolConfigured(godKey, banPoolIndex, handle)
        local tableConfig = banConfig.GetBanPoolTableConfig(godKey)
        if not tableConfig then
            return true
        end

        local resolvedBanPoolIndex = math.floor(tonumber(banPoolIndex) or 1)
        if resolvedBanPoolIndex < 1 or resolvedBanPoolIndex > banConfig.GetMaxConfigurableBanPools(godKey) then
            return false
        end
        return resolvedBanPoolIndex <= banConfig.GetConfiguredBanPoolCount(godKey, handle)
    end

    function banConfig.ResolveBanBinding(banPoolKey, handle)
        if not godDefs[banPoolKey] then
            return nil, nil
        end

        local tableHandle = handle.table(banPools.getTableAlias(banPoolKey))
        return tableHandle:rowHandle(banPools.getBanPoolIndex(banPoolKey)), banPools.BAN_POOL_ALIAS
    end

    function banConfig.GetBanMask(banPoolKey, handle)
        if not godDefs[banPoolKey] then return 0 end

        local boundHandle, bindAlias = banConfig.ResolveBanBinding(banPoolKey, handle)
        local val = boundHandle.read(bindAlias) or 0
        return band(val, banPools.getBanMask(banPoolKey))
    end

    function banConfig.IsBanPoolCustomized(banPoolKey, handle)
        return banConfig.GetBanMask(banPoolKey, handle) ~= 0
    end

    function banConfig.GetRarityValue(godKey, bitIndex, handle)
        local meta = godDefs[godKey]
        if not meta or not meta.rarityVar then return 0 end

        local packedVal = handle.read(meta.rarityVar) or 0
        local shift = bitIndex * 2
        return band(rshift(packedVal, shift), 3)
    end

    return banConfig
end

return {
    create = CreateBanConfig,
}
