-- luacheck: globals bit32 store ResetBoonBansUiHarness import

public = {}
_PLUGIN = { guid = "test-boon-bans" }

local MAX_UINT32 = 4294967295

local function deepCopy(orig)
    if type(orig) ~= "table" then
        return orig
    end
    local copy = {}
    for key, value in pairs(orig) do
        copy[key] = deepCopy(value)
    end
    return copy
end

local function makeBitBinaryOp(predicate)
    return function(a, b)
        local result = 0
        local bitValue = 1
        a = a or 0
        b = b or 0

        while a > 0 or b > 0 do
            local abit = a % 2
            local bbit = b % 2
            if predicate(abit, bbit) then
                result = result + bitValue
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bitValue = bitValue * 2
        end

        return result
    end
end

bit32 = {
    band = makeBitBinaryOp(function(a, b)
        return a == 1 and b == 1
    end),
    bor = makeBitBinaryOp(function(a, b)
        return a == 1 or b == 1
    end),
    bnot = function(a)
        return MAX_UINT32 - (a or 0)
    end,
    lshift = function(a, n)
        return ((a or 0) * (2 ^ (n or 0))) % (2 ^ 32)
    end,
    rshift = function(a, n)
        return math.floor((a or 0) / (2 ^ (n or 0)))
    end,
}

rom = {
    mods = {},
    game = {
        DeepCopyTable = deepCopy,
    },
    ImGuiCol = {
        Button = 1,
        ButtonHovered = 2,
        ButtonActive = 3,
        Text = 4,
        Header = 5,
        HeaderHovered = 6,
        HeaderActive = 7,
    },
    gui = {
        add_to_menu_bar = function() end,
        add_imgui = function() end,
    },
}

lib = {
    isEnabled = function()
        return false
    end,
    integrations = {
        invoke = function(_, _, fallback)
            return fallback
        end,
    },
    store = {
        write = function(targetStore, key, value)
            if targetStore and type(targetStore.write) == "function" then
                targetStore.write(key, value)
            end
        end,
    },
}

local storeValues = {}
store = {}

function store.read(key)
    return storeValues[key]
end

function store.write(key, value)
    storeValues[key] = value
end

local function makeBoon(key, bit, rarity)
    rarity = rarity or {}
    local boon = {
        Key = key,
        Name = key,
        NameLower = string.lower(key),
        Bit = bit,
        Mask = 2 ^ bit,
        Rarity = rarity,
    }

    if rarity.isDuo then
        boon.IsSpecial = true
        boon.IsRarityEligible = false
        boon.SpecialDisplayLabel = "[D] " .. key
        boon.SpecialTooltip = "Duo Boon"
        boon.SpecialBadgeText = " D "
        boon.SpecialBadgeColor = { 0.82, 1.0, 0.38, 1.0 }
    elseif rarity.isLegendary then
        boon.IsSpecial = true
        boon.IsRarityEligible = false
        boon.SpecialDisplayLabel = "[L] " .. key
        boon.SpecialTooltip = "Legendary Boon"
        boon.SpecialBadgeText = " L "
        boon.SpecialBadgeColor = { 1.0, 0.56, 0.0, 1.0 }
    elseif rarity.isElemental then
        boon.IsSpecial = true
        boon.IsRarityEligible = false
        boon.SpecialDisplayLabel = "[I] " .. key
        boon.SpecialTooltip = "Elemental Infusion"
        boon.SpecialBadgeText = " I "
        boon.SpecialBadgeColor = { 1.0, 0.29, 1.0, 1.0 }
    else
        boon.IsSpecial = false
        boon.IsRarityEligible = true
        boon.SpecialDisplayLabel = key
    end

    return boon
end

local function makeBaseGodMeta()
    return {
        Apollo = {
            key = "Apollo",
            displayTextKey = "1st Apollo",
            uiGroup = "Core",
            maxBanPools = 3,
            defaultBanPools = 2,
            banPoolGroupKey = "Apollo",
            banPoolIndex = 1,
            sortIndex = 1,
            rarityVar = "PackedApolloRarity",
        },
        Apollo2 = {
            key = "Apollo2",
            duplicateOf = "Apollo",
            banPoolGroupKey = "Apollo",
            banPoolIndex = 2,
            uiGroup = "Core",
        },
        Apollo3 = {
            key = "Apollo3",
            duplicateOf = "Apollo",
            banPoolGroupKey = "Apollo",
            banPoolIndex = 3,
            uiGroup = "Core",
        },
        Circe = {
            key = "Circe",
            displayTextKey = "Circe",
            uiGroup = "Bonus",
            banPoolGroupKey = "Circe",
            banPoolIndex = 1,
            sortIndex = 2,
            rarityVar = "PackedCirceRarity",
        },
        AxeHammer = {
            key = "AxeHammer",
            displayTextKey = "Axe Hammer",
            uiGroup = "Hammers",
            banPoolGroupKey = "AxeHammer",
            banPoolIndex = 1,
            sortIndex = 3,
        },
        HadesKeepsake = {
            key = "HadesKeepsake",
            display = "Hades Keepsake",
            uiGroup = "Keepsakes",
            banPoolGroupKey = "HadesKeepsake",
            banPoolIndex = 1,
            sortIndex = 4,
        },
    }
