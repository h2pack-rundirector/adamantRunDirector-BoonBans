-- luacheck: globals TestDataLogic bit32 import game GetEquippedWeapon

local lu = require("luaunit")

TestDataLogic = {}

local function MakeGodDefs()
    return {
        Apollo = {
            key = "Apollo",
            displayTextKey = "Apollo",
            colorKey = "ApolloVoice",
            lootSource = { type = "LootSet", key = "ApolloUpgrade" },
            uiGroup = "Core",
            banPoolGroupKey = "Apollo",
            banPoolIndex = 1,
            defaultBanPools = 2,
            maxBanPools = 3,
            hasRarity = true,
        },
        Apollo2 = {
            key = "Apollo2",
            duplicateOf = "Apollo",
            colorKey = "ApolloVoice",
            banPoolGroupKey = "Apollo",
            banPoolIndex = 2,
            hasRarity = true,
        },
        Staff = {
            key = "Staff",
            displayTextKey = "Staff",
            colorKey = "StaffColor",
            lootSource = { type = "WeaponUpgrade", key = "WeaponUpgrade" },
            banPoolGroupKey = "Staff",
            banPoolIndex = 1,
            defaultBanPools = 1,
            maxBanPools = 1,
            showPackedValueColors = false,
        },
        HadesKeepsake = {
            key = "HadesKeepsake",
            displayTextKey = "Jeweled Pom",
            colorKey = "HadesVoice",
            banPoolGroupKey = "HadesKeepsake",
            banPoolIndex = 1,
        },
        CirceBNB = {
            key = "CirceBNB",
            displayTextKey = "Black Night Banishment",
            colorKey = "CirceVoice",
            banPoolGroupKey = "CirceBNB",
            banPoolIndex = 1,
        },
        CirceCRD = {
            key = "CirceCRD",
            displayTextKey = "Red Citrine Divination",
            colorKey = "CirceVoice",
            banPoolGroupKey = "CirceCRD",
            banPoolIndex = 1,
        },
        Judgement2 = {
            key = "Judgement2",
            displayTextKey = "Second Biome Judgement",
            colorKey = "HadesVoice",
            banPoolGroupKey = "Judgement2",
            banPoolIndex = 1,
        },
    }
end

local function MakeBaseCatalog()
    return {
        Apollo = {
            boons = {
                { Key = "Strike", Name = "Strike", Bit = 0, Mask = 1, IsRarityEligible = true, IsBridalGlowEligible = true },
                { Key = "Duo", Name = "Duo", Bit = 1, Mask = 2, IsRarityEligible = false, IsBridalGlowEligible = false },
            },
        },
        Staff = {
            boons = {
                { Key = "StaffBonk", Name = "Staff Bonk", Bit = 0, Mask = 1, IsRarityEligible = true },
            },
        },
    }
end

function TestDataLogic.setUp()
    import = function(path, _, ...)
        return assert(loadfile("src/" .. path))(...)
    end
    game = {
        Color = {
            ApolloVoice = { 255, 128, 0, 255 },
            StaffColor = { 0, 255, 0, 255 },
            Black = { 0, 0, 0, 255 },
        },
    }
    GetEquippedWeapon = function()
        return "WeaponStaff"
    end
end

function TestDataLogic.testStorageKeepsGlobalsAndControlsDeclareTraitSources()
    local godDefs = MakeGodDefs()
    local baseCatalog = MakeBaseCatalog()
    local storage = dofile("src/mods/data/storage.lua").buildStorage()
    local byAlias = {}
    for _, node in ipairs(storage) do
        byAlias[node.alias] = node
    end

    lu.assertEquals(byAlias.ImproveFirstNBoonRarity.type, "int")
    lu.assertEquals(byAlias.BridalGlowTargetBoon.type, "string")

    local catalog = {
        entries = {
            Apollo = baseCatalog.Apollo,
            Staff = baseCatalog.Staff,
        },
    }
    local controls = dofile("src/mods/data/controls.lua").build(godDefs, catalog)
    lu.assertEquals(controls.Apollo.template, "TraitSource")
    lu.assertEquals(controls.Apollo.maxTiers, 3)
    lu.assertEquals(controls.Apollo.defaultTiers, 2)
    lu.assertEquals(controls.Apollo.group, "Core")
    lu.assertTrue(controls.Apollo.hasRarity)
    lu.assertEquals(controls.Apollo.items[1].key, "Strike")
    lu.assertTrue(controls.Apollo.items[1].isBridalGlowEligible)
    lu.assertEquals(controls.Apollo.items[2].isRarityEligible, false)
    lu.assertFalse(controls.Apollo.items[2].isBridalGlowEligible)
    lu.assertEquals(controls.Staff.showValueColors, false)
end

