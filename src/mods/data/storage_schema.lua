local function BuildBanBits(baseCatalog, banPools, banPoolKey, packedAlias)
    local catalogGodKey = banPools.getCatalogKey(banPoolKey)
    local entry = packedAlias and baseCatalog[catalogGodKey] or nil
    local bits = {}

    if packedAlias and entry and entry.boons and #entry.boons > 0 then
        for _, boon in ipairs(entry.boons) do
            bits[#bits + 1] = {
                alias = banPools.makeBanAlias(packedAlias, boon.Key),
                label = boon.Name,
                offset = boon.Bit,
                width = 1,
                type = "bool",
                default = false,
            }
        end
    end

    return bits
end

local function BuildPackedRarityBits(godDefs, baseCatalog, banPools)
    local bitsByPackedAlias = {}
    for godKey, entry in pairs(baseCatalog) do
        local meta = godDefs[godKey]
        if meta and meta.rarityVar then
            local bits = {}
            for _, boon in ipairs(entry.boons) do
                if boon.IsRarityEligible ~= false then
                    bits[#bits + 1] = {
                        alias = banPools.makeRarityAlias(meta.rarityVar, boon.Key),
                        label = boon.Name,
                        offset = boon.Bit * 2,
                        width = 2,
                        type = "int",
                        min = 0,
                        max = 3,
                    }
                end
            end
            if #bits > 0 then
                bitsByPackedAlias[meta.rarityVar] = bits
            end
        end
    end

    return bitsByPackedAlias
end

local function BuildPackedStorageNode(packedStorageBits, item)
    local bits = item.bits or packedStorageBits[item.key]
    if not bits then
        return {
            type = "int",
            alias = item.key,
            default = item.default,
        }
    end

    local packedWidth = 0
    for _, bit in ipairs(bits) do
        local used = bit.offset + bit.width
        if used > packedWidth then
            packedWidth = used
        end
    end

    return {
        type = "packedInt",
        alias = item.key,
        default = item.default,
        width = packedWidth,
        bits = bits,
    }
end

local function BuildBanPoolTableStorageNodes(godDefs, baseCatalog, banPools, packedStorageBits)
    local nodes = {}
    local added = {}
    local tableSpecs = {}

    for banPoolKey in pairs(godDefs) do
        local tableConfig = banPools.isTableOwner(banPoolKey) and banPools.getTableConfig(banPoolKey) or nil
        if tableConfig and not added[tableConfig.alias] then
            local packedAlias = banPools.BAN_POOL_ALIAS
            local bits = BuildBanBits(baseCatalog, banPools, banPoolKey, packedAlias)
            if #bits > 0 then
                tableSpecs[#tableSpecs + 1] = {
                    alias = tableConfig.alias,
                    maxRows = tableConfig.maxRows,
                    defaultRows = tableConfig.defaultRows,
                    packedAlias = packedAlias,
                    bits = bits,
                }
                added[tableConfig.alias] = true
            end
        end
    end

    table.sort(tableSpecs, function(a, b)
        return a.alias < b.alias
    end)

    for _, spec in ipairs(tableSpecs) do
        nodes[#nodes + 1] = {
            type = "table",
            alias = spec.alias,
            minRows = 1,
            maxRows = spec.maxRows,
            defaultRows = spec.defaultRows,
            row = {
                BuildPackedStorageNode(packedStorageBits, {
                    key = spec.packedAlias,
                    default = 0,
                    bits = spec.bits,
                }),
            },
        }
    end

    return nodes
end

local function BuildStorage(godDefs, baseCatalog, banPools)
    local packedStorageBits = BuildPackedRarityBits(godDefs, baseCatalog, banPools)
    local storage = {
        { type = "int",    alias = "ImproveFirstNBoonRarity",
            default = 0, min = 0, max = 15 },
        { type = "string", alias = "BridalGlowTargetBoon",
            default = "", maxLen = 128 },
        { type = "int",    alias = "NpcViewRegion",                   persist = false, hash = false,
            default = 4, min = 1, max = 4 },
        { type = "string", alias = "BanFilterText",                   persist = false, hash = false,
            default = "", maxLen = 128 },
        { type = "string", alias = "ActiveOlympianRoot",              persist = false, hash = false,
            default = "Aphrodite", maxLen = 64 },
        { type = "string", alias = "ActiveOtherGodRoot",              persist = false, hash = false,
            default = "Hermes", maxLen = 64 },
        { type = "string", alias = "ActiveHammerRoot",                persist = false, hash = false,
            default = "Staff", maxLen = 64 },
        { type = "string", alias = "ActiveNpcRoot",                   persist = false, hash = false,
            default = "Arachne", maxLen = 64 },
        { type = "string", alias = "BridalGlowRoot",                  persist = false, hash = false,
            default = "", maxLen = 64 },
    }

    for _, node in ipairs(BuildBanPoolTableStorageNodes(godDefs, baseCatalog, banPools, packedStorageBits)) do
        table.insert(storage, node)
    end

    local packedKeys = {}
    for key in pairs(packedStorageBits) do
        table.insert(packedKeys, { key = key, default = 0 })
    end
    table.sort(packedKeys, function(a, b)
        return a.key < b.key
    end)
    for _, item in ipairs(packedKeys) do
        table.insert(storage, BuildPackedStorageNode(packedStorageBits, item))
    end

    return storage
end

return {
    buildStorage = BuildStorage,
}
