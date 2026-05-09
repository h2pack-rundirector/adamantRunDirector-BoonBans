local meta = {}

local internal = RunDirectorBoonBans_Internal
local MODULE_ID = "BoonBans"

local function Log(fmt, ...)
    local activeStore = internal.store
    local debugEnabled = activeStore and activeStore.read("DebugMode") == true or false
    lib.logging.logIf(MODULE_ID, debugEnabled, fmt, ...)
end

local GROUP_CORE       = "Core"
local GROUP_BONUS      = "Bonus"
local GROUP_HAMMERS    = "Hammers"
local GROUP_UW_NPC     = "Underworld"
local GROUP_SF_NPC     = "Surface"
local GROUP_KEEPSAKES  = "Keepsakes"

local MAX_GOD_TIERS    = 10
local MAX_HAMMER_TIERS = 5
local MAX_HERMES_TIERS = 5
local TIER_BAN_ALIAS   = "Bans"
internal.TIER_BAN_ALIAS = TIER_BAN_ALIAS

local function GetBitCount(source, defaultPrefix)
    if not source then return 8 end
    local count = 0

    if source.type == "LootSet" then
        local container = LootSetData[defaultPrefix]
        local data

        if container and container[source.key] then
            data = container[source.key]
        else
            data = LootSetData[source.key] or (LootSetData.Loot and LootSetData.Loot[source.key])
        end

        if data then
            if data.WeaponUpgrades then count = count + #data.WeaponUpgrades end
            if data.Traits then count = count + #data.Traits end

            if source.subKey and data[source.subKey] then
                count = count + #data[source.subKey]
            end
        end
    elseif source.type == "UnitSet" then
        local unit = UnitSetData[source.unitKey]
        if unit and unit[source.unitSetKey] and unit[source.unitSetKey].Traits then
            count = #unit[source.unitSetKey].Traits
        end
    elseif source.type == "SpellData" then
        for _ in pairs(SpellData) do count = count + 1 end
    elseif source.type == "WeaponUpgrade" then
        local data = LootSetData.Loot and LootSetData.Loot.WeaponUpgrade and LootSetData.Loot.WeaponUpgrade.Traits
        if data then
            local prefixes = source.prefixes or { defaultPrefix }
            for _, trait in ipairs(data) do
                for _, p in ipairs(prefixes) do
                    if string.find(trait, p, 1, true) == 1 then
                        count = count + 1
                        break
                    end
                end
            end
        end
    elseif source.type == "MetaUpgrade" then
        local data = _G[source.dataSource]
        if data then
            for k, _ in pairs(data) do
                local isValid = true
                if source.exclude and source.exclude[k] then isValid = false end
                if isValid then count = count + 1 end
            end
        end
    elseif source.type == "Keepsake" then
        if source.key == "HadesKeepsake" then
            local unit = UnitSetData["NPC_Hades"]
            if unit and unit["NPC_Hades_Field_01"] and unit["NPC_Hades_Field_01"].Traits then
                count = #unit["NPC_Hades_Field_01"].Traits
            end
        end
    end

    Log("BitCheck: %-12s | Type: %-13s | Count: %d",
        defaultPrefix or "??",
        source.type,
        count)

    return count > 0 and count or 1
end

local function GetOrdinal(n)
    local s = tostring(n)
    if n % 100 == 11 or n % 100 == 12 or n % 100 == 13 then return s .. "th" end
    local last = n % 10
    if last == 1 then return s .. "st" end
    if last == 2 then return s .. "nd" end
    if last == 3 then return s .. "rd" end
    return s .. "th"
end
local baseOlympians = {
    { name = "Aphrodite",  color = "AphroditeVoice" },
    { name = "Apollo",     color = "ApolloVoice" },
    { name = "Ares",       color = "AresVoice" },
    { name = "Demeter",    color = "DemeterVoice" },
    { name = "Hephaestus", color = "HephaestusVoice" },
    { name = "Hera",       color = "HeraDamage" },
    { name = "Hestia",     color = "HestiaVoice" },
    { name = "Poseidon",   color = "PoseidonVoice" },
    { name = "Zeus",       color = "ZeusVoice" },
    { name = "Hermes",     color = "HermesVoice",      group = GROUP_BONUS, tiers = MAX_HERMES_TIERS }
}

local baseWeapons = {
    { key = "Staff",  color = "SpringGreen",        display = "Staff" },
    { key = "Dagger", color = "Silver",             display = "Blades" },
    { key = "Axe",    color = "OrangeRed",          display = "Axe" },
    { key = "Torch",  color = "Gold",               display = "Torch" },
    { key = "Lob",    color = "BonesActive",        display = "Skull" },
    { key = "Suit",   color = "DeepSkyBlue",        display = "Coat" },
}