function TestDataLogic.testControlsFailFastWhenRequiredSourceHasNoExtractedTraits()
    local godDefs = {
        Apollo = {
            key = "Apollo",
            displayTextKey = "Apollo",
            lootSource = { type = "LootSet", key = "ApolloUpgrade" },
            banPoolGroupKey = "Apollo",
            banPoolIndex = 1,
        },
    }
    local catalog = {
        entries = {
            Apollo = {
                boons = {},
            },
        },
    }

    local ok, err = pcall(function()
        dofile("src/mods/data/controls.lua").build(godDefs, catalog)
    end)

    lu.assertFalse(ok)
    lu.assertNotNil(string.find(err, "required control Apollo produced no traits", 1, true))
    lu.assertNotNil(string.find(err, "LootSet ApolloUpgrade", 1, true))
end

function TestDataLogic.testTraitSourceUsesTraitNamesAsPackedKeys()
    local templates = dofile("src/mods/controls/templates.lua")
    local instance = templates.TraitSource.prepare({
        name = "Apollo",
        items = {
            { key = "Strike", label = "Strike", bit = 0, isRarityEligible = true },
            { key = "Duo", label = "Duo", bit = 1, isRarityEligible = false },
            { key = "Cast", label = "Cast", bit = 2, isRarityEligible = true, isBridalGlowEligible = true },
        },
        maxTiers = 2,
        defaultTiers = 1,
        hasRarity = true,
        group = "Core",
    })
    local storage = templates.TraitSource.storage(instance)

    lu.assertEquals(storage[1].row[1].bits[1].key, "Strike")
    lu.assertEquals(storage[1].row[1].bits[2].key, "Duo")
    lu.assertEquals(storage[1].row[1].bits[3].key, "Cast")
    lu.assertEquals(storage[3].bits[1].key, "Strike")
    lu.assertEquals(storage[3].bits[2].key, "Cast")
    lu.assertEquals(#storage[3].bits, 2)

    local source = templates.TraitSource.createRuntime({}, instance)
    lu.assertEquals(source:name(), "Apollo")
    lu.assertEquals(source:group(), "Core")
    lu.assertEquals(source:maxTiers(), 2)
    lu.assertEquals(source:defaultTiers(), 1)
    lu.assertTrue(source:hasRarity())
    lu.assertTrue(source:hasBridalGlowTargets())
    local targets = {}
    lu.assertEquals(source:collectBridalGlowTargets(targets), targets)
    lu.assertEquals(targets, {
        {
            key = "Cast",
            label = "Cast",
            sourceName = "Apollo",
        },
    })
    lu.assertEquals(source:findBridalGlowTarget("Cast"), targets[1])
    lu.assertNil(source:findBridalGlowTarget("Strike"))
end

function TestDataLogic.testCatalogDuplicatesEntriesAndSourceResolverResolvesSources()
    local catalogModule = dofile("src/mods/data/catalog/catalog.lua")
    local sourceResolverModule = dofile("src/mods/data/source_resolver.lua")
    local godDefs = MakeGodDefs()
    local baseCatalog = MakeBaseCatalog()
    local catalog = catalogModule.build(godDefs, baseCatalog)
    local sourceResolver = sourceResolverModule.create(godDefs, catalog)

    lu.assertEquals(catalog.entries.Apollo.color, { 1, 128 / 255, 0, 1 })
    lu.assertEquals(catalog.traitLookup.Strike, {
        { god = "Apollo", bit = 0, mask = 1 },
        { god = "Apollo2", bit = 0, mask = 1 },
    })
    lu.assertEquals(catalog.entries.Apollo2.boons[1].God, "Apollo2")
    lu.assertEquals(sourceResolver.infoFromLoot("ApolloUpgrade"), {
        controlName = "Apollo",
        sourceName = "Apollo",
        tierKey = "Apollo",
        tierIndex = 1,
    })
    lu.assertEquals(sourceResolver.infoFromLoot("WeaponUpgrade"), {
        controlName = "Staff",
        sourceName = "Staff",
        tierKey = "Staff",
        tierIndex = 1,
    })
    lu.assertEquals(sourceResolver.primarySourceName("Apollo2"), "Apollo")
    lu.assertEquals(sourceResolver.primarySourceName("Unknown"), "Unknown")
    lu.assertEquals(sourceResolver.infoFromTrait("Strike", "Apollo", 2), {
        controlName = "Apollo",
        sourceName = "Apollo",
        tierKey = "Apollo2",
        tierIndex = 2,
        traitName = "Strike",
    })
    lu.assertEquals(sourceResolver.specialSource("blackNightBanishment"), {
        controlName = "CirceBNB",
        sourceName = "CirceBNB",
        tierKey = "CirceBNB",
        tierIndex = 1,
    })
    lu.assertEquals(sourceResolver.specialSource("hadesKeepsake"), {
        controlName = "HadesKeepsake",
        sourceName = "HadesKeepsake",
        tierKey = "HadesKeepsake",
        tierIndex = 1,
    })
    lu.assertEquals(sourceResolver.specialSource("redCitrineDivination"), {
        controlName = "CirceCRD",
        sourceName = "CirceCRD",
        tierKey = "CirceCRD",
        tierIndex = 1,
    })
    lu.assertEquals(sourceResolver.judgementSource(2), {
        controlName = "Judgement2",
        sourceName = "Judgement2",
        tierKey = "Judgement2",
        tierIndex = 1,
    })
end
