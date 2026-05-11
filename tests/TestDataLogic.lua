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
            banPoolGroupKey = "Apollo",
            banPoolIndex = 1,
            defaultBanPools = 2,
            maxBanPools = 3,
            rarityVar = "PackedRarityApollo",
        },
        Apollo2 = {
            key = "Apollo2",
            duplicateOf = "Apollo",
            colorKey = "ApolloVoice",
            banPoolGroupKey = "Apollo",
            banPoolIndex = 2,
            rarityVar = "PackedRarityApollo",
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
    }
end

local function MakeBaseCatalog()
    return {
        Apollo = {
            boons = {
                { Key = "Strike", Name = "Strike", Bit = 0, Mask = 1, IsRarityEligible = true },
                { Key = "Duo", Name = "Duo", Bit = 1, Mask = 2, IsRarityEligible = false },
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
    import = function(path)
        return dofile("src/" .. path)
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

function TestDataLogic.testBanPoolsExposeStableAliasesKeysAndMasks()
    local banPools = dofile("src/mods/data/ban_pools.lua").create(MakeGodDefs(), MakeBaseCatalog())

    lu.assertEquals(banPools.getCatalogKey("Apollo2"), "Apollo")
    lu.assertEquals(banPools.getGroupKey("Apollo2"), "Apollo")
    lu.assertEquals(banPools.getTableAlias("Apollo2"), "ApolloBanPools")
    lu.assertEquals(banPools.getBanPoolKey("Apollo", 1), "Apollo")
    lu.assertEquals(banPools.getBanPoolKey("Apollo", 2), "Apollo2")
    lu.assertEquals(banPools.getMaxBanPools("Apollo2"), 3)
    lu.assertEquals(banPools.getDefaultBanPools("Apollo2"), 2)
    lu.assertFalse(banPools.isTableOwner("Apollo2"))
    lu.assertTrue(banPools.isTableOwner("Apollo"))
    lu.assertEquals(banPools.getBanPackedAlias("Apollo"), "Bans")
    lu.assertEquals(banPools.makeBanAlias("Bans", "Strike"), "Bans__Strike")
    lu.assertEquals(banPools.getRarityAlias("Apollo", "Strike"), "PackedRarityApollo__Strike")
    lu.assertEquals(banPools.getBitCount("Apollo2"), 2)
    lu.assertEquals(banPools.getBanMask("Apollo"), 3)
end

function TestDataLogic.testBanConfigProjectsStoreAndSessionThroughTableRows()
    local godDefs = MakeGodDefs()
    local banPools = dofile("src/mods/data/ban_pools.lua").create(godDefs, MakeBaseCatalog())
    local banConfig = dofile("src/mods/data/ban_config.lua").create(godDefs, banPools)
    local rows = {
        { Bans = 3 },
        { Bans = 1 },
    }
    local handle = {
        table = function(alias)
            lu.assertEquals(alias, "ApolloBanPools")
            return {
                count = function()
                    return #rows
                end,
                rowHandle = function(_, index)
                    return {
                        read = function(childAlias)
                            return rows[index][childAlias]
                        end,
                    }
                end,
            }
        end,
        read = function(alias)
            if alias == "PackedRarityApollo" then
                return 8
            end
            return nil
        end,
    }

    lu.assertEquals(banConfig.ResolveGodKey("Apollo2"), "Apollo")
    lu.assertEquals(banConfig.GetConfiguredBanPoolCount("Apollo", handle), 2)
    lu.assertTrue(banConfig.IsBanPoolConfigured("Apollo", 2, handle))
    lu.assertFalse(banConfig.IsBanPoolConfigured("Apollo", 3, handle))
    lu.assertEquals(banConfig.GetBanMask("Apollo2", handle), 1)
    lu.assertTrue(banConfig.IsBanPoolCustomized("Apollo2", handle))
    lu.assertEquals(banConfig.GetRarityValue("Apollo", 1, handle), 2)
end

function TestDataLogic.testStorageSchemaBuildsTableRowsAndRarityPackedNodes()
    local godDefs = MakeGodDefs()
    local baseCatalog = MakeBaseCatalog()
    local banPools = dofile("src/mods/data/ban_pools.lua").create(godDefs, baseCatalog)
    local storage = dofile("src/mods/data/storage_schema.lua").buildStorage(godDefs, baseCatalog, banPools)
    local byAlias = {}
    for _, node in ipairs(storage) do
        byAlias[node.alias] = node
    end

    local tableNode = byAlias.ApolloBanPools
    lu.assertEquals(tableNode.type, "table")
    lu.assertEquals(tableNode.maxRows, 3)
    lu.assertEquals(tableNode.defaultRows, 2)
    lu.assertEquals(tableNode.row[1].type, "packedInt")
    lu.assertEquals(tableNode.row[1].alias, "Bans")
    lu.assertEquals(tableNode.row[1].bits[1], {
        alias = "Bans__Strike",
        label = "Strike",
        offset = 0,
        width = 1,
        type = "bool",
        default = false,
    })

    local rarityNode = byAlias.PackedRarityApollo
    lu.assertEquals(rarityNode.type, "packedInt")
    lu.assertEquals(#rarityNode.bits, 1)
    lu.assertEquals(rarityNode.bits[1].alias, "PackedRarityApollo__Strike")
    lu.assertEquals(rarityNode.bits[1].width, 2)
end

function TestDataLogic.testCatalogDuplicatesEntriesAndResolvesWeaponLootSource()
    local catalogModule = dofile("src/mods/data/catalog/catalog.lua")
    local godDefs = MakeGodDefs()
    local baseCatalog = MakeBaseCatalog()
    local catalog = catalogModule.build(godDefs, baseCatalog)

    lu.assertEquals(catalog.getEntry("Apollo").color, { 1, 128 / 255, 0, 1 })
    lu.assertEquals(catalog.findTraitEntries("Strike"), {
        { god = "Apollo", bit = 0, mask = 1 },
        { god = "Apollo2", bit = 0, mask = 1 },
    })
    lu.assertEquals(catalog.getBoons("Apollo2")[1].God, "Apollo2")
    lu.assertEquals(catalog.getGodFromLootsource("ApolloUpgrade"), "Apollo")
    lu.assertEquals(catalog.getGodFromLootsource("WeaponUpgrade"), "Staff")
end
