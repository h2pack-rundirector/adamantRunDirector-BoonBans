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
            maxTiers = 3,
            tier = 1,
            sortIndex = 1,
            rarityVar = "PackedApolloRarity",
            packedConfig = { bits = 5, var = "Bans", table = "ApolloTiers", row = 1 },
            tierTableConfig = { alias = "ApolloTiers", maxRows = 3, defaultRows = 2 },
        },
        Apollo2 = {
            key = "Apollo2",
            duplicateOf = "Apollo",
            tier = 2,
            uiGroup = "Core",
            packedConfig = { bits = 5, var = "Bans", table = "ApolloTiers", row = 2 },
        },
        Apollo3 = {
            key = "Apollo3",
            duplicateOf = "Apollo",
            tier = 3,
            uiGroup = "Core",
            packedConfig = { bits = 5, var = "Bans", table = "ApolloTiers", row = 3 },
        },
        Circe = {
            key = "Circe",
            displayTextKey = "Circe",
            uiGroup = "Bonus",
            sortIndex = 2,
            rarityVar = "PackedCirceRarity",
            packedConfig = { bits = 3, var = "PackedCirce" },
        },
        AxeHammer = {
            key = "AxeHammer",
            displayTextKey = "Axe Hammer",
            uiGroup = "Hammers",
            sortIndex = 3,
            packedConfig = { bits = 2, var = "PackedAxeHammer" },
        },
        HadesKeepsake = {
            key = "HadesKeepsake",
            display = "Hades Keepsake",
            uiGroup = "Keepsakes",
            sortIndex = 4,
            packedConfig = { bits = 2, var = "PackedHadesKeepsake" },
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
    lib.integrations = lib.integrations or {
        invoke = function(_, _, fallback)
            return fallback
        end,
    }
    lib.integrations.invoke = lib.integrations.invoke or function(_, _, fallback)
        return fallback
    end

    for key in pairs(storeValues) do
        storeValues[key] = nil
    end
    storeValues.ViewRegion = 4
    if opts.storeValues then
        for key, value in pairs(opts.storeValues) do
            storeValues[key] = value
        end
    end

    RunDirectorBoonBans_Internal = {
        godMeta = deepCopy(opts.godMeta or makeBaseGodMeta()),
        godInfo = deepCopy(opts.godInfo or makeBaseGodInfo()),
    }

    local internal = RunDirectorBoonBans_Internal
    local banConfig = deepCopy(opts.banConfig or {
        Apollo = 1,
        Apollo2 = 0,
        Apollo3 = 9,
        Circe = 2,
        AxeHammer = 0,
        HadesKeepsake = 0,
    })
    local rarityValues = deepCopy(opts.rarityValues or {})
    local recalcCalls = 0

    internal.GetRootKey = opts.getRootKey
    internal.GetBanConfig = function(godKey, session)
        local meta = internal.godMeta[godKey]
        local packedVar = meta and meta.packedConfig and meta.packedConfig.var or nil
        if session and packedVar and type(session.read) == "function" then
            local staged = session.read(packedVar)
            if staged ~= nil then
                return staged
            end
        end
        return banConfig[godKey] or 0
    end
    internal.SetBanConfig = function(godKey, value)
        local previous = banConfig[godKey] or 0
        banConfig[godKey] = value
        return previous ~= value
    end
    internal.RecalculateBannedCounts = function()
        recalcCalls = recalcCalls + 1
    end
    internal.UpdateGodStats = function(godKey)
        local entry = internal.godInfo[godKey]
        if not entry or not entry.boons then
            return false
        end
        local count = 0
        local cfg = banConfig[godKey] or 0
        for _, boon in ipairs(entry.boons) do
            if bit32.band(cfg, boon.Mask) ~= 0 then
                count = count + 1
            end
        end
        entry.banned = count
        entry.total = #entry.boons
        return true
    end
    internal.GetRarityValue = function(godKey, bitIndex)
        local valueByBit = rarityValues[godKey] or {}
        return valueByBit[bitIndex] or 0
    end
    internal.SetRarityValue = function(godKey, bitIndex, newValue)
        rarityValues[godKey] = rarityValues[godKey] or {}
        local previous = rarityValues[godKey][bitIndex] or 0
        rarityValues[godKey][bitIndex] = newValue
        return previous ~= newValue
    end
    internal.ResetGodBans = function(godKey)
        local previous = banConfig[godKey] or 0
        if previous == 0 then
            return false
        end
        banConfig[godKey] = 0
        internal.UpdateGodStats(godKey)
        return true
    end
    internal.ResetAllBans = function()
        local changed = false
        for godKey, value in pairs(banConfig) do
            if value ~= 0 then
                banConfig[godKey] = 0
                internal.UpdateGodStats(godKey)
                changed = true
            end
        end
        return changed
    end
    internal.ResetAllRarity = function()
        rarityValues = {}
        return true
    end
    internal.GetRarityAlias = function(scopeKey, boonKey)
        return scopeKey .. "_" .. boonKey .. "_Rarity"
    end
    internal.GetBanRootAlias = function(scopeKey)
        local meta = internal.godMeta[scopeKey]
        return meta and meta.packedConfig and meta.packedConfig.var or nil
    end
    internal.MakeBanAlias = function(packedVar, boonKey)
        return tostring(packedVar) .. "__" .. tostring(boonKey)
    end

    import = function(path)
        dofile("src/" .. path)
    end

    dofile("src/mods/ui.lua")

    for godKey, _ in pairs(internal.godInfo) do
        internal.UpdateGodStats(godKey)
    end

    return internal.ui, internal, {
        banConfig = banConfig,
        rarityValues = rarityValues,
        getRecalcCalls = function()
            return recalcCalls
        end,
    }
end
