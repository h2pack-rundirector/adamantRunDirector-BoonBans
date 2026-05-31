local deps = ...
local uiStyle = deps.style

local roots = {}
local EMPTY_OPTS = {}

local function buildBanPools(source)
    local maxTiers = source:maxTiers()
    if maxTiers <= 1 then
        return {
            { key = source:tierKey(1), label = "Bans" },
        }
    end

    local configuredTiers = source:tierCount()
    if configuredTiers < 1 then configuredTiers = 1 end
    if configuredTiers > maxTiers then configuredTiers = maxTiers end

    local banPools = {}
    for tierIndex = 1, configuredTiers do
        banPools[#banPools + 1] = {
            key = source:tierKey(tierIndex),
            label = source:tierLabel(tierIndex),
        }
    end
    return banPools
end

function roots.buildTraitSourceRoot(source, opts)
    opts = opts or EMPTY_OPTS
    local sourceName = source:name()
    return {
        id = sourceName,
        label = opts.label or source:label(),
        color = source:color() or uiStyle.DEFAULT_GOD_COLOR,
        group = opts.group or source:group(),
        primaryGodKey = sourceName,
        controlName = sourceName,
        maxBanPools = source:maxTiers(),
        hasRarity = source:hasRarity(),
        hasBridalGlow = opts.hasBridalGlow == true,
        banPools = buildBanPools(source),
    }
end

return roots