local baseSingles = {
    -- Underworld
    { key = "Arachne",       color = "ArachneVoice",      group = GROUP_UW_NPC },
    { key = "Narcissus",     color = "NarcissusVoice",    group = GROUP_UW_NPC },
    { key = "Echo",          color = "EchoVoice",         group = GROUP_UW_NPC },
    { key = "Hades",         color = "HadesVoice",        group = GROUP_UW_NPC,    unitSetKey = "NPC_Hades_Field_01" },
    -- Surface
    { key = "Medea",         color = "MedeaVoice",        group = GROUP_SF_NPC },
    { key = "Circe",         color = "CirceVoice",        group = GROUP_SF_NPC },
    { key = "Icarus",        color = "IcarusVoice",       group = GROUP_SF_NPC },
    { key = "Dionysus",      color = "DionysusDamage",    group = GROUP_SF_NPC },
    -- Bonus
    { key = "Selene",        color = "SeleneVoice",       group = GROUP_BONUS,     lootSourceType = "SpellData" },
    { key = "Artemis",       color = "ArtemisDamage",     group = GROUP_BONUS,     unitSetKey = "NPC_Artemis_Field_01" },
    { key = "Athena",        color = "AthenaDamageLight", group = GROUP_BONUS,     unitSetKey = "NPC_Athena_01" },
    -- Keepsake
    { key = "HadesKeepsake", color = "HadesVoice",        group = GROUP_KEEPSAKES,
    duplicateOf = "Hades", display = "Jeweled Pom", lootSourceType = "Keepsake" }
}

local baseSpecials = {
    {
        metaKey = "ChaosBuffs",
        key = "Chaos",
        display = "Chaos Buffs",
        color = "ChaosVoice",
        group = GROUP_BONUS,
        packedVar = "PackedChaosBuff",
        lootSource = { type = "LootSet", key = "TrialUpgrade", subKey = "PermanentTraits" }
    },
    {
        metaKey = "ChaosCurses",
        key = "Chaos",
        display = "Chaos Curses",
        color = "ChaosVoice",
        group = GROUP_BONUS,
        packedVar = "PackedChaosCurse",
        lootSource = { type = "LootSet", key = "TrialUpgrade", subKey = "TemporaryTraits" }
    },
    {
        metaKey = "CirceBNB",
        key = "CirceBNB",
        display = "Black Night Banishment",
        color = "CirceVoice",
        group = GROUP_SF_NPC,
        packedVar = "PackedCirceBNB",
        lootSource = { type = "MetaUpgrade", dataSource = "MetaUpgradeData", exclude = { BaseMetaUpgrade = true } }
    },
    {
        metaKey = "CirceCRD",
        key = "CirceCRD",
        display = "Red Citrine Divination",
        color = "CirceVoice",
        group = GROUP_SF_NPC,
        packedVar = "PackedCirceCRD",
        lootSource = { type = "MetaUpgrade", dataSource = "MetaUpgradeCardData", exclude = { BaseMetaUpgrade = true, BaseBonusMetaUpgrade = true } }
    },
    {
        metaKey = "Judgement1",
        key = "Judgement1",
        display = "First Biome Judgement",
        color = "HadesVoice",
        group = GROUP_BONUS,
        packedVar = "PackedJudgement1",
        lootSource = { type = "MetaUpgrade", dataSource = "MetaUpgradeCardData", exclude = { BaseMetaUpgrade = true, BaseBonusMetaUpgrade = true } }
    },
    {
        metaKey = "Judgement2",
        key = "Judgement2",
        display = "Second Biome Judgement",
        color = "HadesVoice",
        group = GROUP_BONUS,
        packedVar = "PackedJudgement2",
        lootSource = { type = "MetaUpgrade", dataSource = "MetaUpgradeCardData", exclude = { BaseMetaUpgrade = true, BaseBonusMetaUpgrade = true } }
    },
    {
        metaKey = "Judgement3",
        key = "Judgement3",
        display = "Third Biome Judgement",
        color = "HadesVoice",
        group = GROUP_BONUS,
        packedVar = "PackedJudgement3",
        lootSource = { type = "MetaUpgrade", dataSource = "MetaUpgradeCardData", exclude = { BaseMetaUpgrade = true, BaseBonusMetaUpgrade = true } }
    }
}

local currentSortIndex = 1

local function RegisterGod(key, data)
    meta[key] = data
    meta[key].sortIndex = currentSortIndex
    currentSortIndex = currentSortIndex + 1
end