end

local function makeBaseGodInfo()
    local apolloBoons = {
        makeBoon("Strike", 0),
        makeBoon("Wave Pair", 1, { isDuo = true }),
        makeBoon("Sun Glory", 2, { isLegendary = true }),
        makeBoon("Cast", 3),
        makeBoon("Infusion", 4, { isElemental = true }),
    }

    local info = {
        Apollo = {
            color = { 1.0, 0.7, 0.1, 1.0 },
            boons = deepCopy(apolloBoons),
        },
        Apollo2 = {
            color = { 1.0, 0.7, 0.1, 1.0 },
            boons = deepCopy(apolloBoons),
        },
        Apollo3 = {
            color = { 1.0, 0.7, 0.1, 1.0 },
            boons = deepCopy(apolloBoons),
        },
        Circe = {
            color = { 0.7, 0.2, 1.0, 1.0 },
            boons = {
                makeBoon("Hex", 0),
                makeBoon("Charm Pair", 1, { isDuo = true }),
                makeBoon("Ward", 2),
            },
        },
        AxeHammer = {
            color = { 0.6, 0.4, 0.2, 1.0 },
            boons = {
                makeBoon("Cleave", 0),
                makeBoon("Break", 1),
            },
        },
        HadesKeepsake = {
            color = { 0.6, 0.6, 0.7, 1.0 },
            boons = {
                makeBoon("Ashen Gift", 0),
                makeBoon("Gloam Pair", 1, { isDuo = true }),
            },
        },
    }

    for _, entry in pairs(info) do
        entry.boonByKey = {}
        entry.total = #entry.boons
        entry.banned = 0
        for _, boon in ipairs(entry.boons) do
            entry.boonByKey[boon.Key] = boon
        end
    end

    return info
end

function ResetBoonBansUiHarness(opts)
    opts = opts or {}
    local godDefs = deepCopy(opts.godDefs or makeBaseGodMeta())
    local catalogEntries = deepCopy(opts.catalogEntries or makeBaseGodInfo())
    local configuredCounts = deepCopy(opts.configuredCounts or {
        Apollo = 2,
    })
    local banMasks = deepCopy(opts.banMasks or {
        Apollo = 1,
        Apollo2 = 0,
        Apollo3 = 9,
        Circe = 2,
        AxeHammer = 0,
        HadesKeepsake = 0,
    })

    local function resolveGodKey(key)
        local def = godDefs[key]
        if def and def.duplicateOf then
            return resolveGodKey(def.duplicateOf)
        end
        return key
    end

    local banPools = {
        BAN_POOL_ALIAS = "Bans",
    }

    function banPools.getGroupKey(banPoolKey)
        local def = godDefs[banPoolKey]
        return def and def.banPoolGroupKey or banPoolKey
    end

    function banPools.getMaxBanPools(banPoolKey)
        local groupDef = godDefs[banPools.getGroupKey(banPoolKey)]
        return groupDef and groupDef.maxBanPools or 1
    end

    function banPools.getBanPoolKey(groupKey, banPoolIndex)
        if banPoolIndex <= 1 then
            return groupKey
        end
        return groupKey .. tostring(banPoolIndex)
    end

    function banPools.getBanPoolIndex(banPoolKey)
        local def = godDefs[banPoolKey]
        return def and def.banPoolIndex or 1
    end

    function banPools.getBanPackedAlias(banPoolKey)
        if not godDefs[banPoolKey] then
            return nil
        end
        return banPools.BAN_POOL_ALIAS
    end

    function banPools.makeBanAlias(packedAlias, boonKey)
        return tostring(packedAlias) .. "__" .. tostring(boonKey)
    end

    function banPools.getRarityAlias(godKey, boonKey)
        local def = godDefs[godKey]
        return def and def.rarityVar and (def.rarityVar .. "__" .. boonKey) or nil
    end

    function banPools.getBanMask(banPoolKey)
        local entry = catalogEntries[banPoolKey]
        return entry and ((2 ^ #entry.boons) - 1) or 0
    end

    local banConfig = {}

    function banConfig.ResolveGodKey(key)
        return resolveGodKey(key)
    end

    function banConfig.GetConfiguredBanPoolCount(godKey)
        return configuredCounts[resolveGodKey(godKey)] or 1
    end

    function banConfig.IsBanPoolCustomized(banPoolKey)
        return (banMasks[banPoolKey] or 0) ~= 0
    end

    import = function(path)
        return dofile("src/" .. path)
    end

    local data = {
        godDefs = godDefs,
        catalog = {
            entries = catalogEntries,
        },
        banPools = banPools,
        banConfig = banConfig,
    }
    local uiModel = import("mods/ui/ui_model.lua").create(data)
    return uiModel, data, {
        configuredCounts = configuredCounts,
        banMasks = banMasks,
    }
end
