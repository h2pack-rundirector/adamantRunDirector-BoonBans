local banResolverModule = {}

local band = bit32.band
local RARITY_BY_VALUE = { [1] = "Common", [2] = "Rare", [3] = "Epic" }

function banResolverModule.create(catalog, banPools, banConfig, store, runState, godDefs)
    local resolver = {}

    function resolver.findTraitInfo(traitName, filterGodKey, knownBanPoolIndex)
        local list = catalog.findTraitEntries(traitName)
        if not list then return nil end

        local targetEntry = nil
        if filterGodKey then
            for _, entry in ipairs(list) do
                local entryGodKey = banConfig.ResolveGodKey(entry.god)
                if entryGodKey == filterGodKey then
                    targetEntry = entry
                    break
                end
            end
        end
        if not targetEntry then
            targetEntry = list[1]
        end

        local banPoolIndex = knownBanPoolIndex
        if not banPoolIndex and runState then
            local godKey = banConfig.ResolveGodKey(targetEntry.god)
            banPoolIndex = runState.getBanPoolIndex(godKey)
        end
        if not banPoolIndex then
            banPoolIndex = 1
        end

        for i = 1, #list do
            local entry = list[i]
            local entryBanPoolIndex = banPools.getBanPoolIndex(entry.god)
            if entryBanPoolIndex == banPoolIndex then
                if not filterGodKey or banConfig.ResolveGodKey(entry.god) == filterGodKey then
                    return entry
                end
            end
        end
        return nil
    end

    function resolver.getGodFromLootsource(lootKey)
        return catalog.getGodFromLootsource(lootKey)
    end

    function resolver.getTraitGodKey(traitName)
        local info = resolver.findTraitInfo(traitName, nil)
        if not info then
            return nil
        end
        return banConfig.ResolveGodKey(info.god)
    end

    function resolver.isTraitBanned(traitName, opts)
        opts = opts or {}
        local info = resolver.findTraitInfo(traitName, opts.filterGodKey, opts.banPoolIndex)
        if not info then
            return false, nil
        end

        local cache = opts.cache
        local banMask = cache and cache[info.god] or nil
        if banMask == nil then
            banMask = banConfig.GetBanMask(info.god, store)
            if cache then
                cache[info.god] = banMask
            end
        end

        return band(banMask, info.mask) ~= 0, info
    end

    function resolver.getTraitRarityOverride(traitName, opts)
        opts = opts or {}
        local info = resolver.findTraitInfo(traitName, nil)
        if not info or not info.god then
            return nil, info
        end

        local godKey = banConfig.ResolveGodKey(info.god)
        local godDef = godDefs and godDefs[godKey] or nil
        if not godDef or not godDef.rarityVar then
            return nil, info
        end

        if opts.currentGodKey == godKey and not banConfig.IsBanPoolConfigured(godKey, opts.banPoolIndex, store) then
            return nil, info
        end

        local banPoolKey = godKey
        if opts.currentGodKey == godKey and (opts.banPoolIndex or 1) > 1 then
            banPoolKey = banPools.getBanPoolKey(godKey, opts.banPoolIndex)
        end

        local banMask = banConfig.GetBanMask(banPoolKey, store)
        if band(banMask, info.mask) ~= 0 then
            return nil, info
        end

        local rarityValue = banConfig.GetRarityValue(godKey, info.bit, store)
        return RARITY_BY_VALUE[rarityValue], info
    end

    function resolver.shouldBlockTraitEligibility(traitName, opts)
        opts = opts or {}
        local info = resolver.findTraitInfo(traitName, nil)
        if not info then
            return false
        end

        if opts.isKeepsakeOffering and info.god == "Hades" and godDefs[info.god].duplicateOf == nil then
            if catalog.entries["HadesKeepsake"] then
                return band(banConfig.GetBanMask("HadesKeepsake", store), info.mask) ~= 0
            end
            return false
        end

        local infoGodKey = banConfig.ResolveGodKey(info.god)
        local infoBanPoolIndex = banPools.getBanPoolIndex(info.god)
        if not banConfig.IsBanPoolConfigured(infoGodKey, infoBanPoolIndex, store) then
            return false
        end

        return band(banConfig.GetBanMask(info.god, store), info.mask) ~= 0
    end

    return resolver
end

return banResolverModule
