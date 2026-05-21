-- Static giver and ban-pool definitions. This table owns structure only;
-- player choices live in store/data refs, and resolved game data lives in catalog.
local godDefs = {}

local GROUP_CORE       = "Core"
local GROUP_BONUS      = "Bonus"
local GROUP_HAMMERS    = "Hammers"
local GROUP_UW_NPC     = "Underworld"
local GROUP_SF_NPC     = "Surface"
local GROUP_KEEPSAKES  = "Keepsakes"

local MAX_GOD_BAN_POOLS    = 10
local MAX_HAMMER_BAN_POOLS = 5
local MAX_HERMES_BAN_POOLS = 5

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
    { name = "Hermes",     color = "HermesVoice",      group = GROUP_BONUS, banPools = MAX_HERMES_BAN_POOLS }
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
        defKey = "ChaosBuffs",
        key = "Chaos",
        display = "Chaos Buffs",
        color = "ChaosVoice",
        group = GROUP_BONUS,
        lootSource = { type = "LootSet", key = "TrialUpgrade", subKey = "PermanentTraits" }
    },
    {
        defKey = "ChaosCurses",
        key = "Chaos",
        display = "Chaos Curses",
        color = "ChaosVoice",
        group = GROUP_BONUS,
        lootSource = { type = "LootSet", key = "TrialUpgrade", subKey = "TemporaryTraits" }
    },
    {
        defKey = "CirceBNB",
        key = "CirceBNB",
        display = "Black Night Banishment",
        color = "CirceVoice",
        group = GROUP_SF_NPC,
        lootSource = { type = "MetaUpgrade", dataSource = "MetaUpgradeData", exclude = { BaseMetaUpgrade = true } }
    },
    {
        defKey = "CirceCRD",
        key = "CirceCRD",
        display = "Red Citrine Divination",
        color = "CirceVoice",
        group = GROUP_SF_NPC,
        lootSource = { type = "MetaUpgrade", dataSource = "MetaUpgradeCardData", exclude = { BaseMetaUpgrade = true, BaseBonusMetaUpgrade = true } }
    },
    {
        defKey = "Judgement1",
        key = "Judgement1",
        display = "First Biome Judgement",
        color = "HadesVoice",
        group = GROUP_BONUS,
        lootSource = { type = "MetaUpgrade", dataSource = "MetaUpgradeCardData", exclude = { BaseMetaUpgrade = true, BaseBonusMetaUpgrade = true } }
    },
    {
        defKey = "Judgement2",
        key = "Judgement2",
        display = "Second Biome Judgement",
        color = "HadesVoice",
        group = GROUP_BONUS,
        lootSource = { type = "MetaUpgrade", dataSource = "MetaUpgradeCardData", exclude = { BaseMetaUpgrade = true, BaseBonusMetaUpgrade = true } }
    },
    {
        defKey = "Judgement3",
        key = "Judgement3",
        display = "Third Biome Judgement",
        color = "HadesVoice",
        group = GROUP_BONUS,
        lootSource = { type = "MetaUpgrade", dataSource = "MetaUpgradeCardData", exclude = { BaseMetaUpgrade = true, BaseBonusMetaUpgrade = true } }
    }
}

local currentSortIndex = 1

local function RegisterGod(key, data)
    godDefs[key] = data
    godDefs[key].sortIndex = currentSortIndex
    currentSortIndex = currentSortIndex + 1
end

local function RegisterBanPoolLootGod(def)
    local banPools       = def.banPools or MAX_GOD_BAN_POOLS
    local group       = def.group or GROUP_CORE
    local loot        = def.name .. "Upgrade"

    local srcData     = { type = "LootSet", key = loot }

    RegisterGod(def.name, {
        key = def.name,
        displayTextKey = def.name,
        colorKey = def.color,
        lootSource = srcData,
        uiGroup = group,
        banPoolGroupKey = def.name,
        banPoolIndex = 1,
        defaultBanPools = math.min(banPools, 5),
        maxBanPools = banPools
    })

    for i = 2, banPools do
        local key = def.name .. i
        RegisterGod(key, {
            key = key,
            displayTextKey = GetOrdinal(i) .. " " .. def.name,
            colorKey = def.color,
            lootSource = srcData,
            duplicateOf = def.name,
            uiGroup = group,
            banPoolGroupKey = def.name,
            banPoolIndex = i
        })
    end
end

local function RegisterBanPoolWeaponGod(def)
    local loot = "WeaponUpgrade"
    local srcData = { type = "WeaponUpgrade", key = loot }
    local banPools = def.banPools or MAX_HAMMER_BAN_POOLS

    RegisterGod(def.key, {
        key = def.key,
        displayTextKey = "1st " .. def.display,
        colorKey = def.color,
        lootSource = srcData,
        uiGroup = GROUP_HAMMERS,
        showPackedValueColors = false,
        banPoolGroupKey = def.key,
        banPoolIndex = 1,
        defaultBanPools = math.min(banPools, 3),
        maxBanPools = banPools
    })

    for i = 2, banPools do
        local key = def.key .. tostring(i)
        RegisterGod(key, {
            key = key,
            displayTextKey = GetOrdinal(i) .. " " .. def.display,
            colorKey = def.color,
            lootSource = srcData,
            duplicateOf = def.key,
            uiGroup = GROUP_HAMMERS,
            showPackedValueColors = false,
            banPoolGroupKey = def.key,
            banPoolIndex = i
        })
    end
end

local function BuildSingleSourceData(def)
    local sourceType = def.lootSourceType or "UnitSet"

    if sourceType == "UnitSet" then
        return {
            type = "UnitSet",
            unitKey = "NPC_" .. def.key,
            unitSetKey = def.unitSetKey or
                ("NPC_" .. def.key .. "_01")
        }
    end
    if sourceType == "SpellData" then
        return { type = "SpellData" }
    end
    if sourceType == "Keepsake" then
        return { type = "Keepsake", key = def.key }
    end
    return {}
end

local function RegisterSingleBanPoolGod(def)
    local sourceData = BuildSingleSourceData(def)

    RegisterGod(def.key, {
        key = def.key,
        displayTextKey = def.display or def.key,
        colorKey = def.color,
        lootSource = sourceData,
        duplicateOf = def.duplicateOf,
        uiGroup = def.group,
        banPoolGroupKey = def.key,
        banPoolIndex = 1,
        defaultBanPools = 1,
        maxBanPools = 1,
    })
end

local function RegisterSpecialBanPoolGod(def)
    RegisterGod(def.defKey, {
        key = def.key,
        displayTextKey = def.display,
        colorKey = def.color,
        uiGroup = def.group,
        lootSource = def.lootSource,
        banPoolGroupKey = def.defKey,
        banPoolIndex = 1,
        defaultBanPools = 1,
        maxBanPools = 1,
    })
end

for _, def in ipairs(baseOlympians) do
    RegisterBanPoolLootGod(def)
end

for _, def in ipairs(baseWeapons) do
    RegisterBanPoolWeaponGod(def)
end

for _, def in ipairs(baseSingles) do
    RegisterSingleBanPoolGod(def)
end

for _, def in ipairs(baseSpecials) do
    RegisterSpecialBanPoolGod(def)
end


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
    if godDefs[key] then
        godDefs[key].rarityVar = varName
    end
end

for _, entry in pairs(godDefs) do
    if entry.duplicateOf then
        local parent = godDefs[entry.duplicateOf]
        if parent and parent.rarityVar then
            entry.rarityVar = parent.rarityVar
        end
    end
end

return {
    build = function()
        return godDefs
    end,
}
