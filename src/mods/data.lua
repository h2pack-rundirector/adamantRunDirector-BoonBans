local internal = RunDirectorBoonBans_Internal

local function BuildPackedStorageNode(item)
    local bits = item.bits or internal.GetPackedStorageBits(item.key)
    if not bits then
        return {
            type = "int",
            alias = item.key,
            default = item.default,
        }
    end

    local packedWidth = nil
    local lastBit = bits[#bits]
    if lastBit then
        packedWidth = lastBit.offset + lastBit.width
    end

    return {
        type = "packedInt",
        alias = item.key,
        default = item.default,
        width = packedWidth,
        bits = bits,
    }
end

local function BuildTierTableStorageNodes()
    local nodes = {}
    local added = {}
    local tableSpecs = {}

    for metaKey, meta in pairs(internal.godMeta) do
        local tableConfig = meta and meta.tierTableConfig or nil
        if tableConfig and not added[tableConfig.alias] then
            local packedAlias = internal.TIER_BAN_ALIAS
            local bits = internal.BuildBanBits(metaKey, packedAlias)
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
                BuildPackedStorageNode({
                    key = spec.packedAlias,
                    default = 0,
                    bits = spec.bits,
                }),
            },
        }
    end

    return nodes
end

function internal.BuildStorage()
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

    for _, node in ipairs(BuildTierTableStorageNodes()) do
        table.insert(storage, node)
    end

    local packedKeys = {}
    for key in pairs(internal.GetOrBuildPackedStorageBits()) do
        table.insert(packedKeys, { key = key, default = 0 })
    end
    table.sort(packedKeys, function(a, b)
        return a.key < b.key
    end)
    for _, item in ipairs(packedKeys) do
        table.insert(storage, BuildPackedStorageNode(item))
    end

    return storage
end

return internal
