-- luacheck: globals TestTraitOfferFilteringLogic TraitData GetTotalLootChoices lib

local lu = require("luaunit")

TestTraitOfferFilteringLogic = {}

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

function TestTraitOfferFilteringLogic:setUp()
    self.wraps = {}
    lib = {}
    TraitData = {
        Allowed = {},
        Banned = {},
        Blocked = {},
        Duo = { IsDuoBoon = true },
        Eligible = {},
        AshenGift = {},
    }
    GetTotalLootChoices = function()
        return 3
    end
    self.apolloConfigured = true

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
    self.runState = {
        scratch = MakeScratch(),
        getBanPoolIndex = function()
            return 1
        end,
    }
    self.traitInfo = {
        controlFromLoot = function(lootName)
            return lootName == "ApolloUpgrade" and "Apollo" or nil
        end,
        currentControlFromTrait = function(traitName)
            local query = {}
            if traitName == "Blocked" then
                query.controlName = "Apollo"
                query.tierIndex = 1
            end
            if traitName == "AshenGift" then
                query.controlName = "Hades"
                query.tierIndex = 1
            end
            query = query or {}
            if traitName == "Blocked"
                and (query.controlName == nil or query.controlName == "Apollo")
                and (query.tierIndex == nil or query.tierIndex == 1) then
                return {
                    controlName = "Apollo",
                    tierKey = "Apollo",
                    tierIndex = 1,
                    traitName = traitName,
                }
            end
            if traitName == "AshenGift" then
                return {
                    controlName = "Hades",
                    tierKey = "Hades",
                    tierIndex = 1,
                    traitName = traitName,
                }
            end
            return nil
        end,
        isBanned = function(name)
            return name == "Banned"
        end,
    }
    self.sources = {
        Apollo = {
            isTierConfigured = function()
                return self.apolloConfigured
            end,
            isBanned = function(_, traitName)
                return traitName == "Blocked"
            end,
        },
        HadesKeepsake = {
            isBanned = function(_, traitName)
                return traitName == "AshenGift"
            end,
        },
    }
    self.runtime = {
        controls = {
            get = function(name)
                return self.sources[name]
            end,
        },
    }

    assert(loadfile("src/mods/logic/trait_offer_filtering.lua"))({
        module = self.host,
        runState = self.runState,
        traitInfo = self.traitInfo,
        jpomContext = {
            isJpomOffering = false,
        },
        offerContext = {
            scratchKey = "lootOffers",
        },
    })
end

function TestTraitOfferFilteringLogic:testEligibleUpgradesEarlyExitsForUnconfiguredBanPool()
    self.apolloConfigured = false
    local vanilla = {
        { ItemName = "Allowed" },
        { ItemName = "Banned" },
    }
    local lootData = { Name = "ApolloUpgrade" }

    local queue = self.wraps.GetEligibleUpgrades(self.host, self.runtime, function()
        return vanilla
    end, {}, lootData, {})

    lu.assertEquals(queue, vanilla)
    lu.assertNil(self.runState.scratch.mapTake("lootOffers", lootData))
end

function TestTraitOfferFilteringLogic:testEligibleUpgradesStoresPendingOfferInRunStateScratch()
    local lootData = { Name = "ApolloUpgrade" }
    local fullList = {
        { ItemName = "Allowed" },
        { ItemName = "Banned" },
    }

    local queue = self.wraps.GetEligibleUpgrades(self.host, self.runtime, function()
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

function TestTraitOfferFilteringLogic:testTraitEligibilityCanBeBlocked()
    local result = self.wraps.IsTraitEligible(self.host, self.runtime, function()
        return true
    end, {
        Name = "Blocked",
    }, {})

    lu.assertFalse(result)
end

function TestTraitOfferFilteringLogic:testJpomEligibilityRoutesThroughKeepsakeControl()
    assert(loadfile("src/mods/logic/trait_offer_filtering.lua"))({
        module = self.host,
        runState = self.runState,
        traitInfo = self.traitInfo,
        jpomContext = {
            isJpomOffering = true,
        },
        offerContext = {
            scratchKey = "lootOffers",
        },
    })

    local result = self.wraps.IsTraitEligible(self.host, self.runtime, function()
        return true
    end, {
        Name = "AshenGift",
    }, {})

    lu.assertFalse(result)
end

function TestTraitOfferFilteringLogic:testTraitEligibilitySkipDuringReplacementTraitsUsesVanilla()
    local replacementCalled = false
    local eligibilityDuringReplacement = nil

    self.wraps.GetReplacementTraits(self.host, self.runtime, function()
        replacementCalled = true
        eligibilityDuringReplacement = self.wraps.IsTraitEligible(self.host, self.runtime, function()
            return true
        end, {
            Name = "Blocked",
        }, {})
        return { "Blocked" }
    end, { "Blocked" }, nil)

    lu.assertTrue(replacementCalled)
    lu.assertTrue(eligibilityDuringReplacement)
end
