-- luacheck: globals TestRunStateLogic CurrentRun IsGodTrait lib

local lu = require("luaunit")

TestRunStateLogic = {}

local function MakeStore(values)
    values = values or {}
    return {
        read = function(key)
            return values[key]
        end,
    }
end

function TestRunStateLogic:setUp()
    CurrentRun = {}
    IsGodTrait = function()
        return true
    end
    lib = {
        gameCache = {
            get = function(object, packId, moduleId, key, factory)
                object.__testGameCache = object.__testGameCache or {}
                local pack = object.__testGameCache[packId] or {}
                object.__testGameCache[packId] = pack
                local module = pack[moduleId] or {}
                pack[moduleId] = module
                if module[key] == nil then
                    module[key] = factory()
                end
                return module[key]
            end,
        },
    }
    self.module = dofile("src/mods/logic/run_state.lua")
end

function TestRunStateLogic:testScratchSupportsValuesMapsAndTake()
    local runState = self.module.create(MakeStore())

    runState.scratch.set("activeGod", "Apollo")
    lu.assertEquals(runState.scratch.get("activeGod"), "Apollo")

    runState.scratch.mapSet("offers", "DuoBoon", "ZeusUpgrade")
    lu.assertEquals(runState.scratch.mapGet("offers", "DuoBoon"), "ZeusUpgrade")
    lu.assertEquals(runState.scratch.mapTake("offers", "DuoBoon"), "ZeusUpgrade")
    lu.assertNil(runState.scratch.mapGet("offers", "DuoBoon"))

    runState.scratch.clear("activeGod")
    lu.assertNil(runState.scratch.get("activeGod"))
end

function TestRunStateLogic:testRunCacheTracksAcquisitionsPerCurrentRun()
    local runState = self.module.create(MakeStore({ ImproveFirstNBoonRarity = 2 }))

    lu.assertTrue(runState.hasCurrentRun())
    lu.assertEquals(runState.getBanPoolIndex("Apollo"), 1)
    lu.assertEquals(runState.recordAcquisition("Apollo"), 1)
    lu.assertEquals(runState.getBanPoolIndex("Apollo"), 2)

    local oldRun = CurrentRun
    CurrentRun = {}
    lu.assertEquals(runState.getBanPoolIndex("Apollo"), 1)
    CurrentRun = oldRun
    lu.assertEquals(runState.getBanPoolIndex("Apollo"), 2)
end

function TestRunStateLogic:testForcedRarityConsumesOnlyWhenConfiguredAndGodTrait()
    local runState = self.module.create(MakeStore({ ImproveFirstNBoonRarity = 1 }))

    lu.assertEquals(runState.getForcedRarityRemaining(), 1)
    lu.assertTrue(runState.shouldForceRarity({ GodLoot = true }))
    lu.assertTrue(runState.consumeForcedRarity("ApolloStrike"))
    lu.assertEquals(runState.getForcedRarityRemaining(), 0)
    lu.assertFalse(runState.consumeForcedRarity("ApolloStrike"))
end

function TestRunStateLogic:testMissingCurrentRunReturnsSafeDefaults()
    CurrentRun = nil
    local runState = self.module.create(MakeStore({ ImproveFirstNBoonRarity = 3 }))

    lu.assertFalse(runState.hasCurrentRun())
    lu.assertEquals(runState.getBanPoolIndex("Apollo"), 1)
    lu.assertNil(runState.recordAcquisition("Apollo"))
    lu.assertEquals(runState.getForcedRarityRemaining(), 0)
    lu.assertFalse(runState.consumeForcedRarity("ApolloStrike"))
end

function TestRunStateLogic:testForcedRarityDoesNotConsumeForNonGodTrait()
    IsGodTrait = function()
        return false
    end
    local runState = self.module.create(MakeStore({ ImproveFirstNBoonRarity = 1 }))

    lu.assertFalse(runState.consumeForcedRarity("NonGodTrait"))
    lu.assertEquals(runState.getForcedRarityRemaining(), 1)
end
