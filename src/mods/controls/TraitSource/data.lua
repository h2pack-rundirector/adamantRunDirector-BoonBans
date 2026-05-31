local bor, lshift = bit32.bor, bit32.lshift

local data = {}

local function cloneList(source)
    local copy = {}
    for index, value in ipairs(source or {}) do
        copy[index] = value
    end
    return copy
end

local function maxBitWidth(bits)
    local width = 0
    for _, bit in ipairs(bits or {}) do
        local used = (bit.offset or 0) + (bit.width or 1)
        if used > width then
            width = used
        end
    end
    return width
end

local function normalizeTierCount(instance, count)
    local nextCount = math.floor(tonumber(count) or instance.defaultTiers or 1)
    if nextCount < 1 then nextCount = 1 end
    if nextCount > instance.maxTiers then nextCount = instance.maxTiers end
    return nextCount
end

function data.prepare(instance)
    instance.items = cloneList(instance.items)
    instance.itemByKey = {}
    instance.itemByBit = {}
    instance.bridalGlowTargets = {}
    instance.bridalGlowTargetByKey = {}
    instance.banBits = {}
    instance.rarityBits = {}
    local defaultTiers = tonumber(instance.defaultTiers) or 1
    instance.maxTiers = math.max(math.floor(tonumber(instance.maxTiers) or defaultTiers), 1)
    instance.defaultTiers = normalizeTierCount(instance, defaultTiers)
    instance.fullMask = 0
    instance.valueColors = {}

    for _, item in ipairs(instance.items) do
        item.key = item.key or item.Key
        item.label = item.label or item.Name or item.key
        item.displayLabel = item.displayLabel or item.SpecialDisplayLabel or item.label
        item.searchText = item.searchText or tostring(item.label or item.key):lower()
        item.bit = math.floor(tonumber(item.bit or item.Bit) or 0)
        item.mask = item.mask or lshift(1, item.bit)
        item.isRarityEligible = item.isRarityEligible ~= false and item.IsRarityEligible ~= false
        item.isBridalGlowEligible = item.isBridalGlowEligible == true or item.IsBridalGlowEligible == true
        instance.itemByKey[item.key] = item
        instance.itemByBit[item.bit] = item
        instance.fullMask = bor(instance.fullMask, item.mask)

        local bit = {
            key = item.key,
            label = item.displayLabel,
            offset = item.bit,
            width = 1,
            type = "bool",
            default = false,
            _valueColor = instance.showValueColors == false and nil or item.valueColor,
        }
        instance.banBits[#instance.banBits + 1] = bit
        if type(bit._valueColor) == "table" then
            instance.valueColors[item.key] = bit._valueColor
        end

        if instance.hasRarity ~= false and item.isRarityEligible then
            instance.rarityBits[#instance.rarityBits + 1] = {
                key = item.key,
                label = item.label,
                offset = item.bit * 2,
                width = 2,
                type = "int",
                min = 0,
                max = 3,
                default = 0,
            }
        end

        if item.isBridalGlowEligible then
            local target = {
                key = item.key,
                label = item.bridalGlowLabel or item.label,
                sourceName = instance.name,
            }
            instance.bridalGlowTargets[#instance.bridalGlowTargets + 1] = target
            instance.bridalGlowTargetByKey[item.key] = target
        end
    end

    instance.banWidth = maxBitWidth(instance.banBits)
    instance.rarityWidth = maxBitWidth(instance.rarityBits)
    instance.hasRarity = instance.hasRarity ~= false and #instance.rarityBits > 0
    return instance
end

function data.storage(instance)
    local storage = {
        {
            key = "Tiers",
            type = "table",
            minRows = 1,
            maxRows = instance.maxTiers,
            defaultRows = instance.defaultTiers,
            row = {
                {
                    key = "Bans",
                    type = "packedInt",
                    default = 0,
                    width = instance.banWidth,
                    bits = instance.banBits,
                },
            },
        },
        {
            key = "Filter",
            type = "string",
            persist = false,
            hash = false,
            default = "",
            maxLen = 128,
        },
    }

    if instance.hasRarity then
        storage[#storage + 1] = {
            key = "Rarity",
            type = "packedInt",
            default = 0,
            width = instance.rarityWidth,
            bits = instance.rarityBits,
        }
    end

    return storage
end

data.normalizeTierCount = normalizeTierCount

return data
