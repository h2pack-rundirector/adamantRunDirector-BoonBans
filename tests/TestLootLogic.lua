-- luacheck: globals TestLootLogic TraitData GetTotalLootChoices lib
-- luacheck: globals AddRarityToTraits AddStackToTraits GetHeroTrait HeraTraitRarityPresentation IncreaseTraitLevel thread

local lu = require("luaunit")

TestLootLogic = {}

local function MakeScratch()
    local maps = {}
    return {
        mapSet = function(name, key, value)
            maps[name] = maps[name] or {}
            maps[name][key] = value
        end,
        mapTake = function(name, key)
            local map = maps[name]
            if not map then return nil end
            local value = map[key]
            map[key] = nil
            return value
        end,
    }
end

function TestLootLogic:setUp()
    self.wraps = {}
    lib = {}
    TraitData = {
        Allowed = {},
        Banned = {},
        Duo = { IsDuoBoon = true },
        Eligible = {},
    }
    GetTotalLootChoices = function()
        return 3
    end
    GetHeroTrait = function() return nil end
    AddRarityToTraits = function() return nil end
    AddStackToTraits = function() end
    HeraTraitRarityPresentation = function() end
    IncreaseTraitLevel = function() end
    thread = function(fn, ...)
        return fn(...)
    end

    self.data = {
        banConfig = {
            IsBanPoolConfigured = function()
                return true
            end,
        },
        banPools = {
            getBanPoolKey = function(godKey)
                return godKey
            end,
        },
        godDefs = {
            Apollo = {},
        },
    }

    self.host = {
        hooks = {
            wrap = function(funcName, callback)
                self.wraps[funcName] = callback
            end,
        },
        isEnabled = function()
            return true
        end,
        logIf = function() end,
    }
    self.store = {
        get = function()
            return {
                read = function()
                    return nil
                end,
            }
        end,
    }
    self.runState = {
        scratch = MakeScratch(),
        getBanPoolIndex = function()
            return 1
        end,
        shouldForceRarity = function()
            return false
        end,
    }
    self.banResolver = {
        getGodFromLootsource = function(lootName)
            return lootName == "ApolloUpgrade" and "Apollo" or nil
        end,
        isTraitBanned = function(name)
            return name == "Banned"
        end,
        getTraitRarityOverride = function(name)
            if name == "Allowed" then
                return "Epic"
            end
            return nil
        end,
        shouldBlockTraitEligibility = function(name)
            return name == "Blocked"
        end,
    }

    local lootLogic = dofile("src/mods/logic/loot_logic.lua").bind(self.data)
    lootLogic.registerHooks(self.host, self.store, self.runState, self.banResolver)
end

function TestLootLogic:testEligibleUpgradesEarlyExitsForUnconfiguredBanPool()
    self.data.banConfig.IsBanPoolConfigured = function()
        return false
    end
    local vanilla = {
        { ItemName = "Allowed" },
        { ItemName = "Banned" },
    }
    local lootData = { Name = "ApolloUpgrade" }

    local queue = self.wraps.GetEligibleUpgrades(function()
        return vanilla
    end, {}, lootData, {})

    lu.assertEquals(queue, vanilla)
    lu.assertNil(self.runState.scratch.mapTake("lootOffers", lootData))
end

function TestLootLogic:testEligibleUpgradesStoresPendingOfferInRunStateScratch()
    local lootData = { Name = "ApolloUpgrade" }
    local fullList = {
        { ItemName = "Allowed" },
        { ItemName = "Banned" },
    }

    local queue = self.wraps.GetEligibleUpgrades(function()
        return fullList
    end, {}, lootData, {})

    lu.assertEquals(queue, {
        { ItemName = "Allowed" },
    })

    local pending = self.runState.scratch.mapTake("lootOffers", lootData)
    lu.assertEquals(pending.fullCount, 2)
    lu.assertEquals(pending.allowed, {
        { ItemName = "Allowed" },
    })
end

function TestLootLogic:testSetTraitsOnLootConsumesPendingOfferAndInjectsMissingAllowedBoon()
    local lootData = {
        Name = "ApolloUpgrade",
        UpgradeOptions = {
            { ItemName = "Banned" },
            { ItemName = "Filler" },
            { ItemName = "Other" },
        },
        BlockReroll = true,
    }
    self.runState.scratch.mapSet("lootOffers", lootData, {
        allowed = {
            { ItemName = "Allowed" },
        },
        fullCount = 4,
    })

    self.wraps.SetTraitsOnLoot(function() end, lootData, {})

    local foundAllowed = false
    for _, option in ipairs(lootData.UpgradeOptions) do
        if option.ItemName == "Allowed" then
            foundAllowed = true
        end
    end

    lu.assertTrue(foundAllowed)
    lu.assertFalse(lootData.BlockReroll)
    lu.assertNil(self.runState.scratch.mapTake("lootOffers", lootData))
end

function TestLootLogic:testSetTraitsOnLootAppliesRarityOverrides()
    local lootData = {
        Name = "ApolloUpgrade",
        UpgradeOptions = {
            { ItemName = "Allowed" },
        },
    }

    self.wraps.SetTraitsOnLoot(function() end, lootData, {})

    lu.assertEquals(lootData.UpgradeOptions[1].Rarity, "Epic")
    lu.assertTrue(lootData.UpgradeOptions[1].ForceRarity)
end

function TestLootLogic:testTraitEligibilityCanBeBlocked()
    local result = self.wraps.IsTraitEligible(function()
        return true
    end, {
        Name = "Blocked",
    }, {})

    lu.assertFalse(result)
end

function TestLootLogic:testTraitEligibilitySkipDuringReplacementTraitsUsesVanilla()
    local replacementCalled = false
    local eligibilityDuringReplacement = nil

    self.wraps.GetReplacementTraits(function()
        replacementCalled = true
        eligibilityDuringReplacement = self.wraps.IsTraitEligible(function()
            return true
        end, {
            Name = "Blocked",
        }, {})
        return { "Blocked" }
    end, { "Blocked" }, nil)

    lu.assertTrue(replacementCalled)
    lu.assertTrue(eligibilityDuringReplacement)
end

function TestLootLogic:testRarityChancesCanForceEpic()
    self.runState.shouldForceRarity = function()
        return true
    end

    local chances = self.wraps.GetRarityChances(function()
        return { Common = 0.5, Rare = 0.4, Epic = 0.1 }
    end, { GodLoot = true })

    lu.assertEquals(chances, {
        Common = 0.0,
        Rare = 0.0,
        Epic = 1.0,
    })
end
