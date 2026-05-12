-- luacheck: globals TestAcquisitionLogic TraitData lib

local lu = require("luaunit")

TestAcquisitionLogic = {}

local function MakeRunState()
    local values = {}
    local maps = {}
    local counts = {}

    return {
        scratch = {
            clear = function(name)
                values[name] = nil
                maps[name] = nil
            end,
            set = function(name, value)
                values[name] = value
            end,
            get = function(name)
                return values[name]
            end,
            mapSet = function(name, key, value)
                maps[name] = maps[name] or {}
                maps[name][key] = value
            end,
            mapGet = function(name, key)
                return maps[name] and maps[name][key] or nil
            end,
        },
        hasCurrentRun = function()
            return true
        end,
        recordAcquisition = function(godKey)
            counts[godKey] = (counts[godKey] or 0) + 1
            return counts[godKey]
        end,
        getCount = function(godKey)
            return counts[godKey] or 0
        end,
        consumeForcedRarity = function()
            return true
        end,
    }
end

function TestAcquisitionLogic:setUp()
    public = {}
    _PLUGIN = { guid = "test-boon-bans-acquisition" }

    self.wraps = {}
    lib = {
        hooks = {
            Wrap = function(funcName, ...)
                local args = { ... }
                self.wraps[funcName] = args[#args]
            end,
        },
    }

    TraitData = {
        ReboundingSparkBoon = { IsDuoBoon = true },
        ZeusStrikeBoon = {},
    }

    self.data = {
        banConfig = {
            ResolveGodKey = function(key)
                return key
            end,
        },
    }

    self.runState = MakeRunState()
    self.host = {
        isEnabled = function()
            return true
        end,
        logIf = function() end,
    }
    self.banResolver = {
        getGodFromLootsource = function(lootKey)
            if lootKey == "ZeusUpgrade" then
                return "Zeus"
            end
            if lootKey == "ApolloUpgrade" then
                return "Apollo"
            end
            return nil
        end,
        getTraitGodKey = function(traitName)
            if traitName == "ZeusStrikeBoon" then
                return "Zeus"
            end
            return nil
        end,
    }

    local acquisition = dofile("src/mods/logic/acquisition.lua").bind(self.data)
    acquisition.registerHooks(self.host, self.runState, self.banResolver)
end

function TestAcquisitionLogic:testDuoAcquisitionUsesRememberedOfferSource()
    self.wraps.CreateUpgradeChoiceButton(
        function()
            return { Data = { Name = "ReboundingSparkBoon" } }
        end,
        nil,
        { Name = "ZeusUpgrade" }
    )

    self.wraps.OpenUpgradeChoiceMenu(function() end, { Name = "ApolloUpgrade" })
    self.wraps.CreateUpgradeChoiceButton(
        function()
            return { Data = { Name = "ReboundingSparkBoon" } }
        end,
        nil,
        { Name = "ZeusUpgrade" }
    )

    self.wraps.AddTraitToHero(function()
        return { Name = "ReboundingSparkBoon" }
    end, {
        FromLoot = true,
    })

    lu.assertEquals(self.runState.getCount("Zeus"), 1)
    lu.assertEquals(self.runState.getCount("Apollo"), 0)
end

function TestAcquisitionLogic:testNonDuoFallsBackToCatalog()
    self.wraps.AddTraitToHero(function()
        return { Name = "ZeusStrikeBoon" }
    end, {
        FromLoot = true,
    })

    lu.assertEquals(self.runState.getCount("Zeus"), 1)
end

function TestAcquisitionLogic:testAcquisitionOnlyAdvancesForLootWithoutSkipFlags()
    self.wraps.AddTraitToHero(function()
        return { Name = "ZeusStrikeBoon" }
    end, {})
    lu.assertEquals(self.runState.getCount("Zeus"), 0)

    self.wraps.AddTraitToHero(function()
        return { Name = "ZeusStrikeBoon" }
    end, {
        FromLoot = true,
        SkipActivatedTraitUpdate = true,
    })
    lu.assertEquals(self.runState.getCount("Zeus"), 0)

    self.wraps.AddTraitToHero(function()
        return { Name = "ZeusStrikeBoon" }
    end, {
        FromLoot = true,
    })
    lu.assertEquals(self.runState.getCount("Zeus"), 1)
end