for _, def in ipairs(baseOlympians) do
    local tiers       = def.tiers or MAX_GOD_TIERS
    local group       = def.group or GROUP_CORE
    local loot        = def.name .. "Upgrade"

    local srcData     = { type = "LootSet", key = loot }
    local dynamicBits = GetBitCount(srcData, def.name)

    RegisterGod(def.name, {
        key = def.name,
        displayTextKey = def.name,
        colorKey = def.color,
        packedConfig = { var = TIER_BAN_ALIAS, table = def.name .. "Tiers", row = 1, bits = dynamicBits },
        tierTableConfig = {
            alias = def.name .. "Tiers",
            maxRows = tiers,
            defaultRows = math.min(tiers, 5),
        },
        lootSource = srcData,
        uiGroup = group,
        tier = 1,
        maxTiers = tiers
    })

    for i = 2, tiers do
        local key = def.name .. i
        RegisterGod(key, {
            key = key,
            displayTextKey = GetOrdinal(i) .. " " .. def.name,
            colorKey = def.color,
            packedConfig = { var = TIER_BAN_ALIAS, table = def.name .. "Tiers", row = i, bits = dynamicBits },
            lootSource = srcData,
            duplicateOf = def.name,
            uiGroup = group,
            tier = i
        })
    end
end

for _, def in ipairs(baseWeapons) do
    local loot = "WeaponUpgrade"
    local srcData = { type = "WeaponUpgrade", key = loot }
    local dynamicBits = GetBitCount(srcData, def.key)
    local tiers = def.tiers or MAX_HAMMER_TIERS

    RegisterGod(def.key, {
        key = def.key,
        displayTextKey = "1st " .. def.display,
        colorKey = def.color,
        packedConfig = { var = TIER_BAN_ALIAS, table = def.key .. "Tiers", row = 1, bits = dynamicBits },
        tierTableConfig = {
            alias = def.key .. "Tiers",
            maxRows = tiers,
            defaultRows = math.min(tiers, 3),
        },
        lootSource = srcData,
        uiGroup = GROUP_HAMMERS,
        showPackedValueColors = false,
        tier = 1,
        maxTiers = tiers
    })

    for i = 2, tiers do
        local key = def.key .. tostring(i)
        RegisterGod(key, {
            key = key,
            displayTextKey = GetOrdinal(i) .. " " .. def.display,
            colorKey = def.color,
            packedConfig = { var = TIER_BAN_ALIAS, table = def.key .. "Tiers", row = i, bits = dynamicBits },
            lootSource = srcData,
            duplicateOf = def.key,
            uiGroup = GROUP_HAMMERS,
            showPackedValueColors = false,
            tier = i
        })
    end
end

for _, def in ipairs(baseSingles) do
    local sourceType = def.lootSourceType or "UnitSet"
    local sourceData = {}

    if sourceType == "UnitSet" then
        sourceData = {
            type = "UnitSet",
            unitKey = "NPC_" .. def.key,
            unitSetKey = def.unitSetKey or
                ("NPC_" .. def.key .. "_01")
        }
    elseif sourceType == "SpellData" then
        sourceData = { type = "SpellData" }
    elseif sourceType == "Keepsake" then
        sourceData = { type = "Keepsake", key = def.key }
    end

    local dynamicBits = GetBitCount(sourceData, def.key)

    RegisterGod(def.key, {
        key = def.key,
        displayTextKey = def.display or def.key,
        colorKey = def.color,
        packedConfig = { var = "Packed" .. def.key, offset = 0, bits = dynamicBits },
        lootSource = sourceData,
        duplicateOf = def.duplicateOf,
        uiGroup = def.group
    })
end

for _, def in ipairs(baseSpecials) do
    local dynamicBits = GetBitCount(def.lootSource, def.key)
    RegisterGod(def.metaKey, {
        key = def.key,
        displayTextKey = def.display,
        colorKey = def.color,
        uiGroup = def.group,
        packedConfig = { var = def.packedVar, offset = 0, bits = dynamicBits },
        lootSource = def.lootSource
    })
end


internal.godMeta = meta


local rarityEligible = {
    Aphrodite  = "PackedRarityAphrodite",
    Apollo     = "PackedRarityApollo",
    Ares       = "PackedRarityAres",
    Demeter    = "PackedRarityDemeter",
    Hephaestus = "PackedRarityHephaestus",
    Hera       = "PackedRarityHera",
    Hestia     = "PackedRarityHestia",
    Poseidon   = "PackedRarityPoseidon",
    Zeus       = "PackedRarityZeus",

    Hermes     = "PackedRarityHermes",
    Artemis    = "PackedRarityArtemis",
    Athena     = "PackedRarityAthena",
    Dionysus   = "PackedRarityDionysus"
}

for key, varName in pairs(rarityEligible) do
    if meta[key] then
        meta[key].rarityVar = varName
    end
end

for _, entry in pairs(meta) do
    if entry.duplicateOf then
        local parent = meta[entry.duplicateOf]
        if parent and parent.rarityVar then
            entry.rarityVar = parent.rarityVar
        end
    end
end
