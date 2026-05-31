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
        controlFromLoot = function(lootName)
            return lootName == "ApolloUpgrade" and "Apollo" or nil
        end,
        controlFromTrait = function(traitName, query)
            query = query or {}
            if traitName == "Allowed"
                and (query.controlName == nil or query.controlName == "Apollo")
                and (query.tierIndex == nil or query.tierIndex == 1) then
                return {
                    controlName = "Apollo",
                    tierKey = "Apollo",
                    tierIndex = 1,
                    traitName = traitName,
                }
            end
            return nil
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

    assert(loadfile("src/mods/logic/trait_offer_finalization.lua"))({
        module = self.host,
        runState = self.runState,
        traitInfo = self.traitInfo,
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
