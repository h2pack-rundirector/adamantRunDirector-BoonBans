local internal = RunDirectorBoonBans_Internal

local function BuildPackedStorageNode(item)
    local bits = internal.GetPackedStorageBits(item.key)
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
