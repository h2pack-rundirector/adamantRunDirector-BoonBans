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
    self.contextWraps = {}
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
            contextWrap = function(funcName, callback)
                self.contextWraps[funcName] = callback
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
        getBanPoolPickCounts = function()
            return {
                Apollo = 0,
            }
        end,
    }
    self.traitInfo = {
        resolveLoot = function(runtime, lootName)
            if lootName ~= "ApolloUpgrade" then
                return nil, nil
            end
            return runtime.controls.get("Apollo"), {
                controlName = "Apollo",
                tierKey = "Apollo",
                tierIndex = 1,
            }
        end,
        resolveCurrentTrait = function(runtime, traitName)
            if traitName == "Blocked" then
                local info = {
                    controlName = "Apollo",
                    tierKey = "Apollo",
                    tierIndex = 1,
                    traitName = traitName,
                }
                return runtime.controls.get("Apollo"), info
            end
            if traitName == "AshenGift" then
                local info = {
                    controlName = "Hades",
                    tierKey = "Hades",
                    tierIndex = 1,
                    traitName = traitName,
                }
                return nil, info
            end
            return nil, nil
        end,
        currentTierIndex = function()
            return 1
        end,
        isBanned = function(name)
            return name == "Banned"
        end,
        hadesKeepsake = function(runtime)
            return runtime.controls.get("HadesKeepsake")
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
        data = {
            get = function(alias)
                return {
                    read = function()
                        return alias == "EnablePadding"
                    end,
                }
            end,
        },
        controls = {
            get = function(name)
                return self.sources[name]
            end,
        },
    }
    self.paddingCalls = {}
    self.padding = {
        readConfig = function(runtime)
            return {
                enabled = runtime.data.get("EnablePadding"):read() == true,
            }
        end,
        extendLootQueue = function(queue, opts)
            self.paddingCalls[#self.paddingCalls + 1] = opts
            queue[#queue + 1] = { ItemName = "Banned" }
        end,
    }

    assert(loadfile("src/mods/logic/trait_offer_filtering.lua"))({
        module = self.host,
        runState = self.runState,
        traitInfo = self.traitInfo,
        padding = self.padding,
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
        { ItemName = "Banned" },
    })

    local pending = self.runState.scratch.mapTake("lootOffers", lootData)
    lu.assertEquals(pending.fullCount, 2)
    lu.assertEquals(pending.allowed, {
        { ItemName = "Allowed" },
    })
    lu.assertEquals(#self.paddingCalls, 1)
    lu.assertEquals(self.paddingCalls[1].banned, {
        { ItemName = "Banned" },
    })
    lu.assertEquals(self.paddingCalls[1].sourceInfo.controlName, "Apollo")
    lu.assertEquals(self.paddingCalls[1].tierIndex, 1)
    lu.assertEquals(self.paddingCalls[1].pickCount, 0)
end

function TestTraitOfferFilteringLogic:testTraitEligibilityCanBeBlocked()
    local result = self.wraps.IsTraitEligible(self.host, self.runtime, function()
        return true
    end, {
        Name = "Blocked",
    }, {})

    lu.assertFalse(result)
end

function TestTraitOfferFilteringLogic:testTraitEligibilitySkipDuringReplacementTraitsUsesVanilla()
    local context = {
        wrap = function(funcName, callback)
            self.contextWraps[funcName] = callback
        end,
    }
    self.contextWraps.GetReplacementTraits(self.host, self.runtime, context)

    local eligibilityDuringReplacement = self.contextWraps.IsTraitEligible(function()
        return true
    end, {
        Name = "Blocked",
    }, {})

    lu.assertTrue(eligibilityDuringReplacement)
end
