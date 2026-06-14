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
            wrap = function(funcName, keyOrCallback, maybeCallback)
                self.wraps[funcName] = maybeCallback or keyOrCallback
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
    self.traitEligibility = assert(loadfile("src/mods/logic/trait_eligibility.lua"))({
        traitInfo = self.traitInfo,
    })
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
        fillLootQueue = function(queue, banned, runtime, opts)
            self.paddingCalls[#self.paddingCalls + 1] = {
                banned = banned,
                runtime = runtime,
                opts = opts,
            }
            if opts.addRealPadding ~= false then
                queue[#queue + 1] = { ItemName = "Banned" }
            end
            if #queue >= opts.queueMaxSize or opts.sourceCount < opts.minSourceCount then
                return nil
            end
            local item = banned and banned[1] or nil
            if not item then
                return nil
            end
            local filler = { ItemName = item.ItemName, BoonBansSafetyFiller = true }
            queue[#queue + 1] = filler
            return {
                [item.ItemName] = true,
            }
        end,
    }

    assert(loadfile("src/mods/logic/trait_offer_filtering.lua"))({
        module = self.host,
        runState = self.runState,
        traitInfo = self.traitInfo,
        traitEligibility = self.traitEligibility,
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
    lu.assertEquals(self.paddingCalls[1].opts.sourceInfo.controlName, "Apollo")
    lu.assertEquals(self.paddingCalls[1].opts.tierIndex, 1)
    lu.assertEquals(self.paddingCalls[1].opts.pickCount, 0)
end

function TestTraitOfferFilteringLogic:testEligibleUpgradesFillsArtificialShortQueueWithSafetyOption()
    self.padding.fillLootQueue = function(queue, banned, _, opts)
        if #queue >= opts.queueMaxSize or opts.sourceCount < opts.minSourceCount then
            return nil
        end
        local item = banned and banned[1] or nil
        if not item then
            return nil
        end
        local filler = { ItemName = item.ItemName, BoonBansSafetyFiller = true }
        queue[#queue + 1] = filler
        return {
            [item.ItemName] = true,
        }
    end
    local lootData = { Name = "ApolloUpgrade" }
    local fullList = {
        { ItemName = "Allowed" },
        { ItemName = "Eligible" },
        { ItemName = "Banned" },
    }

    local queue = self.wraps.GetEligibleUpgrades(self.host, self.runtime, function()
        return fullList
    end, {}, lootData, {})

    lu.assertEquals(queue, {
        { ItemName = "Allowed" },
        { ItemName = "Eligible" },
        { ItemName = "Banned", BoonBansSafetyFiller = true },
    })

    local pending = self.runState.scratch.mapTake("lootOffers", lootData)
    lu.assertEquals(pending.safetyFillerNames, {
        Banned = true,
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

function TestTraitOfferFilteringLogic:testTraitEligibilityNilTraitUsesVanilla()
    local result = self.wraps.IsTraitEligible(self.host, self.runtime, function(traitData)
        lu.assertNil(traitData)
        return false
    end, nil, {})

    lu.assertFalse(result)
end

function TestTraitOfferFilteringLogic:testTraitEligibilitySkipDuringReplacementTraitsUsesVanilla()
    local eligibilityDuringReplacement = nil
    self.wraps.GetReplacementTraits(self.host, self.runtime, function()
        eligibilityDuringReplacement = self.wraps.IsTraitEligible(self.host, self.runtime, function()
            return true
        end, {
            Name = "Blocked",
        }, {})
    end)

    lu.assertTrue(eligibilityDuringReplacement)
end

function TestTraitOfferFilteringLogic:testReplacementTraitsUsesVanillaWhenDisabled()
    self.host.isEnabled = function()
        return false
    end

    local result = self.wraps.GetReplacementTraits(self.host, self.runtime, function(value)
        return value
    end, "vanilla")

    lu.assertEquals(result, "vanilla")
end
