-- luacheck: globals TestTraitOfferFinalizationLogic GetTotalLootChoices lib

local lu = require("luaunit")

TestTraitOfferFinalizationLogic = {}

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

function TestTraitOfferFinalizationLogic:setUp()
    self.wraps = {}
    lib = {}
    GetTotalLootChoices = function()
        return 3
    end
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
        lookupLoot = function(lootName)
            if lootName == "ApolloUpgrade" then
                return {
                    controlName = "Apollo",
                    sourceName = "Apollo",
                    tierKey = "Apollo",
                    tierIndex = 1,
                }
            end
            return nil
        end,
        currentTierIndex = function()
            return 1
        end,
        resolveTrait = function(runtime, traitName, sourceInfo, tierIndex)
            local controlName = sourceInfo and sourceInfo.controlName or nil
            if traitName == "Allowed"
                and (controlName == nil or controlName == "Apollo")
                and (tierIndex == nil or tierIndex == 1) then
                return runtime.controls.get("Apollo"), {
                    controlName = "Apollo",
                    tierKey = "Apollo",
                    tierIndex = 1,
                    traitName = traitName,
                }
            end
            return nil, nil
        end,
    }
    self.runtime = {
        controls = {
            get = function(name)
                if name ~= "Apollo" then
                    return nil
                end
                return {
                    hasRarity = function()
                        return true
                    end,
                    isTierConfigured = function()
                        return true
                    end,
                    isBanned = function()
                        return false
                    end,
                    rarityOverride = function(_, traitName)
                        return traitName == "Allowed" and "Epic" or nil
                    end,
                }
            end,
        },
    }
    self.padding = assert(loadfile("src/mods/logic/padding.lua"))()

    assert(loadfile("src/mods/logic/trait_offer_finalization.lua"))({
        module = self.host,
        runState = self.runState,
        traitInfo = self.traitInfo,
        padding = self.padding,
        offerContext = {
            scratchKey = "lootOffers",
        },
    })
end

function TestTraitOfferFinalizationLogic:testSetTraitsOnLootConsumesPendingOfferAndInjectsMissingAllowedBoon()
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

    self.wraps.SetTraitsOnLoot(self.host, self.runtime, function() end, lootData, {})

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

function TestTraitOfferFinalizationLogic:testSetTraitsOnLootAppliesRarityOverrides()
    local lootData = {
        Name = "ApolloUpgrade",
        UpgradeOptions = {
            { ItemName = "Allowed" },
        },
    }

    self.wraps.SetTraitsOnLoot(self.host, self.runtime, function() end, lootData, {})

    lu.assertEquals(lootData.UpgradeOptions[1].Rarity, "Epic")
    lu.assertTrue(lootData.UpgradeOptions[1].ForceRarity)
end

function TestTraitOfferFinalizationLogic:testSetTraitsOnLootConvertsSafetyFillersToFallbackGold()
    local lootData = {
        Name = "ApolloUpgrade",
        UpgradeOptions = {
            { ItemName = "Allowed" },
            { ItemName = "BannedA", BoonBansSafetyFiller = true },
            { ItemName = "BannedB" },
        },
    }
    self.runState.scratch.mapSet("lootOffers", lootData, {
        allowed = {
            { ItemName = "Allowed" },
        },
        fullCount = 3,
        safetyFillerNames = {
            BannedA = true,
            BannedB = true,
        },
    })

    self.wraps.SetTraitsOnLoot(self.host, self.runtime, function() end, lootData, {})

    lu.assertEquals(lootData.UpgradeOptions, {
        { ItemName = "Allowed", Rarity = "Epic", ForceRarity = true },
        { ItemName = "FallbackGold", Type = "Trait", Rarity = "Common" },
        { ItemName = "FallbackGold", Type = "Trait", Rarity = "Common" },
    })
end
