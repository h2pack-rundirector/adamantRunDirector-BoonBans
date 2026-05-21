local godCatalog = nil
local godDefs = nil
local banConfig = nil
local banPools = nil

local uiData = {}
local EMPTY_LIST = {}
local EMPTY_OPTS = {}

uiData.DEFAULT_GOD_COLOR = { 1, 1, 1, 1 }
uiData.MUTED_TEXT_COLOR = { 0.6, 0.6, 0.6, 1.0 }
uiData.RARITY_COLORS = {
    [0] = { 0.7, 0.7, 0.7, 1.0 },
    [1] = { 1.0, 1.0, 1.0, 1.0 },
    [2] = { 0.0, 0.54, 1.0, 1.0 },
    [3] = { 0.62, 0.07, 1.0, 1.0 },
}
uiData.RARITY_LABELS = {
    [0] = "Auto",
    [1] = "Comm",
    [2] = "Rare",
    [3] = "Epic",
}
uiData.NPC_REGION_OPTIONS = {
    { label = "Neither", value = 1 },
    { label = "Underworld", value = 2 },
    { label = "Surface", value = 3 },
    { label = "Both", value = 4 },
}
uiData.BAN_FILTER_TEXT_ALIAS = "BanFilterText"
uiData.NPC_VIEW_REGION_ALIAS = "NpcViewRegion"
uiData.ROOT_NAV_WIDTH = 220

local packedBanDisplayValuesByBanPool = {}
local packedBanValueColorsByBanPool = {}

local function GetOrdinal(n)
    local s = tostring(n)
    if n % 100 == 11 or n % 100 == 12 or n % 100 == 13 then return s .. "th" end
    local last = n % 10
    if last == 1 then return s .. "st" end
    if last == 2 then return s .. "nd" end
    if last == 3 then return s .. "rd" end
    return s .. "th"
end

local function GetGodDef(godKey)
    return godDefs and godDefs[godKey] or nil
end

local function GetForcedBoonDisplayLabel(boon)
    if not boon then
        return ""
    end
    return boon.SpecialDisplayLabel or uiData.GetBoonText(boon)
end

local function GetBoonMarkerColor(boon)
    return type(boon) == "table" and boon.SpecialBadgeColor or nil
end

local function GetGodDisplayLabel(godKey, def)
    def = def or {}
    local display = def.displayTextKey or godKey
    if banPools.getMaxBanPools(godKey) > 1 then
        display = display:gsub("^1st%s+", "")
    end
    return display
end

local function IsRarityGod(godKey)
    local def = GetGodDef(godKey)
    return type(def) == "table" and def.rarityVar ~= nil
end

local function BuildBanPools(godKey, data)
    local maxBanPools = banPools.getMaxBanPools(godKey)
    if maxBanPools <= 1 then
        return {
            { key = godKey, label = "Bans" },
        }
    end

    local configuredBanPools = banConfig.GetConfiguredBanPoolCount(godKey, data)
    if configuredBanPools < 1 then configuredBanPools = 1 end
    if configuredBanPools > maxBanPools then configuredBanPools = maxBanPools end
    local rootBanPools = {}

    for banPoolIndex = 1, configuredBanPools do
        local banPoolKey = banPools.getBanPoolKey(godKey, banPoolIndex)
        if GetGodDef(banPoolKey) then
            rootBanPools[#rootBanPools + 1] = {
                key = banPoolKey,
                label = GetOrdinal(banPoolIndex),
            }
        end
    end

    if #rootBanPools == 0 then
        rootBanPools[1] = { key = godKey, label = "Bans" }
    end
    return rootBanPools
end

function uiData.GetBanPoolBoons(banPoolKey)
    local entry = godCatalog[banPoolKey]
    if entry and entry.boons then
        return entry.boons
    end
    return EMPTY_LIST
end

function uiData.BuildPackedBanValueColors(banPoolKey)
    local cached = packedBanValueColorsByBanPool[banPoolKey]
    if cached then
        return cached
    end

    local colors = {}
    local packedAlias = banPools.getBanPackedAlias(banPoolKey)
    if type(packedAlias) ~= "string" or packedAlias == "" then
        return colors
    end
    local godKey = banConfig.ResolveGodKey(banPoolKey)
    local godDef = godDefs and godDefs[godKey] or nil
    if type(godDef) == "table" and godDef.showPackedValueColors == false then
        packedBanValueColorsByBanPool[banPoolKey] = colors
        return colors
    end

    for _, boon in ipairs(uiData.GetBanPoolBoons(banPoolKey)) do
        local color = GetBoonMarkerColor(boon)
        local childAlias = banPools.makeBanAlias(packedAlias, boon.Key)
        if type(childAlias) == "string" and childAlias ~= "" and type(color) == "table" then
            colors[childAlias] = color
        end
    end

    packedBanValueColorsByBanPool[banPoolKey] = colors
    return colors
end

function uiData.BuildPackedBanDisplayValues(banPoolKey)
    local cached = packedBanDisplayValuesByBanPool[banPoolKey]
    if cached then
        return cached
    end

    local displayValues = {}
    local packedAlias = banPools.getBanPackedAlias(banPoolKey)
    if type(packedAlias) ~= "string" or packedAlias == "" then
        return displayValues
    end

    for _, boon in ipairs(uiData.GetBanPoolBoons(banPoolKey)) do
        local childAlias = banPools.makeBanAlias(packedAlias, boon.Key)
        if type(childAlias) == "string" and childAlias ~= "" then
            displayValues[childAlias] = GetForcedBoonDisplayLabel(boon)
        end
    end

    packedBanDisplayValuesByBanPool[banPoolKey] = displayValues
    return displayValues
end

function uiData.GetBoonText(boon)
    return boon.Name or boon.Key or ""
end

function uiData.GetVisibleBanCount(banPoolKey, data)
    if type(banPoolKey) ~= "string" or banPoolKey == "" then
        return 0
    end

    local filterText = ""
    if data then
        filterText = tostring(data.get(uiData.BAN_FILTER_TEXT_ALIAS):read() or ""):lower()
    end
    local visibleCount = 0

    for _, boon in ipairs(uiData.GetBanPoolBoons(banPoolKey)) do
        local boonText = (boon.NameLower or string.lower(uiData.GetBoonText(boon)))
        local matchesText = filterText == "" or boonText:find(filterText, 1, true) ~= nil
        if matchesText then
            visibleCount = visibleCount + 1
        end
    end

    return visibleCount
end

function uiData.GetGodColor(banPoolKey)
    local entry = godCatalog[banPoolKey]
    if entry and type(entry.color) == "table" then
        return entry.color
    end
    return uiData.DEFAULT_GOD_COLOR
end

function uiData.BuildBanPoolRoot(godKey, opts)
    opts = opts or EMPTY_OPTS
    local godDef = GetGodDef(godKey) or {}
    local maxBanPools = banPools.getMaxBanPools(godKey)
    return {
        id = godKey,
        label = opts.label or GetGodDisplayLabel(godKey, godDef),
        group = opts.group,
        primaryGodKey = godKey,
        maxBanPools = maxBanPools,
        hasRarity = opts.hasRarity ~= nil and opts.hasRarity or IsRarityGod(godKey),
        hasBridalGlow = opts.hasBridalGlow == true,
        banPools = BuildBanPools(godKey, opts.data),
    }
end

return {
    create = function(data)
        godCatalog = data.catalog.entries
        godDefs = data.godDefs
        banConfig = data.banConfig
        banPools = data.banPools
        packedBanDisplayValuesByBanPool = {}
        packedBanValueColorsByBanPool = {}
        return uiData
    end,
}
